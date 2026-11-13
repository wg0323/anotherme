# Exchange / Queue / Binding 声明

Exchange、Queue、Binding 通过 `@Bean` 在 `@Configuration` 类集中声明。声明时明确 durable、autoDelete 和队列类型；队列类型创建后不能直接修改，迁移时新建队列并切换发布与消费。

## 持久化与队列类型

不允许丢失的消息需要同时使用：

- durable Exchange 和 Queue；
- `MessageDeliveryMode.PERSISTENT` 消息，Spring AMQP 默认使用持久化投递，仍需检查自定义 `MessagePostProcessor` 没有覆盖它；
- publisher confirm 和消费者处理完成后的 ACK。

这些配置不能复制 classic queue 的消息内容。需要抗 Broker 单节点故障时，在具备多数派节点的集群中使用 quorum queue：

```java
@Bean
public DirectExchange alarmExchange() {
    return ExchangeBuilder.directExchange("nsp.alarm.exchange").durable(true).build();
}

@Bean
public Queue alarmQueue() {
    return QueueBuilder.durable("nsp.alarm.queue")
            .withArgument("x-queue-type", "quorum")
            .withArgument("x-dead-letter-exchange", "nsp.alarm.dlx")
            .withArgument("x-dead-letter-routing-key", "alarm.dead")
            .build();
}

@Bean
public Binding alarmBinding(Queue alarmQueue, DirectExchange alarmExchange) {
    return BindingBuilder.bind(alarmQueue).to(alarmExchange).with("alarm.ai2na");
}
```

单节点 quorum queue 没有高可用收益。quorum queue 会增加多数派复制和确认延迟，临时队列、可丢失采样数据或极低延迟场景不必使用。已有 classic queue 不能直接追加 `x-queue-type` 原地变更。

## 死信队列

不允许丢失的核心队列配置 DLX。目标 Exchange、Binding 和 Queue 必须在业务流量进入前存在；目标缺失或不可路由时消息仍可能丢失。

```java
@Bean
public DirectExchange alarmDlxExchange() {
    return ExchangeBuilder.directExchange("nsp.alarm.dlx").durable(true).build();
}

@Bean
public Queue alarmDeadQueue() {
    return QueueBuilder.durable("nsp.alarm.dead.queue")
            .withArgument("x-queue-type", "quorum")
            .build();
}

@Bean
public Binding alarmDeadBinding(Queue alarmDeadQueue, DirectExchange alarmDlxExchange) {
    return BindingBuilder.bind(alarmDeadQueue).to(alarmDlxExchange).with("alarm.dead");
}
```

上例用 optional queue arguments 固定 DLX，便于展示完整拓扑。生产环境需要在线调整 DLX 时优先使用 RabbitMQ Policy；修改队列 `x-arguments` 通常需要重建队列，不能当作动态配置。

DLX 默认转发并不提供绝对的至少一次保证。RabbitMQ 版本支持 quorum queue 的 at-least-once dead-lettering 时，核心队列按官方要求同时配置 `dead-letter-strategy=at-least-once`、`overflow=reject-publish` 和队列长度限制，并评估额外 CPU、内存及重复消息。旧版本通过监控、持久化失败记录和补偿机制覆盖该风险。

死信队列还要配置专门消费者、幂等落库、告警和受控重放，详见 `consumer.md`。仅声明 DLQ 而不消费，会造成无人处理的积压。

## TTL 与积压保护

- 只有业务有明确时效要求时才设置 `x-message-ttl`。TTL 到期是主动让消息离开原队列，不是通用可靠性配置，核心业务不得照抄固定的 60 秒 TTL。
- 为队列设置长度或字节上限，防止磁盘和内存耗尽。不允许静默丢弃时评估 `reject-publish` 背压；`drop-head` 会删除队头消息。
- DLQ 同样需要容量上限、最老消息年龄和队列深度告警，重放前评估下游承载能力。

参考：[RabbitMQ Quorum Queues](https://www.rabbitmq.com/docs/quorum-queues) 和 [Dead Letter Exchanges](https://www.rabbitmq.com/docs/dlx)。
