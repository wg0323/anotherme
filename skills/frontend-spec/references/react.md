# React 编码规约

> 来源：阿里巴巴前端规约 · React 编码规约（https://alibaba.github.io/f2e-spec/），2026-10-29 提取改写。编号沿用官方原文。
> 级别：`强制` 必须遵守；`推荐` 尽量遵守；`参考` 理解并牢记。
> 原文基于 React 16 与 class 组件时代，本文件面向 React 19+ 更新。新项目以函数组件 + Hooks 为主，class 相关条目（2.1.5、2.1.6、2.2.x、2.4、2.6）仅在维护存量代码时适用；React 19 已忽略 `propTypes` 并移除函数组件 `defaultProps`，函数组件使用类型声明与参数默认值。

## 一、编码风格

- `强制`（1.1.1）JSX 使用 2 个空格缩进，禁止 4 个空格或 Tab。
- `强制`（1.2.1）自闭合标签的斜线前有且仅有一个空格：`<Foo />`，禁止 `<Foo/>` 或 `<Foo     />`。
- `强制`（1.2.2）同一行内标签与属性之间、属性与属性之间只有一个空格：`<App cozy />`。
- `强制`（1.2.3）属性大括号内部两侧无空格：`<Foo bar={baz} />`。
- `强制`（1.2.4）属性等号两边不加空格：`<Hello name={firstname} />`。
- `强制`（1.3.1）JSX 属性用双引号（沿用 HTML 约定）；JS 代码内的字符串仍用单引号。

  ```jsx
  // bad
  <Foo bar='bar' />
  <Foo style={{ left: "20px" }} />

  // good
  <Foo bar="bar" />
  <Foo style={{ left: '20px' }} />
  ```

- `强制`（1.4.1）多行 JSX 用小括号包裹；单行 JSX 无需括号。

  ```jsx
  // bad
  render() {
    return <MyComponent variant="long body" foo="bar">
             <MyChild />
           </MyComponent>;
  }

  // good
  render() {
    return (
      <MyComponent variant="long body" foo="bar">
        <MyChild />
      </MyComponent>
    );
  }
  ```

- `强制`（1.5.1）无子元素的标签写成自闭合标签：`<Foo variant="stuff" />`。
- `强制`（1.5.2）属性换行：不超过 100 字符时标签名与属性可写在一行；一旦有换行，则每个属性独占一行。

  ```jsx
  // bad - 属性应全部换行，或全部写在一行
  <Foo superLongParam="bar"
       anotherSuperLongParam="baz" />

  // good
  <Foo
    superLongParam="bar"
    anotherSuperLongParam="baz"
  />
  ```

- `强制`（1.5.3）属性多行时，结束标签的 `/>` 另起一行。
- `强制`（1.5.4）有子节点的组件或 DOM 元素禁止使用 `dangerouslySetInnerHTML`。
- `强制`（1.5.5）HTML 空元素（`img`、`br`、`hr` 等）不能有子节点，也不能使用 `dangerouslySetInnerHTML`。
- `推荐`（1.5.6）避免使用 `dangerouslyXyz` 类危险属性，它已被明确标记为可能引入漏洞。
- `强制`（1.5.7）JSX 文本节点中不使用 `//` 或 `/* */` 形式的注释字符串，注释要写在 `{/* */}` 或标签属性区内。

  ```jsx
  // bad
  <div>// empty div</div>

  // good
  <div>{/* empty div */}</div>
  ```

- `强制`（1.5.8）标签中禁止出现未转义的无意义字符 `>`、`"`、`'`、`}`。用 `&gt;`、`&quot;`、`&apos;`、`&#125;` 等实体，或写成表达式 `<div>{'>'}</div>`。

## 二、组件基础

- `参考`（2.1.1）使用自定义 `@jsx` 标注时，确保真正的 JSX 工厂变量被引入。
- `强制`（2.1.2）禁止使用未声明的组件，先 import 再使用。
- `强制`（2.1.3）每个文件只包含一个 React 组件（可包含多个函数组件）。
- `强制`（2.1.4）函数组件中禁止使用 `this`，从 `props` / `context` 参数取值。
- `强制`（2.1.5）用 ES6 `class` 创建组件，禁止 `createReactClass`。
- `参考`（2.1.6）没有内部状态或 refs 的组件用函数组件，不用 class 组件。
- `强制`（2.1.7）禁止使用 `React.createElement`，除非应用初始化不走 JSX 文件。

