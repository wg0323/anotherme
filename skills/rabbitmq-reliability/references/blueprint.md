# 默认实施方案：至少一次投递 + 消费幂等

本文件是默认路线总纲。先按本文确定边界、表结构与失败链，再进入 `outbox.md`、`producer.md`、`consumer.md`、`declaration.md` 的实现细节；Spring Boot 2.x/3.x 的写法差异先看 `version-diff.md`。

术语：`message_id` 指消息的业务身份，等于 Outbox 的 `event_id`、AMQP 的 `messageId`，重试与重放都保持不变；`publish_attempt` 是生产端第几次发送；`retry_count` 是消费端第几次重试；`replay_attempt` 是死信第几次重放。四者不要混用。

## 目标

在“至少一次”投递语义下保证三件事：

1. 业务成功时，消息最终要么已发出，要么进入可查询的 `FAILED` / 死信终态，能被自动补偿或人工重放，不会静默消失；
2. 同一业务事件被重复投递时，业务结果只产生一次；
3. 消费失败时不丢消息、不无限重试，终态可查、可重放、可对账。

不承诺端到端 exactly-once。所有“只执行一次”的结论都必须落到消费端幂等（业务唯一键、同事务去重记录或状态机）。

## 适用边界

适用：

- 单个服务内，业务写库与消息发送需要保持一致；
- 消费端可能收到重复消息，或处理失败需要重试；
- 使用关系型数据库，且能加唯一约束；
- 需要死信兜底、人工重放和事后对账。

前提（不满足就不要套用）：

- Outbox 表与业务表同库，能在同一个本地事务写入；分库分表时两者必须同分片，扫描任务按分片处理；
- 消费端能提供业务操作级幂等键，或能在同一事务内写入 `(consumer_group, message_id)` 去重记录（去重表与业务表同库）；
- 外部副作用（支付、短信、RPC）的下游具备幂等能力或对账手段。

不适用，需另行设计：

- 跨库、跨服务的分布式事务；
- 严格的消息顺序；
- 没有唯一约束的存储（部分 NoSQL、纯 Redis）；
- 消费逻辑包含外部副作用且下游没有幂等能力；
- 要求 exactly-once 的场景。

## 铁律

1. 生产端：业务数据与待发消息写入同一个本地事务（同库、同分片），禁止在业务事务之外直接发消息。本方案只约束“业务写库 + 消息”需一致的消息，不涉及无业务写库的通知类消息。
2. Broker：交换器、队列 durable，消息 persistent；开启 publisher confirm + mandatory，并处理 return。
3. 消费端：先完成业务落库并提交，再 ack；禁止先 ack 后处理；禁止 `requeue=true` 无限重回队列。核心消息使用 Spring `AcknowledgeMode.MANUAL`，监听方法在业务事务提交后显式 `basicAck`，失败时显式 `basicNack`；ack 必须在提交之后，不能把 `@Transactional` 加在监听方法上并在方法体内 ack。
4. 幂等：有业务操作级幂等键时直接建唯一索引，它是最终兜底，去重表可选；没有时，`(consumer_group, message_id)` 去重记录与业务写入同事务提交，去重记录就是最终兜底，不能把它降级为“只是优化”。Redis 只能是更前置的优化。外部副作用仍需下游幂等或对账，去重记录本身不能消除外部重复。
5. 失败：有界退避重试 → 死信落库 → 告警 → 人工/定时重放 → 对账补偿。重试次数放在消息头，不依赖 `x-death`。
6. 所有中间状态可查询，所有终态有清理策略；清理/保留窗口必须大于最大重试窗口与人工重放窗口。

## 先判断，再落地

按顺序确认，不要跳过：

1. 业务有没有能唯一标识同一业务操作的幂等键（如支付流水号，或订单号 + `event_type` / 版本；不能把所有事件都只用订单号判重）？
2. 重复消息占比高不高？单条处理成本大不大？
3. 消费逻辑有没有外部副作用（支付、短信、RPC）？
4. 同一条消息是否会被多个业务或消费组订阅？
5. 是否已经分库分表，或使用非关系型存储？
6. 消费结果是否需要被查询/回放，或依赖消息顺序？

