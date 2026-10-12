---
name: java-spec
description: |
  Java 编码规范。只要编写、修改、重构或审查 Java 代码，就必须使用本技能：
  涵盖命名、常量、代码格式、面向对象、集合、并发、控制语句、注释等强制规范。
  同时包含 VSCode 中 Java Maven 项目的首次初始化配置要求。
---

# Java 编码规范

## 强制规范（高频核心）

### 命名

1. 命名首尾禁止下划线/美元符；禁用拼音、中文命名。
2. 大小写规范：类 UpperCamelCase（DO/BO/DTO/VO/PO/UID 后缀大写）；方法/参数/成员/局部变量 lowerCamelCase；常量全大写下划线分隔 `MAX_STOCK_COUNT`。
3. 抽象类 Abstract/Base 开头；异常类 Exception 结尾；测试类 Test 结尾；包名纯小写、单数、单语义单词。
4. POJO 布尔变量禁止 is 前缀，避免序列化异常。

### 常量与格式

5. 代码禁止魔法值；long 字面量后缀大写 L。
6. 大括号：空写 `{}`；左 `{` 不换行，右 `}` 后 else 不换行、其余换行。
7. 4 空格缩进，禁用 tab；单行 ≤ 120 字符；`//` 注释后空一格；文件 UTF-8，换行 Unix。
8. 关键字 if/for/while/switch 与括号间加空格；运算符两侧空格；方法参数逗号后空格。

### 面向对象与集合

9. 静态成员/方法用类名访问，禁止对象调用；重写方法加 `@Override`；弃用过时 API。
10. 常量前置调用 equals：`"str".equals(var)`；包装类比较统一 equals。
11. POJO 属性、RPC 出入参用包装类型；局部变量优先基本类型；POJO 不设属性默认值；构造方法无业务逻辑；必须重写 toString。
12. 重写 equals 必须重写 hashCode；subList 不可强转 ArrayList；foreach 禁止 add/remove，改用 Iterator；集合转数组用 `toArray(T[])`；Arrays.asList 返回集合不可增删。

### 并发

13. 统一使用 `ThreadPoolExecutor` 创建线程池，禁用 `Executors`；线程/线程池命名语义化；单例保证线程安全。
14. `SimpleDateFormat` 禁止 static，改用 `DateTimeFormatter`/`ThreadLocal`。
15. 优先无锁结构；锁范围最小化；多资源加锁顺序统一防死锁。

### 控制语句与性能

16. switch 每个 case 必须 break/return 或注释穿透，必须加 default。
17. if/for/while/do 单行也必须带大括号。
18. 正则预编译 `Pattern.compile`，不写在方法内；取毫秒用 `System.currentTimeMillis()`。

## 执行规则

1. 生成代码自动遵守全部规范。
2. 代码违反强制规范时，先指出问题，再输出修正代码。
3. 代码简洁可读，遵循 DRY；多层 if-else 改用卫语句/策略/工厂等设计模式。

## 详细规范（按场景读取）

| 场景 | 参考文件 |
| ---- | -------- |
| 面向对象/集合/并发/控制语句/注释的推荐项细则，命名、常量、格式的推荐项 | `references/coding-details.md` |
| VSCode 中 Java Maven 项目初始化配置 | `references/vscode-setup.md` |
