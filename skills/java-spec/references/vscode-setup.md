# VSCode Java Maven 项目初始化配置

在 VSCode 中开发 Java Maven 项目时，项目创建或首次打开时应自动配置以下文件：

1. `.vscode/settings.json`：设置 `java.configuration.updateBuildConfiguration` 为 `automatic`（避免 "Unsupported operation" 错误），`projectName` 应与 pom.xml 中的 artifactId 一致。
2. `.vscode/launch.json`：提供通用调试配置，`projectName` 与 pom.xml 的 artifactId 一致，包含一个 "Current File" 配置项，vmArgs 添加 `-Dfile.encoding=UTF-8`。
3. 不在项目根目录放置 launch.json，统一放在 `.vscode/` 目录下。

## JDK 版本冲突处理（老项目 + 新版扩展）

### 何时需要处理

项目编译用较低版本 JDK，而 VSCode 扩展自身要求更高版本时。二者属于**不同进程**：
扩展的语言服务器由插件开发者决定 JDK，项目编译由 maven + `JAVA_HOME` 决定，本就该分开。

按报错特征定位是哪个扩展：

| 报错特征 | 出错的扩展 | 要配置的配置项 |
|---|---|---|
| `Java 21 or more recent is required` | `redhat.java`（Java 语言服务器） | `java.jdt.ls.java.home` |
| `Error trying to find JVM` / `--list-modules` / `Could not create the Java Virtual Machine` | `vmware.vscode-spring-boot`（Spring Boot Tools，随 Extension Pack 安装） | `spring-boot.ls.java.home` |

### 处理原则

1. **绝不修改 `JAVA_HOME` / `PATH`** —— 那会连项目编译版本一起改掉。
2. **不要建议降级扩展版本** —— 旧版 `redhat.java` 也要 JDK 17，本机没有时同样起不来。
3. **用项目级 `.vscode/settings.json` 解决**（局部优先于全局）。若路径因机器而异，改用 VSCode 用户设置以免污染仓库。
4. 项目本身就是 JDK 17+ 时不存在此问题，不要画蛇添足。

### 配置前先探测路径，禁止假设

```powershell
Get-ChildItem -Path 'C:\Java','C:\Program Files\Java','C:\Program Files\Eclipse Adoptium','C:\jvms\store' -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
```

对候选路径逐个执行 `<path>\bin\java.exe -version` 确认版本后再写入。

### 配置模板（路径替换为探测结果）

```json
"java.jdt.ls.java.home": "<高版本JDK路径>",
"spring-boot.ls.java.home": "<高版本JDK路径>",
"java.configuration.runtimes": [
  { "name": "JavaSE-1.8", "path": "<项目编译用JDK路径>", "default": true },
  { "name": "JavaSE-21",  "path": "<高版本JDK路径>" }
]
```

`name` 中的 `JavaSE-1.8` 需按项目实际编译级别调整（1.8 / 11 / 17 / 21）。

### 完成后必须验证

1. 重启 VSCode（此配置需完整重启，Reload Window 不够）。
2. 输出面板 → Language Support for Java，确认语言服务器用的是高版本 JDK。
3. 终端执行 `java -version` 与 `mvn -v`，**必须仍显示项目编译用的版本** —— 这一步验证项目侧未被污染。

### 两个坑

- Spring Boot Tools 会主动扫描 `jvms` / `scoop` 等目录找 JDK，容易误选老版本后崩在 `java --list-modules`（JDK 9+ 参数）。
  只有显式指定 `spring-boot.ls.java.home`，它才会停止扫描。
- 配置项名以扩展的 `package.json` 为准，不同版本可能不同（如 `spring-boot.ls.java.home` 与改名后的 `spring.ls.java.home`）。不确定时先查：
  `Select-String -Path "$env:USERPROFILE\.vscode\extensions\*spring*\package.json" -Pattern '[a-z\-\.]*ls\.java\.home' -AllMatches`
