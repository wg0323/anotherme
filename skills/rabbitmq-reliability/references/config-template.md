# 连接与基础配置模板

以下配置适用于“不允许丢失、无严格顺序要求”的消费队列。核心消息使用手动 ack：监听方法必须在业务事务提交后显式 `basicAck`，失败时显式 `basicNack`。`prefetch` 和并发数是压测起点，不是所有项目的固定答案；慢任务、小内存实例或下游容量较低时应降低。

- 连接信息通过 `application.yml` 配置，dev/prod 使用 Spring Profile 隔离。
- 生产账号密码只从环境变量读取，不提供默认凭据，并限制对应 vhost 的最小权限。
- Confirm 保持异步；不要在业务请求线程中每发送一条就等待确认。

```yaml
spring:
  rabbitmq:
    host: ${RABBITMQ_HOST:127.0.0.1}
    port: ${RABBITMQ_PORT:5672}
    username: ${RABBITMQ_USERNAME}
    password: ${RABBITMQ_PASSWORD}
    virtual-host: ${RABBITMQ_VHOST:/}
    connection-timeout: 10s
    requested-heartbeat: 30s
    publisher-confirm-type: correlated
    publisher-returns: true
    template:
      mandatory: true
    listener:
      simple:
        acknowledge-mode: manual         # 监听方法显式 basicAck/basicNack；ack 必须在事务提交后
        default-requeue-rejected: false  # 异常未被显式 nack 时的兜底：不重回原队列；必须配 DLX
        prefetch: 50                     # 压测起点；控制未 ACK 数和消费者内存
        concurrency: 2                   # 单实例起始并发，按 CPU 与下游容量调整
        max-concurrency: 8
        retry:
          enabled: false                 # 默认由应用发布重试消息；开启本地重试会与手动 ack 重复发布
```

## 配置边界

- `publisher-confirm-type` 自 Spring Boot 2.2 起提供；2.0/2.1 只能用 `publisher-confirms: true`。`publisher-returns`、`template.mandatory` 与 listener 各键（含 `retry.*`）三档一致，档位差异见 `version-diff.md`。
- `prefetch: 1` 会限制流水线并降低吞吐。RabbitMQ 官方给出的常见高吞吐参考区间是 100～300，但长耗时任务应从更小的值开始，避免进程崩溃时大量重投或内存堆积。
- 手动 ack 不会在监听方法正常返回后自动确认。每个分支都必须显式 ack 或 nack；漏掉会让消息在 Channel 关闭后重投，造成积压和重复消费。
- ack 必须在业务事务提交之后执行。不要给监听方法加 `@Transactional` 并在方法体内 ack：ack 会先于事务提交，提交失败时消息已经丢失。把业务处理放到独立的 `@Transactional` 服务方法，返回后再 ack。
- 默认关闭 Spring Retry。若开启本地重试，必须保证监听方法不会在每次重试时重复发布重试消息；含上层事务时设置 `stateless: false`，并提供唯一 `messageId`。
- 消费者发布重试消息时必须等待该次 publisher confirm（有界超时）并检查 `mandatory` return，确认已路由后再 ack 原消息；业务主路径仍走 Outbox + 异步 confirm，不要逐条同步等待。
- `default-requeue-rejected: false` 是异常未被显式 ack/nack 时的兜底；它必须与 DLQ、失败记录和告警配套，否则容器拒绝后消息会被丢弃。
- 反序列化等 fatal 异常发生在监听器之前。Spring AMQP 2.1.9+ 默认在 MANUAL 下也会 reject 且不 requeue；2.0～2.1.8 可能滞留 unacked，需自定义拒绝处理或保留 AUTO，不能直接套用本模板，详见 `version-diff.md`。
- 同一应用同时有核心与非核心监听时，用独立的 `SimpleRabbitListenerContainerFactory` 分别配置 ack 模式，不要用一个全局开关兼顾。
- 成功 Confirm 记指标，失败和超时记告警上下文。高吞吐下逐条 INFO 日志会引入额外 I/O。
