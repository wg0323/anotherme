# 配置项检查清单（上线前逐项核对）

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
