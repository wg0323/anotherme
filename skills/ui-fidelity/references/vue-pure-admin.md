# vue-pure-admin 实例细则

> 事实来源：`pure-admin/vue-pure-admin` main 分支（`package.json` 版本 7.0.0）的 `src/style/tailwind.css`、`src/style/theme.scss`、`src/views/system/user/index.vue`、`stylelint.config.js`。
> **使用前先核对项目自身版本**：v7 起样式方案为 Tailwind CSS 4；v6 及更早多为 Tailwind CSS 3 + `tailwind.config.ts`，语法不同（见第 4 节对照表）。以项目 `package.json` 里的 `tailwindcss` 版本为准，冲突时以项目内实际代码为最高依据。

## 1. 样式体系是三层，不是一层

```
Element Plus CSS 变量（--el-*）        ← 组件库自带，随主题/暗色切换
        ↓ 被引用
项目主题变量（--pure-theme-*）          ← src/style/theme.scss，按 html[data-theme] 切换 8 套配色
        ↓ 被引用
Tailwind @theme 映射（--color-*）       ← src/style/tailwind.css，生成 bg-* / text-* 工具类
```

理解这三层的意义：**改动颜色只能在 token 层进行，不能在页面里写死色值**，否则暗色主题和主题色切换会失效。

## 2. 颜色 token 全集（仅 4 个）

`src/style/tailwind.css` 的原文定义：

```css
@theme {
  --color-bg_color: var(--el-bg-color);
  --color-primary: var(--el-color-primary);
  --color-text_color_primary: var(--el-text-color-primary);
  --color-text_color_regular: var(--el-text-color-regular);
}
```

因此页面里可用的颜色工具类只有：

| 类名 | 实际含义 | 典型用途 |
| ---- | -------- | -------- |
| `bg-bg_color` | `--el-bg-color` | 页面、搜索区、卡片背景 |
| `text-primary` / `bg-primary` / `border-primary` | `--el-color-primary` | 主色文字与强调 |
| `text-text_color_primary` | `--el-text-color-primary` | 正文主色 |
| `text-text_color_regular` | `--el-text-color-regular` | 次要文字 |

更多颜色一律走 Element Plus 变量，例如 `var(--el-fill-color-light)`、`var(--el-border-color-lighter)`、`var(--el-text-color-secondary)`。

**禁止**：`#409eff`、`rgb(...)`、`bg-white`、`text-gray-500`、`border-slate-200`。Tailwind 默认色板不参与主题切换，暗色模式下会变成刺眼的白块。

## 3. 页面骨架（列表页标准答案）

`src/views/system/user/index.vue` 的结构，精简后如下——**新列表页按这个骨架复制**：

```vue
<script setup lang="ts">
import { PureTableBar } from "@/components/RePureTableBar";
import { useRenderIcon } from "@/components/ReIcon/src/hooks";
import { useXxx } from "./utils/hook";   // 表单、列定义、请求都放在 hook 里

defineOptions({ name: "XxxManage" });     // 必填，与路由 name 对应
</script>

<template>
  <el-form :inline="true" class="search-form bg-bg_color w-full pl-8 pt-3 overflow-auto">
    <!-- 每个查询项用 class="w-45!" 固定宽度 -->
    <el-form-item label="名称：" prop="name">
      <el-input v-model="form.name" placeholder="请输入名称" clearable class="w-45!" />
    </el-form-item>
    <el-form-item>
      <el-button type="primary" :icon="useRenderIcon('ri/search-line')" :loading="loading">搜索</el-button>
      <el-button :icon="useRenderIcon(Refresh)" @click="resetForm(formRef)">重置</el-button>
    </el-form-item>
  </el-form>

  <PureTableBar title="标题" :columns="columns" @refresh="onSearch">
    <template #buttons>
      <el-button type="primary" :icon="useRenderIcon(AddFill)" @click="openDialog()">新增</el-button>
    </template>
    <template v-slot="{ size, dynamicColumns }">
      <pure-table
        row-key="id"
        adaptive
        align-whole="center"
        table-layout="auto"
        :loading="loading"
        :size="size"
        :data="dataList"
        :columns="dynamicColumns"
        :pagination="{ ...pagination, size }"
        :header-cell-style="{ background: 'var(--el-fill-color-light)', color: 'var(--el-text-color-primary)' }"
      />
    </template>
  </PureTableBar>
</template>

<style lang="scss" scoped>
.search-form {
  :deep(.el-form-item) {
    margin-bottom: 12px;
  }
}
</style>
```

