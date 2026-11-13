# 生产者消息可靠性

不允许丢失的消息使用 Outbox 持久化事件，再由投递任务发布。`CorrelationData` 只携带本次发布的定位信息，不再保存用于重发的完整消息体；恢复数据来源是 Outbox，不是应用内存。

## 先明确 Confirm 与 Return 的含义

- ACK 表示 Broker 已接管消息。持久化消息路由到 durable queue 时涉及落盘；quorum queue 需要多数派接受。它不表示消费者已经处理成功。
- nack 表示 Broker 无法成功处理并拒绝承担责任，不能简单解释为“未到达 Exchange”。
- 不可路由且 `mandatory=true` 时，Broker 先返回 `basic.return`，随后仍可能发送 ACK。因此 ACK 不能替代 Return 处理。
- Confirm 没有到达不代表一定失败。超时重发会产生重复，必须复用业务事件 ID。

生产端必须同时处理 nack、return、发送异常和 Confirm 超时。回调注册使用 `RabbitTemplateCustomizer`，避免应用启动阶段才注册造成的空窗期。

## CorrelationData 与回调

以下 `OutboxPublishService` 是应用需要实现的持久化状态处理接口。回调方法应快速交给有界工作状态处理器，不直接执行长耗时数据库操作或循环重发。

```java
@Getter
public class PublishCorrelationData extends CorrelationData {

    private final long publishAttempt;

    public PublishCorrelationData(String eventId, long publishAttempt) {
        super(eventId);
        this.publishAttempt = publishAttempt;
    }
}
```

```java
@Slf4j
@Component
@RequiredArgsConstructor
public class RabbitPublishCallback implements RabbitTemplate.ConfirmCallback, RabbitTemplate.ReturnsCallback {

    private static final String PUBLISH_ATTEMPT_HEADER = "publishAttempt";

    private final OutboxPublishService outboxPublishService;

    @Override
    public void confirm(CorrelationData correlationData, boolean ack, String cause) {
        if (!(correlationData instanceof PublishCorrelationData)) {
            if (!ack) {
                log.error("消息发布被 nack 且缺少 Outbox 定位信息: cause={}", cause);
            }
            return;
        }
        PublishCorrelationData data = (PublishCorrelationData) correlationData;
        if (ack) {
            outboxPublishService.onAck(data.getId(), data.getPublishAttempt());
            return;
        }
        log.warn("消息发布被 nack: eventId={}, publishAttempt={}, cause={}",
                data.getId(), data.getPublishAttempt(), cause);
        outboxPublishService.onNack(data.getId(), data.getPublishAttempt(), cause);
    }

    @Override
    public void returnedMessage(ReturnedMessage returned) {
        MessageProperties properties = returned.getMessage().getMessageProperties();
        Object attemptHeader = properties.getHeaders().get(PUBLISH_ATTEMPT_HEADER);
        String eventId = properties.getMessageId();
        byte[] body = returned.getMessage().getBody();
        log.error("消息未路由到队列: eventId={}, exchange={}, routingKey={}, replyCode={}, bodyLength={}",
                eventId, returned.getExchange(), returned.getRoutingKey(),
                returned.getReplyCode(), body != null ? body.length : 0);
        if (eventId == null || !(attemptHeader instanceof Number)) {
            return;
        }
        long publishAttempt = ((Number) attemptHeader).longValue();
        outboxPublishService.onReturn(eventId, publishAttempt, returned.getReplyText());
    }
}
```

`onAck`、`onNack` 和 `onReturn` 必须按“事件 ID + 发送次数”做条件更新，防止旧回调覆盖新状态。Return 已发生时，同次发布的迟到 ACK 不得再将记录更新为 `SENT`。

## 发布与回调注册

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
    public RabbitTemplateCustomizer rabbitTemplateCustomizer(RabbitPublishCallback publishCallback) {
        return template -> {
            template.setConfirmCallback(publishCallback);
            template.setReturnsCallback(publishCallback);
        };
    }
}
```

```java
@Component
@RequiredArgsConstructor
public class OutboxPublisher {

    private static final String PUBLISH_ATTEMPT_HEADER = "publishAttempt";

    private final RabbitTemplate rabbitTemplate;
    private final OutboxPublishService outboxPublishService;

    public void publish(String eventId, long publishAttempt, String exchange,
                        String routingKey, Object payload) {
        PublishCorrelationData correlationData = new PublishCorrelationData(eventId, publishAttempt);
        try {
            rabbitTemplate.convertAndSend(exchange, routingKey, payload, message -> {
                MessageProperties properties = message.getMessageProperties();
                properties.setMessageId(eventId);
                properties.setHeader(PUBLISH_ATTEMPT_HEADER, publishAttempt);
                return message;
            }, correlationData);
        } catch (RuntimeException e) {
            outboxPublishService.onPublishException(eventId, publishAttempt, e.getMessage());
            log.warn("消息调用发布失败，等待 Outbox 补偿: eventId={}, publishAttempt={}",
                    eventId, publishAttempt, e);
        }
    }
}
```

调用 `publish` 前，Outbox 记录必须已持久化为本次 `SENDING` 尝试。方法返回只表示客户端已发起发布，是否成功由回调和超时回收任务确定。

## 消息格式与性能

- 使用 `Jackson2JsonMessageConverter` 时，消息类不必实现 `Serializable` 或定义 `serialVersionUID`。
- 信任包只填写项目实际 DTO 包，禁止 `*` 或 `java.util` 等过宽范围。
- 消息体保持精简，大文件传受控引用，不把文件内容塞进 MQ。
- Confirm 使用异步流水线。成功路径更新指标，不逐条记录 INFO；nack、return、超时保留事件 ID、路由和错误摘要。
- 禁止在 Confirm 回调中立即重发三次。重试调度、退避、上限和最终告警统一由 Outbox 任务处理，详见 `outbox.md`。

参考：[RabbitMQ Publisher Confirms](https://www.rabbitmq.com/docs/confirms#publisher-confirms)。