## 三、方法与生命周期

- `推荐`（2.2.1）不在 JSX 属性中使用 `.bind()`，每次 render 都会生成新函数；在 constructor 中绑定或使用箭头函数属性。
- `强制`（2.2.2）`render` 方法必须有返回值。
- `强制`（2.2.3）禁止在 React 19+ 使用已移除的 `ReactDOM.render`，改用 `react-dom/client` 的 `createRoot`；需要组件实例时使用 ref，不依赖渲染 API 的返回值。
- `强制`（2.2.4）继承 `React.PureComponent` 时禁止实现 `shouldComponentUpdate`，否则 PureComponent 失去意义。
- `强制`（2.2.5）禁止已废弃的 API：`React.render`、`React.unmountComponentAtNode`、`React.findDOMNode`、`React.renderToString`、`React.createClass`、从 `react` 导入 `PropTypes`、`React.DOM.*`。
- `强制`（2.2.6）禁止使用 `findDOMNode`，严格模式下已弃用，改用 ref。
- `强制`（2.2.7）禁止使用 `componentWillMount`、`componentWillReceiveProps`、`componentWillUpdate`：
  - `componentWillMount()` → `constructor()` 或 `componentDidMount()`
  - `componentWillReceiveProps()` → `componentDidUpdate()` 或其他方式
  - `componentWillUpdate()` → `componentDidUpdate()` 或 `getSnapshotBeforeUpdate()`
- `强制`（2.2.8）禁止在 `componentWillUpdate` 内 `setState`；响应 props 变更时优先直接计算、使用受控组件、通过 `key` 重置或在 `componentDidUpdate()` 处理副作用，仅在 state 必须跟踪 props 历史变化时使用 `getDerivedStateFromProps()`。

## 四、Props

- `强制`（2.3.1）prop 使用小驼峰命名：`userName`、`phoneNumber`。
- `强制`（2.3.2）声明过的 prop 必须被使用，未使用的删除。
- `参考`（2.3.3）优先用解构获取 `props` / `state`，函数组件直接在参数中解构。

  ```jsx
  // bad
  const MyComponent = (props) => <div id={props.id} />;

  // good
  const MyComponent = ({ id }) => <div id={id} />;
  ```

- `强制`（2.3.4）prop 值为 `true` 时省略取值：写 `<Foo hidden />`。
- `推荐`（2.3.5）Props 优先用 TypeScript 或其他静态类型方案声明；`propTypes` 仅用于维护 React 18 及以下的存量代码，React 19 会静默忽略它。
- `推荐`（2.3.6）存量 `propTypes` 不使用模糊类型：`any` 换成具体类型，`array` / `object` 换成 `arrayOf` / `shape`。
- `参考`（2.3.7）函数组件用参数默认值声明可选 prop 的默认值；class 组件可继续使用 `defaultProps`。
- `强制`（2.3.8）存量 `propTypes` 中 `isRequired` 的属性禁止在 class 组件 `defaultProps` 中赋值，否则类型检查失去意义。
- `推荐`（2.3.9）不用数组索引作为 `map` 生成元素的 key，用稳定的业务 id；索引在重排序或头部插入时会失效。

  ```jsx
  // bad
  {todos.map((todo, index) => <Todo {...todo} key={index} />)}

  // good
  {todos.map((todo) => <Todo {...todo} key={todo.id} />)}
  ```

- `强制`（2.3.10）禁止把 `children` 当属性名，子内容写在标签之间。
- `强制`（2.3.11）禁止声明重复的属性名。
- `强制`（2.3.12）`style` 的值必须是对象：`<div style={{ color: 'red' }} />`。
- `推荐`（2.3.13）`target="_blank"` 不单独使用，必须搭配 `rel="noopener noreferrer"`，防止被打开页面通过 `window.opener` 操纵原页面。

## 五、State 与 Refs

