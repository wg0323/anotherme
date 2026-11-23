# 移动端：uni-app + uview-plus

适用：移动端 H5、微信公众号内页、微信小程序、Android/iOS App，一套代码多端。不适用：只交付 H5 且项目已有 Vant（沿用现状）。

## 一、创建工程

```bash
npx degit dcloudio/uni-preset-vue#vite-ts my-app
cd my-app
npm install
npm run dev:h5          # 浏览器调试
npm run dev:mp-weixin   # 产物在 dist/dev/mp-weixin，用微信开发者工具导入
```

- 用 TypeScript 模板（`vite-ts`），与 `uniapp-spec` 的 `<script setup lang="ts">` 要求一致。
- 用 HBuilderX 直接打开该目录即可运行到手机、调用云打包；CLI 与 HBuilderX 可以共用同一个工程。
- 不用 uni-app x：uts 生态和 uview-plus 都不支持，组件与资料都少。
- 不用 Vue2 版 uni-app：Vue2 已 EOL，新项目无理由选。

## 二、接入 uview-plus

```bash
npm install uview-plus@3.8.138   # 锁死：npm 上最后一个 MIT 版本，不要带 ^
npm install -D sass@1.63.2       # Sass 1.8.0+ 会对 @import 持续报弃用告警，按官方建议锁版本
```

```json
// package.json 里必须是精确版本，出现 ^ 或 ~ 就说明锁失败了
{
  "dependencies": {
    "uview-plus": "3.8.138"
  }
}
```

3.8.139（2026-10-30）起官方转付费授权，新版只在 DCloud 插件市场分发（当前市场版 3.8.161，普通授权 99 元、源码授权 199 元）。本项目固定 `3.8.138`，三条红线：不执行 `npm update`；不写成 `^3.8.138`；不从插件市场导入 3.8.139+ 的源码。lock 文件一并提交，保证换机器、换 CI 装到同一版本。

需要 3.8.139 之后才有的修复或组件时，不要升级，也不要买授权后混用两个来源——换备选 `wot-design-uni`（MIT）。

官方文档站描述的是当前市场版（3.8.161），个别组件的参数与行为可能与 3.8.138 有出入；查文档时以本地 `node_modules/uview-plus/components/<组件名>/` 的源码为准，文档对不上就按源码来。

```ts
// src/main.ts
import { createSSRApp } from 'vue'
import { createPinia } from 'pinia'
import uviewPlus from 'uview-plus'
import App from './App.vue'

export function createApp() {
  const app = createSSRApp(App)
  app.use(createPinia())
  app.use(uviewPlus)
  return { app }
}
```

```ts
// src/types/uview-plus.d.ts —— 该包不带类型声明，不加这行 tsc 会报找不到声明文件
declare module 'uview-plus' {
  import type { Plugin } from 'vue'
  const uviewPlus: Plugin
  export default uviewPlus
}
```

```scss
/* src/uni.scss 末尾追加主题变量 */
@import 'uview-plus/theme.scss';
```

```vue
<!-- src/App.vue 的 style 中加入基础样式 -->
<style lang="scss">
@import 'uview-plus/index.scss';
</style>
```

```json
// src/pages.json，easycom 规则顺序不能调：^u-- 必须排在 ^u- 之前
{
  "easycom": {
    "autoscan": true,
    "custom": {
      "^u--(.*)": "uview-plus/components/u-$1/u-$1.vue",
      "^up-(.*)": "uview-plus/components/u-$1/u-$1.vue",
      "^u-([^-].*)": "uview-plus/components/u-$1/u-$1.vue"
    }
  }
}
```

组件统一写 `up-` 前缀（如 `<up-button>`），避免与 uni-app 内置组件重名。改完 easycom 要重启开发服务才生效。

## 三、目录约定

