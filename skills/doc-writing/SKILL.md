---
name: doc-writing
description: |
  项目文档编写规范。当用户涉及以下场景时必须使用本技能：
  编写或更新 README、CHANGELOG、使用指南、Markdown 形式的 API/架构文档，
  新建工程/项目脚手架交付自述文件（README），组织文档目录结构，以及文档中代码示例的编写。
  不适用于 Knife4j/Swagger/OpenAPI3 等在线接口文档的生成与配置（归 springboot-spec）。
---

# 文档编写规范

## 通用要求

- 所有文档使用 Markdown 格式，文件编码 UTF-8，换行符统一 Unix(LF)。
- 使用简洁、清晰的语言，避免拼写和语法错误。
- 使用中文作为主要语言，技术专有名词可保留英文。
- 文档内容应保持最新：每次代码变更需同步更新对应文档；废弃文档移至 `deprecated/` 或标注 `@deprecated`。
- 文件命名：全小写英文 + 连字符（如 `api-guide.md`），禁止中文文件名。

## 目录结构

- `README.md`、`CHANGELOG.md`：项目根目录；README 文件名固定 `README.md`（全大写 + `.md`），禁止 `readme.md`/`README.MD`/`README_CN.md`/`项目说明.md` 等变体。
- `docs/`：给人读的说明性文档。源码 `src/`、可执行脚本 `db/`、IDE 配置 `.vscode/`、构建配置 `pom.xml`、构建产物 `target/` 一律不进 docs。
  - 分类：`requirements/`（需求计划）、`guide/`（使用指南）、`architecture/`（架构决策）、`api/`（对接文档，预留）、`operations/`（运维手册，预留）、`examples/`、`images/`。
  - 门槛：同类文档满 3 份再建子目录，否则先平铺 `docs/` 根下，避免空壳目录。
  - 完整判据、分类树（含生命周期）、维护规则见 `references/docs-structure.md`（唯一真相源）。

## 文档内容组织

- 从整体到局部，从简单到复杂；重要信息放在前面；相关内容放在一起。
- 使用小标题和列表增强可读性。
- 单段不超过 5 行；超过 3 个并列点使用列表。
- 架构图优先使用 Mermaid 代码块（内嵌于 Markdown）；截图存放于 `docs/images/` 目录，使用相对路径引用。
- 文档中的外部链接应定期检查有效性，避免死链。

## 代码示例规范

- 所有代码块必须标注语言类型（如 ```java、```json、```bash），禁止无语言标注的裸代码块。
- 示例代码应尽量独立可运行；依赖外部服务（数据库、中间件等）时需在注释中说明前置条件。
- 代码应当简洁且易于理解，添加适当的注释解释关键部分，说明预期输出或行为。
- 更新示例以匹配最新 API。
- 复杂规范建议同时给出 ✅ 正确示例 和 ❌ 错误示例，形成对比便于理解。

## 详细参考

| 场景 | 参考文件 |
| ---- | -------- |
| 编写/交付 README（新建项目自述文件、章节骨架、按项目类型裁剪、填写红线） | `references/readme-template.md` |
| 编写 CHANGELOG | `references/changelog-template.md` |
| 组织 docs/ 目录（进/不进判据、满 3 份门槛、分类树） | `references/docs-structure.md` |