按答案选择组合，禁止无脑套用全套：

| 判断结果 | 选择 |
| --- | --- |
| 有业务操作级幂等键 | 业务唯一索引；去重表可选，作为前置优化 |
| 无业务操作级幂等键 | 同事务 `(consumer_group, message_id)` 去重记录作为最终兜底；合成幂等键可选 |
| 重复率高 / 单条处理昂贵 | 增加 Redis 前置过滤（PROCESSING/DONE + 租约），DB 唯一键兜底 |
| 有外部副作用 | `PROCESSING → SUCCESS/FAILED` 状态机 + 下游幂等 + 对账；下游无幂等能力则不适用 |
| 多个消费组订阅 | 去重键必须带 `consumer_group`；若多个组必须共享同一业务效果，去重表不能跨组兜底，改用业务唯一键 |
| 分库分表 / 非关系型存储 | Outbox 同库同事务不成立，另行设计（按分片本地消息表、CDC，或改用支持事务消息的 MQ） |
| 需要结果回放 | 业务侧保存响应摘要/结果引用，或存在去重记录中；命中后直接返回；纯 MQ 消费通常不需要 |
| 严格顺序 | 本方案不适用，改用单队列单消费者或分区有序方案 |

## 分层实施清单

### 生产端（Outbox）

- 在业务库建 `mq_outbox`，与业务表同事务写入 `PENDING`；字段全集见 `outbox.md`。
- 业务事件唯一：为 `(biz_type, biz_key, event_type)` 建唯一索引，或使用调用方传入的幂等键；重复创建时返回已有记录。同一业务对象会产生多次同类事件时，`biz_key` 需带事件序号/版本。不要只靠随机生成的 `message_id` 去重，否则每次重试都会生成新消息。
- 定时任务扫描待发消息，用条件更新 `PENDING → SENDING` 抢占，同时递增 `publish_attempt`、写入 `lease_until` 并提交；多实例不能只靠 JVM 锁。
- 发布时把 `message_id` 写入 AMQP `messageId`，把 `publish_attempt` 放入消息头并传给 `CorrelationData`。
- confirm 回调按 `message_id + publish_attempt` 条件更新：成功置 `SENT`；nack 记录错误、计算 `next_retry_time` 并回到可重试状态；迟到回调不得覆盖新尝试。
- 确认超时回收为 `PENDING`（结果是未知，不是失败）；超过上限置 `FAILED` 并告警，保留 payload 与路由，支持补偿任务或人工重放。
- 扫描间隔是投递延迟的下限。低延迟场景可在事务提交后主动触发一次投递，定时扫描只做兜底；引入 CDC（如 Debezium）可进一步降低延迟，但会增加组件与运维成本，不作为默认。

### Broker

- 交换器、队列 durable，消息 persistent；需要抗 Broker 单节点故障时使用 quorum queue（需多节点集群），单机 durable 只防进程重启。
- 重试延迟队列与主队列同等级：原消息 ack 后，重试副本是唯一副本；要求抗单节点故障时延迟队列也用 quorum，避免节点故障丢失重试消息。
- 开启 publisher confirm 与 mandatory，处理不可路由消息；return 之后仍可能收到 ack，不能只等 ack。
- 核心消息使用 `MANUAL`：监听方法在业务事务提交后显式 `basicAck`，失败时显式 `basicNack`。`AUTO` 只用于可丢失或非核心的简单场景，以及 `version-diff.md` 规定的 Spring AMQP 2.0～2.1.8 fatal 异常兼容方案；核心消息禁止 `NONE`。
- DLX、DLQ 与绑定必须在业务流量进入前创建；目标不可路由时消息仍会丢失，不能把“有 DLQ”当成绝对不丢。
- `default-requeue-rejected=false` 必须与 DLX、失败记录和告警配套，否则最终失败会被直接丢弃。

