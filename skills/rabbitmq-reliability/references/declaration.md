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
            .withArgument("x-dead-letter-exchange", "nsp.alarm.dead.parking.dlx")
            .withArgument("x-dead-letter-routing-key", "alarm.dead.parking")
            .build();
}

@Bean
public Binding alarmDeadBinding(Queue alarmDeadQueue, DirectExchange alarmDlxExchange) {
    return BindingBuilder.bind(alarmDeadQueue).to(alarmDlxExchange).with("alarm.dead");
}

@Bean
public DirectExchange alarmDeadParkingExchange() {
    return ExchangeBuilder.directExchange("nsp.alarm.dead.parking.dlx").durable(true).build();
}

@Bean
public Queue alarmDeadParkingQueue() {
    return QueueBuilder.durable("nsp.alarm.dead.parking.queue")
            .withArgument("x-queue-type", "quorum")
            .build();
}

@Bean
public Binding alarmDeadParkingBinding(Queue alarmDeadParkingQueue,
                                       DirectExchange alarmDeadParkingExchange) {
    return BindingBuilder.bind(alarmDeadParkingQueue).to(alarmDeadParkingExchange).with("alarm.dead.parking");
}
```

上例用 optional queue arguments 固定 DLX，便于展示完整拓扑。生产环境需要在线调整 DLX 时优先使用 RabbitMQ Policy；修改队列 `x-arguments` 通常需要重建队列，不能当作动态配置。

DLX 默认转发并不提供绝对的至少一次保证。RabbitMQ 版本支持 quorum queue 的 at-least-once dead-lettering 时，核心队列以及需要在落库失败后 nack 到备用目标的 DLQ，都要按官方要求同时配置 `dead-letter-strategy=at-least-once`、`overflow=reject-publish` 和队列长度限制，并评估额外 CPU、内存及重复消息。旧版本通过监控、持久化失败记录和补偿机制覆盖该风险。

`nsp.alarm.dead.parking.queue` 是死信落库失败时的最后备用目标，不配置消费者自动回流原 DLQ，避免死信循环。它必须有容量、队列深度和最老消息年龄告警；存储修复后由受控补偿任务将消息重新送入死信落库流程。没有声明并验证这个备用目标时，死信消费者不得直接 `basicNack(requeue=false)`。

死信队列还要配置专门消费者、幂等落库、基于死信记录的异步告警和受控重放，详见 `consumer.md`。仅声明 DLQ 而不消费，会造成无人处理的积压。

## 重试延迟队列

重试退避使用独立的延迟队列：队列不配置消费者，`x-message-ttl` 设为该级别的退避时间，`x-dead-letter-exchange` / `x-dead-letter-routing-key` 指回原业务 Exchange 和路由键。每个退避级别一个队列，不要把 1s/5s/30s/2min 混在一个队列：per-message TTL 只在队头生效，会队头阻塞。

```java
@Bean
public Queue alarmRetry1sQueue() {
    return QueueBuilder.durable("nsp.alarm.retry.1s")
            .withArgument("x-message-ttl", 1000)
            .withArgument("x-dead-letter-exchange", "nsp.alarm.exchange")
            .withArgument("x-dead-letter-routing-key", "alarm.ai2na")
            .build();
}
```

路由键固定的队列可以显式设置 `x-dead-letter-routing-key`；多路由键场景省略该参数，让 DLX 使用原路由键。重试消息在原消息 ack 之前发布，并等待该次 publisher confirm 且检查 `mandatory` return：confirm ack 且未被 return 后才 ack 原消息；confirm nack/超时/return 时 nack 进死信。原业务 Exchange/Binding/Queue 必须已存在，否则 TTL 到期后重试消息会被丢弃。延迟队列承载的仍是“不允许丢失”的消息：单机 classic durable 只防 Broker 重启，不防节点故障，节点故障会丢掉已经 ack 的原始消息对应的重试副本。要求抗单节点故障时，延迟队列同样使用 quorum queue，并确认发布 confirm 在多数派接受后返回。

## TTL 与积压保护

- 业务队列的 `x-message-ttl` 只在有明确时效要求时设置；TTL 到期是主动让消息离开原队列，不是通用可靠性配置，核心业务不得照抄固定的 60 秒 TTL。重试延迟队列的 TTL 是延迟机制，两者不要混用。
- 为队列设置长度或字节上限，防止磁盘和内存耗尽。不允许静默丢弃时评估 `reject-publish` 背压；`drop-head` 会删除队头消息。
- DLQ 同样需要容量上限、最老消息年龄和队列深度告警，重放前评估下游承载能力。

参考：[RabbitMQ Quorum Queues](https://www.rabbitmq.com/docs/quorum-queues) 和 [Dead Letter Exchanges](https://www.rabbitmq.com/docs/dlx)。
