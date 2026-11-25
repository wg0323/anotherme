---
name: desktop-stack
description: |
  Windows 桌面小工具的固定技术栈与工程约束。当用户新建桌面小工具、托盘/悬浮窗/常驻工具、
  本地单机软件，或选择桌面壳（Tauri 2 / Electron）、确定 Tauri 工程结构、IPC 封装、打包分发方式时使用本技能。
  负责“选什么、从哪起步”；HTML/CSS/JS/TS 语言规范归 frontend-spec，后台与移动端选型归 frontend-stack。
---

# Windows 桌面小工具技术栈

面向“单机、单人、单窗口为主”的 Windows 小工具，固定 `Tauri 2 + Vite + Vue 3 + TypeScript + Naive UI`。配置口径 2026-11-25 按官方 config schema 2.12.7 核实。

## 一、默认栈

| 维度 | 选择 | 说明 |
| --- | --- | --- |
| 桌面壳 | Tauri 2 | 复用系统 WebView2，安装包与常驻内存远小于 Electron |
| 前端 | Vue 3 + Vite + TypeScript | `strict: true`，不写 JS |
| UI 库 | Naive UI 2.x | TS 类型完整、内置暗色主题、不依赖 sass，适合小窗口 |
| 图标 | `@vicons/*` 按需 | 不引第二套图标库 |
| 状态 | 先 `ref`/`reactive`；跨页共享超过两处再上 Pinia | 小工具不预置 Pinia |
| 路由 | 单窗口用状态切视图，不引 Vue Router；确需路由用 hash 模式 | 避免自定义协议下 history 404 |
| 系统能力 | Rust + `windows` crate | 前端只 `invoke`，不拼 PowerShell |
| 打包 | NSIS（主）+ MSI | 产物在 `src-tauri/target/release/bundle` |
| 起步 | `npm create tauri-app@latest` → Vue + TypeScript | 详见 `references/scaffold.md` |

## 二、铁律

1. 桌面壳只选 Tauri 2，新工具不引 Electron；存量 Electron 项目沿用、不迁移。
2. 所有系统能力在 Rust 侧实现为 `#[tauri::command]`，前端只经 `src/api.ts` 调用。页面里不出现裸 `invoke("...")`。
3. 命令统一返回 `Result<T, String>`，前端每个调用都处理失败分支；不写 `await invoke(...)` 之后无 catch。
4. 阻塞型工作（进程、文件遍历、下载）不占命令线程：用 `std::thread` 或 `spawn_blocking`，长任务用 `app.emit` 推事件。
5. 调子进程必须隐藏控制台：Windows 加 `CREATE_NO_WINDOW`，否则每条命令闪黑框；GBK 输出用 `encoding_rs` 解码。
6. 插件能力必须在 `src-tauri/capabilities/*.json` 声明，缺失时运行时报 `not allowed`；自定义命令默认不受限，敏感命令用 `build.rs` 的 `AppManifest::commands` 纳入权限体系。
7. `identifier` 用反向域名（`com.<name>.<tool>`），发布后不改；`com.tauri.dev` 会被构建拒绝。
8. 窗口形态写 `tauri.conf.json`（`decorations` / `transparent` / `alwaysOnTop` / `skipTaskbar` / `windowEffects`），不用前端 CSS 伪造；无边框窗口必须自己实现拖拽区与关闭按钮。
9. 窗口效果需 `transparent: true`；`acrylic` / `blur` 在拖动缩放时明显掉帧，Win11 优先 `mica` 系列。
10. 需管理员权限的操作不静默提权：检测后提示，并提供“以管理员身份重启”。
11. 不做后端、账号、云同步、自动更新服务；确需时单独评估，不默认加。
12. 新建工程交付 README：WebView2 依赖、Node/Rust/MSVC 版本、开发命令、打包命令与产物路径。

## 三、最小调用约定

```rust
// src-tauri/src/lib.rs
#[tauri::command]
fn read_config(path: String) -> Result<String, String> {
    std::fs::read_to_string(&path).map_err(|e| format!("读取失败：{e}"))
}
```

```ts
// src/api.ts —— 唯一的 invoke 出口
import { invoke } from '@tauri-apps/api/core'

export const api = {
  readConfig: (path: string) => invoke<string>('read_config', { path })
}
```

- 命令名 snake_case，前端方法名 camelCase，一一对应。
- JS 入参 camelCase 对应 Rust 参数 snake_case，Tauri 自动转换（`taskId` → `task_id`）。
- Rust 结构体加 `#[serde(rename_all = "camelCase")]`，与前端 TS 接口字段保持一致。

## 四、按场景读取

| 场景 | 参考文件 |
| --- | --- |
| 新建工程：环境版本、脚手架、vite/tsconfig/tauri.conf 基线、目录 | `references/scaffold.md` |
| Rust 命令：错误、长任务与事件、子进程与编码、路径与日志、权限 | `references/ipc-and-rust.md` |
| 窗口形态：无边框/透明/置顶、窗口效果、托盘、自启动、单实例、快捷键 | `references/windows-shell.md` |
| 打包分发：NSIS/MSI、图标、WebView2 安装模式、版本号、签名、批处理脚本 | `references/packaging.md` |

## 五、边界与分工

- 只覆盖 Windows。需要 macOS/Linux 同时交付时仍是 Tauri，但窗口效果、托盘、自启动要按平台分支，不能照搬这里。
- 需要重型原生控件、COM 组件、驱动交互时评估 WPF / WinUI 3，不硬套 WebView。
- 桌面小工具不为了“能联网”引入后端；确需服务端时按 `springboot-spec` 单独建。
- HTML/CSS/JS/TS 语言规范归 `frontend-spec`；后台与移动端选型归 `frontend-stack`；模板内视觉保真归 `ui-fidelity`。
