# 连接与基础配置模板

以下配置适用于“不允许丢失、无严格顺序要求”的消费队列。`prefetch` 和并发数是压测起点，不是所有项目的固定答案；慢任务、小内存实例或下游容量较低时应降低。

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
        acknowledge-mode: auto           # 容器在监听方法正常返回后 ACK，不是 AMQP auto-ack
        default-requeue-rejected: false  # 最终失败进入 DLX；未配置 DLX 时会被丢弃
        prefetch: 50                     # 压测起点；控制未 ACK 数和消费者内存
        concurrency: 2                   # 单实例起始并发，按 CPU 与下游容量调整
        max-concurrency: 8
        retry:
          enabled: true
          initial-interval: 1s
          multiplier: 2
          max-interval: 10s
          max-attempts: 3                # 包含首次调用，只用于可恢复的临时异常
          stateless: true                # 上层存在事务时改 false，并提供唯一 messageId
```

## 配置边界

- `prefetch: 1` 会限制流水线并降低吞吐。RabbitMQ 官方给出的常见高吞吐参考区间是 100～300，但长耗时任务应从更小的值开始，避免进程崩溃时大量重投或内存堆积。
- 本地重试会占用消费线程。下游长时间不可用时，应停止本地重试，改用有次数上限的延迟重试；永久业务异常、反序列化错误和参数错误不得反复重试。
- Spring Retry 默认可能遍历到的异常范围取决于项目配置。通过自定义重试策略或拦截器排除永久异常，不能仅抛 `AmqpRejectAndDontRequeueException` 就假设本地重试一定会跳过。
- `default-requeue-rejected: false` 必须与 DLQ、失败记录和告警配套，否则重试耗尽后消息会被丢弃。
- 成功 Confirm 记指标，失败和超时记告警上下文。高吞吐下逐条 INFO 日志会引入额外 I/O。
