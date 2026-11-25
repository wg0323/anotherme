# 窗口形态与常驻能力

## 一、窗口配置

在 `tauri.conf.json` 的 `app.windows[]` 里改，不要在页面里用 CSS 伪造系统窗口行为：

| 字段 | 作用 | 备注 |
| --- | --- | --- |
| `label` | 窗口标识 | 与 capabilities 对应，主窗口固定 `main` |
| `decorations` | 系统标题栏与边框 | `false` 时自行实现拖拽与按钮 |
| `transparent` | 透明背景 | 窗口效果的前置条件 |
| `alwaysOnTop` | 置顶 | 悬浮类小工具 |
| `skipTaskbar` | 不在任务栏显示 | 托盘常驻工具 |
| `resizable` | 是否可缩放 | 固定尺寸小工具设 `false` |
| `minWidth` / `minHeight` | 最小尺寸 | 防止布局压塌 |
| `windowEffects` | 系统材质 | `mica` / `acrylic` 等 |
| `shadow` | 系统投影 | 与透明窗口搭配时按视觉决定 |
| `center` | 启动居中 | 小窗口默认开 |

窗口效果：

```json
{
  "transparent": true,
  "windowEffects": { "effects": ["mica"] }
}
```

- 必须 `transparent: true`，否则效果不生效。
- `mica` / `micaDark` / `micaLight` / `tabbed` / `tabbedDark` / `tabbedLight` 仅 Windows 11。
- `acrylic` 支持 Win10/11；`blur` 支持 Win7/10/11 22H1。
- 官方 schema 明确：`acrylic` 与 `blur` 在拖动、缩放窗口时性能差。小工具优先 `mica`；只能用 acrylic 时把窗口设为不可缩放。
- 启用系统标题栏或阴影时效果可能异常，必要时同时关掉 `decorations` / `shadow`。

## 二、无边框窗口

声明式拖拽区：

```html
<div class="titlebar" data-tauri-drag-region>
  <span>Toolbox</span>
  <button @click="minimize">—</button>
  <button @click="close">×</button>
</div>
```

- `data-tauri-drag-region` 只对带该属性的元素生效，不继承给子元素；子元素也要能拖动就逐个加。
- 不要把整页设成拖拽区，否则输入框与按钮会失灵。

需要双击最大化或自定义逻辑时手动调用：

```ts
import { getCurrentWindow } from '@tauri-apps/api/window'

const win = getCurrentWindow()

async function onTitlebarMouseDown(e: MouseEvent) {
  if (e.buttons !== 1) return
  e.detail === 2 ? await win.toggleMaximize() : await win.startDragging()
}
```

```ts
await win.minimize()
await win.toggleMaximize()
await win.close()
```

所需权限：

```json
"permissions": [
  "core:window:default",
  "core:window:allow-start-dragging",
  "core:window:allow-minimize",
  "core:window:allow-toggle-maximize",
  "core:window:allow-close"
]
```

## 三、托盘

`src-tauri/Cargo.toml` 开启内置 feature：

```toml
tauri = { version = "2", features = ["tray-icon"] }
```

`lib.rs` 在 `.setup(|app| { ... })` 里创建：

```rust
use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    Manager,
};

fn show_main(app: &tauri::AppHandle) {
    if let Some(win) = app.get_webview_window("main") {
        let _ = win.unminimize();
        let _ = win.show();
        let _ = win.set_focus();
    }
}

let show = MenuItem::with_id(app, "show", "显示", true, None::<&str>)?;
let quit = MenuItem::with_id(app, "quit", "退出", true, None::<&str>)?;
let menu = Menu::with_items(app, &[&show, &quit])?;

TrayIconBuilder::new()
    .icon(app.default_window_icon().unwrap().clone())
    .menu(&menu)
    .show_menu_on_left_click(false)
    .on_menu_event(|app, event| match event.id.as_ref() {
        "show" => show_main(app),
        "quit" => app.exit(0),
        _ => {}
    })
    .on_tray_icon_event(|tray, event| {
        if let TrayIconEvent::Click {
            button: MouseButton::Left,
            button_state: MouseButtonState::Up,
            ..
        } = event
        {
            show_main(tray.app_handle());
        }
    })
    .build(app)?;
```

