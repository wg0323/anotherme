> **已归档**：历史 rule，内容已迁移至 springboot-spec 技能，不再作为 IDE 规则加载（trigger frontmatter 已移除）。

# 1. 工程结构

## 1.1 包命名规范

- **强制**：包名统一使用小写，点分隔符之间有且仅有一个自然语义的英语单词。
- **强制**：包名使用单数形式，禁止使用复数 (e.g., `user` 而非 `users`)。
- **说明**：entity 包下实体类对应的 Service（如 DeviceService、AlarmEventService）使用官方默认推荐：Service 接口继承 IService<T>，ServiceImpl 继承 ServiceImpl<Mapper, T>，通过 baseMapper 访问 Mapper。
- **说明**：非 entity 对应的业务编排 Service（如 CommandService）使用纯接口风格，不继承 IService，通过构造器注入依赖。

## 1.2 包职责说明

| 包名           | 职责                              | 命名示例                                    |
| -------------- | --------------------------------- | ------------------------------------------- |
| `controller`   | HTTP 请求路由、参数绑定、响应封装 | `UserController`                            |
| `service`      | 业务服务接口                      | `UserService`                               |
| `service.impl` | 业务服务实现                      | `UserServiceImpl`                           |
| `mapper`       | MyBatis Mapper 接口               | `UserMapper`                                |
| `entity`       | 数据库实体映射                    | `User`                                      |
| `dto`          | 接收请求参数                      | `UserCreateDTO`, `UserUpdateDTO`            |
| `vo`           | 响应数据封装                      | `UserVO`, `UserDetailVO`                    |
| `converter`    | DTO/Entity/VO 对象转换            | `UserConverter`                             |
| `config`       | 配置类                            | `WebConfig`, `SwaggerConfig`                |
| `constant`     | 常量定义                          | `UserConstant`                              |
| `enums`        | 枚举类                            | `UserStatusEnum`                            |
| `exception`    | 异常类                            | `BusinessException`                         |
| `utils`        | 工具类                            | `StringUtils`、`DateUtils`、`SecurityUtils` |

## 1.3 类命名规范

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
| Converter    | `{实体名}Converter`   | `UserConverter`                              |
| Config       | `{功能}Config`        | `WebConfig`, `RedisConfig`                   |
| Constant     | `{模块}Constant`      | `UserConstant`；位于 `constant` 包下的常量类可省略 Constant 后缀，如 `OrderStatus` |
| Enum         | `{功能}Enum`          | `UserStatusEnum`, `OrderStatusEnum`          |
| Exception    | `{业务}Exception`     | `BusinessException`, `UserNotFoundException` |
| Utils        | `{功能}Utils`         | `DateUtils`, `StringUtils`                   |

# 2. API 设计

## 2.1 RESTful 规范

### URL 设计原则

- **强制**：URL 中使用名词表示资源，使用复数形式。
- **强制**：URL 中禁止包含动词，动作通过 HTTP 方法表达。
- **强制**：URL 中使用小写字母，单词间用连字符 `-` 分隔。

## 2.2 HTTP 方法使用

| HTTP 方法 | 操作类型     | 幂等性 | 示例              |
| --------- | ------------ | ------ | ----------------- |
| `GET`     | 查询资源     | 是     | 获取用户列表/详情 |
| `POST`    | 创建资源     | 否     | 新建用户          |
| `PUT`     | 全量更新资源 | 是     | 更新用户全部信息  |
| `PATCH`   | 部分更新资源 | 是     | 更新用户状态      |
| `DELETE`  | 删除资源     | 是     | 删除用户          |

## 2.3 HTTP 状态码规范

| 状态码                      | 含义       | 使用场景                               |
| --------------------------- | ---------- | -------------------------------------- |
| `200 OK`                    | 成功       | GET/PUT/PATCH/DELETE 成功              |
| `201 Created`               | 创建成功   | POST 创建资源成功                      |
| `204 No Content`            | 无内容     | DELETE 成功或 PUT 更新成功无需返回数据 |
| `400 Bad Request`           | 请求错误   | 参数校验失败、格式错误                 |
| `401 Unauthorized`          | 未认证     | 未登录或 Token 无效                    |
| `403 Forbidden`             | 禁止访问   | 无权限访问该资源                       |
| `404 Not Found`             | 资源不存在 | 资源不存在                             |
| `409 Conflict`              | 冲突       | 资源已存在、版本冲突                   |
| `422 Unprocessable Entity`  | 无法处理   | 业务规则校验失败                       |
| `500 Internal Server Error` | 服务器错误 | 系统内部异常                           |

# 3. 代码质量

## 3.1 依赖注入

- **强制**：必须使用构造函数注入 (Constructor Injection)。
- **禁止**：字段注入 (`@Autowired` on fields) 或 Setter 注入。
- **实现**：推荐使用 Lombok 的 `@RequiredArgsConstructor` 自动生成构造函数。
- **不可变性**：所有依赖字段必须声明为 `private final`。

## 3.2 数据模型与 DTO

- **强制**：API 层必须使用 **DTO** 进行数据传输，严禁直接暴露 Entity。
- **强制**：不同场景使用不同的 DTO/VO 对象。
- **推荐**：使用 MapStruct 或自定义 Converter 进行对象转换。

## 3.3 控制器规范

- **职责**：Controller 仅负责 HTTP 请求路由、参数绑定、响应封装。
- **禁止**：Controller 中严禁包含任何业务逻辑。
- **规范**：使用 `@RestController` 和 `@RequestMapping` 注解。

## 3.4 日志记录

- **框架**：必须使用 SLF4J，推荐 Lombok `@Slf4j`。
- **强制**：禁止字符串拼接日志消息，必须使用占位符 `{}`。
- **强制**：记录异常时必须将异常对象作为最后一个参数传入。
- **规范**：生产环境禁止使用 `System.out` 或 `e.printStackTrace()`。

## 3.5 异常处理

- **强制**：统一使用 `@ControllerAdvice` 进行全局异常处理。
- **强制**：自定义业务异常继承 `RuntimeException`。
- **规范**：异常信息不暴露系统内部细节。

## 3.6 数据安全

- **强制**：所有外部输入必须进行校验。
- **强制**：敏感数据（密码、身份证等）禁止明文存储。
- **强制**：敏感信息禁止输出到日志。
- **强制**：SQL 查询必须使用参数绑定，禁止字符串拼接。
- **推荐**：使用 Spring Security 进行权限控制。

# 4. 单元测试

## 4.1 测试命名规范

- **强制**：测试类以 `Test` 结尾。
- **强制**：测试方法使用 `should_{预期结果}_when_{条件}` 或 `test_{方法名}_{场景}` 格式。
- **强制**：测试类与被测试类包结构一致。

```
src/main/java/com/example/user/service/impl/UserServiceImpl.java
src/test/java/com/example/user/service/impl/UserServiceImplTest.java
```

## 4.2 测试覆盖要求

- **强制**：核心业务逻辑代码覆盖率不低于 **80%**。
- **强制**：以下场景必须编写单元测试：
  - 复杂的业务逻辑。
  - 金额计算、状态流转。
  - 边界条件、异常分支。
  - 公共工具类方法。