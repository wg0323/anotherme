# 项目 UI 基线模板

> **存放位置**：基线统一放在**仓库根**的 `docs/`，不放进前端子项目；前端本身就是独立仓库时，“仓库根”就是该前端项目的根目录。
> 单前端使用 `docs/ui-baseline.md`。多前端按 `doc-writing` 技能的 `references/docs-structure.md` 处理：不足 3 份平铺为 `docs/ui-baseline-<项目名>.md`，满 3 份放入 `docs/ui-baseline/<项目名>.md`。
> 多前端必须为每个项目使用独立基线，不让 PC 与移动端共用文件。
>
> **用途**：复制本文件后逐项填写。它是 AI 生成界面的**唯一事实来源**——技能只提供方法，具体 token、组件、基准页写在这里。
> 留空的条目视为“未定义”，AI 必须停下询问，不得自行补全。

---

## 1. 模板信息

| 项 | 填写内容 |
| --- | -------- |
| 前端代码目录（相对仓库根） | 例：`frontend/`、`web/`、`apps/admin/`；前端在仓库根时填 `./` |
| 模板来源与版本 | 例：pure-admin/vue-pure-admin v7.0.0（精简版 pure-admin-thin v7.0.0） |
| UI 组件库及版本 | 例：Element Plus 2.14 |
| 样式方案 | 例：Tailwind CSS 4 + SCSS |
| 图标方案 | 例：unplugin-icons + @iconify，`~icons/ri/*`、`~icons/ep/*` |
| 全局样式入口（相对前端代码目录） | 例：`src/style/tailwind.css`、`src/style/theme.scss`、`src/style/element-plus.scss` |
| 包管理与 lint 命令（在前端代码目录执行） | 例：pnpm，`pnpm lint` |

## 2. 基准页清单（最关键的一节）

选 1～3 个“写得最规范”的现有页面当作标准答案。AI 生成同类页面前必须先完整读取对应文件。

| 页面类型 | 基准文件路径（相对第 1 节的前端代码目录） | 该文件示范了什么 |
| -------- | ------------ | ---------------- |
| 列表页（搜索 + 表格 + 分页） | 例：`src/views/system/user/index.vue` | 搜索表单、工具栏按钮、批量操作条、行操作、分页 |
| 表单页 / 新增编辑弹窗 | 例：`src/views/xxx/form.vue` | 弹窗宽度、表单项排布、校验提示、底部按钮位置 |
| 详情页 | 例：`src/views/xxx/detail.vue` | 卡片分组、字段标签与值的对齐方式 |
| 其他高频页面 | | |

## 3. 颜色白名单

只允许使用下列 token。**禁止出现十六进制色值，禁止使用 Tailwind 默认色板**（`bg-white`、`text-gray-500`、`border-slate-200` 等）——这些颜色在暗色主题下不会跟随切换。

| 用途 | 类名 / 变量 |
| ---- | ----------- |
| 页面与卡片背景 | 例：`bg-bg_color` |
| 主色文字与强调 | 例：`text-primary` |
| 主要文字 | 例：`text-text_color_primary` |
| 次要文字 | 例：`text-text_color_regular` |
| 表头 / 选中态底色 | 例：`var(--el-fill-color-light)` |
| 分隔线 | 例：`var(--el-border-color-lighter)` |

## 4. 组件白名单

| 用途 | 组件名 | 导入路径 | 禁止的替代方案 |
| ---- | ------ | -------- | -------------- |
| 数据表格 | 例：`pure-table` | `@pureadmin/table` | 禁止裸 `el-table` 自拼分页 |
| 表格工具栏 | 例：`PureTableBar` | `@/components/RePureTableBar` | 禁止自己搭标题栏与右侧按钮区 |
| 图标渲染 | 例：`useRenderIcon` | `@/components/ReIcon/src/hooks` | 禁止直接引入图标组件 |
| 弹窗 | | | |
| 分页 | | | |
| 业务卡片 | | | |

## 5. 布局与间距约定

| 项 | 约定 |
| --- | ---- |
| 页面外层包裹 | 例：搜索区 `bg-bg_color`，表格区不再额外套 `el-card` |
| 常用布局工具类 | 例：`flex-c`（水平垂直居中）、`flex-bc`（两端对齐）、`flex-ac`（环绕居中） |
| 间距取值 | 例：仅用 4 的倍数；搜索表单 `pt-3 pl-8`，行间距 12px |
| 圆角与阴影 | 例：沿用 `--el-border-radius-base`，不自加 `shadow-lg` |
| 响应式 | 例：窄屏用 `deviceDetection()` 判断，不自造媒体查询断点 |

## 6. 样式写法约定

- **原子类与 scoped SCSS 的分工**：例：布局用原子类，复杂状态与深层选择器用 scoped SCSS。
- **覆盖组件内部样式**：只在 `<style lang="scss" scoped>` 内用 `:deep()`，并在注释里写明为什么要覆盖。
- **禁止**：`!important` 堆叠、未经用户明确批准的全局覆盖 `.el-*`、内联 `style` 写颜色、在模板里写 `<style>` 非 scoped。批准的全局修改须记录在差异说明中。

## 7. 禁止清单

以下按项目实际情况增删，写进去的就是硬红线：

- 禁止引入新的 UI 库、CSS 框架、图标库、动画库。
- 禁止新增设计令牌（颜色、字号、圆角、阴影、间距变量）。
- 禁止自行新建通用组件——需要时先停下问人，由人决定是否沉淀。
- 禁止批量改写既有页面的 class、结构或 props 命名。
- 未经用户明确批准，禁止修改全局样式入口（第 1 节列出的文件）；批准项须记录在差异说明中。
- 禁止改动模板自带的布局壳、主题切换、权限路由等基础设施代码。
- （按项目补充）

## 8. 交付自检

- [ ] 已完整读过第 2 节的基准页
- [ ] 颜色全部来自第 3 节，无十六进制值；使用 Tailwind 时无默认色板
- [ ] 组件全部来自第 4 节
- [ ] 无未经批准的全局样式改动，无 `!important`；批准项已记录
- [ ] 项目配置 lint 时已执行并通过，未配置时标记不适用
- [ ] 项目支持暗色主题时已切换检查，未支持时标记不适用
