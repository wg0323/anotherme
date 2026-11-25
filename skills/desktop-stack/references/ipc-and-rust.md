# Rust 命令与前端调用

## 一、注册与调用

```rust
// src-tauri/src/lib.rs
mod ports;

#[tauri::command]
fn read_config(path: String) -> Result<String, String> {
    std::fs::read_to_string(&path).map_err(|e| format!("读取失败：{e}"))
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![read_config, ports::list_ports])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

```ts
// src/api.ts —— 唯一的 invoke 出口
import { invoke } from '@tauri-apps/api/core'

export interface PortItem {
  port: number
  pid: number
  processName: string
}

export const api = {
  readConfig: (path: string) => invoke<string>('read_config', { path }),
  listPorts: () => invoke<PortItem[]>('list_ports')
}
```

| 约定 | 说明 |
| --- | --- |
| 命名 | 命令 snake_case，前端方法 camelCase，一一对应 |
| 参数 | JS 传 camelCase，Rust 用 snake_case，Tauri 自动转换（`taskId` → `task_id`） |
| 返回类型 | `invoke<T>` 显式标注；Rust 结构体加 `#[serde(rename_all = "camelCase")]` 与 TS 接口对齐 |
| 单一出口 | 页面只 import `api`，不直接 import `invoke`；改命令名时只改一处 |

## 二、错误

- 统一 `Result<T, String>`，错误文案写给用户看：中文、说清哪一步失败，不返回 `unwrap()` 的堆栈。
- 需要区分错误类型时用 `thiserror` 定义枚举，并实现 `Serialize`（或统一转 `String`）后再返回；命令里不 `panic!`，panic 在前端只表现为一个无信息的 rejection。
- 前端在 `api.ts` 外层统一把 `unknown` 错误转成可展示文案，页面只处理业务分支。

```ts
async function call<T>(fn: () => Promise<T>, tips: string): Promise<T | null> {
  try {
    return await fn()
  } catch (e) {
    console.error(tips, e)
    return null
  }
}
```

## 三、长任务与事件

命令里不跑耗时循环，否则 IPC 卡住、窗口操作也会迟滞：

```rust
use tauri::Emitter;   // emit 在 Emitter trait 上，必须导入

#[tauri::command]
async fn scan(app: tauri::AppHandle) -> Result<(), String> {
    let _ = tauri::async_runtime::spawn(async move {
        for i in 0..100 {
            let _ = app.emit("scan-progress", i);
        }
        let _ = app.emit("scan-done", ());
    });
    Ok(())
}
```

```ts
import { listen } from '@tauri-apps/api/event'

const unlisten = await listen<number>('scan-progress', (e) => {
  progress.value = e.payload
})
// 组件卸载时调用 unlisten()
```

- 需要取消的任务：命令返回 `taskId`，用 `tauri::State` 保存子进程 PID 或取消标志，再提供 `task_cancel(task_id)`。
- 事件名用 kebab-case，payload 用可序列化结构，不传拼接字符串。
- 事件监听必须在组件卸载时注销，否则重复进入页面会叠加回调。

## 四、子进程与编码

```rust
#[cfg(windows)]
use std::os::windows::process::CommandExt;

let mut cmd = std::process::Command::new("jvms");
cmd.args(["list"]);                                  // 不拼 cmd /c 字符串
#[cfg(windows)]
cmd.creation_flags(0x0800_0000);                     // CREATE_NO_WINDOW
let out = cmd.output().map_err(|e| e.to_string())?;

// 中文 Windows 下命令行输出常为 GBK
let (text, _, _) = encoding_rs::GBK.decode(&out.stdout);
```

| 规则 | 原因 |
| --- | --- |
| 一律 `creation_flags(CREATE_NO_WINDOW)` | 否则 GUI 应用每调一次命令行闪一次黑框 |
| 参数用 `.args([...])`，不拼 `cmd /c "..."` | 避免空格路径与命令注入 |
| GBK 输出用 `encoding_rs` | 直接 `String::from_utf8` 会得到乱码或直接失败 |
| 结束进程按 PID 精确匹配 | 禁止 `taskkill /IM xxx.exe /F` 批量杀，会误伤用户其他进程 |
| 等待子进程设超时 | 卡死的命令行会把命令线程一直占住 |

## 五、路径、配置与日志

- 数据目录用 `app.path().app_data_dir()` / `app_config_dir()`，不硬编码 `%APPDATA%`。
- 键值配置用 `tauri-plugin-store`；结构化配置自己读写 JSON 也行，但要固定到应用目录。
- 日志用 `tauri-plugin-log`，输出到应用日志目录，方便用户回传排查。
- 文件操作前校验路径：前端传入的路径必须落在允许目录内，防止前端被注入后任意读写。

## 六、权限声明

```json
{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "default",
  "description": "Capability for the main window",
  "windows": ["main"],
  "permissions": [
    "core:default",
    "core:window:allow-start-dragging",
    "autostart:default"
  ]
}
```

- `windows` 匹配窗口 `label`，不是标题。
- 插件权限格式 `<plugin>:<permission>`，默认集是 `<plugin>:default`，单条命令是 `<plugin>:allow-xxx`。
- 自定义命令默认对所有窗口开放；要收紧时在 `build.rs` 声明：

```rust
fn main() {
    tauri_build::try_build(
        tauri_build::Attributes::new()
            .app_manifest(tauri_build::AppManifest::new().commands(&["read_config"])),
    )
    .unwrap();
}
```

- 运行时报 `not allowed`：先确认命令属于哪个插件，再确认权限标识是否写到了该命令的 `allow-*`。授权过宽的 scope 等于没设边界。
