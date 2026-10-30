---
name: springboot-spec
description: |
  SpringBoot 后端工程规范。当用户涉及以下场景时必须使用本技能：
  新建/搭建 SpringBoot 工程或模块、初始化后端项目、生成 CRUD 与脚手架代码、划分包结构、
  编写 Controller/Service/Mapper、设计 RESTful API、生成 API 接口文档（Knife4j/Swagger/OpenAPI3，Controller 强制标注 @Tag/@Operation/@Parameter/@ApiResponse）、依赖注入、日志输出与 Logback 配置、异常处理、数据安全、编写单元测试、工程编码统一 UTF-8 与 Windows 控制台乱码排查。
  适用于 SpringBoot + MyBatis/MyBatis-Plus 技术栈的 Java 后端开发。
---

# SpringBoot 工程规范

## 核心铁律

**前置门禁**：本技能管的是工程结构、分层、依赖注入与接口约定；凡产出或修改 `.java` 源文件，必须同时加载 `java-spec` 并逐条遵守其命名、常量、集合、并发等强制规范。两个技能同时适用，不得以“已加载本技能”为由跳过 `java-spec`。

1. 依赖注入必须使用构造函数注入：依赖字段声明为 `private final`，构造器由 Lombok `@RequiredArgsConstructor` 在类上生成，**禁止手写构造器**（仅当构造器参数需要 `@Lazy`/`@Qualifier`/`@Value` 等注解时才手写）；禁止字段注入（`@Autowired` 打在字段上）与 Setter 注入。判定口径：`pom.xml` 已有 lombok 依赖时一律用 `@RequiredArgsConstructor`，不因存量代码是手写构造器而沿用旧风格；只有项目无 lombok 依赖时才手写构造器。
2. API 层必须使用 DTO 进行数据传输，严禁直接暴露 Entity；不同场景使用不同的 DTO/VO 对象；对象转换统一放在 `converter` 包的 `XxxConverter` 静态方法中，禁止引入 MapStruct（注解处理器配置成本高于收益），禁止在 Controller/Service 内内联字段拷贝。
3. Controller 仅负责 HTTP 请求路由、参数绑定、响应封装，严禁包含任何业务逻辑；使用 `@RestController` + `@RequestMapping`。
4. 日志必须使用 SLF4J：类上标注 `@Slf4j` 生成 logger（lombok 依赖同铁律 1；项目无 lombok 时才用 `LoggerFactory.getLogger`），占位符 `{}` 拼接，异常对象作为最后一个参数传入；禁止字符串拼接日志、`System.out`、`e.printStackTrace()`。
5. 统一使用 `@ControllerAdvice` 全局异常处理；自定义业务异常继承 `RuntimeException`；异常信息不暴露系统内部细节。
6. 安全开发基线：所有外部输入必须校验；隶属用户的资源必须做归属权校验，严禁仅凭登录态操作他人数据；敏感数据（密码、身份证等）禁止明文存储、禁止输出到日志，前端展示与日志打印必须脱敏；SQL 必须参数绑定（MyBatis 用 `#{}`，禁止 `${}`），禁止字符串拼接；涉及登录态、角色权限或资源归属的接口必须用 Spring Security 做认证授权，禁止手写 Token 校验与自定义拦截器鉴权，纯 CRUD/内部工具不强制引入；短信/支付等平台资源接口必须限流、冷却与人机校验；详见 `references/security.md`。
7. 包名小写、点分隔符间有且仅有一个自然语义英语单词、单数形式。
8. Service 分层强制：所有业务 Service 一律「接口 + 实现」两个文件，接口在 `service` 包、实现在 `service.impl` 包；**禁止只产出无接口的 `@Service public class XxxService`**。Entity 对应 Service 的接口继承 `IService<T>`、实现继承 `ServiceImpl<Mapper, T>`，通过 baseMapper 访问 Mapper；非 entity 对应的业务编排 Service（如 CommandService）为纯接口，不继承 IService，通过构造器注入依赖。本约定是团队分层规范，不适用「避免过度封装 / 只写最少代码」的简化判断。
9. 日志输出基线：默认「控制台 + 滚动日志文件（按时间 + 大小切分）」；仅当明确要求关注/分离错误日志时，追加独立 ERROR 日志文件。统一使用 `src/main/resources/logback-spring.xml`，必须 `include org/springframework/boot/logging/logback/defaults.xml` 并使用内置 `${CONSOLE_LOG_PATTERN}`/`${FILE_LOG_PATTERN}`（禁止自定义 pattern 变量），滚动策略用 `SizeAndTimeBasedRollingPolicy`（JDK 8/Spring Boot 2.x 与 JDK 17+/3.x 通用；禁用已弃用的 `SizeAndTimeBasedFNATP`）；详见 `references/logging.md`。
10. API 文档与 Controller 注解基线（强制）：对外接口必须提供在线文档，统一使用 Knife4j（基于 springdoc-openapi / OpenAPI3）。**所有 Controller 类必须有 `@Tag`，每个映射方法必须有 `@Operation`，每个路径变量/查询参数/请求头必须有 `@Parameter`，每个方法至少一条 `@ApiResponse` 描述成功返回**；请求体不给参数加 `@Parameter`，由 DTO 的 `@Schema` 描述类与字段；`pom.xml` 必须开启 `-parameters`，否则参数名丢失。缺任一项视为不合规，不得交付。Swagger 注解包在 Boot 2.x 与 3.x 完全一致（`io.swagger.v3.oas.annotations.*`），换版本只换依赖坐标与 `javax`/`jakarta` 校验包，不换注解；禁止已停更的 springfox（Boot 2.6+ 启动崩溃、Boot 3.x 不兼容）。Boot 3.x 依赖必须带 `jakarta` 后缀；原版 `com.github.xiaoymin` 4.5.0 适配 Boot 2.6~3.3，Boot 3.4/3.5+ 换社区 fork `com.baizhukui` 5.x（drop-in，仅改 groupId）。生产环境必须用 `knife4j.production=true` 或鉴权关闭文档裸奔；强制清单 C1~C6、逐参数写法与自检命令详见 `references/api-doc.md`。
11. 构建默认跳过测试（目的仅是打包提速，不降低测试要求）：新建工程在 `pom.xml` 的 `<properties>` 中配置 `<maven.test.skip>true</maven.test.skip>`，使 `mvn compile`/`package`/`install` 全程自动跳过测试的编译与执行，无需每次手动加 `-DskipTests`；运行测试不改 pom，命令行覆盖即可：`mvn test -Dmaven.test.skip=false`。交付含核心业务逻辑的代码前，必须用该命令显式运行并通过对应测试，禁止只写不跑（执行纪律遵循 test-execution 技能）；详见 `references/testing.md`。
12. 新建工程必须交付自述文件：工程根目录固定输出 `README.md`（全大写 + `.md`），章节骨架、按项目类型裁剪与填写红线统一遵循 `doc-writing` 技能的 `references/readme-template.md`（唯一真相源，未安装该技能时按其骨架生成）。本栈差异项：环境要求写 JDK/Maven/MySQL/Redis 实际版本；快速开始按「导入 SQL → 改 `application-dev.yml` → 激活 dev Profile 启动」给出当前终端可直接复制执行的命令；配置说明列 `spring.datasource.*` 及 Boot 3.x 的 `spring.data.redis.*`、Boot 2.x 的 `spring.redis.*` 等实际关键项；API 文档写实际访问地址 `http://localhost:{server.port}/doc.html` 并说明生产环境用 `knife4j.production=true` 关闭；部署指南写 `mvn package` + `java -jar` 与日志路径；纯后端工程省略前端/小程序启动小节。
13. 工程编码统一 UTF-8（根治 Windows 控制台乱码）：新建工程必须在五处同时对齐 UTF-8——① 源文件（VSCode `files.encoding=utf8`）；② 构建（`pom.xml` 的 `project.build.sourceEncoding`）；③ HTTP（`application.yml` 的 `server.servlet.encoding`）；④ JVM 输出（`.vscode/launch.json` 的 `vmArgs` + `console: integratedTerminal`）；⑤ 终端代码页（终端 profile 启动即 `chcp 65001`），缺一处都可能残留乱码。控制台乱码根因是「JVM 输出编码（写入端）与终端代码页（解读端）不匹配」，`application.yml` 只管 HTTP、`pom.xml` 只管构建，均无法根治控制台乱码；Debug Console（`internalConsole`）中文乱码为已知无解限制，必须走集成终端。五处具体配置、按 JDK 版本（8~17 与 18+）的 `vmArgs` 差异、验证清单与常见坑详见 `references/encoding.md`。

