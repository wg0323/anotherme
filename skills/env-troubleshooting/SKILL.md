---
name: env-troubleshooting
description: |
  开发环境与工具链故障的定界与修复。当出现终端或控制台中文乱码、代码里已声明 UTF-8 仍乱码、
  代码页 chcp 问题、文件编码被误识别、IDE 语言服务器或扩展启动失败（JDK 版本不匹配、
  Error trying to find JVM）、终端 profile 不生效（编码、PATH、Ctrl+C 行为异常）、
  任务与调试终端和手动终端行为不一致、Maven/npm 构建输出乱码、系统环境变量与项目版本冲突时使用：
  先把现象定界到「代码 / 构建 / IDE 扩展 / 终端 / 操作系统」中的一层，再单点修复并验收，
  全程不改动全局环境。不适用于业务代码缺陷（归各语言规范技能）与测试执行纪律（归 test-execution）。
---

# 开发环境与工具链故障处置

症状出现在终端、IDE 或构建工具上，而代码侧已经按规范做对了——这类问题靠反复试配置解决不了，只能先定界。下面的流程把"现象 → 进程 → 层"固定下来，再逐层修。

## 核心铁律

1. 先定界后配置：必须说清"现象 → 出现在哪个进程 → 哪一层"。定不出来就继续取证，禁止先加一个配置项试试。
2. 一次只动一层，改完立刻验收。同时改多处等于放弃归因，验不过先回退再重新定界。
3. 落位由内向外：项目 `.vscode/*.json` → 用户设置 → 系统环境。**永不修改** `JAVA_HOME`、`PATH`、系统默认代码页（`chcp` 只影响当前会话）、注册表与全局工具版本，也不建议用户改。
4. 配置前先读事实：当前代码页、`JAVA_HOME`、实际生效的 profile、扩展版本，用命令读出来，禁止假设路径与版本。
5. 每条修复自带"判据 + 验收"：说明看到什么现象才用这条，以及用什么命令证明修好了。只给配置不写判据视为未完成。
6. 必须能解释"为什么之前会错"。解释不了说明定界没做完，回到第 1 条——否则换个终端入口还会重犯。

## 定界四步

| 步 | 动作 | 判据 |
| -- | ---- | ---- |
| 1 认入口 | 确认现象来自哪个进程 | 手动终端 / 任务与调试终端 / Debug Console / 扩展输出面板 / 构建进程 / 外部窗口 |
| 2 取证 | 读当前真实状态 | 命令清单见 `diagnosis-protocol.md` |
| 3 单点修 | 只改那一层的配置载体 | 项目设置 vs 用户设置 vs 环境变量 |
| 4 验收 | 跑验收命令，确认生效条件 | 关闭所有终端 / 重载窗口 / 完整重启 |

同一句现象可能指向两层。典型例子：代码里设了 UTF-8 仍乱，要么是**解读端**（终端代码页）没对齐，要么是**改错了终端入口**（只配了 `defaultProfile`，而日志来自 tasks/debug 终端）。判据：在手动终端里运行同一程序输出正常、只有 F5 或跑任务时才乱 → 入口错配；两处都乱 → 解读端。别拿 PowerShell 的 `echo 中文` 当判据，它走 Unicode 输出，代码页错了也显示正常。

## 现象 → 层 → 去向

| 现象 | 先怀疑的层 | 详见 |
| ---- | ---------- | ---- |
| 代码里已设 UTF-8，控制台仍乱码 | 解读端或终端入口错配 | `console-encoding.md`、`terminal-profiles.md` |
| 编辑器打开源码中文就乱 | 存储端 `files.encoding` | `console-encoding.md` |
| 打包后运行乱、IDE 内正常 | 构建端 | `console-encoding.md` |
| 改了配置没生效 | 旧终端实例 / 作用域 / 值形态 | `terminal-profiles.md`、`diagnosis-protocol.md` |
| `Java 21 or more recent is required` | 扩展宿主 JDK | `jdk-and-extension.md` |
| 崩在 `--list-modules` 或 `Error trying to find JVM` | 扩展自动扫 JDK 误选 | `jdk-and-extension.md` |
| 终端 `java -version` 与项目不一致 | 项目侧 `JAVA_HOME` / PATH | `jdk-and-extension.md` |
| Ctrl+C 不中断、PATH 或颜色异常 | 终端 profile 选错 | `terminal-profiles.md` |
| Debug Console 中文乱、终端正常 | 走了 `internalConsole` | `console-encoding.md` |

## 详细规范（按场景读取）

| 场景 | 参考文件 |
| ---- | -------- |
| 取证命令、按层修复与验收对照、改了没生效的六个原因、交付留痕格式 | `references/diagnosis-protocol.md` |
| 控制台乱码五端对齐、JVM/Python/Node 写入端编码、验证清单与常见坑 | `references/console-encoding.md` |
| VSCode 三个终端入口的区别、profile 写法与生效条件、错配排查 | `references/terminal-profiles.md` |
| 扩展宿主 JDK 与项目 JDK 分离、报错定位扩展、路径探测与验证 | `references/jdk-and-extension.md` |

## 边界

- 新建工程的编码基线（五处对齐的要求）由 `springboot-spec` 铁律 13 约束，其详解指向本技能的 `console-encoding.md`，两处不重复维护。
- 测试怎么跑、超时与止损、进程收尾归 `test-execution`。
- 具体配置项名称、版本兼容性与官方行为语义的查证走 `external-research`（官方来源优先）。
- 业务代码缺陷、工程结构与代码风格归各语言规范技能，本技能只处理环境与工具链层。
