---
name: rabbitmq-reliability
description: |
  Spring Boot 项目接入 RabbitMQ 的消息可靠性与性能权衡规范。当用户涉及以下场景时必须使用本技能：
  接入或配置 RabbitMQ、发送/消费消息、声明 Exchange/Queue/Binding、配置发布确认
  （confirm/returns）、事务性 Outbox、消费幂等与重试、死信队列、消息 TTL、quorum queue、
  prefetch/并发调优。目标是在明确故障边界的前提下实现至少一次投递和业务幂等，
  避免以关闭可靠性的方式换取吞吐量。含 Spring Boot 2.x（JDK 8）与 3.x（JDK 17+）两档写法差异：
  发布确认配置键、Return 回调接口、回调注册方式、javax/jakarta 校验包，先判档位再写代码与配置。
  含默认实施方案（Outbox、手动 ack、消费幂等、有界重试、死信重放）、失败矩阵与验证清单。
  仅适用于 Spring Boot + Spring AMQP 技术栈。
---

# RabbitMQ 消息可靠性与性能规范

先判断消息是否允许丢失、是否要求抗 Broker 单节点故障、是否存在顺序约束，再选择配置；没有特殊理由时按下面的默认路线落地。可靠性目标是“至少一次投递 + 业务幂等”，不是承诺传输层绝不重复。

## 默认实施路线

默认按 `references/blueprint.md` 落地，完整判断表、失败矩阵与验证项以该文件为准：

1. 判边界与幂等键：消息能否丢、是否抗单节点故障、是否要求顺序；有业务操作级幂等键用唯一索引，没有时用同事务 `(consumer_group, message_id)` 去重记录作为最终兜底。
2. 生产端：业务与 `PENDING` Outbox 同库同事务 → 扫描抢占 `SENDING` → 发布（`messageId` + `publish_attempt`）→ confirm/return/超时回收 → `SENT` / `FAILED`。
3. Broker：durable + persistent + quorum（按需）+ confirm/mandatory；DLX/DLQ 在流量进入前创建并配置消费者。
4. 消费端：核心消息使用手动 ack，业务事务提交后显式 `basicAck`；去重记录与业务写入同事务，有业务操作级幂等键用它、没有时去重记录就是最终兜底；唯一键冲突须核对业务操作与内容指纹，不一致不得按重复成功确认；外部副作用用 `PROCESSING` 状态机 + 下游幂等。
5. 失败链与验证：消息头重试计数 → 分级 TTL 延迟队列 → 死信落库 → 告警 → CAS 重放 → 对账；按 `blueprint.md` 的验证清单与 `performance.md` 的故障演练执行。

## 核心铁律

