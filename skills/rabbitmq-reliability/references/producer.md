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
- **强制**：`ConfirmCallback` 中 `ack=false`（消息未到达 Exchange）时必须触发重发，复用 `CorrelationDataWithMessage` 保存的 payload 重新投递；重发必须设次数上限（建议 ≤3 次），禁止无限重发。
- **强制**：重发达到上限仍失败必须最终兜底——落库到失败消息表并告警，交由定时补偿任务或人工处理，禁止仅打日志后丢弃。
- **规范**：重发会导致重复投递，消费端必须保证幂等（见 `consumer.md`）。

```java
@Getter
public class CorrelationDataWithMessage extends CorrelationData {
    private final String exchange;
    private final String routingKey;
    private final Object payload;
    /** 已重发次数，用于限制重发上限；随 CorrelationData 在多次重发间传递累计 */
    private final AtomicInteger retryCount = new AtomicInteger(0);

    public CorrelationDataWithMessage(String id, String exchange, String routingKey, Object payload) {
        super(id);
        this.exchange = exchange;
        this.routingKey = routingKey;
        this.payload = payload;
    }
}
```

### ack=false 重发落地（生产级 ConfirmCallback）

上文基础版 `ConfirmCallback` 仅记录日志，生产环境必须升级为「重发 + 次数上限 + 最终兜底」。`FailedMessageStore`（失败消息落库）与 `AlarmNotifier`（告警）为需自行实现的兜底组件。

```java
@Slf4j @Component
public class RabbitConfirmCallback implements RabbitTemplate.ConfirmCallback {

    /** 重发次数上限 */
    private static final int MAX_RETRY = 3;

    /**
     * ConfirmCallback 经 RabbitTemplateCustomizer 注入到 RabbitTemplate，
     * 若再反向依赖 RabbitTemplate 会形成循环依赖，必须用 @Lazy 打破。
     */
    @Lazy @Autowired
    private RabbitTemplate rabbitTemplate;

    private final FailedMessageStore failedMessageStore;  // 失败消息落库兜底
    private final AlarmNotifier alarmNotifier;            // 告警组件

    public RabbitConfirmCallback(FailedMessageStore failedMessageStore, AlarmNotifier alarmNotifier) {
        this.failedMessageStore = failedMessageStore;
        this.alarmNotifier = alarmNotifier;
    }

    @Override
    public void confirm(CorrelationData correlationData, boolean ack, String cause) {
        if (ack) {
            log.info("消息投递成功: id={}", correlationData != null ? correlationData.getId() : null);
            return;
        }
        // ack=false：消息未到达 Exchange，需要重发
        if (!(correlationData instanceof CorrelationDataWithMessage)) {
            log.error("消息投递失败且缺少重发上下文，无法重发: cause={}", cause);
            return;
        }
        CorrelationDataWithMessage cd = (CorrelationDataWithMessage) correlationData;
        int retry = cd.getRetryCount().incrementAndGet();
        if (retry <= MAX_RETRY) {
            log.warn("消息投递失败，第 {} 次重发: id={}, exchange={}, routingKey={}, cause={}",
                    retry, cd.getId(), cd.getExchange(), cd.getRoutingKey(), cause);
            // 复用保存的 exchange/routingKey/payload 重新投递，沿用同一 cd 以累计重发次数
            rabbitTemplate.convertAndSend(cd.getExchange(), cd.getRoutingKey(), cd.getPayload(), cd);
        } else {
            // 达到上限：最终兜底——落库 + 告警，禁止直接丢弃
            log.error("消息重发 {} 次仍失败，转失败消息表兜底: id={}, exchange={}, routingKey={}",
                    MAX_RETRY, cd.getId(), cd.getExchange(), cd.getRoutingKey());
            failedMessageStore.saveSendFailure(cd.getId(), cd.getExchange(), cd.getRoutingKey(), cd.getPayload(), cause);
            alarmNotifier.notifySendFailed(cd.getId(), cd.getExchange(), cd.getRoutingKey());
        }
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
