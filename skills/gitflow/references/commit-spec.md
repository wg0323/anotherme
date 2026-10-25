# Commit 提交规范

## Message 格式

```text
<type>(<scope>): <subject>

<body>

<footer>
```

示例：

```text
feat(user): 新增用户注册功能

- 实现邮箱注册
- 添加验证码校验

Closes #123
```

## 提交类型（type）

| 类型       | 说明                   | 适用场景                              |
| ---------- | ---------------------- | ------------------------------------- |
| `feat`     | 新功能                 | Feature 分支新增业务功能              |
| `fix`      | Bug 修复               | develop/release/hotfix 分支内缺陷修复 |
| `docs`     | 文档更新               | 注释、README、接口文档修改            |
| `style`    | 代码格式（不影响功能） | 缩进、换行、空格、格式化              |
| `refactor` | 重构代码               | 无新增功能、无 Bug 修复，优化代码结构 |
| `perf`     | 性能优化               | 接口、SQL、算法执行效率优化           |
| `test`     | 增加测试               | 单元测试、集成测试用例新增修改        |
| `chore`    | 构建过程或辅助工具变动 | 脚本、依赖管理、工程配置非业务代码    |
| `ci`       | CI/CD 配置变动         | 流水线、自动化部署配置修改            |
| `revert`   | 回滚提交               | 撤销历史某次已合并提交                |
| `build`    | 构建系统或外部依赖变动 | 打包脚本、第三方依赖包升降级          |

> 注意：不存在 `hotfix` 类型。线上紧急修复统一使用 `fix` 类型，并通过 footer 标注 `Hotfix: true` 或关联 Issue 号区分。

## 影响范围（scope）

- **按模块**：`user`、`order`、`payment`、`product`
- **按功能**：`auth`、`api`、`config`、`db`
- **按层级**：`controller`、`service`、`mapper`

## subject 规则

- **强制**：使用祈使句，首字母小写，结尾不加句号。
- **强制**：使用简体中文描述，专有名词保留英文原文（参见「中文与编码要求」）。
- **强制**：中文不超过 25 字，英文不超过 50 字符；优先保证语义完整，最长不超过 72 字符。
- **强制**：准确描述本次提交做了什么。

```text
✅ feat(user): 新增用户头像上传功能
❌ feat(user): 新增用户头像上传功能。（结尾有句号）
❌ feat(user): 新增了用户头像上传的功能并且支持了裁剪和压缩以及格式转换等...（超长且冗余）
```

## 中文与编码要求

### 语言

- **强制**：subject 与 body 使用简体中文，禁止中英混杂式表述。

  ```text
  ✅ fix(order): 修复 Redis 缓存过期导致订单状态异常
  ❌ fix(order): fix 了 Redis 缓存 expire 导致订单 status 异常
  ```

- **允许**：业界通用的专有名词、产品名、技术缩写保留英文原文，不强行翻译。

常见保留英文的专有名词（非穷举；判断原则：业界有稳定英文写法的一律保留）：

| 类别 | 示例 |
| ---- | ---- |
| 语言与框架 | Java、Python、Go、Spring Boot、Spring Cloud、MyBatis、Vue、React、uni-app |
| 中间件与存储 | Redis、MySQL、MongoDB、Elasticsearch、Kafka、RabbitMQ、RocketMQ、Flink、Spark、Nginx |
| 工程与运维 | Docker、Kubernetes、Jenkins、Maven、Gradle、Git、GitFlow、CI/CD、DevOps |
| 通用技术术语 | API、SDK、SQL、JSON、HTTP、RESTful、JWT、OAuth、RPC、MQ、JVM、JDK、ORM、Cache、Token、Session、PR、Issue、Bug |

### 编码与防乱码

Windows 下中文乱码可能来自 message 存储编码，也可能来自 Git 日志输出编码与终端代码页不一致，按以下要求分别处理：

1. **项目级提交编码声明 UTF-8**（禁止加 `--global`，避免污染全局环境）：

   ```bash
   git config i18n.commitEncoding utf-8
   ```

2. **日志输出编码对齐终端**：终端已使用 UTF-8（如代码页 65001）时，可项目级执行 `git config i18n.logOutputEncoding utf-8`；其他终端按实际代码页设置，不要为了修复显示问题修改存储正确的 message。
3. **message 一律 UTF-8 无 BOM**：用编辑器编写时确认保存编码为 UTF-8。
4. **提交渠道防损坏**：优先用编辑器提交；多行或含中文的信息写入 UTF-8 临时文件后 `git commit -F <文件>`，避免在 cmd 中用 `-m` 直接传长中文（cmd 默认 GBK 代码页易损坏传参）。
5. **提交后自检**：执行 `git log -1` 确认中文显示正常。出现异常时先检查终端代码页和 `i18n.logOutputEncoding`，在 UTF-8 终端中用 `git log -1 --encoding=utf-8` 复核；确认原提交内容损坏后才修正本次 message。

## body 规则

- **强制**：默认使用简体中文，专有名词保留英文原文。
- **推荐**：详细说明代码变动的动机和改动对比。
- **推荐**：分条列出关键变更点。

## footer 规则

- **关联 Issue**：`Closes #123`、`Fixes #456`。
- **热修标识**：线上紧急修复必须标注 `Hotfix: true`。
- **Breaking Change**：必须显式标注不兼容变更说明。