骨架里有 5 个不可省的约定：`defineOptions({ name })`、搜索区 `bg-bg_color`、查询项 `w-45!`、`PureTableBar` 包裹、`pure-table` 的 `adaptive` + `pagination`。

## 4. Tailwind 版本语法对照（最高频错误点）

| 场景 | Tailwind 4（v7，正确） | Tailwind 3（旧，v7 中写错） |
| ---- | ---------------------- | --------------------------- |
| 提升优先级 | `w-45!`（后缀） | `!w-45`（前缀） |
| 引用 CSS 变量 | `bg-(--el-fill-color-light)` | `bg-[var(--el-fill-color-light)]` |
| 任意值 | `w-[calc(100%-200px)]` | 同左 |

另外 `src/style/tailwind.css` 里还定义了可直接用的自定义工具类：

| 工具类 | 等价于 |
| ------ | ------ |
| `flex-c` | `flex justify-center items-center` |
| `flex-ac` | `flex justify-around items-center` |
| `flex-bc` | `flex justify-between items-center` |

布局时优先用这三个，不要每次手写一长串。

## 5. 图标规则

- 统一用 `useRenderIcon()` 渲染：`:icon="useRenderIcon(Refresh)"`，或直接传字符串 `useRenderIcon('ri/search-line')`。
- 图标集只有 `@iconify` 下的 `ri`（Remix Icon）与 `ep`（Element Plus），以 `~icons/ri/xxx`、`~icons/ep/xxx` 形式引入。
- **禁止**：安装新图标库、在模板里直接写 `<IconXxx />` 组件、用 emoji 代替图标。

## 6. 正反例对照

**表格**

```vue
<!-- 错误：裸 el-table，自行拼分页与工具栏 -->
<el-table :data="list"> ... </el-table>

<!-- 正确：PureTableBar + pure-table -->
<PureTableBar :columns="columns"> <template v-slot="{ size, dynamicColumns }"> ... </template> </PureTableBar>
```

**背景与文字**

```vue
<!-- 错误：暗色主题下变成刺眼白块 -->
<div class="p-4 bg-white rounded-lg shadow">

<!-- 正确：跟随主题 -->
<el-form class="search-form bg-bg_color w-full pl-8 pt-3 overflow-auto">
```

**优先级写法**

```vue
<!-- 错误（Tailwind 4 无效） -->
<el-input class="!w-45" />

<!-- 正确 -->
<el-input class="w-45!" />
```

**表头样式**

```vue
<!-- 错误：直接写死色值 -->
:header-cell-style="{ background: '#f5f7fa' }"

<!-- 正确：走 Element Plus 变量 -->
:header-cell-style="{ background: 'var(--el-fill-color-light)', color: 'var(--el-text-color-primary)' }"
```

**局部覆盖**

```vue
<!-- 错误：全局覆盖，污染其他页面 -->
<style>
.el-button:focus-visible { outline: none; }
</style>

<!-- 正确：scoped + :deep() -->
<style lang="scss" scoped>
:deep(.el-button:focus-visible) { outline: none; }
</style>
```

## 7. 建议的基准页

| 页面类型 | 建议文件 | 说明 |
| -------- | -------- | ---- |
| 列表页（搜索 + 表格 + 分页 + 批量操作 + 行操作） | `src/views/system/user/index.vue` | 覆盖面最全，是首选基准 |
| 树形 / 左树右表 | `src/views/system/user/tree.vue` 及其组合方式 | 同一页面中有 `deviceDetection()` 响应式写法 |
| 业务逻辑组织 | `src/views/system/user/utils/hook.ts` | 表单、列定义、分页、弹窗开关都放在 hook 里，页面只留模板 |
| 弹窗表单 | 与列表页同目录的表单组件（以项目实际为准） | 新增/编辑复用同一组件，通过 `openDialog('修改', row)` 打开 |

## 8. 工程校验

项目自带 `pnpm lint`（eslint + prettier + stylelint），其中 stylelint 使用 `stylelint-config-recess-order` 强制属性排序、`prettier/prettier` 强制格式。交付前必须运行并通过，不要手写与 lint 规则冲突的样式块。
