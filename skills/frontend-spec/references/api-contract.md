# 接口数据契约：大整数 ID

## 适用范围

后端主键为雪花 ID（19 位 `Long`）或任何超过 `2^53-1` 的整数时适用。后端默认以字符串下发，前端按字符串处理。

## 精度丢失发生在哪一刻

只发生在 `JSON.parse`（含 `axios` 默认解析、小程序 `res.data` 解析、`fetch().json()`）把响应体里的**裸数字**转成 `Number` 的瞬间。一旦是带引号的字符串，后续 `map` 键、`localStorage`、`JSON.stringify` 都安全。

因此判断标准很简单：抓包看响应体里 `id` 有没有引号。有引号就与前端无关，没引号则前端做多少转换都救不回来。

## 强制项

1. **类型声明**：TS 接口中所有 ID 字段（`id`、`xxxId`、`parentId`、`userId` 等）一律 `string`，禁止写 `number`。

   ```ts
   interface UserVO {
     id: string;
     deptId: string;
     name: string;
   }
   ```

2. **禁止数值化**：`Number(id)`、`parseInt(id)`、`parseFloat(id)`、`+id`、`id * 1`、`id - 0` 一律禁止，隐式转换同样禁止（如 `id > 0`、`id === 1`）。

3. **禁止按 ID 排序或比较**：字符串比较按字典序，`'9' > '10'` 为 `true`，与数值序相反。排序、大小比较、区间查询全部交由后端 SQL 完成。

4. **原样回传**：路径参数、查询参数、请求体直接用字符串，不做中间转换。

5. **组件取值保持字符串**：`el-table` 的 `row-key`、`el-select` 的 `value`、表单字段都保持 `string`；ID 场景禁止用 `el-input-number`，它会把值转成 `Number`。

## 正反例

```js
// bad：解析后末位已变，请求详情必然 404
const id = Number(row.id);
await axios.get(`/api/users/${id}`);

// good：原样透传
await axios.get(`/api/users/${row.id}`);
```

```js
// bad：字典序排序，结果错乱
list.sort((a, b) => a.id - b.id);

// good：分页与排序交给后端
await axios.get('/api/users', { params: { sort: 'id,desc' } });
```

```js
// bad：判断条件被隐式转成数字后再比较
if (row.id > 0) { /* ... */ }

// good
if (row.id) { /* ... */ }
```

## 后端未改造时的兜底

服务端还是返回裸数字时，在 HTTP 层用 `json-bigint` 拦截解析，避免精度在入口就丢掉：

```js
import JSONbig from 'json-bigint';

const jsonbig = JSONbig({ storeAsString: true });

const res = await axios.get('/api/users', {
  transformResponse: [(data) => jsonbig.parse(data)],
});
```

`storeAsString: true` 必须显式开启：默认行为是返回 `BigNumber` 对象，模板里直接渲染会显示成对象、`JSON.stringify` 会走样。兜底只是止血，仍需推动后端按 `springboot-spec` 的 `id-serialization.md` 在序列化层修复——Web、App、小程序、第三方开放接口逐个接 `json-bigint` 不现实。

## 与后端的分工

| 环节 | 责任方 | 做法 |
| ---- | ---- | ---- |
| 响应体 ID 带引号 | 后端 | 全局 `Long` → `String` 序列化，见 `springboot-spec` 的 `id-serialization.md` |
| 入参 ID 接收 | 前端 | 字符串原样透传，后端 `@PathVariable Long` 自动转换 |
| 排序与范围查询 | 后端 | SQL 层按 `bigint` 处理，前端不参与 |
| 数据库存储 | 后端 | 保持 `bigint`，禁止改 `varchar` |
