# 编码细则（推荐项）

## 面向对象

- 循环拼接字符串用 StringBuilder。
- 方法顺序：公有方法 → 私有方法 → get/set。
- setter 用 this 赋值。
- 布尔属性不可同时存在 isXxx()、getXxx()。

## 集合操作

- 初始化集合指定容量。
- Map 遍历用 entrySet。
- Set 去重替代 List.contains。

## 并发

- CountDownLatch 确保 countDown 执行。
- 多线程随机数用 ThreadLocalRandom。
- 双重检查锁用 volatile。

## 控制语句

- if-else 层级 ≤ 3，多用卫语句/策略模式。
- 复杂条件提前赋值变量。
- 少用取反判断。
- 高并发场景避免 `==` 中断判断。
