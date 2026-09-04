---
name: springboot-spec
description: |
  SpringBoot 后端工程规范。当用户涉及以下场景时必须使用本技能：
  新建 SpringBoot 工程或模块、划分包结构、编写 Controller/Service/Mapper、
  设计 RESTful API、生成 API 接口文档（Knife4j/Swagger/OpenAPI3）、依赖注入、日志输出与 Logback 配置、异常处理、数据安全、编写单元测试。
  适用于 SpringBoot + MyBatis/MyBatis-Plus 技术栈的 Java 后端开发。
---

# SpringBoot 工程规范

## 核心铁律

1. 依赖注入必须使用构造函数注入，依赖字段声明为 `private final`（推荐 Lombok `@RequiredArgsConstructor`）；禁止字段注入（`@Autowired` 打在字段上）与 Setter 注入。
2. API 层必须使用 DTO 进行数据传输，严禁直接暴露 Entity；不同场景使用不同的 DTO/VO 对象；对象转换推荐 MapStruct 或自定义 Converter。
3. Controller 仅负责 HTTP 请求路由、参数绑定、响应封装，严禁包含任何业务逻辑；使用 `@RestController` + `@RequestMapping`。
4. 日志必须使用 SLF4J（推荐 `@Slf4j`），占位符 `{}` 拼接，异常对象作为最后一个参数传入；禁止字符串拼接日志、`System.out`、`e.printStackTrace()`。
5. 统一使用 `@ControllerAdvice` 全局异常处理；自定义业务异常继承 `RuntimeException`；异常信息不暴露系统内部细节。
6. 所有外部输入必须校验；敏感数据（密码、身份证等）禁止明文存储、禁止输出到日志；SQL 必须参数绑定，禁止字符串拼接；权限控制推荐 Spring Security。
7. 包名小写、点分隔符间有且仅有一个自然语义英语单词、单数形式。
8. Entity 对应 Service 使用官方默认风格：接口继承 `IService<T>`，实现继承 `ServiceImpl<Mapper, T>`，通过 baseMapper 访问 Mapper；非 entity 对应的业务编排 Service（如 CommandService）使用纯接口风格，不继承 IService，通过构造器注入依赖。
9. 日志输出基线：默认「控制台 + 滚动日志文件（按时间 + 大小切分）」；仅当明确要求关注/分离错误日志时，追加独立 ERROR 日志文件。统一使用 `src/main/resources/logback-spring.xml`，滚动策略用 `SizeAndTimeBasedRollingPolicy`（JDK 8/Spring Boot 2.x 与 JDK 17+/3.x 通用；禁用已弃用的 `SizeAndTimeBasedFNATP`）；详见 `references/logging.md`。
10. API 文档基线：对外接口必须提供在线文档，统一使用 Knife4j（基于 springdoc-openapi / OpenAPI3），注解用 `@Tag`/`@Operation`/`@Schema`；禁止已停更的 springfox（Boot 2.6+ 启动崩溃、Boot 3.x 不兼容）。Boot 3.x 依赖必须带 `jakarta` 后缀；原版 `com.github.xiaoymin` 4.5.0 适配 Boot 2.6~3.3，Boot 3.4/3.5+ 换社区 fork `com.baizhukui` 5.x（drop-in，仅改 groupId）。生产环境必须用 `knife4j.production=true` 或鉴权关闭文档裸奔；详见 `references/api-doc.md`。

## 详细规范（按场景读取）

| 场景 | 参考文件 |
| ---- | -------- |
| 包结构、包职责、类命名 | `references/project-structure.md` |
| RESTful URL、HTTP 方法、状态码 | `references/api-design.md` |
| API 文档（Knife4j/OpenAPI3）选型、接入、注解、生产安全 | `references/api-doc.md` |
| 单元测试命名与覆盖要求 | `references/testing.md` |
| 日志输出策略、Logback 配置、滚动/错误日志 | `references/logging.md` |
