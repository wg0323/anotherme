# 定界协议：取证、单点修复与验收

环境故障的处置顺序固定为四步。跳步的典型后果是"配置加了一堆，现象时好时坏，说不清哪条起了作用"。

## 第一步：确认现象来自哪个进程

先看现象出现在哪里，不要先看代码。

| 现象出现的位置 | 归属 | 查什么 |
| -------------- | ---- | ------ |
| 手动新开的终端 | 终端 profile | `terminal.integrated.defaultProfile.*` |
| 跑任务或 F5 调试时才出现 | tasks/debug 终端 | `terminal.integrated.automationProfile.*` |
| "调试控制台"标签里 | Debug Console | `launch.json` 的 `console` 字段 |
| "输出"面板某个扩展名下 | 扩展宿主进程 | 该扩展的专属配置项 |
| 独立打开的 Windows Terminal / cmd | 操作系统 | 不属于项目配置，只能告知，不改系统 |
| `mvn` / `npm` 自己的输出 | 构建进程 | 构建工具的项目级配置 |

## 第二步：取证

把当前真实状态读出来，再决定改什么。以下命令在 VSCode 集成终端（PowerShell）执行。

终端与编码状态：

```powershell
chcp
[Console]::OutputEncoding.WebName
$OutputEncoding.WebName
$PSVersionTable.PSVersion
```

`chcp` 期望 `65001`；`[Console]::OutputEncoding.WebName` 期望 `utf-8`。`$OutputEncoding` 在 PowerShell 5.1 下是 `us-ascii` 属正常，它只管往外部程序喂输入。

运行时与路径：

```powershell
$env:JAVA_HOME
(Get-Command java).Source
java -version
mvn -v
java -XshowSettings:properties -version 2>&1 | Select-String 'encoding'
```

`(Get-Command java).Source` 能直接暴露"终端里的 java 到底是哪一个"，比猜测 PATH 顺序快。三条版本信息互相矛盾时，说明 PATH 上有多个 JDK。

系统与语言环境：

```powershell
Get-WinSystemLocale | Select-Object Name, LCID
Get-Culture | Select-Object Name
```

中文系统通常是 `zh-CN` / `0804`，控制台默认代码页 936。

配置文件的实际位置与内容：

```powershell
Get-Content .vscode\settings.json -ErrorAction SilentlyContinue
Get-Content .vscode\launch.json -ErrorAction SilentlyContinue
```

同一项在两个作用域都存在时，工作区（`.vscode`）覆盖用户设置。排查时先确认自己改的是哪一份。

## 第三步：按层单点修复

| 层 | 典型现象 | 改哪里 | 生效条件 | 验收 |
| -- | -------- | ------ | -------- | ---- |
| 存储 | 编辑器打开源码中文就乱 | `.vscode/settings.json` 的 `files.encoding` | 重新打开文件 | 文件中文正常显示 |
| 构建 | 打包后运行乱、IDE 内正常 | `pom.xml` / `.mvn/jvm.config` | 重新构建 | 重新打包后运行，中文正常 |
| 传输 | 接口或表单中文乱 | `application.yml` 的 `server.servlet.encoding` | 重启应用 | 调一次含中文的接口 |
| 写入 | 程序往控制台输出的中文乱 | `launch.json` 的 `vmArgs`、启动脚本 | 重新启动调试 | 日志中文正常 |
| 解读 | 终端里显示乱，程序侧正确 | 终端 profile 的 `chcp 65001` | **关闭所有终端**再新开 | `chcp` 显示 65001 |
| 扩展宿主 | 扩展启动失败、语言服务不可用 | 扩展专属 setting（如 `java.jdt.ls.java.home`） | **完整重启** IDE | 输出面板无报错，且终端里的版本未被改动 |

一次只改一行。改完立刻跑对应验收命令，过了再动下一处。

## 第四步：确认生效并解释原因

验收通过只完成一半。还要能回答"为什么之前是错的"——答不上来说明定界没做完，现象大概率会以另一种形式回来。

## 改了没生效的六个原因

按出现频率排列，逐条排掉比重新猜配置快。

1. **改错入口**：出问题的是 tasks/debug 终端，却只改了 `defaultProfile`，或反之。
2. **旧进程还在用旧配置**：已打开的终端标签、已启动的调试会话、扩展宿主进程，都不会热更新。
3. **改错作用域**：改的是用户设置，工作区 `.vscode/settings.json` 里有同名项把值盖掉了。
4. **值的形态错**：`defaultProfile` 要 profile **名字**，`automationProfile` 要 profile **定义对象**，写反了不报错也不生效。
5. **配置文件语法错误**：JSONC 里多余的逗号、注释位置不对，IDE 解析失败后静默回退到默认值。
6. **被更靠近进程的配置覆盖**：`launch.json` 里的 `args`/`env` 优先于 `settings.json` 的同类项。

## 回退与留痕

改之前先把原值记下来（贴进对话、记在临时文件都行）。排查失败时能逐行退回原始状态，比"重置所有设置"安全——后者会连带清掉与本问题无关的自定义项。

修复完成后，交付内容要包含这几项，缺一项就算没修完：

1. 现象原文（报错或乱码所在的界面与位置）；
2. 定界结论（哪一层，依据是哪条命令的输出）；
3. 改了哪个文件的哪一项（贴改动前后）；
4. 生效条件（关终端 / 重载窗口 / 完整重启）；
5. 验收命令与期望输出；
6. 为什么之前会错。

第 6 项是防止下次换个入口又重犯的关键，哪怕只是一句"之前配的 automationProfile 只作用于 tasks/debug"。

## 不能做的事

- 不改 `JAVA_HOME`、`PATH`、系统默认代码页、注册表——这类改动会影响本机所有项目，且难以回退。
- 不建议降级或升级全局工具来绕过问题。
- 不用"重置所有设置"或重装 IDE 作为排查手段。
- 不在没读当前状态的情况下同时加多条配置。
