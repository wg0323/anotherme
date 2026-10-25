# 版本控制与完整 GitFlow 流程

## 语义化版本号规范

**标准格式**：`MAJOR.MINOR.PATCH[-PRERELEASE]`

| 版本位           | 递增触发条件                     | 版本变更示例  |
| ---------------- | -------------------------------- | ------------- |
| `MAJOR` 主版本   | 不兼容的公共 API 或行为变更；兼容的架构重构、业务大改版不单独触发 | 1.0.0 → 2.0.0 |
| `MINOR` 次版本   | 向后兼容，新增业务功能迭代       | 1.0.0 → 1.1.0 |
| `PATCH` 补丁版本 | 线上版本缺陷修复、小问题补丁     | 1.0.0 → 1.0.1 |

预发布后缀标识：

- `alpha`：内部开发自测版本
- `beta`：团队内测提测版本
- `rc`：候选发布版本，接近正式上线

## Git Tag 标签管理

| Tag 类型     | 允许创建的分支        | 格式示例      | 说明                              |
| ------------ | --------------------- | ------------- | --------------------------------- |
| 正式版本 Tag | **仅 master**         | `v1.0.0`      | 生产部署唯一依据                  |
| 预发布 Tag   | **仅 release/\***     | `v1.0.0-rc.1` | 测试验证用，禁止用于生产部署      |
| 禁止打标分支 | `feature/fix/develop` | -             | 严禁在任何临时/开发分支打版本 Tag |

```bash
# 在 master 分支创建带说明的正式版本标签
git tag -a v1.0.0 -m "Release version 1.0.0 正式上线"
git push origin v1.0.0

# 在 release 分支创建预发布标签
git tag -a v1.0.0-rc.1 -m "Release candidate 1 for v1.0.0"
git push origin v1.0.0-rc.1

# 本地删除标签
git tag -d v1.0.0
# 远程仓库删除标签（需二次确认）
git push origin --delete v1.0.0
```

## 四段式标准 GitFlow 全流程

### 流程 1：新功能迭代开发（Feature 流程）

1. 切换并拉取远端最新 develop 分支。
2. 基于 develop 创建 `feature/*` 功能分支，本地编码自测。
3. 开发完成后，若分支未共享则 rebase 上游 develop 解决冲突；若已共享则 merge develop。
4. 发起 PR 以 **Squash Merge** 方式合并至 develop。
5. PR 审核 + CI 校验通过后合入 develop，删除 feature 临时分支。

### 流程 2：版本打包预发布（Release 流程）

1. 当期迭代所有 feature 分支全部合并完毕，develop 分支代码冻结。
2. 基于 develop 新建 `release/vX.Y.Z` 发布分支。
3. 测试人员基于 release 分支测试，仅在本分支修复 bug，禁止新增需求；可在 release 分支打预发布 Tag。
4. 测试验收通过后，发起两次 PR（均使用 `--no-ff` Merge Commit）：
   - PR1：release → master，合并后在 master 创建并推送正式版本 Tag。
   - PR2：release → develop，把 release 期间所有 bug 修复同步回开发基线。
5. 两次合并全部完成，删除 release 分支。

### 流程 3：线上生产环境紧急热修复（Hotfix 流程）

1. 切换至 master 分支，拉取远端最新线上稳定代码。
2. 基于 master 新建 `hotfix/*` 补丁分支，针对性修复线上故障。
3. 自测 + 测试验证修复生效后，发起双向 PR（均使用 `--no-ff` Merge Commit）：
   - PR1：hotfix 合并入 master，新增补丁 Patch 版本 Tag 并推送，用于生产环境紧急发布。
   - PR2：hotfix 必须合并入 develop，避免下一轮迭代丢失本次线上修复。
4. 双分支合并完毕，删除 hotfix 临时分支。

### 流程 4：迭代内开发 bug 修复（Fix 流程）

1. 从最新 develop 拉出 `fix/*` 分支修改问题。
2. 修复自测完成后以 **Squash Merge** 方式 PR 合入 develop，审核通过后删除 fix 分支。
