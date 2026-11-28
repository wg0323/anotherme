# 工程结构与类命名

## 工程根目录布局

单个 SpringBoot 工程根目录按「人读的说明 vs 机器执行的资产」划分：

```text
project-root/
├── src/         # 源码：Java + resources，唯一可编译来源
├── db/          # 数据库可执行资产：schema.sql、初始化/迁移脚本，被 mysql 执行
├── docs/        # 给人读的说明性文档（组织规则见 doc-writing 技能 references/docs-structure.md）
├── .vscode/     # IDE 配置：settings.json / launch.json
├── pom.xml      # Maven 构建配置
└── target/      # 构建产物，已被 .gitignore 忽略
```

边界：

- `db/schema.sql` 是要被 mysql 执行的**资产**，留在 `db/`，不进 docs；对应的设计说明文档才进 docs。
- 源码、可执行脚本、IDE 配置、构建配置、构建产物一律不进 docs。
- docs/ 内部如何分类、建目录门槛，遵循 `doc-writing` 技能（唯一真相源）。

## 包结构：先模块、后分层（强制）

`src/main/java/{basePackage}` 下先按业务域建模块包，模块包内再按职责分层。模块名与分层包名同规则：小写、单数、单语义英语单词；禁止把分层包提到根包让所有模块共用一套 `controller`/`service`，也禁止拿技术分层充当模块名。与存量项目按层平铺的包结构冲突时，以本节结构为准，新代码不得继续沿用扁平包。

```text
src/main/java/{basePackage}/
├── {ProjectName}Application.java              # 启动类直接位于根包
├── {module}/                                  # 业务模块：一个业务域一个包，如 user、order、payment
│   ├── controller/{Entity}Controller.java
│   ├── service/{Entity}Service.java
│   ├── service/impl/{Entity}ServiceImpl.java
│   ├── mapper/{Entity}Mapper.java
│   ├── entity/{Entity}.java
│   ├── dto/
│   ├── vo/
│   ├── converter/                             # 按 SB-2 条件创建
│   └── constant/  enums/  exception/  utils/  # 仅放只服务本模块的类
├── config/                                    # 全局：跨模块共享
└── constant/  enums/  exception/  utils/      # 全局：跨模块共享
```

放置判据：

- 按使用方归属：只被一个模块使用 → 放该模块子包；被 ≥2 个模块或框架层使用 → 放根包全局子包。
- 即使子包只有一个类，也保留完整分包路径；禁止把类直接放在模块包根下，也禁止把常量、枚举、异常塞进使用它的 `controller`/`service` 包。
- 模块按业务域划分，不按技术分层划分。

模块内子包职责（固定分层）：

| 子包           | 职责                              | 命名示例                         |
| -------------- | --------------------------------- | -------------------------------- |
| `controller`   | HTTP 请求路由、参数绑定、响应封装 | `UserController`                 |
| `service`      | 业务服务接口                      | `UserService`                    |
| `service.impl` | 业务服务实现                      | `UserServiceImpl`                |
| `mapper`       | MyBatis Mapper 接口               | `UserMapper`                     |
| `entity`       | 数据库实体映射                    | `User`                           |
| `dto`          | 接收请求参数                      | `UserCreateDTO`, `UserUpdateDTO` |
| `vo`           | 响应数据封装                      | `UserVO`, `UserDetailVO`         |
| `converter`    | 对象转换（按需创建）              | `UserConverter`                  |

根包全局子包（跨模块共享）：

| 子包        | 职责         | 命名示例                                    |
| ----------- | ------------ | ------------------------------------------- |
| `config`    | 配置类       | `WebConfig`, `SwaggerConfig`                |
| `constant`  | 跨模块常量   | `CommonConstant`                            |
| `enums`     | 跨模块枚举   | `YesNoEnum`                                 |
| `exception` | 全局异常     | `BusinessException`                         |
| `utils`     | 跨模块工具类 | `StringUtils`、`DateUtils`、`SecurityUtils` |

## 对象转换分档（强制）

转换落点由「复用次数」和「是否存在非等价映射」决定，与 VO 的数量无关。判定顺序固定：先判 A 档，不成立再看 B 档。

| 档 | 判定条件（全部满足才成立） | 落点 |
| --- | --- | --- |
| A 就地一行 | 只在一处调用；源与目标同名属性类型完全一致；无脱敏、无码值翻译、无嵌套转换 | 调用处 `BeanUtils.copyProperties(source, target)` |
| B 抽 Converter | 任一成立：同一转换 ≥2 处调用；被 `list.stream().map()` 引用；存在非等价映射 | `converter` 包的 `XxxConverter` 静态方法 |

### A 档正例

```java
// user/service/impl/UserServiceImpl.java
UserVO vo = new UserVO();
BeanUtils.copyProperties(user, vo);   // org.springframework.beans.BeanUtils，Spring 自带
return vo;
```

目标对象必须有 setter（Lombok `@Data` / `@Setter`）。`@Builder`、`@Value`、record 没有 setter，`copyProperties` 不报错但目标全空，这类 VO 直接走 B 档。

### B 档正例

```java
// user/converter/UserConverter.java
public final class UserConverter {

    private UserConverter() {
    }

    public static UserVO toVO(User user) {
        if (user == null) {
            return null;
        }
        UserVO vo = new UserVO();
        BeanUtils.copyProperties(user, vo);      // 同名同类型字段先整体拷贝
        vo.setNickname(user.getUserName());      // 字段名不同，显式映射
        // 枚举 -> 展示文本
        vo.setStatusDesc(user.getStatus() == null ? null : user.getStatus().getDesc());
        return vo;
    }

    public static List<UserVO> toVOList(List<User> users) {
        return users.stream().map(UserConverter::toVO).collect(Collectors.toList());
    }
}
```

