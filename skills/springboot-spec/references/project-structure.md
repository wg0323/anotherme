# 工程结构与类命名

## 包职责说明

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
| Converter    | `{实体名}Converter`   | `UserConverter`                              |
| Config       | `{功能}Config`        | `WebConfig`, `RedisConfig`                   |
| Constant     | `{模块}Constant`      | `UserConstant`；位于 `constant` 包下的常量类可省略 Constant 后缀，如 `OrderStatus` |
| Enum         | `{功能}Enum`          | `UserStatusEnum`, `OrderStatusEnum`          |
| Exception    | `{业务}Exception`     | `BusinessException`, `UserNotFoundException` |
| Utils        | `{功能}Utils`         | `DateUtils`, `StringUtils`                   |
