# HTML 编码规约

> 来源：阿里巴巴前端规约 · HTML 编码规约（https://alibaba.github.io/f2e-spec/），2026-10-29 提取改写。带编号的规则沿用官方原文编号，便于与原文对照。
> 级别：`强制` 必须遵守；`推荐` 尽量遵守；`参考` 理解并牢记。

## 文件样板

```html
<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>页面标题</title>
    <meta name="description" content="页面描述" />
    <link rel="stylesheet" href="index.css" />
  </head>
  <body>
    <div id="root"></div>
    <script src="./index.js"></script>
  </body>
</html>
```

## 文档结构

- `强制` 文档开头必须有 `<!doctype html>` 且位于 `<html>` 之前，位置错误等同于缺失。
- `强制` 使用 HTML5 doctype，禁止 XHTML / HTML4 doctype；项目统一写小写 `<!doctype html>`。大写 `<!DOCTYPE html>` 在 HTML 中同样合法，仅属于不符合本项目的格式约定。
- `强制` 有且仅有一个位于顶层的 `<html>` 元素；其他元素不得出现在 `<html>` 之外，`<html>` 也不得嵌套在其他元素中。
- `强制` `<html>` 的内容有且仅有一个 `<head>` 和一个 `<body>`；`<script>` 只能置于 `<head>` 或 `<body>` 内。

## lang 属性

- `强制` `<html>` 必须有准确的 `lang` 属性，值使用有效的 BCP 47 语言标签（如 `zh`、`zh-CN`、`zh-Hans`、`en-US`），禁止下划线（`zh_CN` 错误）；只有需要区分地区变体时才添加地区子标签。`lang` 有助于屏幕阅读器、翻译工具与搜索引擎正确处理内容。
- `推荐` 页面内局部内容为其他语言时，在该内容的根元素上单独标注 `lang`，如 `<footer lang="en-US">`。

## meta 元素

- `强制` `<meta>` 必须包含在 `<head>` 内。
- `强制` 必须声明 `<meta charset="utf-8" />`。
- `推荐` 响应式页面必须设置 viewport：`width=device-width, initial-scale=1`。
- `推荐` 不通过 `minimum-scale`、`maximum-scale` 或 `user-scalable=no` 限制用户缩放；页面应支持文本放大至 200% 而不损失内容或功能，自定义手势不能替代浏览器缩放能力。

## 页面标题

- `强制`（1.5.1）页面必须指定 `<title>`，有且仅有 1 个。

## 资源加载

- `推荐`（1.4.1）引入 CSS 与 JS 时无需指定 `type`，`text/css` 与 `text/javascript` 已是默认值。

  ```html
  <link rel="stylesheet" href="example.css" />
  <script src="example.js"></script>
  ```

- `推荐`（1.4.2）在 `<head>` 内引入 CSS，在 `</body>` 前引入 JS。body 内的样式表会引发页面重排重绘；除必须在 DOM 加载前运行的基础库，其余脚本放在 body 末尾以避免渲染阻塞。
- `推荐`（1.4.3）外部资源使用明确的 `https://` 地址，或使用同源根相对/相对 URL；不使用协议相对 URL（`//cdn.example.com/a.js`），避免 HTTP 页面继续加载明文资源。
- `推荐`（1.4.4）用 `preload` 预加载关键资源：`<link rel="preload" href="style.css" as="style" />`。
- `推荐`（1.4.5）用 `preconnect` 与 `dns-prefetch` 处理 DNS 解析延迟。

## 缩进与注释

- `推荐`（2.1.1）统一使用 2 个空格缩进，禁止 4 个空格或 Tab。
- `强制`（2.2.1）HTML 注释中禁止出现任何敏感信息：业务规则、员工隐私（邮箱、手机、身份证号）、AK 与密钥、证书密码、内网 IP/URL、公司与员工内部信息。
- `推荐`（2.2.2）单行注释在注释符与内容之间留一个空格。

  ```html
  <!-- 单行注释 -->
  ```

- `推荐`（2.2.3）多行注释的注释符单独占一行，注释内容 2 个空格缩进。

  ```html
  <!--
    多行注释
  -->
  ```

## 标签

- `强制`（2.3.1）标签名统一小写。

  ```html
  <!-- bad -->
  <H1>Hello, world!</H1>

  <!-- good -->
  <h1>Hello, world!</h1>
  ```

- `推荐`（2.3.2）不省略自闭合标签结尾的斜线，且斜线前留一个空格。这样闭合语义更明确，也与 JSX 规范一致。

  ```html
  <!-- bad -->
  <img src="foo.png" alt="foo">

  <!-- good -->
  <img src="foo.png" alt="foo" />
  ```

## 属性

- `强制`（2.4.1）属性值使用双引号，禁止单引号。

  ```html
  <!-- bad -->
  <link rel='stylesheet' href='example.css' />

  <!-- good -->
  <link rel="stylesheet" href="example.css" />
  ```

- `推荐`（2.4.2）Boolean 属性不写取值，属性存在即表示 `true`。

  ```html
  <!-- bad -->
  <input type="text" disabled="disabled" />

  <!-- good -->
  <input type="text" disabled />
  ```

- `推荐`（2.4.3）自定义属性以 `data-` 为前缀，如 `data-modal="toggle"`。

## 语义化与可访问性

- `参考`（2.5.1）按语义选择标签：列表用 `ul`/`li` 而非 `div` 堆叠，段落用 `p`，锚点用 `a`。这既有助于可访问性，也能在 CSS 加载失败时保持可读。
- `参考`（2.6.1）重视可访问性：`img` 必须提供 `alt`；纯装饰图片用 `alt=""` 或 `role="presentation"`。

## 模板语言

- `强制` 模板变量、过滤器和关键字前后必须有空格：`{{ username }}`、`{{ tags | join(',') }}`。
- `强制` 用户输入必须按输出上下文编码：HTML 文本使用 HTML 转义，属性、URL、CSS 与 JavaScript 分别使用对应的安全编码；向 `<script>` 注入数据时使用框架提供的安全 JSON 序列化并处理 `<` 等字符，不能用 HTML 转义代替，优先避免拼接内联脚本。
