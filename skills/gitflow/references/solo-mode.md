# 单人开发简化 Git 流程（GitFlow 单人模式）

> **适用场景**：项目仅由 1 名开发者独立维护（前端 / 后端均适用），无并行协作、无 PR 评审、无强制 CI。
>
> 本规范是 GitFlow 针对单人维护场景的**官方简化分支**，去掉团队协作开销，但保留 GitFlow 的核心价值：master 为生产稳定基线、语义化版本号、Tag 绑定发布、hotfix 补丁概念。
>
> commit message 规范见 `commit-spec.md`，语义化版本号规则见 `release-flow.md`，两者两种模式通用。

## 与团队模式的差异一览

| 维度 | 团队模式（完整 GitFlow） | 单人模式（简化） |
| ---- | ------------------------ | ---------------- |
| `develop` 常驻分支 | 必须 | 不强制，一般省略 |
| `master` 直接提交 | 禁止 | 允许 |
| `feature/fix` 分支 | 必须从 develop 切出并 PR 合回 | 可选，普通 merge 回 master，无需 PR |
| 合并方式 | Squash / `--no-ff` 强约束 | 不强制，普通 merge 即可 |
| PR + 代码评审 | 强制 | 取消（无第二人评审） |
| `release/*` 分支 | 必须 | 省略，直接在 master 打 Tag 发布 |
| hotfix 双向合并 | master + develop 都必须 | 仅 master（未保留 develop 时） |
| 分支保护规则 | 强制配置 | 可省略 |

## 主线模型

master 为唯一长期主线，任何时刻都应保持**可发布、可上线**状态。不要向 master 提交半成品——未完成的功能用临时分支隔离。

## 场景 1：日常开发（小改动 / 常规迭代）

直接在 master 提交：

```bash
# 1. 同步远端 master
git checkout master
git pull origin master

# 2. 编码、自测 ...

# 3. 提交（严格遵循 commit-spec.md）
git add .
git commit -m "feat(scope): 新增xxx功能"

# 4. 推送
git push origin master
```

## 场景 2：较大 / 有风险的功能（可选用临时分支）

当一个功能改动大、周期长或可能影响主线稳定时，建议切临时分支隔离，但无需 PR：

```bash
# 1. 从最新 master 切出临时分支（Issue 号单人模式可省略）
git checkout master && git pull origin master
git checkout -b feature/<功能简述>     # 或 fix/<问题简述>

# 2. 开发、自测、多次提交 ...

# 3. 完成后回到 master 并合并（未推送过可 rebase，已推送用 merge）
git checkout master && git pull origin master
git merge --no-ff feature/<功能简述>    # --no-ff 保留一个合并节点，便于回溯

# 4. 推送并删除临时分支
git push origin master
git branch -d feature/<功能简述>
```

## 场景 3：版本发布

功能稳定、需要发版时，直接在 master 打 Tag，无需 `release/*` 分支：

```bash
# 1. 确认 master 为待发布状态并已推送
git checkout master && git pull origin master

# 2. 打语义化版本 Tag（版本号递增规则见 release-flow.md）
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin v1.1.0
```

线上部署严格依据 Tag 打包。

## 场景 4：线上热修复（Hotfix）

```bash
# 1. 基于线上对应 Tag / master 直接修复
git checkout master && git pull origin master

# 2. 修改、自测 ...

# 3. 提交并打 PATCH 版本 Tag（git add . 而非 commit -am，确保新增文件不遗漏）
git add .
git commit -m "fix(scope): 修复线上xxx问题" -m "Hotfix: true"
git tag -a v1.1.1 -m "Hotfix v1.1.1"
git push origin master && git push origin v1.1.1
```

> 若确实保留了 develop 分支，则 hotfix 需同步合并回 develop，避免下一轮迭代丢失本次线上修复。

## 单人模式保留的硬约束

1. master 应始终可发布：不提交半成品到 master，未完成功能用临时分支隔离。
2. commit message 严格遵循 `commit-spec.md`。
3. 版本号严格遵循语义化规范，Tag 与发布点一一绑定。
4. 高风险操作二次确认：删除分支、force push、rebase 已推送提交、创建 / 删除 Tag。
5. 生成命令前先确认确为单人维护；一旦项目引入第二名开发者或 PR/CI 流程，立即切回团队模式完整 GitFlow（见 `branch-spec.md`、`release-flow.md`）。
