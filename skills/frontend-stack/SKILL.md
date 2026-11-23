---
name: frontend-stack
description: |
  前端默认技术栈的固定选型与新建工程约束。当用户新建前端项目、给系统补前端、
  选前端框架或 UI 组件库，或确定管理后台、移动端 H5、微信小程序、App 的技术方案时使用本技能。
  负责“选什么、从哪起步”；HTML/CSS/JS/TS 语言规范归 frontend-spec，uni-app 语法与工程细则归 uniapp-spec，
  既有模板内新增页面的视觉保真归 ui-fidelity。
---

# 前端默认技术栈

固定一套大众方案，覆盖管理后台、H5、小程序、App。选型只按“用的人多、资料好查”排序，不追新技术。生态数据与备选方案见 `references/selection.md`（2026-11-23 核实）。

## 一、默认栈

| 维度 | PC 管理后台 | 移动端（H5 / 小程序 / App） |
| --- | --- | --- |
| 框架 | Vue 3 + Vite | uni-app Vue3（非 uni-app x） |
| 语言 | TypeScript | TypeScript |
| UI 库 | Element Plus 2.14.x | uview-plus 3.8.138（锁死版本，`up-` 前缀） |
| 路由 | Vue Router 4 | `pages.json`，不引 Vue Router |
| 状态 | Pinia | Pinia |
| 请求 | Axios 二次封装 | `uni.request` 二次封装，不引 axios |
| 图表 | ECharts 5 | H5 用 ECharts 5，小程序用 uCharts |
| 样式 | SCSS；模板自带 Tailwind 则沿用 | SCSS + rpx |
| 起步 | 克隆 `vue-pure-admin` | `npx degit dcloudio/uni-preset-vue#vite-ts` |

需要桌面端时，用 Electron 壳套后台同一套页面，不另写一套 UI。

## 二、铁律

1. 一个项目只以一套 UI 组件库为主（后台 Element Plus，移动端 uview-plus）。缺组件时先用该库现有组件组合实现；确实要补官方 `uni-ui` 的单个组件，在 README 记录原因，且不改全局主题。
2. 移动端不用 Vant：`vant` 是 Vue3 的 H5(DOM) 库，小程序/App 无 DOM；`vant-weapp` 是微信小程序原生组件，在 uni-app 里只能以 `wxcomponents` 方式用于小程序端，H5 与 App 端没有对应实现。
3. 移动端一律 uni-app 一套代码多端；只有必须用小程序最新原生能力、或接手已有原生小程序时，才按 `wx-miniapp-spec` 写原生。
4. Vue 只准 3.x + `<script setup>`；Vue 2 已 EOL，新项目不选。
5. 请求层必须二次封装（baseURL、Token、错误码、loading）；页面里不出现 `axios`、`uni.request`、接口地址。
6. 存量项目已用其他栈（React、Ant Design Vue、Vant H5、原生小程序）就沿用现有栈，不为统一而换库。
7. 默认栈之外的框架、UI 库、微前端、SSR、新跨端方案，先给出收益与成本、经用户确认后才能引入。
8. 新建前端工程交付 README：技术栈表、启动命令、打包命令、部署目录，按 `doc-writing` 的 `references/readme-template.md` 写。
9. `uview-plus` 固定 `3.8.138`，不升级。它是 npm 上最后一个 MIT 版本（3.8.139 起官方转为付费授权：普通 99 元 / 源码 199 元），个人开发不采购授权，因此禁止 `npm update`、禁止 `^3.8.138` 范围写法、禁止从插件市场导入 3.8.139+ 源码。需要新版才有的修复时，换备选 `wot-design-uni`（MIT），不要升级。理由与判据见 `references/selection.md`。

## 三、按场景读取

| 场景 | 参考文件 |
| --- | --- |
| 新建/改造管理后台：模板选择、目录、请求封装、代理、部署 | `references/admin-vue3-element-plus.md` |
| 新建/改造移动端：工程创建、uview-plus 接入、多端差异、打包 | `references/mobile-uniapp.md` |
| 选型依据、备选与切换条件、不用 Vant 的完整理由 | `references/selection.md` |

## 四、与其他技能的分工

| 维度 | 以谁为准 |
| --- | --- |
| 选什么框架/组件库、从哪起步 | 本技能 |
| HTML/CSS/JS/TS 语言规范 | `frontend-spec` |
| uni-app 语法、目录、跨端适配、README 交付 | `uniapp-spec` |
| 微信小程序原生开发 | `wx-miniapp-spec` |
| 既有模板里加页面的视觉一致 | `ui-fidelity` |
| 后端接口与分层 | `springboot-spec` |
