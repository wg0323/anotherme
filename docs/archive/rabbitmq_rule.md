---
trigger: model_decision
description: RabbitMQ 消息可靠性开发规范，统一约束生产者确认回调、消费者重试策略、Exchange/Queue 声明、消息序列化等标准，确保消息不丢失、不重复消费。
---
# RabbitMQ 消息可靠性开发规范

> 适用场景：所有使用 RabbitMQ 的 SpringBoot 项目。接入 RabbitMQ 时必须遵循本规范，确保消息投递可靠、消费容错完善。

## 1. 连接与基础配置

- **强制**：连接信息通过 `application.yml` 配置，禁止硬编码；dev/prod 通过 Spring Profile 隔离。
- **强制**：敏感信息（host、username、password）使用环境变量占位符，禁止写入真实凭据。

```yaml
spring:
  rabbitmq:
    host: ${RABBITMQ_HOST:127.0.0.1}
    port: ${RABBITMQ_PORT:5672}
    username: ${RABBITMQ_USERNAME:guest}
    password: ${RABBITMQ_PASSWORD:guest}
    virtual-host: ${RABBITMQ_VHOST:/}
    connection-timeout: 10000            # 连接超时 10 秒
    requested-heartbeat: 30              # 心跳 30 秒，检测网络假死
    publisher-confirm-type: correlated   # 生产者发布确认（异步回调）
    publisher-returns: true              # 开启路由失败回调
    template:
      mandatory: true                    # 路由失败时调用 ReturnCallback，禁止丢弃
    listener:
      simple:
        acknowledge-mode: auto           # 异常触发重试，重试耗尽后自动 nack
        prefetch: 1                      # 预取消息数，控制内存压力与分发均衡
        concurrency: 1                   # 最小消费者并发数
        max-concurrency: 5               # 最大消费者并发数
        retry:
          enabled: true                  # 开启消费失败重试
          initial-interval: 1000         # 初始等待 1 秒
          multiplier: 1
          max-attempts: 3                # 最大重试次数
          stateless: true                # 含事务时改为 false，每次重试创建新事务避免状态污染
```

## 2. 生产者消息可靠性

### 2.1 发布确认与路由失败回调

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

### 2.2 CorrelationData 与失败重发

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

## 3. 消费者消息可靠性

- **强制**：`acknowledge-mode` 必须为 `auto`（正常返回自动 ack；抛异常先触发本地重试，重试耗尽后自动 nack），禁止 `manual`（批量确认等明确业务需要除外）。
- **强制**：必须开启消费者重试，`max-attempts` 不超过 3 次，`initial-interval` 不低于 1000ms。
- **强制**：重试耗尽后消息默认丢弃，核心业务必须配置死信队列供人工排查。
- **规范**：含事务时 `stateless` 设为 `false`，每次重试创建新事务避免状态污染。

## 4. Exchange / Queue / Binding 声明

### 4.1 声明方式与持久化

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

### 4.2 死信队列与消息 TTL

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

## 5. 消息发送规范

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

## 6. 消费者编写规范

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

## 7. 配置项检查清单

| 检查项 | 要求 | 配置项 |
|--------|------|--------|
| 发布确认 | 必须开启 | `publisher-confirm-type: correlated` |
| 路由失败回调 | 必须开启 | `publisher-returns: true` |
| mandatory | 必须为 true | `template.mandatory: true` |
| ConfirmCallback | 必须实现 | Java 代码 |
| ReturnsCallback | 必须实现 | Java 代码 |
| 确认模式 | auto | `acknowledge-mode: auto` |
| 消费重试 | 必须开启 | `retry.enabled: true` |
| 最大重试 | 不超过3次 | `retry.max-attempts: 3` |
| 初始间隔 | 不低于1秒 | `retry.initial-interval: 1000` |
| prefetch | 必须设置 | `listener.simple.prefetch` |
| 并发消费者 | 按需设置 | `concurrency` / `max-concurrency` |
| 连接超时 | 必须设置 | `connection-timeout` |
| 心跳 | 必须设置 | `requested-heartbeat` |
| Exchange/Queue 持久化 | 必须持久化 | `durable=true` |
| 死信队列 | 核心业务必须配置 | `x-dead-letter-exchange` |
| 消息 TTL | 按需配置 | `x-message-ttl` |
| 消息序列化 | JSON | `Jackson2JsonMessageConverter` |
| Converter 类型信任 | 跨服务必须配置 | `DefaultJackson2JavaTypeMapper` |
| CorrelationData | 必须传入 | Java 代码 |
| 消费者幂等 | 必须保证 | 业务代码实现 |