## 新建工程骨架（强制产出清单）

新建 Entity 绑定的 CRUD 工程或业务模块时按下列骨架产出文件，缺一即视为不合规（`{Entity}` 换实际实体名，完整包布局见 `references/project-structure.md`）。纯编排、定时任务、消息消费等非 CRUD 模块按实际职责选择 Controller、Service、Mapper 等类型，不强制创造无用途的 Entity 或空目录：

```text
src/main/java/{basePackage}/
├── controller/{Entity}Controller.java
├── service/{Entity}Service.java             # 接口，本包只放接口
├── service/impl/{Entity}ServiceImpl.java    # 实现，@Service 只打在这里
├── mapper/{Entity}Mapper.java
├── entity/{Entity}.java
├── dto/  vo/  converter/
```

- 每个 `XxxService` 必须在 `service.impl` 有对应 `XxxServiceImpl`；Controller 与跨 Service 调用只注入接口，不注入实现类。
- 新建工程必须在 `pom.xml` 声明 lombok 依赖（`<optional>true</optional>`，版本交由 `spring-boot-dependencies` 管理、不写 version），否则 `@RequiredArgsConstructor` 无法编译。
- 正例 / 反例对照见 `references/project-structure.md` 的「Service 分层正反例」。

## 详细规范（按场景读取）

