# 上线检查清单

先按消息等级裁剪：标记为“不允许丢失”的检查项只约束这类消息；可丢弃的采样数据应单独记录其故障边界，不能混用同一套结论。

| 检查项 | 要求 | 验证位置 |
| ---- | ---- | ---- |
| 环境凭据 | 生产账号密码无默认值，权限最小化 | `application-prod.yml`、环境变量 |
| 发布确认 | 不允许丢失的消息开启异步 correlated Confirm | `publisher-confirm-type` |
| 路由失败 | 开启 returns/mandatory，Return 更新持久化状态 | RabbitMQ 配置、`ReturnsCallback` |
| Confirm 含义 | 未把 ACK 当作消费者业务成功 | 代码审查 |
| 发送持久化 | 业务与 Outbox 同事务，进程重启后可恢复 | `mq_outbox`、业务事务 |
| 发送状态机 | 覆盖 PENDING/SENDING/SENT/FAILED 和租约回收 | Outbox 实现 |
| 回调竞态 | 按 eventId + publishAttempt 条件更新，Return 不被迟到 ACK 覆盖 | Outbox 条件更新 |
| nack/超时 | 有限重试、退避和抖动，超过上限落 FAILED 并告警 | Outbox 补偿任务 |
| 消息身份 | 重发复用 eventId，AMQP messageId 可追踪 | 发布代码 |
| Exchange/Queue | 不允许丢失的消息显式 durable | `@Configuration` |
| 消息投递模式 | 不允许丢失的消息为 persistent，未被后处理器覆盖 | 发布代码 |
| 节点故障 | 要求抗 Broker 单节点故障时使用 quorum queue，集群满足多数派 | 队列声明、集群配置 |
| 消费 ACK | 业务事务提交后方法才正常返回；核心消息不用 NONE | Listener 与 Service |
| 消费幂等 | 消费记录唯一索引与业务更新同事务，Redis 仅作优化 | 数据库约束、Service |
| 异常分类 | 永久异常不重试，临时异常有限重试，无无限 requeue | Retry 配置、异常处理 |
| 本地重试 | 含上层事务时 stateless=false；长退避不占消费线程 | Listener 配置 |
| 最终失败 | `default-requeue-rejected=false` 且 DLQ、存储和告警已配置 | Listener、DLX |
| DLX 安全 | 核实当前版本默认转发语义；需要时使用受支持的 at-least-once 配置 | RabbitMQ 版本与 Policy |
| 死信处理 | 幂等落库，存储失败不 ACK，修复后受控重放 | 死信消费者 |
| TTL | 仅有时效需求时设置，无固定 TTL 模板 | Queue/Policy |
| 队列容量 | 有长度/字节限制和积压告警；核心队列不使用 drop-head 静默丢弃 | Queue/Policy |
| prefetch | 经过压测，兼顾吞吐、未 ACK 数和内存 | `listener.simple.prefetch` |
| 消费并发 | 与 CPU、连接池、下游容量和顺序要求匹配 | `concurrency`、`max-concurrency` |
| 消息格式 | JSON DTO 精简，不强制 Serializable，信任包范围明确 | MessageConverter |
| 日志 | 不打印消息体；成功 Confirm 不逐条 INFO | 生产日志配置 |
| 指标告警 | 覆盖 Confirm 延迟、Outbox 年龄、ready/unacked、重试和 DLQ | 监控系统 |
| 故障演练 | 覆盖发布前崩溃、Confirm 丢失、ACK 前崩溃、重复投递与重放 | 演练记录 |

任何一项放宽都要写清允许丢失或重复的场景、恢复方式和负责人。不得仅以“提高吞吐量”为理由跳过故障验证。
