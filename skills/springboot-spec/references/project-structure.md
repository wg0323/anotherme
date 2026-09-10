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