### 消费端

- 去重表最低字段：`consumer_group`、`message_id`、`biz_type`、`event_type`、`payload_hash`、`status`、`trace_id`、`create_time`；状态机模式另加 `update_time`、`owner`、`lease_until`。唯一键 `(consumer_group, message_id)`。使用业务唯一索引时，也要能通过已有业务记录或去重记录核对事件类型与内容指纹。
- 单库单事务消费：去重记录与业务写入同事务；去重记录或业务唯一键冲突后，仅当已存在记录与当前消息属于同一业务操作且 `payload_hash` 或等价内容指纹一致时才视为重复成功，`status` 可恒为 `SUCCESS`；不一致时按数据冲突处理，不得 ack 为成功。
- 跨服务、外部副作用、需要结果回放：使用 `PROCESSING → SUCCESS/FAILED` 状态机，并支持租约超时接管。租约不是锁，接管后可能与原执行并发；外部副作用必须由下游幂等或对账兜底，状态机本身不提供跨服务事务。
- `FAILED` 表示本次执行失败，是否可重试由异常分类决定；重试或重放时用 CAS 把 `FAILED` 重置为 `PROCESSING`（或删除记录）再执行；`SUCCESS` 记录不得重置，只有业务操作与内容指纹均一致的重复消息才按成功返回。
- 有业务操作级幂等键时，业务唯一索引是最终兜底；没有时，同事务 `(consumer_group, message_id)` 去重记录就是最终兜底。去重记录必须与业务写入在同一事务提交，不能先提交去重记录、再另起事务写业务，也不能用 Redis 代替。
- 手动 ack 必须在业务事务提交之后执行；不要把 `@Transactional` 加在监听方法上并在方法体内 ack，也不要在事务未提交时先 ack。
- 先提交业务事务，再 `basicAck`。唯一键冲突优先在事务边界外识别，或用 `INSERT ... ON DUPLICATE KEY` / `INSERT IGNORE` + 影响行数判断；随后核对已有记录的事件类型、版本和内容指纹，一致才按重复成功 ack，不一致则回滚并按永久数据冲突 `basicNack(requeue=false)`、告警，不得重试或确认成功。在事务内捕获普通 insert 的冲突异常后继续提交，在 JPA/Hibernate 或部分数据库上会进入 rollback-only/事务中止状态。
- 高重复率或处理昂贵时，可加 Redis 前置过滤：`PROCESSING/DONE` 两态、owner 令牌、Lua CAS、租约接管；Redis 不可用时降级放行，由数据库唯一键（业务唯一键或去重表唯一键）兜底。

### 失败与死信

