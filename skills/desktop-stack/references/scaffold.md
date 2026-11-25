# 新建桌面小工具工程

## 一、环境要求

| 项 | 要求 | 说明 |
| --- | --- | --- |
| Windows | 10 / 11 64 位 | 运行依赖 WebView2 Runtime（Win11 自带，Win10 多数已随 Edge 安装） |
| Node | 20 LTS 及以上 | 以 Vite 版本 `engines` 为准 |
| Rust | 1.85+（`edition = "2024"`）；用 autostart / single-instance 插件时 1.90+ | 1.90 是这两个插件文档标注的最低版本 |
| 构建工具 | VS Build Tools（MSVC + Windows SDK） | 只装 VS Code 不够 |

先自行确认：

```bash
node -v
rustc -V
cargo -V
```

缺 MSVC 时 `tauri dev` 的表现是链接器 `link.exe not found`，不是 Rust 代码问题。

## 二、创建工程

```bash
npm create tauri-app@latest my-tool
cd my-tool
npm install
npm run tauri dev
```

交互选择：

| 提示 | 选择 |
| --- | --- |
| Frontend language | TypeScript / JavaScript |
| Package manager | npm |
| UI template | Vue |
| UI flavor | TypeScript |

首次 `tauri dev` 要编译整个 Rust 依赖树，几分钟属正常。非交互参数随 CLI 版本变化，需要时查 `npm create tauri-app@latest -- --help`，不照抄网上旧参数。

## 三、目录

```text
my-tool/
├── src/                  # Vue 前端
│   ├── api.ts            # 唯一的 invoke 出口 + 类型定义
│   ├── components/
│   ├── views/
│   ├── App.vue
│   └── main.ts
├── src-tauri/
│   ├── src/
│   │   ├── lib.rs        # Builder、插件、invoke_handler 注册
│   │   ├── main.rs
│   │   └── <domain>.rs   # 一类系统能力一个模块
│   ├── capabilities/default.json
│   ├── icons/
│   ├── Cargo.toml
│   └── tauri.conf.json
├── vite.config.ts
├── tsconfig.json
└── package.json
```

- `src/` 按真实视图拆，不放“以后可能用到”的抽象层。
- `src-tauri/src/` 按能力拆（如 `ports.rs`、`files.rs`），命令名与 `api.ts` 方法名一一对应。
- 不手工改 `src-tauri/gen/`，那是 CLI 生成的 schema。

## 四、vite.config.ts

Tauri 要求固定端口，且不能让 Vite 监听 `src-tauri`（Rust 编译产物会触发前端热更新）：

```ts
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
// @ts-expect-error 未装 @types/node 时的类型报错
import process from 'node:process'

const host = process.env.TAURI_DEV_HOST

export default defineConfig({
  plugins: [vue()],
  clearScreen: false,                 // 不覆盖 Rust 编译报错
  server: {
    port: 1420,
    strictPort: true,                 // 端口被占时直接失败，避免壳连错地址
    host: host || false,
    hmr: host ? { protocol: 'ws', host, port: 1421 } : undefined,
    watch: { ignored: ['**/src-tauri/**'] }
  }
})
```

`devUrl` 与 `port` 必须一致；改端口要两处一起改。

## 五、tauri.conf.json 基线

```json
{
  "$schema": "https://schema.tauri.app/config/2",
  "productName": "MyTool",
  "version": "0.1.0",
  "identifier": "com.yourname.mytool",
  "build": {
    "beforeDevCommand": "npm run dev",
    "devUrl": "http://localhost:1420",
    "beforeBuildCommand": "npm run build",
    "frontendDist": "../dist"
  },
  "app": {
    "windows": [
      {
        "label": "main",
        "title": "MyTool",
        "width": 900,
        "height": 640,
        "minWidth": 720,
        "minHeight": 480,
        "center": true
      }
    ],
    "security": {
      "csp": "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'"
    }
  },
  "bundle": {
    "active": true,
    "targets": ["nsis", "msi"],
    "icon": [
      "icons/32x32.png",
      "icons/128x128.png",
      "icons/128x128@2x.png",
      "icons/icon.ico"
    ]
  }
}
```

| 要点 | 原因 |
| --- | --- |
| 主窗口 `label` 固定 `main` | capabilities 的 `windows` 按 label 匹配，写错权限不生效 |
| `frontendDist` 与 Vite 默认 `outDir`（`dist`）对齐 | 不对齐时生产包加载空白页 |
| `csp` 不写 `null` | 关闭 CSP 等于放弃前端被注入后的第一道约束；Naive UI 用内联样式，`style-src` 需 `'unsafe-inline'`。用 `convertFileSrc` 显示本地图片补 `asset:`，访问本地 HTTP 服务补 `connect-src` |
| 不开 `withGlobalTauri` | 前端用 `@tauri-apps/api` 的 ESM 导入，少暴露一个全局对象 |
| `identifier` 用反向域名 | 发布后改动会换掉 WebView2 数据目录与单实例标识 |

## 六、package.json 脚本

```json
{
  "scripts": {
    "dev": "vite",
    "build": "vue-tsc --noEmit && vite build",
    "preview": "vite preview",
    "tauri": "tauri"
  }
}
```

日常用 `npm run tauri dev`、`npm run tauri build`；给非命令行用户再加一层 `package.bat`（见 `packaging.md`）。`build` 串联 `vue-tsc --noEmit`，保证打包前类型必须通过。

## 七、版本号三处一致

`package.json`、`src-tauri/Cargo.toml`、`src-tauri/tauri.conf.json` 都有版本号。发版前对齐，否则安装包文件名、关于页、Cargo 元数据会互相矛盾。以 `package.json` 为准，改另外两处。

## 八、为什么不是 Electron

| 维度 | Tauri 2 | Electron |
| --- | --- | --- |
| 运行时 | 系统 WebView2 | 自带 Chromium |
| 安装包 | 几 MB 起 | 80 MB 起 |
| 常驻内存 | 交给系统 WebView2 | 每个窗口一套 Chromium 进程树 |
| 系统能力 | Rust 实现，权限按窗口声明 | Node 全量能力，边界靠自觉 |
| 代价 | 需要 Rust + MSVC；Win10 依赖 WebView2 | 纯前端即可，体积与内存高 |

小工具更在意体积、启动速度和常驻内存，选 Tauri。只有在必须支持 Win7、或团队完全没有 Rust 能力时才评估 Electron；存量 Electron 项目不为统一而迁移。
