# Node.js 开发规约

> 来源：阿里巴巴前端规约 · Node.js 开发规约（https://alibaba.github.io/f2e-spec/），2026-10-29 提取改写，编码风格 follow eslint-config-egg。
> 级别：`强制` 必须遵守；`推荐` 尽量遵守；`参考` 理解并牢记。

## 运行时版本

- `强制` 仅使用 Current、Active LTS、Maintenance LTS 版本，禁止 Unstable 与 EOL 版本。
- `推荐` 生产项目优先使用 Active LTS，不使用生命周期通常只有六个月的奇数编号 Current 版本。

## 编码风格

- `推荐`（1.1）直接使用 Node.js 内置全局变量，不要从模块中解构引入：`Buffer`、`URL`、`URLSearchParams`、`TextEncoder`、`TextDecoder`、`process`、`console`。

  ```js
  // bad
  const { Buffer } = require('buffer');

  // good
  const b = Buffer.alloc(16);
  ```

- `推荐`（1.2）使用模块内置的 promises API，不要用回调形式。

  ```js
  // bad
  const fs = require('node:fs');
  fs.readFile(filePath, 'utf8', (error, content) => {});

  // good
  const fs = require('node:fs/promises');
  const content = await fs.readFile(filePath, 'utf8');
  ```

- `推荐`（1.3）`import` / `require` 引用声明放在文件顶端（动态 `require` 除外），模块格式遵循项目现有 ESM/CJS 配置。顺序为「Node 内置模块 → npm 包 → 本地文件」，三类之间各空一行，类内按字典序排列；解构引用以第一个成员定序，解构内部也按字典序。

  ```js
  const fs = require('node:fs');
  const http = require('node:http');

  const { Bar, Foo } = require('tool');
  const moment = require('moment');

  const Car = require('./models/car');
  ```

- `推荐`（1.4）抛出异常必须使用原生 `Error` 对象，禁止抛出字符串、数字、`null`、`undefined` 或字符串拼接后的错误。

  ```js
  // bad
  throw 'error';
  throw 'an ' + new Error();

  // good
  throw new Error('error');
  ```

- `推荐`（1.5）线上环境不要使用 `fs` / `child_process` 的 `sync` 方法（`readFileSync`、`execSync` 等），它会阻塞进程导致请求超时；改用内置的 `node:fs/promises` 或异步子进程 API。

## 安全规约

- `强制`（2.1）在客户端隐藏错误详情，避免暴露敏感系统信息被利用。
- `强制`（2.2）隐藏或伪造技术栈与框架标识（如 `X-Powered-By` 响应头），防止公开漏洞被针对性利用。
- `强制`（2.3）JSONP 跨域接口必须严格校验访问来源，配置域名白名单。
- `强制`（2.4）禁止使用从请求参数或明文 Cookie 中获取的用户标识进行敏感信息查询输出，防止未授权访问与越权。
- `强制`（2.5）防 SQL 注入：SQL 值必须参数化；表名、字段名等无法参数化的标识符必须从服务端固定白名单中选择，不得直接拼接请求输入，必要时使用数据库驱动提供的标识符引用能力。
- `推荐`（2.6）定期检查过期依赖与依赖漏洞并及时升级或替换。
- `推荐`（2.7）用户上传的文件不允许落到服务器本地，必须上传到 OSS 等对象存储。
- `推荐`（2.8）服务端 URL 重定向必须做域名白名单校验，不允许跳转到白名单之外的域名。
- `推荐`（2.9）接口入参严格校验，用 jsonschema、joi 等工具，减少意外输入导致的报错与脏数据。

## 最佳实践

- `推荐`（3.1）应用不应有状态，数据放外部存储，保证实例结束不影响数据与服务。
- `推荐`（3.2）不要用 Node.js 托管前端静态文件，应放 CDN，避免静态资源高访问量阻塞其他服务。
- `推荐`（3.3）把 CPU 密集型任务（gzip、SSL 等）代理给 nginx 或其他服务，Node.js 不适合这类任务。
- `推荐`（3.4）使用 `async/await`，避免回调函数，规避回调地狱并简化异常处理。
- `推荐`（3.5）用 `util.promisify` 把回调式函数转成返回 Promise 的形式。
- `推荐`（3.6）使用原生 `Promise`，不要引入 bluebird 等三方 Promise 库。
- `推荐`（3.7）设计为链式调用的类变更方法返回 `this`；查询、计算和异步方法按其实际结果返回，不为链式调用统一返回 `this`。
- `推荐`（3.8）接入 APM 性能监控平台，覆盖性能快照、依赖更新提示、异常日志与慢 HTTP 日志。
