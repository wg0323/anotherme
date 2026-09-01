---
name: rabbitmq-reliability
description: |
  SpringBoot 项目接入 RabbitMQ 的消息可靠性开发规范。当用户涉及以下场景时必须使用本技能：
  接入或配置 RabbitMQ、发送/消费消息、声明 Exchange/Queue/Binding、配置发布确认
  （confirm/returns）、消费重试、死信队列、消息 TTL、消息序列化。
  目标：确保消息不丢失、不重复消费。仅适用于 SpringBoot + Spring AMQP 技术栈。
---

# RabbitMQ 消息可靠性开发规范

## 核心铁律

1. 连接信息必须走 `application.yml` + 环境变量占位符，禁止硬编码与明文真实凭据；dev/prod 通过 Spring Profile 隔离。
2. 生产者三件套必须开启：`publisher-confirm-type: correlated`、`publisher-returns: true`、`template.mandatory: true`（禁止 `none` 或 `mandatory: false`，会静默丢消息），并实现 `ConfirmCallback` 与 `ReturnsCallback`。
3. 消费者 `acknowledge-mode` 必须为 `auto`（禁止 `manual`，批量确认等明确业务需要除外），开启重试：`max-attempts` 不超过 3 次、`initial-interval` 不低于 1000ms；重试耗尽后消息默认丢弃，核心业务必须配置死信队列。
4. Exchange/Queue/Binding 一律通过 `@Bean` 在 `@Configuration` 类集中声明，禁止 `@Queue`/`@Exchange` 注解分散声明；必须显式 `durable=true`，消息必须持久化（禁止改为非持久化）。
5. 消息体使用 `Jackson2JsonMessageConverter` JSON 序列化，消息体类实现 `Serializable` 并定义 `serialVersionUID`；跨服务消费必须配置 `DefaultJackson2JavaTypeMapper` 信任包。
6. 消费者必须保证幂等（数据库唯一索引 / Redis 分布式锁 / 业务状态校验）；业务异常抛 `AmqpRejectAndDontRequeueException` 拒绝且不重新入队。
7. 日志禁止打印消息体原文（防敏感数据泄露），仅记录长度等元信息。
8. 发送消息必须传入自定义 `CorrelationData` 子类（保存 exchange/routingKey/payload），便于 `ack=false` 时重发；回调注册使用 `RabbitTemplateCustomizer`，避免 `ApplicationRunner` 的回调空窗期。
9. 含事务时重试 `stateless` 设为 `false`，每次重试创建新事务避免状态污染。

## 详细规范与样例代码（按场景读取）

| 场景 | 参考文件 |
| ---- | -------- |
| 连接与完整配置模板 | `references/config-template.md` |
| 生产者：确认回调、失败重发、发送规范 | `references/producer.md` |
| Exchange/Queue/Binding 声明、死信队列、TTL | `references/declaration.md` |
| 消费者：异常处理、重试、幂等 | `references/consumer.md` |
| 上线前配置项逐项检查清单 | `references/checklist.md` |