关闭窗口时隐藏到托盘，在同一个 `tauri::Builder` 链上加：

```rust
.on_window_event(|window, event| {
    if let tauri::WindowEvent::CloseRequested { api, .. } = event {
        api.prevent_close();
        let _ = window.hide();
    }
})
```

- 真正退出只走托盘菜单的 `app.exit(0)`；否则用户关不掉进程。
- Windows 托盘图标用 `icon.ico`，只有 png 时托盘可能不显示。
- Rust 侧创建托盘不需要权限；JS 侧调托盘 API 需要在 capabilities 里给 `core:tray:default`。

## 四、开机自启

```bash
npm run tauri add autostart
```

命令会加 Cargo 依赖、装 `@tauri-apps/plugin-autostart`、补 `autostart:default` 权限。初始化：

```rust
use tauri::Manager;

#[cfg(desktop)]
app.handle().plugin(tauri_plugin_autostart::init(
    tauri_plugin_autostart::MacosLauncher::LaunchAgent,
    None,
))?;
```

```ts
import { enable, disable, isEnabled } from '@tauri-apps/plugin-autostart'

await enable()
await isEnabled()
await disable()
```

- 注册、查询、注销都交给插件，不自己写注册表。
- 开机自启默认写当前用户范围，不需要管理员权限。
- 插件文档要求 Rust ≥ 1.90。

## 五、单实例

```toml
[target.'cfg(any(target_os = "macos", windows, target_os = "linux"))'.dependencies]
tauri-plugin-single-instance = "2"
```

```rust
tauri::Builder::default()
    .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
        if let Some(win) = app.get_webview_window("main") {
            let _ = win.unminimize();
            let _ = win.show();
            let _ = win.set_focus();
        }
    }))
```

- 必须是第一个注册的插件；官方明确要求先于其他插件。
- 插件没有 JS API，不需要 capability。
- 回调里的 `args` 是第二次启动传入的命令行参数，可用于“再次打开时导入文件”这类场景。
- 桌面端专属，用 `#[cfg(desktop)]` 包住。

## 六、全局快捷键

```bash
npm run tauri add global-shortcut
```

```rust
use tauri_plugin_global_shortcut::{
    Code, GlobalShortcutExt, Modifiers, Shortcut, ShortcutState,
};

let shortcut = Shortcut::new(Some(Modifiers::CONTROL | Modifiers::SHIFT), Code::KeyK);

tauri::Builder::default()
    .plugin(
        tauri_plugin_global_shortcut::Builder::new()
            .with_handler(move |app, _shortcut, event| {
                if event.state() == ShortcutState::Pressed {
                    // 唤出窗口或执行动作
                }
            })
            .build(),
    )
    .setup(move |app| {
        app.global_shortcut().register(shortcut.clone())?;
        Ok(())
    })
```

- 退出前成对 `unregister`；只在启动注册、退出不注销，重装版本后可能留下失效占用。
- 快捷键被其他软件占用时注册会失败，必须给用户可更换的入口，不静默失败。
- JS 侧调用需要 `global-shortcut:default` 权限；Rust 侧注册不需要。

## 七、管理员权限

需要提权的操作（改系统环境变量、写 Program Files、结束管理员进程）：

1. 启动时检测是否管理员，页面顶部提示“当前为普通权限，部分功能不可用”。
2. 提供“以管理员身份重启”，用 `Start-Process -Verb RunAs` 拉起当前 exe，然后退出自身。
3. 不静默提权、不引导用户关闭 UAC。

```rust
#[cfg(windows)]
use std::os::windows::process::CommandExt;

#[tauri::command]
fn restart_as_admin(app: tauri::AppHandle) -> Result<(), String> {
    let exe = std::env::current_exe().map_err(|e| e.to_string())?;
    let escaped = exe.to_string_lossy().replace('\'', "''");
    let mut cmd = std::process::Command::new("powershell");
    cmd.args([
        "-NoProfile", "-WindowStyle", "Hidden", "-Command",
        &format!("Start-Process -FilePath '{escaped}' -Verb RunAs"),
    ]);
    #[cfg(windows)]
    cmd.creation_flags(0x0800_0000);
    cmd.spawn().map_err(|e| format!("无法启动提权进程：{e}"))?;
    app.exit(0);
    Ok(())
}
```
