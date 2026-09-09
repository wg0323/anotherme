---
name: uniapp-spec
description: |
  uni-app（Vue3 + Vite）跨端项目开发规范。当用户涉及以下场景时必须使用本技能：
  创建 uni-app 项目、编写页面/组件、封装 uni API 与请求、跨端适配（H5/小程序/App）、
  分包与性能优化。不适用于微信小程序原生开发项目。
---

# uni-app 跨端开发规范

## 一、JS/TS 与组件规范（强制）

1. **语法底线**：禁 `var`/`==`/`!=`/`arguments`/`for...in`/`+`拼接/`module.exports`；优先 `const`、箭头函数、模板字符串、ESModule、解构、可选链 `?.`、空值合并 `??`。
2. **异步处理**：统一 `async/await + try-catch`；仅简短场景用 `.then`；uni API 必须 Promise 化（推荐 `@dcloudio/uni-promisify`），禁回调地狱。
3. **Vue3 Setup**：统一 `<script setup lang="ts">`，禁 Options-API；`defineProps/Emits` 必须显式泛型声明类型 + 默认值。
4. **注释要求**：文件头注明用途/作者/日期/模块；复杂逻辑必注释；生产环境禁 `console.log`。

## 二、uni-app 跨端工程规范

1. **目录约定**：`components`（easycom）、`pages`（含分包）、`api`（按模块拆分 `xxx.Api.ts`）、`config`、`static`、`utils`、`store`（Pinia）、`uni_modules`。
2. **请求与路由**：禁裸调 `uni.request`，必须二次封装（拦截器/Token/错误处理）；跳转优先 JS-API 便于埋点，禁硬编码路由。
3. **跨端适配**：样式优先 `rpx`（px 仅限 H5/1px 边框）；条件编译 `#ifdef` 仅必要时用；区分页面生命周期（onLoad）与组件生命周期（onMounted）。
4. **性能与体积**：导航栏/TabBar 优先原生配置；大图走 CDN；微信主包 ≤2MB；按需分包优化首屏。

## 三、AI 生成项目硬性约束（最高优先级）

> 生成 uni-app 项目时，严格复刻 HBuilderX 官方 Vue3 默认模板，做到零缺失、零截断。

### 完整性校验

- 根目录必含：`App.vue`、`main.js`、`index.html`、`manifest.json`、`pages.json`、`uni.scss`、`.gitignore`。
- 基础文件夹必含：`pages`（含 `index/index.vue`）、`static`、`components`、`uni_modules`、`unpackage`。
- `manifest.json` 填全 H5/小程序/App 配置；`pages.json` 配全路由与窗口样式；`main.js` 标准 `createApp` 挂载；`App.vue` 含 `onLaunch`。

### 输出铁律

- **顺序**：完整树形目录 → 根文件 → pages → components。
- **质量**：所有文件输出**完整可运行源码**，禁省略/截断/只写 template；路径统一 `@/`；生成后自查补全，缺文件视为不合格。
