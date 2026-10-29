# TypeScript 编码规约

> 来源：阿里巴巴前端规约 · TypeScript 编码规约（https://alibaba.github.io/f2e-spec/），2026-10-29 提取改写。
> 级别：`强制` 必须遵守；`推荐` 尽量遵守；`参考` 理解并牢记。
> 本文未覆盖的编码风格，一律遵循 `javascript.md`。

## 类型组织

- `强制` 重载的函数必须写在一起，中间不插入其他函数声明。

  ```ts
  // bad
  export function foo(s: string): void;
  export function foo(n: number): void;
  export function bar(): void;
  export function foo(sn: string | number): void;

  // good
  export function bar(): void;
  export function foo(s: string): void;
  export function foo(n: number): void;
  export function foo(sn: string | number): void;
  ```

- `推荐` 简单类型（数字、字符串、布尔等）用 `T[]` / `readonly T[]`，复杂类型（联合、交叉、对象、函数）用 `Array<T>` / `ReadonlyArray<T>`。

  ```ts
  // bad
  const a: (string | number)[] = ['a', 1];
  const e: Array<string> = ['a', 'b'];

  // good
  const a: Array<string | number> = ['a', 1];
  const e: string[] = ['a', 'b'];
  ```

- `推荐` 优先用 `interface` 定义对象类型；联合类型、别名等无法用 interface 表达时才用 `type`。

  ```ts
  // bad
  type T = { x: number };

  // good
  interface T {
    x: number;
  }
  ```

- `强制` `interface` / `type` 的成员分隔符统一用 `;`，禁止逗号风格与省略分隔符。

- `强制` `interface` / `type` 定义时必须声明成员类型，禁止隐式 `any`。

  ```ts
  // bad
  type Members = {
    member;
  };

  // good
  type Members = {
    member: boolean;
  };
  ```

- `推荐` 接口中的方法用属性方式定义，可获得更严格的检查；重载场景用交叉类型组合。

  ```ts
  // bad
  interface T1 {
    func(arg: string): number;
  }

  // good
  interface T1 {
    func: (arg: string) => number;
  }
  ```

- `推荐` 避免定义空接口，以及只继承单个接口的空接口（与被继承类型等效）。

- `推荐` 定义函数时优先使用参数联合类型，而不是函数类型重载。

  ```ts
  // bad
  function f(x: number): void;
  function f(x: string): void;

  // good
  function f(x: number | string): void;
  ```

- `强制` 禁止无意义的 `void` 类型：只能用于返回值或泛型参数，禁止参与除 `never` 外的联合、交叉，禁止作为属性、参数类型。

## 类型断言

- `强制` 类型断言统一用 `as Type`，禁止 `<Type>` 写法（易与 JSX 混淆）；`as const` 不受此限。

  ```ts
  // bad
  const foo = <string>'bar';

  // good
  const foo = 'bar' as string;
  ```

- `强制` 对象字面量禁止类型断言（断言成 `any` / `unknown` 除外），应直接声明类型。

  ```ts
  // bad
  const x = { ... } as T;

  // good
  const x: T = { ... };
  const y = { ... } as any;
  ```

- `推荐` 变量的值与类型声明相等时优先用 `as const`。

- `推荐` 禁止在相等比较运算符前使用非空断言 `!`，容易与 `!=` / `!==` 混淆。

  ```ts
  // bad
  const isEqualsBar = foo.bar! == 'hello';

  // good
  const isEqualsNum = (1 + foo.num!) == 2;
  ```

- `强制` 禁止在可选链（`?.`）之后使用非空断言 `!`，会引入严重的类型安全问题。

  ```ts
  // bad
  foo?.bar!;

  // good
  foo?.bar;
  ```

## 类与成员

- `推荐` 类属性为字面量时用 `readonly` 而非 `getter`（字面量包括字符串、模板字符串、数字、bigint、正则、null）。例外：对外暴露给 JavaScript 使用者时用 getter，因为 `readonly` 只在编译期生效。
- `推荐` 显式设置成员可访问性：非公开成员标 `protected` / `private`，公开成员可省略 `public`。
- `推荐` 类成员顺序：static 优先于 instance；属性 → 构造函数 → 方法；public → protected → private。
- `推荐` 不要把 `this` 赋值给其他变量，用箭头函数保留作用域。

## 模块与导入

- `强制` 禁止用 `namespace` / `module` 关键字定义命名空间，统一用 ES 模块语法；`declare module`、`declare namespace` 声明的外部类型不受限制。
- `推荐` 新代码优先用 `import` 语法；既有 CommonJS 项目保持模块格式一致，不做无需求的 ESM/CJS 迁移。
- `推荐` 按运行环境配置 `module` / `moduleResolution`：打包器项目用 `bundler`，直接运行于现代 Node.js 的项目用 `NodeNext`，新项目不使用 `node10` 作为默认解析策略。
- `强制` 禁止三斜杠语法 `/// <reference path="..." />` 导入文件，`.d.ts` 声明文件除外。

## 注释指令

- `推荐` 需要抑制类型错误时优先用 `@ts-expect-error`，使多余抑制在问题修复后重新报错；`@ts-ignore` 仅用于维护存量代码。使用 `@ts-expect-error`、`@ts-ignore`、`@ts-nocheck`、`@ts-check` 时必须在同一行跟随说明。

  ```ts
  // bad
  // @ts-expect-error
  console.log('my code');

  // good
  // @ts-expect-error: Legacy API has incomplete types
  console.log('my code');
  ```

- `强制` 禁止使用已废弃的 `// tslint:xxx` 注释指令。

## 格式

- `强制` 类型声明的空格规范：冒号前无空格、冒号后保留一个空格；箭头 `=>` 前后各保留一个空格。

  ```ts
  // bad
  let foo : string = 'bar';
  type Foo = ()=> {};

  // good
  let foo: string = 'bar';
  type Foo = () => {};
  ```

- `强制` 字符串字面量使用单引号。
- `推荐` `+` 连接的两侧同为数字或同为字符串，禁止数字与字符串相加。
