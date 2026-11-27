# 消费者编写规范

消费者按“业务事务成功提交后才 ACK”设计。RabbitMQ 和 Spring 的重投机制会带来重复消息，因此幂等是正常处理流程的一部分，不是异常补丁。

## ACK 与事务边界

核心消息使用 Spring `AcknowledgeMode.MANUAL`：监听方法拿到 `Channel` 和原始 `Message`，在业务事务提交后显式 `basicAck`，失败时显式 `basicNack`。手动模式必须保证每条消息最终 ACK 或 NACK，且只能在接收它的 Channel 上操作；漏掉 ack/nack 会让消息在 Channel 关闭后重投，造成积压和重复消费。

ACK 必须在业务事务提交之后执行。不要把 `@Transactional` 加在监听方法上并在方法体内 ack：方法返回时才提交事务，方法体内的 ack 会先于提交，提交失败时消息已经丢失。把业务处理放到独立的 `@Transactional` 服务方法，返回后再 ack，或用 `TransactionSynchronization.afterCommit` 注册 ack。`basicAck` 本身失败时不要重做业务；消息会按 Channel 关闭或容器拒绝策略重投/进死信，由业务唯一键或同事务去重记录判重。

`AcknowledgeMode.AUTO`（容器在监听方法正常返回后 ACK）只用于可丢失或非核心的简单场景；核心消息使用 MANUAL，但 Spring AMQP 2.0～2.1.8 的转换等 fatal 异常边界按 `version-diff.md` 处理，可保留 AUTO 或实现自定义拒绝处理。AMQP 协议中收到即丢弃的 auto-ack 对应 `AcknowledgeMode.NONE`，核心消息禁止使用。

幂等记录与业务更新必须处于同一个本地事务。消息 DTO 携带的 `messageId` 必须与发布时写入的 AMQP `messageId` 一致，或者直接读取消息属性，不能由消费端重新生成。

1. 以 `messageId` 插入去重记录；有业务操作级幂等键时也可用业务唯一索引判重。订单号等业务对象 ID 必须结合 `event_type`、版本等限定具体操作，不能跨事件类型通用。
2. 在同一事务中更新业务数据并提交，同时保存事件类型和 `payload_hash` 或等价内容指纹。
3. 唯一键冲突后，仅当已存在记录与当前消息属于同一业务操作且内容指纹一致时，才按重复成功返回并显式 ack；不一致时按数据冲突告警并 `basicNack(requeue=false)`，不得当作重复消息确认。
4. 业务失败则整个事务回滚；临时异常发布重试消息后 ack，永久异常 `basicNack(requeue=false)` 进 DLX。

```java
@Slf4j
@Component
@RequiredArgsConstructor
public class AlarmConsumer {

    private final AlarmService alarmService;
    private final RetryMessagePublisher retryMessagePublisher;

    @RabbitListener(queues = "nsp.alarm.queue")
    public void handleAlarm(AlarmMessage message, Message amqpMessage, Channel channel) throws IOException {
        long deliveryTag = amqpMessage.getMessageProperties().getDeliveryTag();
        try {
            // process 是独立的 @Transactional 服务方法，返回时业务事务已提交
            alarmService.process(message);
        } catch (PermanentBusinessException e) {
            log.error("报警消息存在永久业务错误: messageId={}", message.getMessageId(), e);
            channel.basicNack(deliveryTag, false, false);   // 不重回原队列，进 DLX
            return;
        } catch (Exception e) {
            log.warn("报警消息处理失败: messageId={}", message.getMessageId(), e);
            if (retryMessagePublisher.publishRetry(amqpMessage, e)) {
                channel.basicAck(deliveryTag, false);       // 先发布重试，再 ack 原消息
            } else {
                channel.basicNack(deliveryTag, false, false); // 重试发布失败，进死信，宁可重复不可丢失
            }
            return;
        }
        channel.basicAck(deliveryTag, false);               // 业务事务已提交，显式 ack
    }
}
```

`RetryMessagePublisher.publishRetry` 读取消息头 `retry_count`（首次发布为 0，缺失按 0 处理），按级别选择延迟队列，复制原始 payload、`message_id`、业务头和 persistent 投递模式，递增 `retry_count` 后发布，并等待 publisher confirm（有界超时）再返回 `true`；confirm nack、超时、发布异常，或 confirm ack 但被 `mandatory` return（不可路由）返回 `false`，由监听方法 `basicNack(requeue=false)` 送死信。

重试消息保留 payload、`message_id`、业务头和 persistent 投递模式，但不要复制 `expiration`、`deliveryTag`、`redelivered` 等投递属性；原消息的 `expiration` 会让重试副本在延迟队列里提前过期。`publishRetry` 要像 Outbox 生产者一样关联 confirm/return：每次发布用唯一 `CorrelationData`，return 回调从消息头读取 `message_id + retry_count`，不能只看 confirm。只调用 `convertAndSend` 就返回成功，会让原消息在重试副本未落定时被 ack，存在丢消息窗口。

同步 confirm 的具体 API 按 Spring AMQP 档位选择（`CorrelationData.getFuture()` 或 `waitForConfirmsOrDie`），不要跨档复制；return 回调的注册方式见 `version-diff.md`。重试发布建议使用独立 `RabbitTemplate` 或独立回调关联器，避免与 Outbox 生产者的 confirm/return 回调混淆。发布重试确认成功后 ack 失败会产生重复重试消息，属于可接受的重复，由消费幂等吸收。不要在监听方法里用 `Thread.sleep` 做退避，也不要吞掉发布异常后直接 ack。