```text
src/
├── api/          # 接口按模块拆
├── pages/        # 页面与 pages.json 一一对应，含分包目录
├── components/   # 跨页面组件，easycom 自动注册
├── config/       # 接口前缀、业务常量
├── store/        # Pinia
├── static/       # 图片等静态资源
├── utils/        # 请求封装、格式化
└── types/        # 全局类型声明
```

## 四、请求层封装

```ts
// src/config/index.ts
// H5 走同域 /api 由 nginx 或 devServer 代理；小程序与 App 必须填已备案的 HTTPS 域名
export const BASE_URL = '/api'
```

```ts
// src/utils/request.ts
import { BASE_URL } from '@/config'

interface ApiResult<T> {
  code: number
  message: string
  data: T
}

export const request = <T>(options: UniApp.RequestOptions): Promise<T> =>
  new Promise((resolve, reject) => {
    uni.request({
      ...options,
      url: BASE_URL + options.url,
      header: {
        Authorization: `Bearer ${uni.getStorageSync('token') || ''}`,
        ...options.header
      },
      success: (res) => {
        const body = res.data as ApiResult<T>
        if (res.statusCode === 200 && body.code === 200) {
          resolve(body.data)
          return
        }
        if (body.code === 401) {
          uni.reLaunch({ url: '/pages/login/login' })
        }
        uni.showToast({ title: body.message || '请求失败', icon: 'none' })
        reject(new Error(body.message || '请求失败'))
      },
      fail: (err) => {
        uni.showToast({ title: '网络异常，请稍后重试', icon: 'none' })
        reject(err)
      }
    })
  })
```

页面只调 `api/` 里的函数，不直接写 `uni.request`，也不写接口域名。

## 五、多端差异

| 项 | 处理方式 |
| --- | --- |
| 接口地址 | 前端只写相对 `/api`；H5 由代理转发，小程序/App 在部署侧改成 HTTPS 域名前缀 |
| 小程序域名 | request 域名必须 HTTPS 且在微信公众平台配置合法域名；开发者工具可临时勾选“不校验合法域名”，上线前必须配 |
| 登录 | 小程序 `uni.login()` 取 code 交后端换 token；App 用 `uni.login({ provider: 'weixin' })`；H5 公众号授权走同一 API |
| 鉴权 | App 端没有 Cookie，Token 只放 header |
| 样式单位 | 用 rpx；px 仅用于 1px 边框与纯 H5 元素 |
| 条件编译 | `#ifdef MP-WEIXIN` / `#ifdef APP-PLUS` / `#ifdef H5`，仅在端能力确实不同时使用 |
| 页面栈 | 小程序最多 10 层，深层跳转用 `redirectTo`/`reLaunch`，tabBar 页用 `switchTab` |
| nvue | 只支持 flex 布局，非必要不用 nvue 页面 |

## 六、打包发布

| 端 | 命令 / 入口 | 产物与去处 |
| --- | --- | --- |
| H5 | `npm run build:h5` | `dist/build/h5` → nginx，history 路由配 `try_files $uri $uri/ /index.html` |
| 微信小程序 | `npm run build:mp-weixin` | `dist/build/mp-weixin` → 微信开发者工具导入、上传体验版 |
| App | HBuilderX → 发行 → 原生 App 云打包 | 需 DCloud 账号 + Android 证书、iOS 证书与描述文件，产出 apk / ipa |

## 七、禁止项

- 引入 `vant`、`vant-weapp` 或任何第二套 UI 库。
- 页面里裸调 `uni.request`、写死接口域名与 Token。
- 用 Vue2 的 Options API 写页面（`uniapp-spec` 已强制 `<script setup lang="ts">`）。
- 被网上教程带去装 uni-app x / uts 插件，与本栈组件不兼容。
- 在 H5 与小程序里各写一份同名页面，只为绕开端差异。
- 把 `uview-plus` 升到 3.8.139+、写成 `^3.8.138`，或从插件市场导入新版源码——这三件事都会把项目带到付费授权范围内。
