---
name: gitflow
description: |
  标准 GitFlow 工作流的 Git 操作规范。当用户涉及以下任何场景时必须使用本技能：
  编写或检查 commit message、创建或删除分支、选择合并方式（merge/squash/rebase）、
  版本发布、打 Tag、处理 hotfix 线上热修复、配置分支保护策略。
  支持两种模式：团队协作（完整 GitFlow）与单人独立维护（简化版，允许直接提交 master、免 PR/评审/develop/release 常驻分支）。
  团队模式严格基于 GitFlow，禁止混入 Trunk-Based Development、GitHub Flow 等其他工作流。
---

# GitFlow 工作流规范

## 第 0 步：判定开发模式（必须最先执行）

生成任何 Git 操作命令前，先判断当前项目的开发者规模，选择对应模式再套用规则：

| 模式 | 判定条件 | 适用规范 |
| ---- | -------- | -------- |
| 单人模式 | 项目仅由 1 名开发者维护，无并行协作、无 PR 评审、无强制 CI | 下方「单人简化规范」，完整流程读 `references/solo-mode.md` |
| 团队模式 | ≥ 2 名开发者协作，或存在 PR / 代码评审 / CI 流程 | 下方「团队模式全局铁律」及全部 references，规则保持原样 |

- 无法确定规模时，先询问用户「本项目是单人维护还是团队协作」，再生成命令。
- 单人模式是 GitFlow 针对个人独立维护场景的官方简化分支，并非切换到其他工作流；其放宽条款（见下）在单人模式下优先于团队铁律。
- commit message 规范（`references/commit-spec.md`）与语义化版本号规则两种模式通用。
- 一旦项目引入第二名开发者或 PR/CI 流程，立即切回团队模式。

## 单人简化规范（单人模式适用）

核心思想：以 master 为唯一主线，去掉团队协作开销（develop/release 常驻分支、强制 PR、代码评审、双向合并），但保留 GitFlow 的核心价值——master 为生产稳定基线、语义化版本号、Tag 绑定发布。

1. master 允许直接提交与推送，无需先切 develop/feature 分支。
2. 不强制创建 develop 分支；改动大或有风险时，可选切 `feature/*`、`fix/*` 临时分支隔离，完成后普通 merge 回 master（无需 PR/评审），随即删除。
3. 不强制走 `release/*` 分支；功能稳定后直接在 master 打语义化版本 Tag 发布。
4. 线上热修复直接在 master 修改并打 PATCH 版本 Tag；若未保留 develop 则无需双向合并。
5. commit message 仍严格遵循 `references/commit-spec.md`，版本号仍遵循语义化规范。
6. 高风险操作（删除分支、force push、rebase 已推送提交、创建/删除 Tag）仍需二次确认。

完整流程、命令与可选分支策略详见 `references/solo-mode.md`。

## 团队模式全局铁律（最高优先级）

1. master 单向流入、只进不出：仅接收 `release/*`、`hotfix/*` 合并，禁止直接提交或推送。
2. hotfix 修复必须双向合并 master + develop，缺一不可，杜绝修复断层。
3. release 分支生命周期内严禁追加新功能，只允许缺陷修正、版本号与文案微调。
4. 保护分支（master/develop）禁用直接 push，强制走 PR + 代码评审。
5. 正式版本 Tag 与 master 提交点一一绑定，线上部署严格依据 Tag 打包。
6. release/hotfix 合并严禁 Squash，必须使用 `--no-ff` 保留合并节点。
7. 生成任何 Git 操作命令前，先校验其是否符合本技能全部规则；违反时明确拒绝并解释原因，随后给出正确命令。

## 分支命名速查（团队模式）

| 分支类型 | 命名格式 | 示例 |
| -------- | -------- | ---- |
| 长期主分支 | `master` / `develop` | `master`, `develop` |
| 功能开发 | `feature/<Issue号>-<功能简述>` | `feature/123-user-auth` |
| 迭代内修复 | `fix/<Issue号>-<问题简述>` | `fix/124-login-exception` |
| 版本预发布 | `release/v主版本.次版本.补丁版本` | `release/v1.0.0` |
| 线上热修复 | `hotfix/<Issue号>-<故障简述>` | `hotfix/999-payment-crash` |

## 合并策略速查（团队模式）

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
| 单人模式完整简化流程与命令 | `references/solo-mode.md` |
| 编写或检查 commit message（两种模式通用） | `references/commit-spec.md` |
| 团队模式：切分支、分支来源与生命周期、分支保护 | `references/branch-spec.md` |
| 团队模式：版本号、打 Tag、发版、热修复完整流程 | `references/release-flow.md` |
