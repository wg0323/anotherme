# VSCode Java Maven 项目初始化配置

在 VSCode 中开发 Java Maven 项目时，项目创建或首次打开时应自动配置以下文件：

1. `.vscode/settings.json`：设置 `java.configuration.updateBuildConfiguration` 为 `automatic`（避免 "Unsupported operation" 错误），`projectName` 应与 pom.xml 中的 artifactId 一致。
2. `.vscode/launch.json`：提供通用调试配置，`projectName` 与 pom.xml 的 artifactId 一致，包含一个 "Current File" 配置项，vmArgs 添加 `-Dfile.encoding=UTF-8`。
3. 不在项目根目录放置 launch.json，统一放在 `.vscode/` 目录下。

> **编码乱码专项**：上面的 `-Dfile.encoding=UTF-8` 只是「写入端」的一半。Windows 控制台乱码的完整修复（终端 profile `chcp 65001`、`console: integratedTerminal`、JDK 18+ 的 `stdout.encoding`、pom/application.yml 侧的编码统一）以 `env-troubleshooting` 技能的 `references/console-encoding.md` 为唯一真相源；本文件只负责 launch.json/settings.json 的初始化落位，不重复展开编码细节。

## JDK 版本冲突

扩展语言服务器要求的 JDK 与项目编译用的 JDK 是两个进程，本就该分开配置：绝不修改 `JAVA_HOME` / `PATH`，用项目级 `.vscode/settings.json` 指定扩展宿主 JDK，完整重启后确认终端 `java -version` 仍是项目编译版本。

报错特征 → 扩展 → 配置项的对应关系、路径探测命令与验证步骤见 `env-troubleshooting` 技能的 `references/jdk-and-extension.md`（未安装该技能时按上面这段骨架处理）。