- 重试次数放在消息头，每次重投前递增，重试保持 `message_id` 不变；不依赖 `x-death`（quorum queue 的 at-least-once dead-lettering 下可能重复计数），`x-death` 只用于诊断。
- 使用 TTL 延迟队列做退避，禁止 `Thread.sleep` 或原地自旋。不同退避级别使用各自的延迟队列（或延迟交换机插件，需评估可用性与持久化/复制语义），不要把 1s/5s/30s/2min 混在同一个队列：per-message TTL 只在队头生效，会队头阻塞。
- 默认总尝试 3 到 5 次，退避 1s、5s、30s、2min 或指数退避；按业务恢复时间调整，不要硬编码。
- 先发布重试消息并等待 publisher confirm，再 ack 原消息；confirm nack/超时/异常，或 confirm ack 但被 mandatory return（不可路由），都按发布失败处理，nack 进死信，宁可重复不可丢失。只调用 `convertAndSend` 不代表发布成功。前提是 DLX 已配置且目标可达，否则 nack 会直接丢弃。默认关闭 Spring Retry，避免本地重试拦截器重复执行监听方法、重复发布重试消息。
- 重试耗尽进死信交换机；死信消费者接收原始消息体，先落库再 ack。告警由独立任务扫描已落库记录并异步重试，告警失败不再 nack 原消息。落库失败时不得 ack，只有在 DLQ 自身已配置并验证可达的备用 DLX/parking queue 后才能 `basicNack(requeue=false)`；没有备用目标时禁止直接 nack，避免最后一份可恢复消息被丢弃。
- 死信表最低字段：`message_id`、`consumer_group`、`origin_queue`、`origin_exchange`、`origin_routing_key`、`payload`、`reason`、`retry_count`、`status`、`alert_status`、`next_alert_time`、`replay_attempt`、`lease_until`、`create_time`、`update_time`、`replay_time`。按 `(consumer_group, message_id)` 建唯一键，同一逻辑消息只保留一条记录并更新重试次数；若需要保留每次死信事件，改用 `(origin_queue, message_id, death_count)`。异步告警任务按 `alert_status`、`next_alert_time` 扫描并更新告警状态。
- 重放前先修复路由、消息格式或下游故障，并确认该消费组的去重记录状态：`SUCCESS` 直接跳过；`FAILED` 用 CAS 重置为 `PROCESSING`；未过期的 `PROCESSING` 租约等待过期或确认原执行已终止，不能强行并发接管。
- 每次实际重放前递增 `replay_attempt`，按 `PENDING → REPLAYING` 做 CAS 占位并写入 `lease_until`，再携带原 `message_id` 和本次 `replay_attempt` 发布；`replay_attempt` 同时放入消息头并传给 `CorrelationData`。confirm/return 仅在记录仍处于 `REPLAYING` 且 `message_id + replay_attempt` 匹配时更新为 `REPLAYED` 或失败状态，超时回收也必须匹配本次代次；旧尝试的迟到回调不得覆盖新尝试。同步发布异常可按同一代次条件回到 `PENDING`，不能同步等待 confirm 后“失败回滚”。重置 `retry_count`，保持 `message_id` 不变，重复重放必须被拒绝。

## 时间参数规则

- 去重标记的保留/TTL 必须大于消息最大重投窗口与人工重放窗口；清理早于重放窗口会导致重放再次产生业务效果。数据库去重记录用保留期 + 清理任务，不要用 Redis TTL 语义硬套。
- outbox 记录保留时间必须大于最大重试窗口，并覆盖审计与补发需要；`SENT` 记录不能立即物理删除。
- 死信记录保留到人工处理完成，不随短期清理任务删除。
- `PROCESSING` 租约必须大于业务最大耗时；租约过期接管必须依赖业务唯一键或下游幂等兜底。
- confirm 超时、扫描间隔、生产重试上限、消费重试上限共同决定从业务成功到最终终态的最长窗口，必须小于业务可接受的人工介入时间。

## 技术栈映射

| 能力 | RabbitMQ | Kafka | RocketMQ |
| --- | --- | --- | --- |
| 发送确认 | publisher confirm | `acks=all` + `enable.idempotence` | 同步发送结果 |
| 手动确认 | `basicAck` / `basicNack` | 手动提交 offset | 返回消费状态 |
| 延迟重试 | TTL 队列 + DLX | 重试 topic | 延迟级别（4.x 固定级别） |
| 死信 | DLX / DLQ | Dead Letter Topic（客户端约定，非 Broker 内建） | `%DLQ%` |

本表只做概念对照：本 skill 的代码、配置与版本差异只覆盖 RabbitMQ + Spring AMQP；Kafka 的幂等生产者只保证单分区、单会话内的重试不重复，不等于端到端幂等；Kafka/RocketMQ 的落地需另建规范。

## 反模式

