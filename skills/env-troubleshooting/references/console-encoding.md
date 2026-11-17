# 控制台乱码：把写入端与解读端对齐

代码里已经声明了 UTF-8，控制台还是花屏——这不是"某处配置错了"，而是链路上还没对齐的一端在起作用。逐端排查比反复试配置快。

## 根因

Windows 中文系统的控制台默认代码页是 **936（GBK）**，而工程资产多为 **UTF-8**。程序按 UTF-8 写出字节，终端按 GBK 解读，就会出现"代码里的中文是对的、终端里是乱的"。

链路共五端，缺哪一端都会残留乱码：

| # | 层次 | 载体 | 解决什么 | 适用范围 |
| - | ---- | ---- | -------- | -------- |
| 1 | 存储 | `.vscode/settings.json` 的 `files.encoding` | 编辑器打开、编译期字符串常量 | 全语言 |
| 2 | 构建 | `pom.xml` / `.mvn/jvm.config` 等 | 编译、打包、构建输出 | 按构建工具 |
| 3 | 传输 | `application.yml` 的 `server.servlet.encoding` | HTTP 请求与响应 | Spring Boot |
| 4 | 写入 | `launch.json` 的 `vmArgs`、启动脚本 | 程序往控制台写字节用什么编码 | 按运行时 |
| 5 | 解读 | 终端 profile 的 `chcp 65001` | 终端用什么编码读字节 | Windows 全语言 |

三条反复耗时的误解：

- `server.servlet.encoding` 只管 HTTP，`pom.xml` 只管构建，**两者都管不到控制台输出**。
- 只加 `-Dfile.encoding=UTF-8` 而终端仍是 936，输出会**更乱**——写入端与解读端必须同为 UTF-8。
- Debug Console（`internalConsole`）不读 `settings.json`、不响应 `chcp`，其中文乱码是已知限制，Java 调试必须走集成终端。

## 1 源文件编码（全语言）

```json
"files.encoding": "utf8",
"files.autoGuessEncoding": false
```

所有 `.java`/`.yml`/`.xml`/`.properties`/`.py`/`.ts` 一律 UTF-8 无 BOM。关闭 `autoGuessEncoding`，避免 VSCode 对含中文的老文件反复猜 GBK/GB2312，出现"改完一运行又乱"的反复。

老 GBK 文件要先转码再改编码设置，只改设置不会转已有字节。

## 2 构建编码

Java / Maven 工程，`pom.xml` 必须显式声明：

```xml
<properties>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
</properties>
```

`spring-boot-starter-parent` 已默认 UTF-8，显式声明是为了防止脱离 parent 或子模块继承缺失时回退到平台编码。

构建过程本身输出乱码时，用项目级 `.mvn/jvm.config`（Maven 3.3.1+，每行一个 JVM 参数）给 Maven 进程加编码：

```text
-Dfile.encoding=UTF-8
```

不要改系统级 `MAVEN_OPTS`——那会影响本机所有项目。

## 3 HTTP 编码（Spring Boot 专用）

```yaml
server:
  servlet:
    encoding:
      charset: UTF-8
      enabled: true
      force: true
```

`force: true` 让请求与响应都使用 UTF-8，避免只对响应生效。

非 Spring Boot 项目跳过本节，接口乱码按对应框架的字符集配置处理。

## 4 写入端：程序用什么编码往控制台写

JVM 参数按 JDK 版本区分：

| JDK 版本 | `file.encoding` 默认 | 推荐 `vmArgs` |
| -------- | -------------------- | ------------- |
| JDK 8 ~ 17 | 平台编码（中文 Windows 为 GBK） | `-Dfile.encoding=UTF-8 -Dsun.stdout.encoding=UTF-8 -Dsun.stderr.encoding=UTF-8` |
| JDK 18+（JEP 400） | 已是 UTF-8，但控制台 I/O 仍用本地编码 | `-Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 -Dstderr.encoding=UTF-8` |

