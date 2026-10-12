# 编码细则（推荐项）

主文件「强制规范」之外的推荐项细则，按主题分节。

## 命名、常量与格式

### 命名

- 接口实现类后缀 Impl；枚举后缀 Enum、成员全大写。
- 分层方法命名：
  - 单条 get / 多条 list+复数 / 统计 count
  - 新增 save/insert、删除 remove/delete、修改 update

### 常量定义

- 按业务分常量类，不统一存放。
- 限定范围值优先 enum。

### 代码格式

- 单方法 ≤ 80 行。
- 不同逻辑空行分隔。

## 面向对象与集合

- 循环拼接字符串用 StringBuilder。
- 方法顺序：公有方法 → 私有方法 → get/set。
- setter 用 this 赋值。
- 布尔属性不可同时存在 isXxx()、getXxx()。
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

## 注释规范

### 强制

1. 类/属性/方法使用 Javadoc `/** */`；抽象方法完整注释。
2. 所有类标注创建人 + 日期；枚举字段加注释；单行 `//` 注释放代码上方。

### 推荐

- 中文注释，专有名词英文。
- 改代码同步更新注释。
- TODO/FIXME 标注人 + 时间。

## 通用最佳实践

### 强制

1. 正则预编译 `Pattern.compile`，不写在方法内。
2. 页面变量使用 `$!{var}` 防止 null 空白；取毫秒用 `System.currentTimeMillis()`。

### 推荐

- 及时清理废弃代码/配置。
- 容器初始化指定容量。