- `强制`（2.4.1）不要在 `setState` 中读取 `this.state`，批处理场景下读到的是旧值；用回调参数 `prevState`。

  ```jsx
  // bad
  this.setState({ value: this.state.value + 1 });

  // good
  this.setState((prevState) => ({ value: prevState.value + 1 }));
  ```

- `强制`（2.4.2）声明过的 state 必须被使用。
- `强制`（2.5.1）函数组件用 `useRef()`，class 组件用 `React.createRef()` 或回调 ref；禁止字符串 ref。
- `参考`（2.6.1）组件方法排序：static 方法 → constructor → 生命周期（挂载 → 更新 → 卸载）→ 事件处理函数 → render 相关的 getter / 辅助 render 方法 → `render`。
- `强制`（2.7.1）禁止使用 mixins，它引入隐式依赖与命名冲突；改用组件、高阶组件或工具模块。

## 六、命名

- `强制`（3.1）组件文件扩展名使用 `.jsx`、`.tsx`、`.js` 或 `.ts`。
- `强制`（3.2）组件的引用名用大驼峰，组件实例名用小驼峰。

  ```jsx
  // bad
  import reservationCard from './reservation-card';
  const ReservationItem = <ReservationCard />;

  // good
  import ReservationCard from './reservation-card';
  const reservationItem = <ReservationCard />;
  ```

- `推荐`（3.3）高阶组件用 `withFoo(WrappedComponent)` 组合生成 `displayName`，便于开发者工具与报错信息定位。

## 七、Hooks

- `强制`（4.1）只在最顶层调用 Hooks，禁止在循环、条件、嵌套函数或回调中调用。

  ```jsx
  // bad
  function ComponentWithConditionalHook() {
    if (cond) {
      useConditionalHook();
    }
  }

  // good
  function ComponentWithHook() {
    useHook();
  }
  ```

- `强制`（4.2）自定义 Hook 必须以 `use` 开头、使用小驼峰：`useCustomHook`。
- `强制`（4.3）只在 React 函数组件与自定义 Hook 中调用 Hooks，禁止在普通函数或 class 组件中调用。
- `推荐`（4.4）`useEffect` 及同类 Hooks 必须声明全部依赖。该规则偶有误报，确需豁免时用行尾注释 `// eslint-disable-line react-hooks/exhaustive-deps` 显式声明。

  ```jsx
  // bad
  useEffect(() => {
    console.log(local);
  }, []);

  // good
  useEffect(() => {
    console.log(local);
  }, [local]);
  ```

## 八、无障碍（a11y）

以下均为 `推荐` 级，规则来自 WAI-ARIA 规范，落地依赖 `eslint-plugin-jsx-a11y`。

- （5.1）`img` 必须有 `alt`；纯装饰或图标图片写 `alt=""`。
- （5.2）`alt` 不要包含 `image`、`photo`、`picture`，屏幕阅读器已识别为图片。
- （5.3）`a` 元素必须含有对屏幕阅读器可见的内容，不能用 `aria-hidden` 隐藏。
- （5.4）只使用 WAI-ARIA 规范中存在的 `aria-*` 属性，注意拼写（`aria-labelledby` 不是 `aria-labeledby`）。
- （5.5）ARIA 属性与状态的值必须是合法值（`aria-hidden` 只接受 `true` / `false`）。
- （5.6）`meta`、`html`、`script`、`style` 等保留元素不得设置 `role` 与 `aria-*`。
- （5.7）只使用有效的、非抽象的 ARIA role，`datepicker`、`range` 这类无效。
- （5.8）带 `role` 的元素必须同时声明该 role 的必需属性，如 `role="checkbox"` 需带 `aria-checked`。
- （5.9）元素只能使用其显式或隐式 role 支持的 `aria-*` 属性。
- （5.10）`iframe` 必须有唯一且描述内容的 `title`，空字符串、布尔值、数字均不合规。
- （5.11）不使用 `accessKey`，可能与系统或浏览器快捷键冲突。
- （5.12）不使用 `<marquee>`、`<blink>` 等引起视觉分散的元素。
- （5.13）`scope` 属性只能用在 `<th>` 上。