`sun.stdout.encoding`/`sun.stderr.encoding` 适用于 JDK 8~18，JDK 19+ 仍向后兼容；`stdout.encoding`/`stderr.encoding` 是 JDK 19+ 的正式属性。不想区分版本时统一用 `sun.*` 一套，并保留 `-Dfile.encoding=UTF-8` 兜底。

`System.in` 始终跟随本地编码（JDK-8295672，JEP 400 明确排除控制台 I/O），从控制台读中文输入必须配合第 5 端的 `chcp 65001`。

强制走集成终端，否则参数加在 Debug Console 上不起作用：

```json
"console": "integratedTerminal"
```

其它运行时的写入端：

| 运行时 | 配置 | 说明 |
| ------ | ---- | ---- |
| Python | `PYTHONUTF8=1`、`PYTHONIOENCODING=utf-8` | 放进 `terminal.integrated.env.windows` 或 `launch.json` 的 `env` |
| Node.js | 通常无需配置 | 直接调用 Windows Unicode 控制台 API，一般不受 `chcp` 影响；乱码先查是否经过 cmd 管道或字体 |
| 任意进程 | `terminal.integrated.env.windows` | 对所有 profile 生效，是注入编码环境变量的项目级落点 |

## 5 解读端：终端代码页

```json
"terminal.integrated.automationProfile.windows": {
  "path": ["${env:windir}\\System32\\cmd.exe"],
  "args": ["/k", "chcp", "65001"]
}
```

上面这条只修 **tasks/debug 拉起的终端**；手动终端要配 `terminal.integrated.defaultProfile.windows` 指向的 profile。两者的区别、PowerShell 的额外设置与常见错配见 `terminal-profiles.md`。

改完必须关闭所有已打开的终端实例，旧终端不会应用新配置。

## 验证清单

1. 新开终端执行 `chcp`，显示 **65001**。
2. `[Console]::OutputEncoding.WebName` 为 `utf-8`（PowerShell 下检查）。
3. 启动程序，Banner 与含中文的 `log.info` 输出正常。
4. 调一个含中文的接口，请求与响应均正常。
5. 临时核对 JVM 侧：`java -XshowSettings:properties -version 2>&1 | findstr encoding`，确认 `file.encoding` 与 `sun.stdout.encoding`（或 `stdout.encoding`）为 UTF-8。

## 常见坑

| 现象 | 断点位置 | 处理 |
| ---- | -------- | ---- |
| 编辑器打开源文件中文就是乱的 | 第 1 端 | 配 `files.encoding=utf8` + 关 `autoGuessEncoding`；老 GBK 文件先转码 |
| 编辑器正常，控制台中文乱 | 第 4/5 端未对齐 | `vmArgs` 按 JDK 版本补齐 + `console: integratedTerminal`；终端 profile 加 `chcp 65001`；关闭旧终端 |
| 只有 Debug Console 乱、集成终端正常 | 走了 `internalConsole` | 改 `"console": "integratedTerminal"` |
| 接口返回或表单提交中文乱 | 第 3 端 | 配 `server.servlet.encoding` 的 charset/enabled/force |
| 打包后运行乱、IDE 里正常 | 第 2 端 | `pom.xml` 显式声明 `project.build.sourceEncoding` |
| 配了 UTF-8 反而全乱 | 写入端 UTF-8、解读端仍 936 | 重点确认第 5 端是否真的生效，以及是否改错了终端入口 |
| Python 输出乱 | 写入端 | `PYTHONUTF8=1` + `PYTHONIOENCODING=utf-8` |
| 手动终端正常、跑程序才乱 | 改错了终端入口 | 见 `terminal-profiles.md` 的 `automationProfile` 一节 |

## 适用范围

以上配置在 Windows 10/11 + VSCode 1.8x + JDK 8/17/21 上成立。Linux/macOS 不存在代码页概念，乱码通常来自 locale（`LANG`/`LC_ALL`），方向相同但手段不同，不要照搬 `chcp`。