示例把所有非 `PermanentBusinessException` 的异常按临时异常处理；实际项目应按异常类型显式分类，不要把参数错误、反序列化失败等永久异常送进重试队列。

`AlarmService.process` 的事务实现需要识别唯一键冲突并核对已有记录的事件类型、版本和 `payload_hash` 或等价内容指纹；只有同一业务操作且内容一致时才按重复成功返回，内容不一致必须按数据冲突处理，不能正常 ack。有业务操作级幂等键时用业务唯一索引兜底；没有时，同事务去重记录就是最终兜底，去重表不是“只是优化”。若项目使用 Redis 前置去重，Redis 故障或键过期后仍须由数据库唯一键（业务唯一键或去重表唯一键）兜底；不要在业务异常后简单删除 SETNX 键，就把这套流程视为严格幂等。

## 异常分类与重试

- 默认不启用 Spring Retry，由消费者显式发布重试消息：临时异常先发到对应退避级别的 TTL 延迟队列，再 ack 原消息；发布失败则 nack 进死信。这样重试次数、退避和 ack 顺序都由应用控制，不会与手动 ack 重复。
- 若确需本地短重试，单独评估并保证监听方法不会在每次重试时重复发布重试消息；含上层事务时设置 `stateless: false`，并提供唯一 `messageId`。
- 参数错误和明确不可恢复的业务异常不应重试，在监听器内直接 `basicNack(requeue=false)`，由 DLX 接收。
- 反序列化、消息转换和参数映射异常通常发生在监听器调用之前，监听器的 `try/catch` 接收不到，应由容器 `ConditionalRejectingErrorHandler` 拒绝并交给 DLX。Spring AMQP 2.1.9+ 默认即使在 MANUAL 下也会 reject 且不 requeue；2.0～2.1.8 不得直接套用该结论，需自定义拒绝处理或保留 AUTO，版本边界见 `version-diff.md`。
- 重试次数放在消息头并递增，`message_id` 保持不变；不要依赖 `x-death` 计数，`x-death` 只用于诊断。
- `default-requeue-rejected: false` 只决定异常未被显式处理时不返回原队列。没有配置 DLX 时消息仍会被丢弃。
- 无限 requeue 会消耗 CPU、网络并阻塞后续消息，禁止使用。

## 死信处理与重放

死信消费者负责先持久化失败消息，再确认原消息，不在原业务线程中反复重试。告警由独立任务扫描已落库但尚未告警的死信记录并更新告警状态，不放在消息确认的关键路径中。存储操作必须幂等，可用消息 ID、原队列、死信原因和死信次数组成唯一约束，避免 DLX 重投产生重复记录。

```java
@Slf4j
@Component
@RequiredArgsConstructor
public class AlarmDeadLetterConsumer {

    private final FailedMessageStore failedMessageStore;

    @RabbitListener(queues = "nsp.alarm.dead.queue")
    public void handleDeadLetter(Message message, Channel channel) throws IOException {
        MessageProperties properties = message.getMessageProperties();
        long deliveryTag = properties.getDeliveryTag();
        byte[] body = message.getBody();
        Object xDeath = properties.getHeaders().get("x-death");
        log.error("收到死信消息: messageId={}, death={}, bodyLength={}",
                properties.getMessageId(), xDeath, body != null ? body.length : 0);
        try {
            failedMessageStore.saveDeadLetterIfAbsent(properties.getMessageId(), body, properties);
        } catch (Exception e) {
            log.error("死信落库失败: messageId={}", properties.getMessageId(), e);
            channel.basicNack(deliveryTag, false, false);   // 进入 declaration.md 的 parking queue
            return;
        }
        channel.basicAck(deliveryTag, false);               // 只确认已经持久化的消息
    }
}
```

死信落库成功后才 ack；独立告警任务失败时只更新告警状态并退避重试，不再 nack 已落库消息。落库失败时的 `basicNack(requeue=false)` 依赖 `alarmDeadQueue` 自身已配置且验证可达的备用 DLX/parking queue，声明见 `declaration.md`；没有这个备用目标时禁止直接 nack，否则最后一份可恢复消息会被丢弃。

重放前先修复路由、消息格式或下游故障，再通过独立补偿任务发布。重放保持 `message_id` 不变，消费幂等继续生效；重放前检查消费组去重记录：`SUCCESS` 跳过，`FAILED` 用 CAS 重置为 `PROCESSING`。每次实际重放前递增 `replay_attempt`，写入消息头并传给 `CorrelationData`；confirm/return 和超时回收都必须按 `message_id + replay_attempt` 条件更新，旧尝试的迟到回调不得覆盖新尝试。重放任务用 CAS 占位 + 租约 + confirm，不能同步“失败回滚”；不得让 DLQ 消费者直接调用原业务并自动无限重放。

日志不得打印消息体原文。确需保存原始 payload 时，限制访问权限并对敏感字段脱敏。

参考：[RabbitMQ Reliability Guide](https://www.rabbitmq.com/docs/reliability) 和 [Spring AMQP Resilience](https://docs.spring.io/spring-amqp/reference/amqp/resilience-recovering-from-errors-and-broker-failures.html)。
