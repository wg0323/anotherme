# CHANGELOG.md 模板

格式参考 [Keep a Changelog](https://keepachangelog.com/)，遵循语义化版本（Semantic Versioning）规范。

## 强制要求

- 每个版本必须标注发布日期（格式：`YYYY-MM-DD`）。
- 每个版本按以下分类记录变更：
  - `Added`：新增功能。
  - `Changed`：功能变更。
  - `Deprecated`：即将废弃的功能。
  - `Removed`：已移除的功能。
  - `Fixed`：修复问题。
  - `Security`：安全修复。
- 不兼容变更（Breaking Changes）需在版本号与分类中显著标注，并在正文中用 **BREAKING** 前缀说明影响范围。

## 模板

```markdown
# 更新日志

本文件记录项目所有版本的变更，格式基于 Keep a Changelog，版本号遵循语义化版本规范。

## [未发布]

### Added
- 待发布的新功能

## [1.1.0] - 2026-09-01

### Added
- 新增用户注册邮箱验证码功能

### Changed
- 登录接口响应结构调整（**BREAKING**：`data.token` 移至 `data.accessToken`，调用方需同步修改）

### Fixed
- 修复订单列表分页参数越界问题

## [1.0.0] - 2026-08-01

### Added
- 首个正式版本发布
```