### 反例（禁止）

```java
// 违规一：连续逐字段 set。改一个字段要跟着改八行，字段改名时靠肉眼比对
UserVO vo = new UserVO();
vo.setId(user.getId());
vo.setName(user.getName());
vo.setEmail(user.getEmail());

// 违规二：集合用 for 循环逐条 new + set
List<UserVO> voList = new ArrayList<>();
for (User user : users) {
    UserVO vo = new UserVO();
    BeanUtils.copyProperties(user, vo);
    voList.add(vo);
}
```

### 静默区

字段名相同但类型不同（`Date` ↔ `LocalDateTime`、枚举 ↔ 整型、`Long` ↔ `String`）是 `copyProperties` 的静默区：不抛异常、不打日志，目标字段留空。存在这类字段时，不论调用几处，都必须显式 `set` 覆盖，并逐字段核对 VO 有值。

## Service 分层正反例（强制）

所有业务 Service 一律「接口 + 实现」：接口在所属模块的 `service` 包，实现在该模块的 `service.impl` 包，`@Service` 只标注实现类。Controller 与跨 Service 调用只依赖接口。

### entity 绑定型（MyBatis-Plus 官方风格）

下面两个 `extends` 都是强制项：只做到分包 + `implements` 接口不算合规。

```java
// user/service/UserService.java
public interface UserService extends IService<User> {

    Long create(UserCreateDTO dto);
}

// user/service/impl/UserServiceImpl.java
@Service
@RequiredArgsConstructor
public class UserServiceImpl extends ServiceImpl<UserMapper, User> implements UserService {

    @Override
    public Long create(UserCreateDTO dto) {
        User entity = new User();
        // DTO -> Entity
        save(entity);
        return entity.getId();
    }
}
```

### 业务编排型（不绑定 entity）

此档反向禁止继承 `IService`/`ServiceImpl`，否则会凭空多出 `save`/`getById` 等与 Entity 无关的方法。

```java
// order/service/OrderCommandService.java
public interface OrderCommandService {

    void submit(OrderSubmitDTO dto);
}

// order/service/impl/OrderCommandServiceImpl.java
@Service
@RequiredArgsConstructor
public class OrderCommandServiceImpl implements OrderCommandService {

    private final OrderMapper orderMapper;
    private final InventoryService inventoryService;

    @Override
    public void submit(OrderSubmitDTO dto) {
        // 跨 Mapper / 跨 Service 编排
    }
}
```

### 反例（以下写法禁止）

```java
// 违规一：无接口，实现类直接占用服务名
@Service
public class UserService { }

// 违规二：接口名被实现类占用，接口无法按 {实体名}Service 命名
@Service
public class UserServiceImpl { }

// 违规三：上层注入实现类而非接口
private final UserServiceImpl userService;

// 违规四：entity 绑定型降级为「纯接口 + 注入 Mapper」，丢失 MP 通用 CRUD 能力
public interface UserService { }

@Service
@RequiredArgsConstructor
public class UserServiceImpl implements UserService {

    private final UserMapper userMapper;   // 应为 extends ServiceImpl<UserMapper, User>
}

// 违规五：只继承 ServiceImpl 而不实现自定义接口，接口层被架空
@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, User> { }
```

判断口径：`service` 包内每个类型都必须是接口；`service.impl` 包内的类必须 `implements` 对应接口；跨层引用一律面向接口。绑定 Entity 的 Service 还必须同时满足「接口 `extends IService<{Entity}>` + 实现 `extends ServiceImpl<{Entity}Mapper, {Entity}>`」，缺一即不合规；无绑定 Entity 的业务编排型 Service 反向禁止继承 `IService`/`ServiceImpl`。

## 类命名规范

### 通用规则

- **强制**：类名使用 `UpperCamelCase` 风格。
- **强制**：DTO/VO/BO 等后缀保持大写。
- **说明**：Entity 不加后缀（不使用 DO 等后缀），直接使用业务名称。

### 各层类命名

| 类型         | 命名规则              | 示例                                         |
| ------------ | --------------------- | -------------------------------------------- |
| Controller   | `{实体名}Controller`  | `UserController`                             |
| Service 接口 | `{实体名}Service`     | `UserService`                                |
| Service 实现 | `{实体名}ServiceImpl` | `UserServiceImpl`                            |
| Mapper       | `{实体名}Mapper`      | `UserMapper`                                 |
| Entity       | `{实体名}`            | `User`                                       |
| DTO          | `{实体名}{操作}DTO`   | `UserCreateDTO`, `UserQueryDTO`              |
| VO           | `{实体名}{场景}VO`    | `UserVO`, `UserDetailVO`                     |
| Converter    | `{实体名}Converter`   | `UserConverter`（满足抽类条件才建）          |
| Config       | `{功能}Config`        | `WebConfig`, `RedisConfig`                   |
| Constant     | `{模块}Constant`      | `UserConstant`；位于 `constant` 包下的常量类可省略 Constant 后缀，如 `OrderStatus` |
| Enum         | `{功能}Enum`          | `UserStatusEnum`, `OrderStatusEnum`          |
| Exception    | `{业务}Exception`     | `BusinessException`, `UserNotFoundException` |
| Utils        | `{功能}Utils`         | `DateUtils`, `StringUtils`                   |
