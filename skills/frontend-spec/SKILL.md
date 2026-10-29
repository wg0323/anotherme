---
name: frontend-spec
description: |
  前端编码规范。当用户编写、修改、重构或审查 HTML、CSS/SCSS/Less、JavaScript、
  TypeScript、React 组件、Node.js 代码时必须使用本技能：涵盖缩进与分号、命名、注释、
  类型定义、Hooks 用法、模块依赖、Props 校验、服务端安全规约等强制与推荐规范。
  适用于 Web 前端与 Node.js 服务端；Vue / 小程序 / uni-app 的框架语法与工程结构、
  界面视觉保真分别以对应技能为准。
---

# 前端编码规约

依据《阿里巴巴前端规约》提炼。规则分三级：`强制` 必须遵守；`推荐` 尽量遵守；`参考` 理解并牢记。原文编号保留在 references 中，便于与官方文档对照。

## 核心铁律（跨语言最高频）

以下为高频约束，逐条的具体级别与例外见各章节文件。

1. 通用格式：2 个空格缩进与 UTF-8 编码为强制项，单行建议不超过 100 字符。
2. 每条语句以分号结尾；变量声明只用 `const` / `let`，禁止 `var` 与隐式全局变量。
3. 比较一律用 `===` / `!==`，不依赖隐式类型转换。
4. 字符串用单引号（JS / TS），JSX 属性用双引号；模板字符串仅在有插值或换行时使用。
5. 大括号采用 Egyptian Brackets：`{` 前不换行、`}` 独占行，`}` 后接 `else` / `catch` / `while` 时不换行。
6. 命名：变量与函数小驼峰，类与组件大驼峰，全大写下划线仅用于 `export` 的 `const` 常量；命名首尾不加下划线。
7. HTML / CSS：`<!doctype html>` 位于文档开头、`<html lang>` 必须标注、属性值用双引号；CSS 声明以分号结尾，避免不必要的 `!important`，组件样式优先使用 class 选择器。
8. TypeScript：`interface` / `type` 成员必须声明类型、分隔符统一 `;`；断言一律 `as Type`，禁止 `<Type>` 与可选链后的非空断言。
9. React：Hooks 只在组件与自定义 Hook 的顶层调用、自定义 Hook 以 `use` 开头；列表 key 用稳定业务 id；`useEffect` 声明全部依赖。
10. Node.js：抛出原生 `Error`；线上避免 `fs` / `child_process` 的 sync 方法；错误详情不下发客户端、SQL 值必须参数化、入参应严格校验。

## 速查表

| 领域 | 高频约束 |
| ---- | -------- |
| HTML | 标签名小写、语义化选标签、`img` 必带 alt、注释禁含敏感信息 |
| CSS | `:` 后一个空格、十六进制小写且取最短、0 值省略单位、组合器两侧空格 |
| JS | 数组方法回调必须 return、用扩展运算符与解构、单条声明单变量、禁止 `eval` / `debugger` |
| TS | 优先 `interface`、禁止空接口与 `namespace`、类型声明冒号后一个空格 |
| React | 多行 JSX 加小括号、无子元素用自闭合、Props 小驼峰、`target="_blank"` 配 `rel` |
| Node | 依赖按「内置 → 三方 → 本地」排序、用 `node:fs/promises`、应用无状态、上传优先走对象存储 |

## 详细规范（按场景读取）

| 场景 | 参考文件 |
| ---- | -------- |
| 缩进、行宽、字符集等跨语言通用项 | `references/common.md` |
| 页面结构、doctype、meta、资源加载、语义化与可访问性 | `references/html.md` |
| 样式书写、选择器、属性顺序、Sass / Less | `references/css.md` |
| 变量、类型转换、数组对象、函数、类、模块、操作符、注释、命名 | `references/javascript.md` |
| 类型组织、断言、类成员、模块导入、注释指令 | `references/typescript.md` |
| 组件结构、JSX 风格、Props / State / Refs、Hooks、无障碍 | `references/react.md` |
| Node 版本、依赖顺序、异常处理、安全规约、最佳实践 | `references/nodejs.md` |

## 与其他技能的分工

| 维度 | 以谁为准 |
| ---- | -------- |
| 语言层面的编码规范（本技能的 7 章） | 本技能 |
| 既有 Vue 3 模板中的视觉一致与组件复用 | `ui-fidelity` |
| uni-app / 微信小程序的框架语法与工程结构 | `uniapp-spec` / `wx-miniapp-spec` |
| Node.js 服务架构、API、认证与中间件 | `nodejs-backend-patterns` |
| Java / Spring Boot 后端接口、分层与安全 | `springboot-spec` |
| 提交信息与分支流程 | `gitflow` |

## 执行规则

1. 生成前端代码时自动遵守全部 `强制` 项；不采用某条 `推荐` 项时说明理由。
2. 代码违反 `强制` 项时，先指出问题与对应规则编号，再输出修正代码。
3. 项目已配置 ESLint / Stylelint / Prettier 时以项目现有配置为准；配置与本文冲突时按项目配置执行，并说明差异。
