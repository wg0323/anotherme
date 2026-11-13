---
name: rabbitmq-reliability
description: |
  Spring Boot 项目接入 RabbitMQ 的消息可靠性与性能权衡规范。当用户涉及以下场景时必须使用本技能：
  接入或配置 RabbitMQ、发送/消费消息、声明 Exchange/Queue/Binding、配置发布确认
  （confirm/returns）、事务性 Outbox、消费幂等与重试、死信队列、消息 TTL、quorum queue、
  prefetch/并发调优。目标是在明确故障边界的前提下实现至少一次投递和业务幂等，
  避免以关闭可靠性的方式换取吞吐量。仅适用于 Spring Boot + Spring AMQP 技术栈。
---

# RabbitMQ 消息可靠性与性能规范

先判断消息是否允许丢失、是否要求抗 Broker 单节点故障、是否存在顺序约束，再选择配置。可靠性目标是“至少一次投递 + 业务幂等”，不是承诺传输层绝不重复。

## 核心铁律

1. 连接信息走 `application.yml` + 环境变量占位符，生产环境不得为账号密码提供 `guest` 等默认值；dev/prod 通过 Spring Profile 隔离。
2. 不允许丢失的消息启用 `correlated` 发布确认、`publisher-returns` 和 `mandatory`。Confirm 异步处理，禁止逐条同步等待；Return 必须更新持久化发送状态并补偿，不能只记日志。
3. 生产端不能仅依赖内存中的 `CorrelationData` 重发。业务库与 MQ 存在双写且消息不允许丢失时，使用事务性 Outbox，并处理 nack、return、Confirm 超时和进程崩溃。
4. 消费者通常使用 Spring `AcknowledgeMode.AUTO`，容器在监听方法正常返回后 ACK，不等于 AMQP 的 auto-ack。业务数据库提交前不得 ACK；只有批处理、异步处理等确有需要时才用 `MANUAL`。
5. 消费幂等优先用“消费记录唯一索引 + 业务更新”的同一本地事务，或业务唯一约束/状态机。Redis 可以去重和加速，但不能单独承担严格幂等。
6. 只重试临时异常。本地重试次数和间隔按故障类型设置，不得把所有异常统一重试；长时间退避使用 Broker 支持的延迟重试或独立重试队列，避免占住消费线程。永久异常拒绝且不重投，并进入 DLQ。
7. 不允许丢失的消息使用 durable Exchange/Queue 和 persistent 消息。需要抗 Broker 单节点故障时使用 quorum queue；仅组集群、durable 或 persistent 都不会复制 classic queue 的消息内容。
8. 核心队列配置 DLQ、持久化记录、告警和受控重放。DLX 默认转发可能丢失消息，是否支持 at-least-once dead-lettering 必须按 RabbitMQ 版本核实，禁止把“有 DLQ”当成绝对不丢。
9. 不为吞吐量关闭核心消息的 Confirm、持久化或幂等。优先异步发布、合理设置 prefetch 和消费者并发、缩短业务处理时间；成功 Confirm 使用指标统计，不逐条写 INFO 日志。
10. 消息体使用 `Jackson2JsonMessageConverter`，保持精简。JSON 场景不强制 `Serializable`/`serialVersionUID`；跨服务反序列化配置范围明确的信任包，禁止信任所有包。
11. 含上层事务的消费重试将 `stateless` 设为 `false`，并提供唯一 `messageId`。日志禁止打印消息体原文，只记录消息 ID、队列、重试次数和长度等元信息。

## 详细规范与样例代码（按场景读取）

| 场景 | 参考文件 |
| ---- | -------- |
| 连接配置、消费参数基线与性能注意事项 | `references/config-template.md` |
| 事务性 Outbox、状态恢复、数据库与 MQ 双写 | `references/outbox.md` |
| 生产者确认、Return、超时补偿、发送规范 | `references/producer.md` |
| Exchange/Queue/Binding、quorum queue、DLQ、TTL | `references/declaration.md` |
| 消费者事务幂等、异常分类、重试、死信处理 | `references/consumer.md` |
| 吞吐量权衡、压测指标与故障演练 | `references/performance.md` |
| 上线前配置项逐项检查清单 | `references/checklist.md` |

官方语义以 [RabbitMQ Reliability Guide](https://www.rabbitmq.com/docs/reliability)、[Confirms](https://www.rabbitmq.com/docs/confirms) 和项目实际 RabbitMQ/Spring AMQP 版本文档为准。新版本特性不得直接套到旧版本。
