# 雪花 ID 的 JS 精度防护

## 问题

雪花 ID 是 64 位 `Long`，十进制 19 位（约 `1.9e18`）。JS 的 `Number` 是 IEEE754 double，尾数 53 位，安全整数上限 `2^53-1 = 9007199254740991`（16 位）。超出部分被舍入，末几位改变。

典型症状：列表接口能正常返回该记录，点进详情 404、按 ID 更新影响 0 行、关联查询查不到——因为前端回传的 ID 已不是原值。

根因是**所有 19 位 Long 都会中招**，与是否用雪花算法无关；只是雪花 ID 必然 19 位，暴露得最稳定。

## 主方案：全局序列化层转字符串

数据库保持 `bigint`，只在 HTTP JSON 出口把 `Long` 输出成字符串。存储、索引、排序、范围查询都不受影响。

### 配置类（Boot 2.x / 3.x 通用）

```java
@Configuration
public class JacksonConfig {

    @Bean
    public Jackson2ObjectMapperBuilderCustomizer longToStringCustomizer() {
        return builder -> builder
                .serializerByType(Long.class, ToStringSerializer.instance)
                .serializerByType(Long.TYPE, ToStringSerializer.instance);
    }
}
```

import 路径：`org.springframework.boot.autoconfigure.jackson.Jackson2ObjectMapperBuilderCustomizer`、`com.fasterxml.jackson.databind.ser.std.ToStringSerializer`。Boot 2.x 与 3.x 仅 `javax`/`jakarta` 有别，此类两档相同。

### 为什么全局优于逐字段注解

- **机制保证 vs 人肉约定**：注解靠新增字段时记得加，漏一个就是线上偶发「详情查不到」，且难复现。全局配置一次收口。
- **自动覆盖嵌套与集合**：VO 内嵌对象、`List<Long>`、`Map<String, Long>` 的键值都会按运行时类型命中，无需逐个标。
- **只作用于 JSON 出口**：Dubbo/RPC 内部仍是 `Long`，服务间调用无格式变化。

### 配套类型约定（必须同时落地）

全局转换的代价是所有 `Long` 都会变字符串。用类型约定把副作用收敛成一条规则：

| 用途 | 类型 |
| ---- | ---- |
| 主键、关联 ID、外键 | `Long` |
| 计数（点赞数、评论数） | `int` / `Integer` |
| 金额、比例 | `BigDecimal` |
| 时间 | `LocalDateTime` / `Date`（或 `datetime` + `varchar` 字符串） |
| 毫秒时间戳 | 禁止用 `Long` 承载，改 `LocalDateTime` 或明确 `String` |

落地后「JSON 里的 ID 是字符串」成为稳定可写进接口文档的契约，前端 TS 的 ID 字段统一 `string`。

## 三个坑

1. **`Long.TYPE` 必须注册**。`private long id` 走基本类型匹配，只注册 `Long.class` 不生效。两个都要写。
2. **禁用 `spring.jackson.generator.write-numbers-as-strings`**。它是 `JsonGenerator.Feature.WRITE_NUMBERS_AS_STRINGS`，会把 `int`、`double`、`BigDecimal` 全部转成字符串，副作用远大于收益。
3. **启用前先普查 `Long` 字段**。全局配置会连带影响所有用同一个 `ObjectMapper` 的场景（HTTP、复用该实例的 MQ 序列化、缓存序列化）。存量代码里的 `Long` 业务字段必须先改造：

   ```bash
   rg -n "Long |long " src/main/java --glob "!*Test*.java"
   ```

   结果中凡是主键、ID 之外的命中，先改为 `int`/`BigDecimal`/`LocalDateTime` 再启用全局配置。

## 反序列化方向：无需任何配置

- JSON 里 `"id": "1234567890123456789"` → `Long` 字段：Jackson `LongDeserializer` 原生支持 `VALUE_STRING`。
- 路径/查询参数 `@PathVariable Long id`、`@RequestParam Long id`：Spring 的 `StringToNumberConverterFactory` 负责转换。
- MyBatis 参数绑定：`#{id}` 传 `Long` 或 `String` 均按 JDBC 类型处理，MySQL 侧会做隐式转换；但**方法签名保持 `Long`**，不要为了接收字符串把 Service/Mapper 参数类型改成 `String`，否则 `bigint` 与 `varchar` 比较会让索引失效。

## 接口文档对齐

VO 的 ID 字段保持 `Long`（减少无意义的类型转换代码），用注解修正文档显示类型，否则 Knife4j 显示 `integer(int64)`、前端按 number 生成类型：

```java
@Schema(description = "主键ID（字符串形式，防 JS 精度丢失）", type = "string")
private Long id;
```

## 存量项目兜底（不为统一而改造）

已上线项目按现状处理，二选一即可，不要求迁移到全局配置：

- **逐字段注解**：`@JsonSerialize(using = ToStringSerializer.class)` 打在 VO/DTO 的 ID 字段上，嵌套对象与集合元素需逐个覆盖，容易漏。
- **FastJson 项目**：全局配置 `FastJsonHttpMessageConverter` 的 `SerializerFeature.BrowserCompatible`，或字段级 `@JSONField(serializeUsing = com.alibaba.fastjson.serializer.ToStringSerializer.class)`。`BrowserCompatible` 同时会把中文转 `\uXXXX`，属可接受的副作用。

新增模块即使落在存量项目里，也优先加全局配置。

## 验证

启动后直接看响应原文，`id` 带引号才算生效：

```bash
curl -s "http://localhost:8080/users/1"
# 期望：{"code":0,"data":{"id":"1859230471882346496","name":"..."}}
```

若前端仍报查不到，用响应里的 ID 字符串原样回传一次，能查到即说明是序列化问题已修复、前端仍在做数值转换（可在前端打断点确认 `Number(id)` 之类的写法）。

## 不做的事

- **不把主键改成 `varchar`**：InnoDB 聚簇索引体积翻倍、比较变慢、范围查询与自增趋势失效，纯粹为迁就前端牺牲存储与查询性能。
- **不依赖前端 `json-bigint`**：Web、iOS、Android、小程序、第三方开放接口无法穷尽收口，任一消费方漏接就有一批用户打不开详情。服务端是唯一的可控出口。
- **不改成 53 位内雪花**：调整位分配（时间戳改秒级 + 压缩 worker/序列位）虽能让 ID 落在安全范围，但容量上限下降且位宽一旦上线就锁死，改造收益不抵风险，仅在特殊场景考虑。
