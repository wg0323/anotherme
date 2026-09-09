> **已归档**：历史 rule，内容已迁移至 java-spec 技能（references/vscode-setup.md），不再作为 IDE 规则加载（trigger frontmatter 已移除）。

# VSCode Java Maven 项目初始化配置规则

在 VSCode 中开发 Java Maven 项目时，项目创建或首次打开时应自动配置以下文件：

1. `.vscode/settings.json`：设置 `java.configuration.updateBuildConfiguration` 为 `automatic`（避免 "Unsupported operation" 错误），`projectName` 应与 pom.xml 中的 artifactId 一致。
2. `.vscode/launch.json`：提供通用调试配置，`projectName` 与 pom.xml 的 artifactId 一致，包含一个 "Current File" 配置项，vmArgs 添加 `-Dfile.encoding=UTF-8`。
3. 不在项目根目录放置 launch.json，统一放在 `.vscode/` 目录下。