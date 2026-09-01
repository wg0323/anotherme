# 连接与基础配置模板

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