- 先 ack 后处理，或业务异常也 ack。
- `requeue=true` 无限重投。
- 只用 Redis 去重，不落数据库唯一键。
- 去重键不带消费组，多个业务订阅时互相误判。
- 去重记录与业务写入不在同一事务，或先提交去重记录、再另起事务写业务；崩溃后会出现“去重记录已存在、业务未生效”，重投被当成重复跳过。
- Outbox 与业务表不同库/不同分片/不同事务，或先发消息后写库。
- 只靠随机 `message_id` 做业务事件去重。
- 用同一个 TTL 延迟队列混排不同退避级别。
- 依赖 `x-death` 作为唯一的重试计数。
- 死信重放同步“失败回滚”，忽略 confirm 异步与崩溃窗口。
- 重放时不检查/重置消费组去重记录，导致该重试的被当成重复跳过，或已成功的被重复执行。
- 去重记录清理早于重放窗口。
- 把 `PROCESSING` 租约当锁，接管后并发执行且下游无幂等。
- 在会被本地重试拦截器重复执行的路径里发布重试消息，却不排除该异常或路径。
- 只监控队列长度，不监控 Outbox 年龄、`FAILED` 数量和 DLQ。
- confirm 成功就认为消费成功。
- 重放不重置重试次数，或重放改变 `message_id`。
- 对外宣称 exactly-once。

## 验证清单

落地后至少验证：

1. 同一 `message_id` 投递 N 次，业务只成功一次；
2. 换 `message_id`，以相同业务操作幂等键和相同内容指纹投递，业务只成功一次；业务对象 ID 相同但 `event_type`、版本或内容指纹不同的消息必须判为数据冲突，不得当作重复消息 ack；
3. 业务提交后、ack 前进程崩溃，重投不产生重复数据；
4. confirm 失败或超时，outbox 能重发；多实例同时抢占时同一记录只被一个实例发出；
5. 消费连续失败，达到上限后进入死信并落库；死信落库失败时消息不被 ack，而是进入 DLQ 自身的 parking queue，存储修复后可受控恢复；
6. 死信重放后 `message_id` 不变，重复重放被拒绝；重放在 CAS 占位后、发布前崩溃可被租约回收；第一次重放超时回收并发起第二次重放后，第一次迟到的 Confirm/Return 不得改变第二次重放状态；
7. Redis 不可用时消费仍能依靠数据库唯一键（业务唯一键或去重表唯一键）完成；
8. Return 后迟到 ACK 不会把记录覆盖为 `SENT`；
9. 清理任务不会删除未处理完的死信、未发送的 outbox 和仍在重放窗口内的去重记录。

故障演练与压测指标见 `performance.md`，逐项上线检查见 `checklist.md`。

## 失败矩阵

输出方案时必须给出与下表同维度的矩阵：

| 失败点 | 兜底层 |
| --- | --- |
| 业务提交前崩溃 | 本地事务回滚，无消息，无副作用 |
| Broker 单节点故障 | quorum queue 多数派仍可读写；单机 durable 不覆盖，需监控与恢复 |
| 业务提交后、消息发出前崩溃 | Outbox 扫描重发（同一 `message_id`） |
| 发布 nack / 连接异常 | Outbox 退避重试，超过上限 `FAILED` + 告警 |
| 确认超时 | `SENDING` 租约回收为 `PENDING`，重发 + 消费幂等 |
| 不可路由（return） | 标记路由失败、告警，修复拓扑后重放 |
| 消费业务回滚 | 不 ack；临时异常发布重试，永久异常 `basicNack(requeue=false)` |
| 重试发布失败/超时/return | 不 ack 原消息，`basicNack(requeue=false)` 进死信；重试副本未确认不 ack |
| 业务提交后、ack 前崩溃 | 重投 + 去重记录/业务操作级幂等键 + 内容指纹核对 |
| 重复投递或唯一键冲突 | 业务操作与内容指纹均一致才视为重复成功并 ack；不一致按数据冲突 nack 并告警 |
| 重试耗尽 | DLX → 死信消费者落库 → 基于死信记录异步告警 |
| 死信落库失败 | 不 ack；DLQ 自身备用 DLX → parking queue，存储修复后受控恢复；无备用目标时禁止直接 nack |
| 人工重放 | `replay_attempt` 递增 + CAS 占位 + 租约 + confirm/return 条件更新，保持 `message_id`，旧回调不得覆盖新尝试 |

输出契约（拓扑、表结构、关键改动点、验证步骤、不覆盖风险）见 `SKILL.md`。
