---
name: gitflow
description: |
  标准 GitFlow 工作流的 Git 操作规范。当用户涉及以下任何场景时必须使用本技能：
  编写或检查 commit message、创建或删除分支、选择合并方式（merge/squash/rebase）、
  版本发布、打 Tag、处理 hotfix 线上热修复、配置分支保护策略。
  严格基于 GitFlow，禁止混入 Trunk-Based Development、GitHub Flow 等其他工作流。
---

# GitFlow 工作流规范

## 全局铁律（最高优先级）

1. master 单向流入、只进不出：仅接收 `release/*`、`hotfix/*` 合并，禁止直接提交或推送。
2. hotfix 修复必须双向合并 master + develop，缺一不可，杜绝修复断层。
3. release 分支生命周期内严禁追加新功能，只允许缺陷修正、版本号与文案微调。
4. 保护分支（master/develop）禁用直接 push，强制走 PR + 代码评审。
5. 正式版本 Tag 与 master 提交点一一绑定，线上部署严格依据 Tag 打包。
6. release/hotfix 合并严禁 Squash，必须使用 `--no-ff` 保留合并节点。
7. 生成任何 Git 操作命令前，先校验其是否符合本技能全部规则；违反时明确拒绝并解释原因，随后给出正确命令。

## 分支命名速查

| 分支类型 | 命名格式 | 示例 |
| -------- | -------- | ---- |
| 长期主分支 | `master` / `develop` | `master`, `develop` |
| 功能开发 | `feature/<Issue号>-<功能简述>` | `feature/123-user-auth` |
| 迭代内修复 | `fix/<Issue号>-<问题简述>` | `fix/124-login-exception` |
| 版本预发布 | `release/v主版本.次版本.补丁版本` | `release/v1.0.0` |
| 线上热修复 | `hotfix/<Issue号>-<故障简述>` | `hotfix/999-payment-crash` |

## 合并策略速查

| 源分支 → 目标分支 | 合并方式 | 说明 |
| ----------------- | -------- | ---- |
| `feature/fix` → `develop` | Squash Merge | 一个功能对应一个提交节点，保持 develop 历史整洁 |
| `release/hotfix` → `master` | Merge Commit (`--no-ff`) | 严禁 Squash，确保 Tag 指向正确 |
| `release/hotfix` → `develop` | Merge Commit (`--no-ff`) | 严禁 Squash，保证 master 与 develop 历史一致 |

## 高风险操作确认

执行以下操作前必须向用户二次确认：删除分支、创建/推送 Tag、force push、rebase 已共享分支。

## 详细规范（按场景按需读取）

| 场景 | 参考文件 |
| ---- | -------- |
| 编写或检查 commit message | `references/commit-spec.md` |
| 切分支、分支来源与生命周期、分支保护 | `references/branch-spec.md` |
| 版本号、打 Tag、发版、热修复完整流程 | `references/release-flow.md` |
