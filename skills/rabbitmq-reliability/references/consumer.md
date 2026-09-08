# 消费者编写规范

## 确认与重试

- **强制**：`acknowledge-mode` 必须为 `auto`（正常返回自动 ack；抛异常先触发本地重试，重试耗尽后自动 nack），禁止 `manual`（批量确认等明确业务需要除外）。
- **强制**：必须开启消费者重试，`max-attempts` 不超过 3 次，`initial-interval` 不低于 1000ms。
- **强制**：重试耗尽后消息默认丢弃，核心业务必须配置死信队列供人工排查。
- **规范**：含事务时 `stateless` 设为 `false`，每次重试创建新事务避免状态污染。

## 异常处理与幂等

- **强制**：使用 `@RabbitListener` 注解声明消费者，指定 queue 名称。
- **强制**：消费方法必须捕获业务异常并处理，业务异常抛 `AmqpRejectAndDontRequeueException` 拒绝且不重新入队（消息默认丢弃，仅当 Queue 配置 DLX 时才转死信）。
- **说明**：未捕获的非业务异常触发重试，重试耗尽后 nack 进入死信队列（需配置 DLX）。
- **强制**：消费者必须保证幂等性（数据库唯一索引 / Redis 分布式锁 / 业务状态校验，三选一）。
- **强制**：幂等键必须使用业务唯一标识（如 messageId）并设置过期时间，防止 Redis 键无限增长。
- **规范**：采用「处理前 SETNX 占位」的幂等方案时，处理失败（尤其需重试的异常）必须删除幂等键，否则重试/重投会被幂等拦截，导致消息实际未被处理。

```java
@Slf4j @Component @RequiredArgsConstructor
public class AlarmConsumer {

    private final AlarmService alarmService;
    private final StringRedisTemplate redisTemplate;

    private static final String IDEMPOTENT_PREFIX = "mq:idem:alarm:";
    private static final Duration IDEMPOTENT_TTL = Duration.ofHours(24);

    @RabbitListener(queues = "nsp.alarm.queue")
    public void handleAlarm(AlarmMessage message) {
        String idemKey = IDEMPOTENT_PREFIX + message.getMessageId();
        // SETNX 占位：仅首次写入返回 true；重复投递直接跳过，保证幂等
        Boolean first = redisTemplate.opsForValue().setIfAbsent(idemKey, "1", IDEMPOTENT_TTL);
        if (!Boolean.TRUE.equals(first)) {
            log.warn("重复消息已忽略: messageId={}", message.getMessageId());
            return;
        }
        try {
            log.info("收到报警消息: alarmId={}", message.getAlarmId());
            alarmService.process(message);
        } catch (BusinessException e) {
            // 业务异常不可重试：回滚幂等键后拒绝且不重投（配 DLX 则转死信）
            redisTemplate.delete(idemKey);
            log.error("报警消息处理失败(业务异常): alarmId={}", message.getAlarmId(), e);
            throw new AmqpRejectAndDontRequeueException(e);
        } catch (RuntimeException e) {
            // 非业务异常：回滚幂等键后抛出，交由容器重试；否则重试会被幂等键挡住
            redisTemplate.delete(idemKey);
            throw e;
        }
    }
}
```

## 死信队列消费与告警

- **强制**：死信队列必须有专门的消费者监听，做「落库 + 告警」，这是失败消息的最后一道防线，绝不能无人消费（死信 Exchange/Queue 声明见 `declaration.md`）。
- **规范**：死信消费者**不做业务重试**（避免把毒消息又投回业务队列形成循环），仅记录、落库、告警，是否重放由人工或独立补偿任务决定。
- **规范**：遵守核心铁律 7，日志禁止打印死信消息体原文，仅记录长度等元信息；如需落库原文，含敏感数据时先脱敏。

```java
@Slf4j @Component @RequiredArgsConstructor
public class AlarmDeadLetterConsumer {

    private final FailedMessageStore failedMessageStore;  // 死信落库，供人工排查/重放
    private final AlarmNotifier alarmNotifier;            // 告警组件（邮件/钉钉/企业微信等）

    @RabbitListener(queues = "nsp.alarm.dead.queue")
    public void handleDeadLetter(Message message) {
        byte[] body = message.getBody();
        // 死信元信息在 header "x-death"（List<Map>，含 reason=expired/rejected/maxlen、原队列、次数）
        Object xDeath = message.getMessageProperties().getHeaders().get("x-death");
        String reason = xDeath != null ? xDeath.toString() : "unknown";
        log.error("收到死信消息: reason={}, bodyLength={}", reason, body != null ? body.length : 0);

        // 1) 落库：保存原始消息 + 死信元信息，供后续人工排查与重放（敏感数据先脱敏）
        failedMessageStore.saveDeadLetter(body, message.getMessageProperties());
        // 2) 告警：死信代表有消息未被正常处理，必须及时通知责任人
        alarmNotifier.notifyDeadLetter(message.getMessageProperties().getReceivedRoutingKey());
    }
}
```
