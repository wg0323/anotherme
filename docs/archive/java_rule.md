---
trigger: always_on
---
# 1. 命名规范
## 强制
1. 命名首尾禁止下划线/美元符；禁用拼音、中文命名。
2. 大小写规范：
   - 类：UpperCamelCase（DO/BO/DTO/VO/PO/UID后缀大写）
   - 方法/参数/成员/局部变量：lowerCamelCase
   - 常量：全大写下划线分隔 `MAX_STOCK_COUNT`
   - 抽象类Abstract/Base开头；异常类Exception结尾；测试类Test结尾
   - 包名纯小写、单数、单语义单词
3. POJO布尔变量禁止is前缀，避免序列化异常。
## 推荐
1. 接口实现类后缀Impl；枚举后缀Enum、成员全大写。
2. 分层方法命名：
   - 单条get / 多条list+复数 / 统计count
   - 新增save/insert、删除remove/delete、修改update

# 2. 常量定义
## 强制
1. 代码禁止魔法值；long字面量后缀大写L。
## 推荐
1. 按业务分常量类，不统一存放；限定范围值优先enum。

# 3. 代码格式
## 强制
1. 大括号：空写`{}`；左{不换行，右}后else不换行、其余换行。
2. 关键字if/for/while/switch与括号间加空格；运算符两侧空格；左括号紧贴字符。
3. 4空格缩进，禁用tab；//注释后空一格；单行≤120字符换行。
4. 方法参数逗号后空格；文件UTF-8，换行Unix。
## 推荐
单方法≤80行；不同逻辑空行分隔。

# 4. 面向对象
## 强制
1. 静态成员/方法用类名访问，禁止对象调用。
2. 重写方法加@Override；弃用过时API。
3. 常量前置调用equals：`"str".equals(var)`；包装类比较统一equals。
4. POJO属性、RPC出入参用包装类型；局部变量优先基本类型。
5. POJO不设属性默认值；构造方法无业务逻辑；必须重写toString。
6. 布尔属性不可同时存在isXxx()、getXxx()。
## 推荐
循环拼接字符串用StringBuilder；方法顺序：公有→私有→get/set；setter用this赋值。

# 5. 集合操作
## 强制
1. 重写equals必须重写hashCode。
2. subList不可强转ArrayList；foreach禁止add/remove，改用Iterator。
3. 集合转数组使用`toArray(T[])`；Arrays.asList返回集合不可增删。
## 推荐
初始化集合指定容量；Map遍历用entrySet；Set去重替代List.contains。

# 6. 并发规范
## 强制
1. 单例保证线程安全；线程/线程池命名语义化。
2. 统一使用ThreadPoolExecutor创建线程池，禁用Executors。
3. SimpleDateFormat禁止static，改用DateTimeFormatter/ThreadLocal。
4. 优先无锁结构；锁范围最小化；多资源加锁顺序统一防死锁。
## 推荐
CountDownLatch确保countDown执行；多线程随机用ThreadLocalRandom；双重检查锁用volatile。

# 7. 控制语句
## 强制
1. switch每个case必须break/return或注释穿透，必须加default。
2. if/for/while/do单行也必须带大括号；高并发避免==中断判断。
## 推荐
if-else层级≤3，多用卫语句/策略模式；复杂条件提前赋值变量；少用取反判断。

# 8. 注释规范
## 强制
1. 类/属性/方法使用Javadoc `/** */`；抽象方法完整注释。
2. 所有类标注创建人+日期；枚举字段加注释；单行//注释放代码上方。
## 推荐
中文注释，专有名词英文；改代码同步更新注释；TODO/FIXME标注人+时间。

# 9. 通用最佳实践
## 强制
1. 正则预编译Pattern.compile，不写在方法内。
2. 页面变量使用`$!{var}`防止null空白；取毫秒用System.currentTimeMillis()。
## 推荐
及时清理废弃代码/配置；容器初始化指定容量。

# 执行规则
1. 生成代码自动遵守全部规范。
2. 代码违反强制规范时，先指出问题，再输出修正代码。
3. 代码简洁可读，遵循DRY；多层if-else改用策略/工厂等设计模式。