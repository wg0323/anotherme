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
- **强制**：消费者必须保证幂等性（数据库唯一索引 / Redis 分布式锁 / 业务状态校验）。

```java
@Slf4j @Component @RequiredArgsConstructor
public class AlarmConsumer {

    private final AlarmService alarmService;

    @RabbitListener(queues = "nsp.alarm.queue")
    public void handleAlarm(AlarmMessage message) {
        try {
            log.info("收到报警消息: alarmId={}", message.getAlarmId());
            alarmService.process(message);
        } catch (BusinessException e) {
            log.error("报警消息处理失败(业务异常): alarmId={}", message.getAlarmId(), e);
            throw new AmqpRejectAndDontRequeueException(e);
        }
    }
}
```
