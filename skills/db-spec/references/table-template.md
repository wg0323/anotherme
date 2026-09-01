# 标准建表 DDL 模板

逐条落实建表规约的可直接套用模板（字段按业务增删）：

```sql
-- 表名：业务名称_表的作用，单数形式，不用保留字
CREATE TABLE `trade_order` (
  -- 表必备三字段之一：主键
  `id`           bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  -- 业务唯一字段 -> 建唯一索引
  `order_no`     varchar(32)     NOT NULL COMMENT '订单号',
  `user_id`      bigint unsigned NOT NULL COMMENT '下单用户ID',
  -- 金额禁用 float/double，必须 decimal
  `total_amount` decimal(12,2)   NOT NULL DEFAULT 0.00 COMMENT '订单总金额',
  `status`       tinyint unsigned NOT NULL DEFAULT 0 COMMENT '订单状态：0-待支付，1-已支付，2-已取消',
  -- 是否概念字段：is_xxx + unsigned tinyint（1是/0否）
  `is_deleted`   tinyint unsigned NOT NULL DEFAULT 0 COMMENT '是否删除：0-否，1-是',
  -- 表必备三字段：创建/修改时间
  `create_time`  datetime        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`  datetime        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  PRIMARY KEY (`id`),
  -- 唯一索引：uk_字段名
  UNIQUE KEY `uk_order_no` (`order_no`),
  -- 普通索引：idx_字段名；单表索引不超过 5 个
  KEY `idx_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='交易订单表';
```

## 与 ORM 侧的配套约束

- POJO 布尔变量不加 `is` 前缀（如 `deleted`），数据库字段保持 `is_deleted`，通过 `resultMap` 显式映射。
- 更新记录时必须同时更新修改时间字段（`update_time` 或 `gmt_modified`）为当前时间。
- 查询字段明确列出，禁止 `SELECT *`。
