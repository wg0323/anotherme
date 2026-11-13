# 消费者编写规范

消费者按“业务事务成功提交后才 ACK”设计。RabbitMQ 和 Spring 的重投机制会带来重复消息，因此幂等是正常处理流程的一部分，不是异常补丁。

## ACK 与事务边界

通常使用 Spring `AcknowledgeMode.AUTO`：监听方法正常返回后由容器 ACK，抛出异常时按重试和拒绝策略处理。它不是 AMQP 协议中收到即丢弃的 auto-ack；后者对应 Spring 的 `AcknowledgeMode.NONE`，核心消息禁止使用。

只有批量 ACK、异步业务处理等容器无法判断完成时机的场景才使用 `MANUAL`。手动模式必须保证每条消息最终 ACK 或 NACK，且只能在接收它的 Channel 上操作。

幂等记录与业务更新必须处于同一个本地事务。消息 DTO 携带的 `messageId` 必须与发布时写入的 AMQP `messageId` 一致，或者直接读取消息属性，不能由消费端重新生成。

1. 以 `messageId` 或业务唯一键插入消费记录，建立数据库唯一索引。
2. 在同一事务中更新业务数据并提交。
3. 唯一键冲突表示已处理，按成功返回，让容器 ACK。
4. 业务失败则整个事务回滚；临时异常继续抛出，永久异常拒绝且不重投。

```java
@Slf4j
@Component
@RequiredArgsConstructor
public class AlarmConsumer {

    private final AlarmService alarmService;

    @RabbitListener(queues = "nsp.alarm.queue")
    public void handleAlarm(AlarmMessage message) {
        try {
            // process 的事务实现同时完成消费记录唯一写入和业务更新
            alarmService.process(message);
        } catch (PermanentBusinessException e) {
            log.error("报警消息存在永久业务错误: messageId={}", message.getMessageId(), e);
            throw new AmqpRejectAndDontRequeueException(e);
        }
    }
}
```

`AlarmService.process` 的事务实现需要识别唯一键冲突并正常返回，不能把重复消息当成系统错误。若项目使用 Redis 前置去重，Redis 故障或键过期后仍须由数据库约束兜底；不要在业务异常后简单删除 SETNX 键，就把这套流程视为严格幂等。

## 异常分类与重试

- 数据库死锁、短时网络抖动等临时异常可以本地有限重试；含上层事务时设置 `stateless: false`，并提供唯一 `messageId`。
- 参数错误、反序列化失败、明确不可恢复的业务异常不应重试，直接 NACK 且不 requeue，由 DLX 接收。
- 下游持续不可用时，本地重试会占用消费线程。改用 RabbitMQ 当前版本支持的延迟重试，或独立重试 Exchange/Queue，并设置总次数、退避和最终 DLQ。
- 通过重试策略明确排除永久异常。不要仅依赖异常类名，也不要把所有 `RuntimeException` 无差别重试。
- `default-requeue-rejected: false` 只决定最终失败不返回原队列。没有配置 DLX 时消息仍会被丢弃。
- 无限 requeue 会消耗 CPU、网络并阻塞后续消息，禁止使用。

## 死信处理与重放

死信消费者负责持久化失败消息和告警，不在原业务线程中反复重试。存储操作必须幂等，可用消息 ID、原队列、死信原因和死信次数组成唯一约束，避免 DLX 重投产生重复记录。

```java
@Slf4j
@Component
@RequiredArgsConstructor
public class AlarmDeadLetterConsumer {

    private final FailedMessageStore failedMessageStore;
    private final AlarmNotifier alarmNotifier;

    @RabbitListener(queues = "nsp.alarm.dead.queue")
    public void handleDeadLetter(Message message) {
        MessageProperties properties = message.getMessageProperties();
        byte[] body = message.getBody();
        Object xDeath = properties.getHeaders().get("x-death");
        log.error("收到死信消息: messageId={}, death={}, bodyLength={}",
                properties.getMessageId(), xDeath, body != null ? body.length : 0);
        failedMessageStore.saveDeadLetterIfAbsent(properties.getMessageId(), body, properties);
        alarmNotifier.notifyDeadLetter(properties.getMessageId());
    }
}
```

死信落库或告警失败时不得吞掉异常后正常返回，否则容器会 ACK 并删除最后一条可恢复消息。为死信监听单独设计存储故障时的重试、重投或备用告警策略，避免死信循环。

重放前先修复路由、消息格式或下游故障，再通过独立补偿任务发布。重放复用原业务事件 ID，消费幂等继续生效；不得让 DLQ 消费者直接调用原业务并自动无限重放。

日志不得打印消息体原文。确需保存原始 payload 时，限制访问权限并对敏感字段脱敏。

参考：[RabbitMQ Reliability Guide](https://www.rabbitmq.com/docs/reliability) 和 [Spring AMQP Resilience](https://docs.spring.io/spring-amqp/reference/amqp/resilience-recovering-from-errors-and-broker-failures.html)。
