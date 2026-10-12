# docs/ 目录组织规范（唯一真相源）

任何项目（SpringBoot / uni-app / 微信小程序）组织 `docs/` 目录时都必须遵循本文件。`springboot-spec`、`uniapp-spec`、`wx-miniapp-spec` 等技能内嵌的只是本文件的骨架摘要，措辞有出入时以本文件为准。

## 一、进 docs 的判据（硬规则）

- **进 docs**：给人读的说明性内容（一次性归档或长期维护都算）。
- **不进 docs**：机器执行 / 构建 / 环境类资产，包括源码 `src/`、可执行脚本 `db/`、IDE 配置 `.vscode/`、构建配置 `pom.xml`、构建产物 `target/`。
- **边界示例**：`db/schema.sql` 是要被 mysql 执行的**资产**，留在 `db/`，不进 docs；只有"讲这张表为什么这么设计"的说明文档才进 docs。划清"人读的说明 vs 机器执行的资产"这条线后，就不必再纠结"脚本算不算文档"。

> "长期维护"不是进 docs 的门槛，只是 `guide/`、`architecture/` 类的附属属性——`requirements/` 下"写完基本只读"的文档同样属于给人读的说明，照样进 docs。

## 二、建目录的门槛（硬规则）

- 同类文档**满 3 份再建对应子目录**；不足 3 份先平铺在 `docs/` 根下，避免造空壳目录。
- 下面第三节的分类树是**目标态 / 分类维度**，不是初始就必须建齐的目录；按实际文档数量增长逐步建立。

## 三、分类树（目标态）

```text
docs/
├── README.md          目录索引 + 分类规则（把本约束的落地说明写在这里）
├── requirements/      需求与计划：前期写完基本只读（如 prompt.md）
├── guide/             学习与使用：长期维护，代码变了要跟着改（如 learning-guide.md）
├── architecture/      架构与决策：随架构演进（如 production-gap.md）
├── api/         (预留) 第三方对接文档
├── operations/  (预留) 部署运维手册
├── examples/    (工具) 示例代码文档
└── images/      (工具) 文档引用的图片，使用相对路径引用
```

- `api/`、`operations/` 为预留分类，尚无对应文档时不必先建空目录。
- `examples/`、`images/` 为工具目录，按需建立。
- 每个子目录用一句话标注**生命周期**（只读 / 长期维护 / 随架构演进），便于判断改动时是否需要同步。

## 四、维护

- 代码变更时同步更新 `guide/`、`architecture/` 类文档；`requirements/` 类写完基本只读，不随代码改动。
- 废弃文档标注 `@deprecated` 或移至 `deprecated/`，不留悬空链接。
- `docs/README.md` 作为目录索引，增删文档后同步更新。
