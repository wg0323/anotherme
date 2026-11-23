# PC 管理后台：Vue 3 + Element Plus

适用：运营后台、管理系统、内部工具、数据看板。不适用：需要 SEO 的官网、C 端商城前台（走 `mobile-uniapp.md` 的 H5）。

## 一、起步模板

| 模板 | 规模 | 适合 |
| --- | --- | --- |
| `vue-pure-admin` | 20.8k Star，ESM + Vue3 + Vite + Element Plus + TS + Pinia + Tailwind | 默认选择：登录、权限路由、多标签、请求封装、主题都现成 |
| `Geeker-Admin` | 8.1k Star，Vue3 + Vite + Element Plus + TS + Pinia | 需求简单、只要 CRUD 与基础布局时更轻 |

```bash
git clone https://github.com/pure-admin/vue-pure-admin.git my-admin
cd my-admin
rm -rf .git          # 换成自己的仓库
# 改 package.json 里的 name/version，按模板 README 安装依赖
```

不要用 `npm create vue` 从零搭后台：登录态、动态菜单、权限路由、统一布局这四件事都要自己重写一遍，与“前端不是强项”的前提相悖。

## 二、目录约定

```text
src/
├── api/          # 接口按模块拆，一个业务模块一个文件
├── views/        # 页面，与路由一一对应
├── components/   # 跨页面复用组件
├── router/       # 路由与权限守卫
├── store/        # Pinia
├── utils/        # 请求封装、格式化、校验
├── layout/       # 布局骨架，模板提供，不手改结构
└── assets/
```

页面里不写接口地址、不写 Token、不写 baseURL；这三样只出现在 `utils/` 与 `.env.*`。

## 三、请求层封装

```ts
// src/utils/request.ts
import axios from 'axios'
import { ElMessage } from 'element-plus'

const request = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  timeout: 15000
})

request.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

request.interceptors.response.use(
  (response) => {
    // 字段名按后端统一返回体调整
    const { code, message, data } = response.data
    if (code === 200) {
      return data
    }
    ElMessage.error(message || '请求失败')
    if (code === 401) {
      location.href = `/login?redirect=${encodeURIComponent(location.pathname)}`
    }
    return Promise.reject(new Error(message || '请求失败'))
  },
  (error) => {
    ElMessage.error(error.message || '网络异常')
    return Promise.reject(error)
  }
)

export default request
```

业务层只写接口函数，不在页面里拼 URL：

```ts
// src/api/user.ts
import request from '@/utils/request'

export const getUserPage = (params: { pageNum: number; pageSize: number }) =>
  request.get('/system/user/page', { params })
```

## 四、环境与代理

`.env.development` 只写相对路径 `/api`，由 Vite 代理转发，避免代码里出现后端 IP：

```ts
// vite.config.ts
export default defineConfig({
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true
      }
    }
  }
})
```

`.env.production` 保持 `/api` 不变，生产环境由 nginx 反代到后端。环境差异交给代理层，前端不打环境补丁。

## 五、部署

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;   # history 路由刷新不 404 的关键
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

构建命令与产物目录以模板 `package.json` 为准（vue-pure-admin 为 `pnpm build` → `dist`），写进项目 README。

## 六、依赖与版本纪律

- 提交 lock 文件（`pnpm-lock.yaml` 或 `package-lock.json`），不用 `^` 之外的范围写得过宽。
- Element Plus 固定 2.14.x 这一档，升级前看 CHANGELOG 的 Breaking Changes。
- UI 库只装 Element Plus；图标用 `@element-plus/icons-vue`，不另引图标库。
- 图表用 ECharts 5，不引入第二套图表库。

## 七、禁止项

- 页面里直接 `axios.get(...)`、直接读 `localStorage.getItem('token')`。
- 在 `views/` 里写死 `http://192.168.x.x:8080`。
- 引入第二套 UI 库（Ant Design Vue、Naive UI、Vant）做“局部更好看”。
- 改 `layout/` 骨架来适配单个页面；页面视觉一律按 `ui-fidelity` 的基线规则处理。
