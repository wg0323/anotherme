# 版本差异：同一能力在 Boot 2.x / 3.x 分别怎么写

RabbitMQ 接入的 API 在 Spring Boot 2.x 与 3.x 之间有交集但不重合，`RabbitTemplateCustomizer` 甚至到 3.1 才出现。本文件给出分档写法：先判档，再抄对应代码，禁止跨档复制。

本文结论来自官方制品实测（`spring-boot-autoconfigure` 2.1.0 / 2.7.18 / 3.0.0 / 3.1.0 / 3.2.5，`spring-rabbit` 2.2.13 / 2.3.10 / 3.2.1），不按记忆推断。

## 一、判档

取值顺序：`pom.xml` 的 `spring-boot-starter-parent` 版本 → `dependencyManagement` 中 `spring-boot-dependencies` 版本 → `<spring-boot.version>` 属性。JDK 看 `<java.version>` / `<maven.compiler.release>`。实际生效的 AMQP 版本用依赖树确认：

```powershell
mvn dependency:tree -Dincludes=org.springframework.amqp
```

| 档位 | Spring Boot | Spring AMQP | JDK |
| ---- | ---- | ---- | ---- |
| A | 2.0 ~ 2.1 | 2.0 ~ 2.1 | 8 |
| B | 2.2 ~ 2.7 | 2.2 ~ 2.4 | 8 / 11 |
| C | 3.0 ~ 3.x | 3.0 ~ 3.x | 17+ |

## 二、差异总表

| 能力 | 2.0 ~ 2.1 | 2.2 | 2.3 ~ 2.7 | 3.x |
| ---- | ---- | ---- | ---- | ---- |
| 发布确认配置 | `publisher-confirms: true` | `publisher-confirm-type: correlated`（旧键同时被接受） | `publisher-confirm-type: correlated`（旧键已移除） | 同 2.3+ |
| Return 回调接口 | `ReturnCallback`（五参） | `ReturnCallback`（此时未弃用） | `ReturnsCallback` 首选；`ReturnCallback` 已弃用 | 仅 `ReturnsCallback`，旧接口已删除 |
| 回调注册方式 | 自定义 `RabbitTemplate` Bean 或 `InitializingBean` | 同左 | 同左 | `RabbitTemplateCustomizer`（3.1+）；3.0 同左 |
| 消息 DTO 校验 | `javax.validation.*` | 同左 | 同左 | `jakarta.validation.*` |
| 转换器、信任包、listener.retry.* | `Jackson2JsonMessageConverter` + `DefaultJackson2JavaTypeMapper.setTrustedPackages`，键名 `listener.simple.retry.*` | 同左 | 同左 | 同左（Boot 3 仍用 Jackson 2） |
| durable / quorum / DLX / TTL | Broker 侧能力，写法与档位无关 | 同左 | 同左 | 同左 |

即：真正需要分档的只有「发布确认键、Return 回调接口、回调注册方式、校验命名空间」四件事。可靠性设计（Outbox、幂等、重试、死信）不因档位而变化，不要借版本差异重写业务逻辑。

## 三、回调注册的三档写法

### C 档（3.1+）：`RabbitTemplateCustomizer`

```java
@Bean
public RabbitTemplateCustomizer rabbitTemplateCustomizer(RabbitPublishCallback publishCallback) {
    return template -> {
        template.setConfirmCallback(publishCallback);
        template.setReturnsCallback(publishCallback);
    };
}
```

Boot 3.0 没有该类（实测 3.0.0 无、3.1.0 起有），3.0 工程按 B 档处理。把这段贴到 2.x 工程不是「弃用警告」，而是 `cannot find symbol`。

### B 档（2.2 ~ 2.7）：`InitializingBean` 里注册

```java
@Slf4j
@Component
@RequiredArgsConstructor
public class RabbitCallbackRegistrar implements InitializingBean {

    private final RabbitTemplate rabbitTemplate;
    private final RabbitPublishCallback publishCallback;

    @Override
    public void afterPropertiesSet() {
        rabbitTemplate.setConfirmCallback(publishCallback);
        rabbitTemplate.setReturnsCallback(publishCallback);   // 2.2 换 setReturnCallback，见 A 档
    }
}
```

`afterPropertiesSet` 在容器刷新阶段执行，早于监听容器启动与业务首次发送，不存在「启动后才注册」的空窗；不要在发送方法里现场注册，也不要为此自定义 `RabbitTemplate` Bean（会丢掉 Boot 已装配的转换器与重试设置）。

### A 档（2.0 ~ 2.2）：五参 `ReturnCallback`

```java
@Override
public void afterPropertiesSet() {
    rabbitTemplate.setConfirmCallback(publishCallback);
    rabbitTemplate.setReturnCallback((message, replyCode, replyText, exchange, routingKey) ->
            publishCallback.onReturned(message, replyCode, replyText, exchange, routingKey));
}
```

回调类的接口也随之不同，方法体逻辑（取 `messageId` 与发送次数、按「事件 ID + 次数」条件更新、迟到 ACK 不覆盖 Return）完全一致，只是参数来源变了：

```java
// Spring AMQP 2.3+ / 3.x
public void returnedMessage(ReturnedMessage returned)

// Spring AMQP 2.0 ~ 2.2
public void returnedMessage(Message message, int replyCode, String replyText, String exchange, String routingKey)
```

## 四、配置片段的两处差异

A 档只能写布尔开关，其余 listener 配置三档一致（见 `config-template.md`）：

```yaml
spring:
  rabbitmq:
    publisher-confirms: true
    publisher-returns: true
    template:
      mandatory: true
```

B / C 档用枚举型确认模式：

```yaml
spring:
  rabbitmq:
    publisher-confirm-type: correlated
    publisher-returns: true
    template:
      mandatory: true
```

## 五、看到「弃用」警告时怎么判断

- **B 档项目里 `setReturnCallback` 被划掉**：说明 pom 在 2.3 以上、该类库已提供 `setReturnsCallback`。就地换写法即可，不需要升级 Spring Boot。
- **A 档项目里出现弃用提示**：该类库本身到 2.3 才弃用旧接口，2.0~2.2 不会有该警告；若确实报弃用，说明实际依赖版本高于 pom 里看到的声明，先用 `mvn dependency:tree` 核实。
- **C 档项目里想用 `ReturnCallback`**：没有警告，直接编译失败，旧接口已在 Spring AMQP 3.0 删除。
- **不要为了消警告升级大版本**：升级要连带替换 `javax`→`jakarta`、依赖坐标与配置键，属于独立迁移任务，按 `springboot-spec` 的 `version-baseline.md` 整体处理。
