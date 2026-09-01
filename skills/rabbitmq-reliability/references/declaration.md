# Exchange / Queue / Binding 声明

## 声明方式与持久化

- **强制**：Exchange、Queue、Binding 通过 `@Bean` 在 `@Configuration` 类中声明，禁止使用 `@Queue` / `@Exchange` 注解分散声明。
- **强制**：声明时必须显式指定 `durable`、`autoDelete` 等属性；Exchange 和 Queue 必须 `durable=true`。
- **强制**：消息必须持久化（`MessageDeliveryMode.PERSISTENT`，Spring AMQP 默认即持久化，禁止改为非持久化）。

```java
@Bean
public DirectExchange alarmExchange() {
    return ExchangeBuilder.directExchange("nsp.alarm.exchange").durable(true).build();
}

@Bean
public Queue alarmQueue() {
    return QueueBuilder.durable("nsp.alarm.queue").build();
}

@Bean
public Binding alarmBinding(Queue alarmQueue, DirectExchange alarmExchange) {
    return BindingBuilder.bind(alarmQueue).to(alarmExchange).with("alarm.ai2na");
}
```

## 死信队列与消息 TTL

- **强制**：核心业务队列必须通过 `x-dead-letter-exchange` 和 `x-dead-letter-routing-key` 绑定死信交换机；死信 Exchange、Queue、Binding 同样需声明并设置 `durable=true`。
- **规范**：有时效性要求的消息通过队列级 TTL（`x-message-ttl`，单位毫秒）设置过期，过期后转入死信队列。

```java
// 死信 Exchange、Queue、Binding 按常规方式声明（durable=true），此处省略

// 业务队列：绑定死信交换机 + 可选 TTL
@Bean
public Queue alarmQueue() {
    return QueueBuilder.durable("nsp.alarm.queue")
            .withArgument("x-dead-letter-exchange", "nsp.alarm.dlx")
            .withArgument("x-dead-letter-routing-key", "alarm.dead")
            .withArgument("x-message-ttl", 60000)  // 可选：60 秒过期
            .build();
}
```
