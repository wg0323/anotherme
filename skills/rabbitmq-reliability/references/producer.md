# 生产者消息可靠性

## 发布确认与路由失败回调

- **强制**：必须设置 `publisher-confirm-type: correlated`、`publisher-returns: true`、`template.mandatory: true`，禁止使用 `none` 或 `mandatory: false`（会静默丢弃路由失败的消息）。
- **强制**：必须实现 `ConfirmCallback` 和 `ReturnsCallback`，记录投递结果与路由失败信息。
- **规范**：日志中禁止直接打印消息体原文，避免敏感数据泄露；仅记录消息长度等元信息，如需排查再脱敏后以 UTF-8 解码落库。

```java
@Slf4j @Component
public class RabbitConfirmCallback implements RabbitTemplate.ConfirmCallback {
    @Override
    public void confirm(CorrelationData correlationData, boolean ack, String cause) {
        if (ack) {
            log.info("消息投递成功: correlationData={}", correlationData);
        } else {
            log.error("消息投递失败: correlationData={}, cause={}", correlationData, cause);
        }
    }
}

@Slf4j @Component
public class RabbitReturnsCallback implements RabbitTemplate.ReturnsCallback {
    @Override
    public void returnedMessage(ReturnedMessage returned) {
        byte[] body = returned.getMessage().getBody();
        log.error("消息路由失败: exchange={}, routingKey={}, replyCode={}, replyText={}, bodyLength={}",
                returned.getExchange(), returned.getRoutingKey(),
                returned.getReplyCode(), returned.getReplyText(),
                body != null ? body.length : 0);
    }
}
```

## CorrelationData 与失败重发

- **规范**：发送消息时传入自定义 `CorrelationData` 子类，保存 exchange、routingKey、payload，便于 `ack=false` 时重发；ID 使用业务唯一标识。

```java
@Getter
public class CorrelationDataWithMessage extends CorrelationData {
    private final String exchange;
    private final String routingKey;
    private final Object payload;

    public CorrelationDataWithMessage(String id, String exchange, String routingKey, Object payload) {
        super(id);
        this.exchange = exchange;
        this.routingKey = routingKey;
        this.payload = payload;
    }
}
```

## 消息发送规范

- **强制**：消息体使用 JSON 序列化（`Jackson2JsonMessageConverter`），消息体类必须实现 `Serializable` 并定义 `serialVersionUID`。
- **规范**：消息体保持精简，禁止传输大对象。
- **强制**：跨服务消费时必须配置 `DefaultJackson2JavaTypeMapper` 信任包名，避免 `__TypeId__` header 不匹配导致反序列化失败。
- **规范**：使用 `RabbitTemplateCustomizer` 注册回调，在 `RabbitTemplate` 创建阶段即生效，避免 `ApplicationRunner` 的回调空窗期。

```java
@Configuration
public class RabbitConfig {

    @Bean
    public MessageConverter jsonMessageConverter() {
        Jackson2JsonMessageConverter converter = new Jackson2JsonMessageConverter();
        DefaultJackson2JavaTypeMapper typeMapper = new DefaultJackson2JavaTypeMapper();
        typeMapper.setTrustedPackages("com.example.mq.dto");
        converter.setJavaTypeMapper(typeMapper);
        return converter;
    }

    @Bean
    public RabbitTemplateCustomizer rabbitTemplateCustomizer(RabbitConfirmCallback confirmCallback,
                                                              RabbitReturnsCallback returnsCallback) {
        return template -> {
            template.setConfirmCallback(confirmCallback);
            template.setReturnsCallback(returnsCallback);
        };
    }
}

@RequiredArgsConstructor @Component
public class AlarmPublisher {

    private final RabbitTemplate rabbitTemplate;

    public void publish(String routingKey, Object payload, String messageId) {
        CorrelationDataWithMessage cd = new CorrelationDataWithMessage(
                messageId, "nsp.alarm.exchange", routingKey, payload);
        rabbitTemplate.convertAndSend("nsp.alarm.exchange", routingKey, payload, cd);
    }
}
```