| 场景 | 参考文件 |
| ---- | -------- |
| 工程根目录布局(src/db/docs/.vscode/pom.xml/target)、包结构、包职责、类命名、Service 分层正反例 | `references/project-structure.md` |
| RESTful URL、HTTP 方法、状态码 | `references/api-design.md` |
| API 文档（Knife4j/OpenAPI3）选型、接入、注解、生产安全 | `references/api-doc.md` |
| 单元测试原则（AIR/BCDE）、命名、粒度与位置、覆盖要求、数据与外部依赖策略、代码可测性、构建默认跳过测试配置 | `references/testing.md` |
| 日志输出策略、Logback 配置、滚动/错误日志 | `references/logging.md` |
| 工程编码统一 UTF-8、Windows 控制台乱码根治、pom/application.yml/launch.json/VSCode 终端编码配置 | `references/encoding.md` |
| 代码安全（水平越权、CSRF、注入与 XSS 防御、敏感数据脱敏、接口防重放/防滥刷） | `references/security.md` |
| 新建工程 README 交付、章节骨架、按项目类型裁剪、填写红线 | `doc-writing` 技能的 `references/readme-template.md`（未安装该技能时按核心铁律 12 的骨架生成） |

## 交付前自检（逐项核对）

生成工程代码后、交付前逐条确认，任一条不满足先修正再交付：

1. `service` 包内每个类型都是接口，`service.impl` 有对应 `XxxServiceImpl` 且 `implements` 该接口；`@Service` 只出现在实现类上。
2. Controller 及其他层只注入 Service 接口，代码中不出现 `XxxServiceImpl` 作为注入类型。
3. 所有依赖字段为 `private final`，类上有 `@RequiredArgsConstructor`、无手写构造器（参数注解场景除外），无字段注入、无 Setter 注入。
4. Controller 无业务逻辑，入参为 DTO、出参为 VO 或统一响应体。
5. 日志使用 `@Slf4j` 与 `{}` 占位符，无 `System.out`、`e.printStackTrace()`、字符串拼接日志。
6. 对象转换都在 `converter` 包的 `XxxConverter` 静态方法中，Controller/Service 无内联字段拷贝，`pom.xml` 未引入 MapStruct。
7. 新建工程已产出 `src/main/resources/logback-spring.xml`（已 include `defaults.xml` 并使用内置 `${CONSOLE_LOG_PATTERN}`/`${FILE_LOG_PATTERN}`，CONSOLE + 滚动 FILE，`SizeAndTimeBasedRollingPolicy`），应用启动后 `logs/` 目录下日志文件已落盘。
8. 每个 Controller 类有 `@Tag`，每个映射方法有 `@Operation` 与至少一条 `@ApiResponse`，每个路径变量/查询参数/请求头有 `@Parameter`，请求体 DTO 及其字段有 `@Schema`，`pom.xml` 已开启 `-parameters`。
