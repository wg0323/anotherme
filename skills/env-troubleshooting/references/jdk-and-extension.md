# 扩展宿主 JDK 与项目 JDK

"Java 21 or more recent is required"、"Error trying to find JVM"、"Could not create the Java Virtual Machine" 这三类报错，指向的都不是项目代码，而是**扩展自己启动的那个 JVM**。

## 双进程模型

VSCode 里的 Java 开发同时跑着两个 JVM，各自读各自的配置：

| 进程 | 谁决定 JDK | 受什么影响 |
| ---- | ---------- | ---------- |
| 扩展语言服务器（redhat.java、Spring Boot Tools） | 扩展作者要求的最低版本 | `java.jdt.ls.java.home`、`spring-boot.ls.java.home` |
| 项目编译与运行（Maven、java -jar） | 项目目标版本 | `JAVA_HOME`、`java.configuration.runtimes`、pom 的编译级别 |

两者本就该分开。改 `JAVA_HOME` 去迁就扩展，会把项目编译版本一起改掉——这是最常走的错路。

## 报错特征定位扩展

| 报错特征 | 出错的扩展 | 要配的项 |
| -------- | ---------- | -------- |
| `Java 21 or more recent is required` | `redhat.java`（Java 语言服务器） | `java.jdt.ls.java.home` |
| `Error trying to find JVM` / `--list-modules` / `Could not create the Java Virtual Machine` | `vmware.vscode-spring-boot`（Spring Boot Tools，随 Extension Pack 安装） | `spring-boot.ls.java.home` |

Spring Boot Tools 会主动扫描 `jvms`、`scoop` 等目录找 JDK，容易误选老版本，然后崩在 `java --list-modules`（JDK 9+ 才有的参数）。只有显式指定 `spring-boot.ls.java.home`，它才会停止扫描。

## 处理原则

1. 绝不修改 `JAVA_HOME` / `PATH`——那会连项目编译版本一起改掉，而且污染本机其它项目。
2. 不建议降级扩展版本——旧版 `redhat.java` 同样要求 JDK 17，本机没有时一样起不来。
3. 用项目级 `.vscode/settings.json` 解决（局部优先于全局）。JDK 路径因机器而异时，写进用户设置，避免把本机路径提交进仓库。
4. 项目本身就是 JDK 17+ 时不存在此问题，不要画蛇添足。

## 先探测，禁止假设路径

```powershell
Get-ChildItem -Path 'C:\Java','C:\Program Files\Java','C:\Program Files\Eclipse Adoptium','C:\jvms\store' -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
```

对候选路径逐个确认版本，再写进配置：

```powershell
& 'C:\Program Files\Eclipse Adoptium\jdk-21.0.4.7-hotspot\bin\java.exe' -version
# 预期：openjdk version "21.0.4" ...
```

`java.jdt.ls.java.home` 要的是 **JDK 目录**（含 `bin`、`lib`），不是 `bin` 子目录，也不是 JRE。

## 配置模板

```json
"java.jdt.ls.java.home": "<高版本JDK路径>",
"spring-boot.ls.java.home": "<高版本JDK路径>",
"java.configuration.runtimes": [
  { "name": "JavaSE-1.8", "path": "<项目编译用JDK路径>", "default": true },
  { "name": "JavaSE-21",  "path": "<高版本JDK路径>" }
]
```

`name` 里的 `JavaSE-1.8` 按项目实际编译级别调整（1.8 / 11 / 17 / 21）。

## 验证

1. **完整重启 VSCode**。此配置需完整重启，Reload Window 不够。
2. 输出面板 → Language Support for Java，确认语言服务器启动成功、用的是高版本 JDK。
3. 终端执行 `java -version` 与 `mvn -v`，**必须仍显示项目编译用的版本**——这一步证明项目侧没被污染。

## 同类形态：其它扩展选本机运行时

机制相同，只是配置项不同：扩展宿主用的运行时与项目用的运行时分离，改扩展专属设置，不动系统环境。

| 扩展 | 配置项 | 说明 |
| ---- | ------ | ---- |
| Python | `python.defaultInterpreterPath` | 指向项目 venv 或指定解释器 |
| ESLint | `eslint.runtime` | 指定 Node 可执行文件路径 |

## 两个坑

- 配置项名以扩展的 `package.json` 为准，不同版本可能改名（如 `spring-boot.ls.java.home` 与改名后的 `spring.ls.java.home`）。不确定时先查当前安装的版本：

```powershell
Select-String -Path "$env:USERPROFILE\.vscode\extensions\*spring*\package.json" -Pattern '[a-z\-\.]*ls\.java\.home' -AllMatches
```

- 项目级 `.vscode/settings.json` 会被提交进仓库。JDK 路径是机器相关的，个人路径写进这里会让同事拿到一份跑不通的配置——路径因机器而异时放用户设置。
