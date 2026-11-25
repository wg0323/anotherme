# 打包与分发

## 一、命令与产物

| 命令 | 结果 |
| --- | --- |
| `npm run tauri build` | release 构建 + NSIS/MSI 安装包 |
| `npm run tauri build -- --no-bundle` | 只出单个 exe，不生成安装包 |
| `npm run tauri build -- --debug --no-bundle` | debug exe，便于看 panic 信息 |

产物位置（`productName = MyTool`，Cargo 包名 `my-tool`）：

| 文件 | 路径 |
| --- | --- |
| 免安装 exe | `src-tauri/target/release/my-tool.exe` |
| NSIS 安装包 | `src-tauri/target/release/bundle/nsis/MyTool_<version>_x64-setup.exe` |
| MSI 安装包 | `src-tauri/target/release/bundle/msi/MyTool_<version>_x64_<lang>.msi`（默认 `en-US`，随 WiX 语言设置变化） |

首次打 NSIS 会从 GitHub 下载打包插件，网络不通时先用 `--no-bundle` 出 exe 验证功能，再单独解决安装包。

## 二、bundle 配置

```json
{
  "bundle": {
    "active": true,
    "targets": ["nsis", "msi"],
    "icon": [
      "icons/32x32.png",
      "icons/128x128.png",
      "icons/128x128@2x.png",
      "icons/icon.ico"
    ],
    "windows": {
      "webviewInstallMode": { "type": "downloadBootstrapper", "silent": true },
      "nsis": {
        "installMode": "currentUser",
        "languages": ["SimpChinese", "English"],
        "displayLanguageSelector": true
      }
    }
  }
}
```

| 键 | 取值与说明 |
| --- | --- |
| `targets` | Windows 项目直接列 `["nsis", "msi"]`；`"all"` 会把其他平台目标也算进来 |
| `nsis.installMode` | `currentUser`（默认，免管理员）/ `perMachine`（Program Files，需管理员）/ `both`（安装时选，始终需管理员） |
| `nsis.languages` | 不写默认 `["English"]`；中文用户加 `SimpChinese` |
| `nsis.displayLanguageSelector` | 是否在安装界面之前弹语言选择 |
| `nsis.compression` | `lzma`（默认）/ `zlib` / `bzip2` / `none` |

个人工具用 `currentUser`；要装到 Program Files 或给全机器用才选 `perMachine`。

## 三、WebView2 安装模式

`bundle.windows.webviewInstallMode` 是带 `type` 的联合对象，五种取值：

| `type` | 行为 | 适用 |
| --- | --- | --- |
| `downloadBootstrapper`（默认） | 安装时联网下载引导程序 | 常规分发，包体最小 |
| `embedBootstrapper` | 引导程序内嵌，仍需联网 | 网络差；包体约 +1.8 MB |
| `offlineInstaller` | 内置离线安装器 | 目标机器无外网 |
| `fixedRuntime` | 内置固定版本运行时 | 必须锁 WebView2 版本；需额外指定运行时路径，包体约 +180 MB |
| `skip` | 安装器完全不处理 WebView2 | 确定目标机器已有运行时 |

Win10 未装 WebView2 时应用白屏或直接起不来。默认值已覆盖多数情况，内网分发再考虑 `offlineInstaller`。

## 四、图标

```bash
npm run tauri icon ./app-icon.png
```

- 源图 1024×1024、带透明通道的 PNG。
- 生成 `src-tauri/icons/` 全套（含 `icon.ico`），安装器、窗口、托盘都用它。
- 换图标后要重新打包；已安装的旧版本不会自动更新快捷方式图标。

## 五、版本号与命名

- `package.json`、`src-tauri/Cargo.toml`、`src-tauri/tauri.conf.json` 三处版本号必须一致。
- `productName` 决定安装包文件名、默认安装目录、开始菜单名称，发布后不要改。
- `identifier` 决定 WebView2 数据目录与单实例标识，同样发布后不改。
- 安装包版本号来自 `tauri.conf.json` 的 `version`；未写时取 `Cargo.toml` 的版本，两处不一致会出现“关于页与安装包版本不同”。

## 六、签名与 SmartScreen

- 个人开发通常不买代码签名证书，用户首次运行看到“未知发布者”属预期，不是打包错误。
- 正式对外分发再买 OV/EV 证书，配置 `bundle.windows.certificateThumbprint`（或 `signCommand`）。
- 不为了绕过提示教用户关闭 SmartScreen；这等于让用户对真正的恶意软件也不设防。

## 七、打包脚本

项目根目录放 `package.bat`，双击或命令行调用：

```bat
@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

set "MODE=%~1"
if "%MODE%"=="" set "MODE=bundle"

where node >nul 2>nul
if errorlevel 1 (
  echo [错误] PATH 中找不到 node.exe
  exit /b 1
)
where cargo >nul 2>nul
if errorlevel 1 (
  echo [错误] PATH 中找不到 cargo
  exit /b 1
)

if not exist "node_modules" (
  echo [1/3] 安装前端依赖...
  call npm install
  if errorlevel 1 exit /b 1
)

echo [2/3] 清理旧安装包...
if exist "src-tauri\target\release\bundle" rmdir /s /q "src-tauri\target\release\bundle"

echo [3/3] 开始构建...
if /i "%MODE%"=="exe" (
  call npx tauri build --no-bundle
) else if /i "%MODE%"=="debug" (
  call npx tauri build --debug --no-bundle
) else (
  call npx tauri build
)
if errorlevel 1 (
  echo [错误] 构建失败，查看上方输出；网络不通时可先执行 package.bat exe
  exit /b 1
)

echo 产物：
if exist "src-tauri\target\release\my-tool.exe" echo   src-tauri\target\release\my-tool.exe
for /r "src-tauri\target\release\bundle" %%f in (*.exe *.msi) do echo   %%f

endlocal
```

- 脚本只做“查环境 → 装依赖 → 清旧包 → 构建 → 打印产物”，不承载业务逻辑。
- `chcp 65001` 避免中文输出乱码；`cd /d "%~dp0"` 保证从任意目录调用都正确。
- 免安装模式的 exe 名取 Cargo 包名，不是 `productName`。

## 八、常见失败

| 现象 | 原因与处理 |
| --- | --- |
| `link.exe not found` | 未装 VS Build Tools（MSVC + Windows SDK） |
| 安装包阶段卡住或失败 | NSIS/WiX 首次下载失败；先 `--no-bundle`，或改用 `--bundles nsis` |
| 应用启动白屏 | WebView2 未安装，或 `frontendDist` 与 Vite `outDir` 不一致 |
| 托盘无图标 | 只提供了 png，缺 `icon.ico` |
| 杀软报毒 | 未签名 + NSIS 的常见误报；签名可缓解，但不能完全消除 |
| 双击安装包无反应 | 被 SmartScreen 拦截，检查“更多信息”里是否被标记 |
