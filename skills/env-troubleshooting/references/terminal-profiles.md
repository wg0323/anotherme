# VSCode 集成终端的三个入口

终端配置改了不生效，多数不是配置写错，而是**改的那个入口不是出问题的入口**。VSCode 里同时存在三套终端，各自读不同的设置。

## 先判断现象来自哪个入口

| 现象 | 入口 | 配置载体 |
| ---- | ---- | -------- |
| 按 `` Ctrl+` `` 手动新开的终端乱码 | 手动终端 | `terminal.integrated.defaultProfile.windows` 指向的 profile |
| 只有运行任务、按 F5 调试时乱，在手动终端里运行同一程序正常 | 任务/调试终端 | `terminal.integrated.automationProfile.windows` |
| 程序输出跑到"调试控制台"标签，终端里看不到 | Debug Console | `launch.json` 的 `console` 字段 |
| "输出"面板里某个扩展（如 Language Support for Java）报错 | 扩展宿主进程 | 扩展自己的配置项，与终端无关 |

判据只有一条：**在手动终端里运行同一程序正常、只有 F5 或跑任务时才乱 → 出问题的是 `automationProfile`；两处都乱 → 出问题的是 `defaultProfile`。** 两条都配了还乱，去看 Debug Console 与写入端编码（见 `console-encoding.md`）。

别用 PowerShell 的 `echo 中文` 判断终端是否正常：它走 Unicode 输出，代码页错了照样显示正常。要验证就用受代码页影响的程序（JVM 应用，或 `cmd /c echo 中文`）。

## 三个入口的键名差异

| 配置项 | 值的形式 | 说明 |
| ------ | -------- | ---- |
| `terminal.integrated.profiles.windows` | 对象：`{ "名字": { profile 定义 } }` | 定义可用 profile，不决定用哪个 |
| `terminal.integrated.defaultProfile.windows` | **字符串：profile 名字** | 手动终端的默认 profile |
| `terminal.integrated.automationProfile.windows` | **对象：profile 定义** | 只给 tasks/debug 用；不配则跟随 default |
| `terminal.integrated.env.windows` | 对象：环境变量 | 对所有 profile 生效，可放 `PYTHONUTF8` 等 |

最容易踩的错：`defaultProfile` 要写**名字**，`automationProfile` 要写 **profile 定义对象**。两者形式互换，VSCode 不报错，只是不生效。

## profile 写法：覆盖内置，还是新建

两种改法效果不同，选一种，不要混。

覆盖内置 profile（不用改 `defaultProfile`，风险最小）：

```json
"terminal.integrated.profiles.windows": {
  "Command Prompt": {
    "path": ["${env:windir}\\System32\\cmd.exe"],
    "args": ["/k", "chcp", "65001"]
  }
}
```

新建独立 profile（必须同步改 `defaultProfile`，否则新终端仍是旧行为）：

```json
"terminal.integrated.profiles.windows": {
  "UTF-8 PowerShell": {
    "source": "PowerShell",
    "args": ["-NoExit", "-Command", "chcp 65001 > $null"]
  }
},
"terminal.integrated.defaultProfile.windows": "UTF-8 PowerShell"
```

`"path": "cmd"` 这种写法靠 PATH 解析，能用但不稳——PATH 被改动或存在同名程序时会指向别处，建议写 `${env:windir}\\System32\\cmd.exe`。

## 三种 shell 的编码启动参数

| shell | 写法 | 副作用与注意 |
| ----- | ---- | ------------ |
| cmd | `"args": ["/k", "chcp", "65001"]` | `/k` 让窗口在 chcp 后保持；`65001` 即 UTF-8 |
| PowerShell 5.1 | `"args": ["-NoExit", "-Command", "chcp 65001 > $null"]` | `> $null` 屏蔽"活动代码页：65001"提示行；仍乱时追加 `; [Console]::OutputEncoding = [System.Text.Encoding]::UTF8` |
| PowerShell 7 | 无需 chcp | 默认 UTF-8，加了也不影响 |
| Git Bash | 无 `chcp` 概念 | 编码由 locale 决定，照抄 chcp 方案不会生效 |

PowerShell 里两个编码变量管的不是一回事，排查时别混：

- `[Console]::OutputEncoding`：**接收**外部程序（java、mvn）输出的编码，乱码主要看它；
- `$OutputEncoding`：PowerShell 把内容通过管道**喂给**外部程序的编码，PowerShell 5.1 默认 `us-ascii`，它不负责解码输出。

## 生效条件（改完逐条核）

1. **关闭所有已打开的终端实例**。profile 只在创建终端时应用，旧标签页不会热更新。
2. `defaultProfile` 的值必须与 `profiles.windows` 里的键名逐字符一致（含空格与大小写差异）。
3. 改的是哪个作用域要清楚：工作区 `.vscode/settings.json` 覆盖用户设置；改错了地方，重载也不会生效。
4. 不需要重启 VSCode，新开终端即可——这一条与扩展宿主 JDK 不同，后者需要完整重启。

## 常见错误

| 写了什么 | 实际效果 | 正确做法 |
| -------- | -------- | -------- |
| 只配 `automationProfile` | 只有 tasks/debug 终端变了，手动终端照旧 | 手动终端也乱时补 `defaultProfile` |
| 已有 `automationProfile` 后又只改 `defaultProfile` | 跑程序仍用旧 profile，不会跟随 | 同步改 `automationProfile`，或删掉它让 tasks/debug 跟随 default |
| 新建了 profile 但没改 `defaultProfile` | 新 profile 从未被使用 | 同步改 `defaultProfile` |
| 用 `terminal.integrated.shell.windows` | 该设置已废弃，被静默忽略 | 全部迁到 `profiles.windows` + `defaultProfile` |
| 改了配置但没关旧终端 | 旧终端继续用旧编码 | 关闭所有终端标签再新开 |

`automationProfile` 未配置时会跟随 default profile；一旦单独配置，它就**不再跟随**。所以"我改了 default 为什么跑程序还乱"的答案通常是这个设置存在。

## 验证

```powershell
chcp
# 预期：活动代码页: 65001

[Console]::OutputEncoding.WebName
# 预期：utf-8

java -version
mvn -v
# 预期：中文输出正常，且 JDK 版本与项目编译版本一致（版本被改动见 jdk-and-extension.md）
```

手动终端与 tasks/debug 终端要**分别**验证一遍，只测其中一个会漏掉入口错配。