1. 连接信息走 `application.yml` + 环境变量占位符，生产环境不得为账号密码提供 `guest` 等默认值；dev/prod 通过 Spring Profile 隔离。
2. 不允许丢失的消息启用 `correlated` 发布确认、`publisher-returns` 和 `mandatory`。Confirm 异步处理，禁止逐条同步等待；Return 必须更新持久化发送状态并补偿，不能只记日志。消费者发布重试消息时，允许对该次发布做有界同步 confirm，确认且无 return 后再 ack 原消息。
3. 生产端不能仅依赖内存中的 `CorrelationData` 重发。业务库与 MQ 存在双写且消息不允许丢失时，使用事务性 Outbox：Outbox 与业务表同库同分片、同事务写入，确认回调按 `message_id + publish_attempt` 条件更新，并处理 nack、return、Confirm 超时和进程崩溃。
4. 核心消息使用 Spring `AcknowledgeMode.MANUAL`，监听方法在业务事务提交后显式 `basicAck`，失败时显式 `basicNack`；ack 必须在提交之后，不能把 `@Transactional` 加在监听方法上并在方法体内 ack。`AUTO` 只用于可丢失或非核心的简单场景，以及 `version-diff.md` 规定的 Spring AMQP 2.0～2.1.8 fatal 异常兼容方案；禁止 `NONE`，也不得漏掉 ack/nack。
5. 消费幂等：有业务操作级幂等键时用业务唯一索引；没有时，`(consumer_group, message_id)` 去重记录与业务更新在同一本地事务写入，去重记录就是最终兜底。订单号等业务对象 ID 必须结合事件类型或版本限定具体操作；唯一键冲突后，只有业务操作和内容指纹都一致才按重复成功确认，不一致必须按数据冲突处理。Redis 只能做更前置的优化，不能单独承担严格幂等。
6. 只重试临时异常。默认关闭 Spring Retry，由消费者显式发布重试消息到对应退避级别的 TTL 延迟队列，再 ack 原消息；长退避不得占住消费线程。重试次数放消息头并随重投递增，重试保持 `message_id` 不变；不同退避级别使用各自队列，禁止混排。永久异常拒绝且不重投，并进入 DLQ。
7. 不允许丢失的消息使用 durable Exchange/Queue 和 persistent 消息。需要抗 Broker 单节点故障时使用 quorum queue；仅组集群、durable 或 persistent 都不会复制 classic queue 的消息内容。
8. 核心队列配置 DLQ、持久化记录、基于死信记录的异步告警和受控重放；死信落库失败时，DLQ 自身必须有已声明并验证可达的备用 DLX/parking queue，否则禁止直接 nack。DLX 默认转发可能丢失消息，是否支持 at-least-once dead-lettering 必须按 RabbitMQ 版本核实，禁止把“有 DLQ”当成绝对不丢。死信重放保持 `message_id` 不变，每次重放递增 `replay_attempt` 并按它做条件更新，旧回调不得覆盖新尝试；重复重放必须拒绝，重放前按消费组去重记录状态决定跳过还是重置。
9. 不为吞吐量关闭核心消息的 Confirm、持久化或幂等。优先异步发布、合理设置 prefetch 和消费者并发、缩短业务处理时间；成功 Confirm 使用指标统计，不逐条写 INFO 日志。
10. 消息体使用 `Jackson2JsonMessageConverter`，保持精简。JSON 场景不强制 `Serializable`/`serialVersionUID`；跨服务反序列化配置范围明确的信任包，禁止信任所有包。
11. 若保留 Spring 本地重试，含上层事务时将 `stateless` 设为 `false`，并提供唯一 `messageId`；默认重试链路不使用本地重试。日志禁止打印消息体原文，只记录消息 ID、队列、重试次数和长度等元信息。
12. 写代码或配置前先判定 Spring Boot 档位（`pom.xml` 中 `spring-boot-starter-parent` / `spring-boot-dependencies` 的版本），再选本档写法：`publisher-confirm-type` 需 2.2+（2.0/2.1 只能 `publisher-confirms: true`）；`setReturnsCallback` 需 Spring AMQP 2.3+（2.2 及以前用五参 `setReturnCallback`）；`RabbitTemplateCustomizer` 仅 Boot 3.1+ 提供。MANUAL 下反序列化等 fatal 异常还要核对 Spring AMQP 2.1.9 边界：2.1.9+ 默认 reject 且不 requeue，2.0～2.1.8 需自定义拒绝处理或保留 AUTO。看到「弃用」提示时先看本档是否已有替代 API，就地换写法，不因此升级框架；三档对照代码、判档命令与警告排查见 `references/version-diff.md`，禁止跨档复制示例。

## 详细规范与样例代码（按场景读取）

| 场景 | 参考文件 |
| ---- | -------- |
| 默认实施路线：边界判断、幂等选型、Outbox/消费/死信状态机、时间参数、失败矩阵 | `references/blueprint.md` |
| 档位判定、发布确认键与 Return 回调的三档对照、回调注册方式、弃用警告排查 | `references/version-diff.md` |
| 连接配置、手动 ack 参数基线与性能注意事项 | `references/config-template.md` |
| 事务性 Outbox、状态恢复、数据库与 MQ 双写 | `references/outbox.md` |
| 生产者确认、Return、超时补偿、发送规范 | `references/producer.md` |
| Exchange/Queue/Binding、quorum queue、DLQ、TTL | `references/declaration.md` |
| 消费者手动 ack、事务幂等、异常分类、重试、死信处理 | `references/consumer.md` |
| 吞吐量权衡、压测指标与故障演练 | `references/performance.md` |
| 上线前配置项逐项检查清单 | `references/checklist.md` |

## 输出契约

应用本 skill 时，答复必须包含：

- 消息拓扑与状态流转；
- 表结构与唯一键；
- 生产端、消费端、失败处理的关键改动点；
- 失败矩阵（每种失败由哪一层兜底，模板见 `blueprint.md`）；
- 验证步骤；
- 本方案不覆盖的风险（顺序性、跨服务事务、外部副作用、exactly-once）。

官方语义以 [RabbitMQ Reliability Guide](https://www.rabbitmq.com/docs/reliability)、[Confirms](https://www.rabbitmq.com/docs/confirms) 和项目实际 RabbitMQ/Spring AMQP 版本文档为准。新版本特性不得直接套到旧版本。
