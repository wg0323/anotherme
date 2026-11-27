# 上线检查清单

先按消息等级裁剪：标记为“不允许丢失”的检查项只约束这类消息；可丢弃的采样数据应单独记录其故障边界，不能混用同一套结论。

| 检查项 | 要求 | 验证位置 |
| ---- | ---- | ---- |
| 环境凭据 | 生产账号密码无默认值，权限最小化 | `application-prod.yml`、环境变量 |
| 版本档位 | 配置键与回调 API 匹配 pom 的 Boot 档位，无跨档写法 | `pom.xml`、`version-diff.md` |
| 发布确认 | 不允许丢失的消息开启异步 correlated Confirm（2.0/2.1 为 `publisher-confirms`） | `publisher-confirm-type` |
| 路由失败 | 开启 returns/mandatory，Return 更新持久化状态 | RabbitMQ 配置、`ReturnsCallback`（2.2 及以前为五参 `ReturnCallback`） |
| Confirm 含义 | 未把 ACK 当作消费者业务成功 | 代码审查 |
| 发送持久化 | 业务与 Outbox 同事务，进程重启后可恢复 | `mq_outbox`、业务事务 |
| 发送状态机 | 覆盖 PENDING/SENDING/SENT/FAILED 和租约回收 | Outbox 实现 |
| 回调竞态 | 按 message_id + publish_attempt 条件更新，Return 不被迟到 ACK 覆盖 | Outbox 条件更新 |
| nack/超时 | 有限重试、退避和抖动，超过上限落 FAILED 并告警 | Outbox 补偿任务 |
| 消息身份 | 重发复用 message_id，AMQP messageId 可追踪 | 发布代码 |
| Exchange/Queue | 不允许丢失的消息显式 durable | `@Configuration` |
| 消息投递模式 | 不允许丢失的消息为 persistent，未被后处理器覆盖 | 发布代码 |
| 节点故障 | 要求抗 Broker 单节点故障时主队列与重试延迟队列都使用 quorum queue，集群满足多数派 | 队列声明、集群配置 |
| 消费 ACK | 核心消息 MANUAL；ack 在业务事务提交后显式执行，每条消息都有 ack/nack；Spring AMQP 2.0～2.1.8 按版本边界选择 AUTO 或自定义 fatal 拒绝处理；禁止 NONE | Listener、Service、`version-diff.md` |
| 消费幂等 | 有业务操作级幂等键用业务唯一索引；没有时同事务去重记录就是最终兜底；唯一键冲突须核对事件类型与内容指纹，不一致不得按重复成功 ACK；Redis 仅作优化 | 数据库约束、Service、冲突用例 |
| 异常分类 | 业务永久异常 `basicNack(requeue=false)`，临时异常有限重试，无无限 requeue；转换等 fatal 异常由容器错误处理器处理，MANUAL 已核对 Spring AMQP 2.1.9 版本边界 | Listener、ErrorHandler、`version-diff.md` |
| 重试链路 | 默认关闭 Spring Retry；重试发布等待 confirm 且无 return 后再 ack 原消息；重试次数在消息头，message_id 不变 | Listener、Retry 配置 |
| 最终失败 | 手动 `basicNack(requeue=false)` 或 `default-requeue-rejected=false`，且 DLQ、存储和告警已配置 | Listener、DLX |
| DLX 安全 | 核实当前版本默认转发语义；需要时使用受支持的 at-least-once 配置 | RabbitMQ 版本与 Policy |
| 死信处理 | 先幂等落库再 ACK；告警基于死信记录异步重试；落库失败不 ACK，且 DLQ 自身备用 DLX/parking queue 已声明并验证可达 | 死信消费者、告警任务、备用拓扑 |
| 死信重放 | CAS 占位 + 租约 + confirm；每次重放递增 replay_attempt，回调按 message_id + replay_attempt 条件更新，迟到回调不得覆盖新尝试；message_id 不变，重复重放拒绝；重放前检查消费组去重状态 | 重放任务、回调与故障演练 |
| TTL | 仅有时效需求时设置，无固定 TTL 模板 | Queue/Policy |
| 队列容量 | 有长度/字节限制和积压告警；核心队列不使用 drop-head 静默丢弃 | Queue/Policy |
| prefetch | 经过压测，兼顾吞吐、未 ACK 数和内存 | `listener.simple.prefetch` |
| 消费并发 | 与 CPU、连接池、下游容量和顺序要求匹配 | `concurrency`、`max-concurrency` |
| 消息格式 | JSON DTO 精简，不强制 Serializable，信任包范围明确 | MessageConverter |
| 日志 | 不打印消息体；成功 Confirm 不逐条 INFO | 生产日志配置 |
| 指标告警 | 覆盖 Confirm 延迟、Outbox 年龄、ready/unacked、重试和 DLQ | 监控系统 |
| 故障演练 | 覆盖发布前崩溃、Confirm 丢失、手动 ack 前崩溃、重复投递、同业务键不同内容冲突、非法消息体转换失败、死信落库失败进入 parking queue、重放租约回收后的旧 Confirm/Return | 演练记录 |

任何一项放宽都要写清允许丢失或重复的场景、恢复方式和负责人。不得仅以“提高吞吐量”为理由跳过故障验证。
