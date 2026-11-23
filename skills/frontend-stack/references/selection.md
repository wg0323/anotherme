# 选型依据与备选方案

数据于 2026-11-23 取自 GitHub REST API（`api.github.com/repos/<owner>/<repo>`）与 npm registry（`api.npmjs.org/downloads/point/last-month/<pkg>`）。这份表就是“为什么是这几件”的凭证，半年后重查一次即可判断结论是否还成立。

## 一、参考项目清单

| 项目 | 定位 | Star | 最新版本 / 最近推送 | npm 月下载 | 参考维度 |
| --- | --- | --- | --- | --- | --- |
| [element-plus/element-plus](https://github.com/element-plus/element-plus) | Vue3 组件库 | 27,871 | 2.14.8 / 2026-11-20 | 3,400,848 | 后端管理 UI 库 |
| [pure-admin/vue-pure-admin](https://github.com/pure-admin/vue-pure-admin) | Element Plus 后台模板 | 20,776 | 2026-10-12 | - | 工程结构、请求与权限封装 |
| [HalseySpicy/Geeker-Admin](https://github.com/HalseySpicy/Geeker-Admin) | Element Plus 轻量后台模板 | 8,100 | 2026-07-29 | - | 轻量起步备选 |
| [dcloudio/uni-app](https://github.com/dcloudio/uni-app) | Vue 语法跨端框架 | 41,698 | 2026-11-20 | - | 移动端一套代码多端 |
| [ijry/uview-plus](https://github.com/ijry/uview-plus) | uni-app 组件库（Vue3） | 723 | 3.8.138（npm）/ 3.8.161（插件市场） | 48,199 | 移动端 UI 库 |
| [Moonofweisheng/wot-design-uni](https://github.com/Moonofweisheng/wot-design-uni) | uni-app 组件库（Vue3+TS） | 2,302 | 1.14.0 / 2026-09-24 | 14,928 | TS 优选的备选 |
| [dcloudio/uni-ui](https://github.com/dcloudio/uni-ui) | uni-app 官方组件库 | 2,090 | 2026-11-20 | - | 官方兜底备选 |
| [youzan/vant](https://github.com/youzan/vant) | 移动端 H5 组件库（Vue3） | 24,429 | 2026-11-20 | 471,187 | 仅 H5 单端时可用 |
| [youzan/vant-weapp](https://github.com/youzan/vant-weapp) | 微信小程序原生组件库 | 18,482 | 2026-10-10 | - | 说明 vant 无法跨端 |

uview-plus 与 wot-design-uni 的 Star 数偏低，是因为 uni-app 组件库主要经 DCloud 插件市场与 npm 分发，GitHub 关注度不代表实际装机量；判断普及度以 npm 下载量 + 中文教程数量为准。

## 二、三件套的理由

- **Vue3 + Element Plus**：国内中后台事实标准，月下载 340 万，是移动端组件库的 7 倍量级。模板生态最全（后台的权限、菜单、请求、布局都有人做好），对 Java 后端来说，写 CRUD 页面时的心智负担最低。
- **uni-app**：同时覆盖 H5、微信小程序、App 且基于 Vue 的成熟方案里只有它，41.7k Star 且持续推送。已有的 Vue 知识可直接复用，不需要再学一套小程序语法。
- **uview-plus**：uni-app 生态里中文示例与问答最多的一档（120+ 组件，覆盖 H5/小程序/App/nvue），且仍在持续发版。组件 API 沿用 uView，AI 生成与搜索命中的准确率都更高。代价是 3.8.139 起转为付费授权，见下一节。

## 三、uview-plus 的授权（2026-10-30 变更）

官方更新日志 3.8.139 原文：「uview-plus 转为付费授权（插件市场普通授权 99 元、源码授权 199 元），并彻底关闭开发文档站广告」。DCloud 插件市场的版权信息同步改为「uview-plus 已转为付费授权模式，您可在 DCloud 插件市场购买普通授权或源码授权后，将 uview-plus 应用到您的产品中」；2026-11-23 市场版本 3.8.161，普通授权 99 元、源码授权 199 元，支持免费试用。

三处官方口径并不一致，这是传闻的由来：

| 来源 | 说法 |
| --- | --- |
| 仓库 `LICENSE` | MIT（`Copyright (c) 2022-2024 uview-plus.jiangruyi.com`），未随 3.8.139 改动 |
| npm 最后一版 3.8.138 的 README | 「遵循 MIT 开源协议，意味着您无需支付任何费用，也无需授权」 |
| 更新日志 + 插件市场版权信息 | 3.8.139 起付费授权，商用需购买普通/源码授权 |

已定结论（个人开发者，不采购授权）：

- 默认栈固定 `3.8.138`——npm 上最后一个 MIT 版本，该版本随包 README 明确写「无需支付任何费用，也无需授权」；按 MIT 条款，已发布版本的授权不因后续版本改授权而失效。
- 三条红线：不执行 `npm update`；`package.json` 不写 `^3.8.138`；不从插件市场导入 3.8.139+ 源码（市场版是付费版，混入即越过授权边界）。lock 文件必须提交。
- 代价是放弃 3.8.139~3.8.161 的修复与新组件。遇到只在新版修掉的问题，自行在项目内打补丁，或换备选 `wot-design-uni`（MIT，组件 70+），不升级。
- 若项目性质变成对外商业交付、客户要求使用新版，再单独评估 99 元普通授权或 199 元源码授权，不在日常开发里默认采购。

## 四、不用 Vant 的理由

你的原方案是 `uni-app + vant`，问题出在 Vant 的分发形态：

1. `vant`（4.x）基于 DOM，只能在浏览器里跑，对应 uni-app 的 H5 端。
2. 小程序与 App 端没有 DOM，`vant` 编译不过去。
3. 微信小程序端要用 `vant-weapp`，它是一套微信小程序原生自定义组件（`usingComponents` 那套）。uni-app 里只能以 `wxcomponents` 方式把它喂给微信小程序端，H5 与 App 端没有对应实现。
4. 结果就是 H5 一套 UI、小程序一套 UI、App 再一套，正好与“一套代码多端”的目标相反。

例外：项目只交付移动端 H5（公众号内页、活动页），不涉及小程序和 App，用 `vant` 完全合理，它是该场景的主流选择。

## 五、移动端组件库对比

| 维度 | uview-plus（默认） | wot-design-uni（备选） | uni-ui（兜底） |
| --- | --- | --- | --- |
| 组件数量 | 120+，含 nvue 兼容 | 70+ | 基础控件为主 |
| TypeScript | 无类型声明（`package.json` 无 `types`） | TS 源码分发，类型完整 | 一般 |
| 授权 | 默认锁 3.8.138（MIT）；3.8.139 起付费（99 / 199 元） | MIT | MIT |
| 维护 | 个人维护，发版频繁 | 个人维护，发版较慢 | DCloud 官方 |
| 中文资料 | 最多（uView 系教程） | 偏少，文档质量高 | 官方文档 |
| 适用 | 默认项目、组件最齐全，锁 3.8.138 免费版使用 | 需要新版能力或组件类型时替换，MIT 无授权成本 | 只用基础控件、要官方背书 |

切换规则：一个项目只选一套；选了哪套、为什么，写进项目 README 的技术栈表。uview-plus 的弱类型不改本栈的 TS 要求——业务代码仍是 TS，组件 props 以官方文档为准。

### 补充候选：TDesign Uniapp 与 uni-ui

| 维度 | TDesign Uniapp（`@tdesign/uniapp`） | uni-ui（`@dcloudio/uni-ui`） |
| --- | --- | --- |
| 出品方 | 腾讯 TDesign 官方，子包放在 `Tencent/tdesign-miniprogram` 仓库（该库 1,804 Star，2026-11-22 仍推送） | DCloud 官方 |
| 版本 | 1.0.0，2026-10-16 上架插件市场 | 1.5.12，仓库 2026-11-20 仍有推送 |
| 协议 | MIT，无授权成本 | MIT，无授权成本 |
| 组件数 | 约 65，覆盖按钮/表单/弹窗/导航/数据展示 | 40 余个基础控件，含 forms 校验、table、file-picker、data-picker |
| TypeScript | 随包提供 `d.ts` | 一般 |
| npm 月下载 | 8,839 | 27,368 |
| 平台 | Vue2/Vue3、H5、Android、iOS、各小程序；App-nvue 仅部分支持 | 全端由官方兜底 |
| 引入方式 | 只能按需：easycom 或 `unplugin-vue-components` 的 TDesignResolver，不支持全量注册 | easycom，HBuilderX 内置 |
| 主要短板 | 生态与问答量小、组件数中等，遇到问题多靠自己读文档；刚发 1.0，行为仍在调整 | 视觉停留在早期风格，业务型组件少，做 C 端门面撑不住 |
| 结论 | 免费方案里设计与类型最好的一档，适合企业内部、管理类移动端 | 最稳的底座与兜底，适合极简工具型页面，不适合当主 UI 库做对外产品 |

TDesign 的一个实用点是组件 API 与 TDesign 小程序版高度一致，搜不到 uni-app 版答案时可以按小程序版文档和问答对照——这能部分弥补资料量。uni-ui 的优势在于跨端兼容由 DCloud 兜底，基本不会出现“某个端编译不过”的问题。

## 六、不纳入默认栈的方案

| 方案 | 结论 | 触发条件 |
| --- | --- | --- |
| React + Ant Design | 不用 | 存量项目或客户指定；两套框架并行维护对个人全栈是负收益 |
| 微信小程序原生 | 不用 | 必须用小程序最新原生能力，或接手原生项目（按 `wx-miniapp-spec`） |
| Taro | 不用 | 它面向 React 生态，与 Vue 栈不统一 |
| Flutter / React Native | 不用 | 需要原生级性能或复杂动画时再评估 |
| Nuxt3 / SSR | 不用 | 需要 SEO 的官网、内容站才用；后台与业务系统不需要 |
| uni-app x | 不用 | uts 生态与 uview-plus 不兼容，组件与资料都少 |

## 七、已知风险

- uview-plus 固定 3.8.138 后不再获得官方修复：3.8.139~3.8.161 修掉的问题只能在项目内打补丁（改源码就复制组件到本地并记录，不直接改 `node_modules`），补丁清单写进项目 README。
- 授权边界：`npm install uview-plus@3.8.138` 拿到的是 MIT 版，插件市场的 3.8.139+ 是付费版；同一项目只用一个来源，混用等于把授权边界搞乱。
- uni-app 项目对 HBuilderX 与编译器版本敏感，多人协作要统一 HBuilderX 大版本，否则同一份代码打包结果可能不同。
- Element Plus 是 Vue3 专版，不要与 Element UI（Vue2）混用；`element-plus` 与 `element-ui` 同时出现在依赖里就是接错了项目。
- uview-plus 依赖 Sass `@import`，Sass 1.8.0+ 会持续报弃用告警，官方建议锁 `sass@1.63.2`。
