# 工程编码统一（根治 Windows 控制台乱码）

## 根因

Windows 中文系统控制台默认代码页为 **936/GBK**，而工程资产多为 **UTF-8**。乱码的本质是「写入端编码」与「解读端编码」不一致——不是某一处配置错了，而是链路两端没对齐。

要根治控制台乱码，必须在下面**五处同时对齐 UTF-8**，缺一处都可能残留乱码：

| # | 层次 | 文件 | 角色 | 解决哪类乱码 |
| - | ---- | ---- | ---- | ------------ |
| 1 | 源文件编码 | `.vscode/settings.json`（`files.encoding`） | 存储 | 编辑器中文、编译期字符串常量 |
| 2 | 构建编码 | `pom.xml`（`project.build.sourceEncoding`） | 转换 | 编译/打包时源码与资源文件 |
| 3 | HTTP 编码 | `application.yml`（`server.servlet.encoding.*`） | 传输 | 接口请求/响应中文 |
| 4 | JVM 输出编码 | `.vscode/launch.json`（`vmArgs` + `console`） | **写入端** | 程序往控制台写字节用哪种编码 |
| 5 | 终端代码页 | `.vscode/settings.json`（终端 profile `chcp 65001`） | **解读端** | 终端用哪种编码解读字节 |

三条必须澄清的坑（反复耗时正源于此）：

- **`application.yml` 的 `server.servlet.encoding` 只管 HTTP，不管控制台**；`pom.xml` 只管构建。只设这两处无法根治控制台乱码。
- **只设 `-Dfile.encoding=UTF-8` 而终端仍是 GBK，反而更乱**——写入端（第 4 处）与解读端（第 5 处）必须同为 UTF-8。
- **Debug Console（`internalConsole`）不读 `settings.json`、不响应 `chcp`**，其中文乱码是已知无解限制；Java 调试必须走集成终端。

## 1. 源文件编码（.vscode/settings.json）

```json
"files.encoding": "utf8",
"files.autoGuessEncoding": false
```

- **强制**：所有 `.java`/`.yml`/`.xml`/`.properties` 一律 **UTF-8 无 BOM**。
- **说明**：关闭 `autoGuessEncoding`，避免 VSCode 对含中文的老文件反复猜 GBK/GB2312，出现「改完代码一运行又乱码」的玄学问题。

## 2. 构建编码（pom.xml properties）

```xml
<properties>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
</properties>
```

- **说明**：Spring Boot 官方 `spring-boot-starter-parent` 已默认 UTF-8，但**显式声明**可防止脱离 parent、或子模块继承缺失时回退到平台编码（Windows 上即 GBK）。

## 3. HTTP 请求响应编码（application.yml）

```yaml
server:
  servlet:
    encoding:
      charset: UTF-8
      enabled: true
      force: true
```

- **强制**：`force: true` 强制请求与响应都使用 UTF-8，避免仅对响应生效。
- **可选强校验**：`spring.mandatory-file-encoding: UTF-8`——启动时若 JVM `file.encoding` 非 UTF-8 则**直接启动失败并报错**，把「隐性乱码」变成「显性报错」，倒逼第 4 处配对。

## 4. JVM 输出编码（.vscode/launch.json）——按 JDK 版本区分

控制台乱码的**写入端**。`vmArgs` 需按 JDK 版本选择属性名：

| JDK 版本 | `file.encoding` 默认 | 推荐 `vmArgs` |
| -------- | -------------------- | ------------- |
| JDK 8 ~ 17 | 平台编码（中文 Windows 为 GBK） | `-Dfile.encoding=UTF-8 -Dsun.stdout.encoding=UTF-8 -Dsun.stderr.encoding=UTF-8` |
| JDK 18+（JEP 400） | 已是 UTF-8，但**控制台 I/O 仍用本地编码** | `-Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 -Dstderr.encoding=UTF-8` |

- **说明**：`sun.stdout.encoding`/`sun.stderr.encoding` 适用 JDK 8~18，且在 JDK 19+ 仍向后兼容；`stdout.encoding`/`stderr.encoding` 是 JDK 19+ 的正式属性。若不想区分版本，可**统一用 `sun.*` 一套**并保留 `-Dfile.encoding=UTF-8` 兜底。
- **说明**：`System.in` 始终跟随本地编码（JDK-8295672，JEP 400 明确排除控制台 I/O），从控制台读取中文输入须配合第 5 处 `chcp 65001`。

强制走集成终端（禁用 `internalConsole`）：

```json
"console": "integratedTerminal"
```

## 5. 终端代码页（.vscode/settings.json）——控制台乱码的解读端

让集成终端启动即切到 UTF-8：

```json
"terminal.integrated.profiles.windows": {
  "PowerShell": {
    "source": "PowerShell",
    "args": ["-NoExit", "-Command", "chcp 65001 > $null"]
  },
  "Command Prompt": {
    "path": ["${env:windir}\\System32\\cmd.exe"],
    "args": ["/k", "chcp 65001"]
  }
},
"terminal.integrated.defaultProfile.windows": "PowerShell"
```

- **提示**：改完必须**关闭所有已打开的终端实例**，旧终端不会应用新配置。
- **提示**：`chcp 65001 > $null` 中的 `> $null` 用于屏蔽「活动代码页：65001」提示行，界面更干净。

## 验证清单（改完必做）

1. 重启 VSCode / Reload Window，并关闭所有旧终端。
2. 新开集成终端执行 `chcp`，应显示 **65001**。
3. 启动 SpringBoot，Banner 与含中文的 `log.info` 输出正常。
4. 浏览器 / Postman 调含中文的接口，请求与响应均正常。
5. 临时验证 JVM 端：`java -XshowSettings:properties -version 2>&1 | findstr encoding`，确认 `file.encoding`、`sun.stdout.encoding`（或 `stdout.encoding`）为 UTF-8。

## 常见坑速查

| 现象 | 断点在哪一层 | 处理 |
| ---- | ------------ | ---- |
| 编辑器里打开源文件中文就是乱的 | 第 1 处（源文件编码） | 配 `files.encoding=utf8` + 关 `autoGuessEncoding`；老 GBK 文件先转码再打开 |
| 编辑器正常，但**控制台**中文乱码 | 第 4/5 处未对齐 | `launch.json` 加对应 JDK 的 `vmArgs` + `console:integratedTerminal`；终端 profile 加 `chcp 65001`；关闭旧终端 |
| 只有 **Debug Console** 乱、集成终端正常 | 走了 `internalConsole` | 改 `"console": "integratedTerminal"`，忽略 Debug Console 标签 |
| 接口返回 / 表单提交中文乱码 | 第 3 处（HTTP 编码） | `server.servlet.encoding` 配 `charset/enabled/force` |
| 打包后运行乱码、IDE 里正常 | 第 2 处（构建编码） | `pom.xml` 显式声明 `project.build.sourceEncoding=UTF-8` |
| 配了 UTF-8 反而全乱 | 写入端 UTF-8、解读端仍 GBK | 两端必须同为 UTF-8，重点检查第 5 处终端代码页是否真正生效 |
