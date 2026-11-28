---
name: springboot-spec
description: |
  SpringBoot 后端工程规范。当用户涉及以下场景时必须使用本技能：
  新建/搭建 SpringBoot 工程或模块、初始化后端项目、生成 CRUD 与脚手架代码、划分包结构、
  编写 Controller/Service/Mapper、设计 RESTful API、写接口幂等（POST/PUT/PATCH + Idempotency-Key）、生成 API 接口文档（Knife4j/Swagger/OpenAPI3，Controller 强制标注 @Tag/@Operation/@Parameter/@ApiResponse，请求 DTO 与响应 VO 强制标注 @Schema）、依赖注入、日志输出与 Logback 配置、异常处理、数据安全、编写单元测试、工程编码统一 UTF-8 与 Windows 控制台乱码排查。
  适用于 SpringBoot + MyBatis/MyBatis-Plus 技术栈的 Java 后端开发。
---

# SpringBoot 工程规范

## 版本基线（动手前先判档）

同一套写法不跨大版本通用：Boot 2.x 用 `javax.*`、`spring.redis.*`，Boot 3.x 用 `jakarta.*`、`spring.data.redis.*`，部分类只在其中一档存在。动手前先读 `pom.xml` 判档，再决定依赖坐标、配置键与 import，判据按序取值、命中即停：`spring-boot-starter-parent` 的 `<version>` → `dependencyManagement` 中 `spring-boot-dependencies` 的版本 → `<spring-boot.version>` 属性 → `spring-boot-starter-*` 的直接版本。

| 档位 | Spring Boot | JDK | 高频差异 |
| ---- | ---- | ---- | ---- |
| 老项目 | 2.x | 8 / 11 | `javax.validation.*`、`spring.redis.*`、`mysql:mysql-connector-java`、`mybatis-plus-boot-starter`、`druid-spring-boot-starter` |
| 新项目 | 3.x | 17+ | `jakarta.validation.*`、`spring.data.redis.*`、`com.mysql:mysql-connector-j`、`mybatis-plus-spring-boot3-starter`、`druid-spring-boot-3-starter` |

- 依赖坐标、配置键、import 包名、可用 API 必须同档，禁止混用；不得把一档的示例贴到另一档后靠 IDE 编译报错去反推版本。
- JDK 档位看 `<java.version>` / `<maven.compiler.release>`，与 Boot 档位必须自洽：Boot 2.x 工程不得出现 `record`、`var`、文本块、`List.of`。
- 第三方库的变体命名规律、逐项对照表、判定与核对命令见 `references/version-baseline.md`；RabbitMQ 的档位差异见 `rabbitmq-reliability` 技能的 `references/version-diff.md`。

## 条款适用判定（动手前先判，不得整体豁免）

每条铁律带一个适用标记，决定它在本次改动中是否成立：

| 标记 | 含义 | 豁免条件 |
| --- | --- | --- |
| 〔通用〕 | 存量、新建、单文件改动一律适用 | 无。不得以“存量工程”“已批准的设计”“任务很小”“只是改几行”为由跳过 |
| 〔新建〕 | 本次新建工程或新建模块骨架时触发 | 仅当本次不涉及新建工程、不新增 `pom.xml` / 骨架 / 启动类 |
| 〔存量〕 | 存量项目与新建项目的差异处理 | 用于说明差异，本身不构成豁免 |

判“不适用”必须给出触发条件不成立的事实（如“本次未新增 `pom.xml`，SB-11 触发条件不成立”），“这是存量工程”不构成任何〔通用〕条款的豁免理由；对账格式遵循 `spec-gate` 技能。

## 核心铁律

**前置门禁**：本技能管的是工程结构、分层、依赖注入与接口约定；凡产出或修改 `.java` 源文件，必须同时加载 `java-spec` 并逐条遵守其命名、常量、集合、并发等强制规范。两个技能同时适用，不得以“已加载本技能”为由跳过 `java-spec`。

**SB-1**〔通用〕依赖注入必须使用构造函数注入：依赖字段声明为 `private final`，构造器由 Lombok `@RequiredArgsConstructor` 在类上生成，**禁止手写构造器**（仅当构造器参数需要 `@Lazy`/`@Qualifier`/`@Value` 等注解时才手写）；禁止字段注入（`@Autowired` 打在字段上）与 Setter 注入。判定口径：`pom.xml` 已有 lombok 依赖时一律用 `@RequiredArgsConstructor`，不因存量代码是手写构造器而沿用旧风格；只有项目无 lombok 依赖时才手写构造器。
**SB-2**〔通用〕API 层必须使用 DTO 进行数据传输，严禁直接暴露 Entity；不同场景使用不同的 DTO/VO 对象。对象转换按「复用次数 + 是否存在非等价映射」分档，不按文件数量分档：**单点调用、且源与目标同名属性类型完全一致时，就地一行完成**（`org.springframework.beans.BeanUtils.copyProperties(source, target)`，Spring 自带、不算新增依赖；目标必须有 setter，`@Builder`/`@Value`/record 的 VO 不适用；禁止 Apache `commons-beanutils`，反射链路慢一个数量级）。**同一转换被 ≥2 处调用、被集合 `stream().map()` 引用，或存在非等价映射（字段名不同、类型不同、枚举码值翻译、脱敏、嵌套对象转换）时，必须抽到 `converter` 包的 `XxxConverter` 静态方法。** 任何位置禁止连续 ≥2 行 `target.setXxx(source.getXxx())` 的逐字段拷贝。禁止引入 MapStruct（注解处理器配置成本高于收益）。分档正反例见 `references/project-structure.md` 的「对象转换分档」。
**SB-3**〔通用〕Controller 仅负责 HTTP 请求路由、参数绑定、响应封装，严禁包含任何业务逻辑；使用 `@RestController` + `@RequestMapping`。
**SB-4**〔通用〕日志必须使用 SLF4J：类上标注 `@Slf4j` 生成 logger（lombok 依赖同 SB-1；项目无 lombok 时才用 `LoggerFactory.getLogger`），占位符 `{}` 拼接，异常对象作为最后一个参数传入；禁止字符串拼接日志、`System.out`、`e.printStackTrace()`。
**SB-5**〔通用〕统一使用 `@ControllerAdvice` 全局异常处理；自定义业务异常继承 `RuntimeException`；异常信息不暴露系统内部细节。
**SB-6**〔通用〕安全开发基线：所有外部输入必须校验；隶属用户的资源必须做归属权校验，严禁仅凭登录态操作他人数据；敏感数据（密码、身份证等）禁止明文存储、禁止输出到日志，前端展示与日志打印必须脱敏；SQL 必须参数绑定（MyBatis 用 `#{}`，禁止 `${}`），禁止字符串拼接；涉及登录态、角色权限或资源归属的接口必须用 Spring Security 做认证授权，禁止手写 Token 校验与自定义拦截器鉴权，纯 CRUD/内部工具不强制引入；短信/支付等平台资源接口必须限流、冷却与人机校验；详见 `references/security.md`。
**SB-7**〔通用〕包名小写、点分隔符间有且仅有一个自然语义英语单词、单数形式。
**SB-8**〔通用〕Service 分层强制（缺一即不合规）：所有业务 Service 一律「接口 + 实现」两个文件，接口在 `service` 包、实现在 `service.impl` 包；**禁止只产出无接口的 `@Service public class XxxService`**。按是否绑定 Entity 分两档，判据为本 Service 名下是否存在同实体名的 `entity` 与 `mapper`：① entity 绑定型（`pom.xml` 含 `mybatis-plus-boot-starter`，Boot 3 工程为 `mybatis-plus-spring-boot3-starter`）—— 接口 `extends IService<{Entity}>`，实现 `extends ServiceImpl<{Entity}Mapper, {Entity}> implements {Entity}Service`（泛型顺序 Mapper 在前，不可颠倒），增删改查直接用父类 `save`/`getById`/`list`/`baseMapper`，不再额外注入 `{Entity}Mapper` 字段；② 业务编排型（无绑定 Entity，如 `OrderCommandService`）—— 纯接口，实现 `implements` 接口并经构造器注入依赖，不得为凑格式继承 `IService`/`ServiceImpl`。禁止两种降级：把 entity 绑定型写成「纯接口 + 注入 Mapper」，或只 `extends ServiceImpl` 而不 `implements` 自定义接口。纯 MyBatis 项目（无 MyBatis-Plus 依赖）无 `IService` 可用时，entity 绑定型退化为「纯接口 + 实现注入 Mapper」。本约定是团队分层规范，不适用「避免过度封装 / 只写最少代码」的简化判断，也不因存量项目风格而降级。
**SB-9**〔通用 + 新建〕日志输出基线：默认「控制台 + 滚动日志文件（按时间 + 大小切分）」；仅当明确要求关注/分离错误日志时，追加独立 ERROR 日志文件。统一使用 `src/main/resources/logback-spring.xml`，必须 `include org/springframework/boot/logging/logback/defaults.xml` 并使用内置 `${CONSOLE_LOG_PATTERN}`/`${FILE_LOG_PATTERN}`（禁止自定义 pattern 变量），滚动策略用 `SizeAndTimeBasedRollingPolicy`（JDK 8/Spring Boot 2.x 与 JDK 17+/3.x 通用；禁用已弃用的 `SizeAndTimeBasedFNATP`）；详见 `references/logging.md`。
**SB-10**〔通用〕API 文档与 Controller 注解基线（强制）：对外接口必须提供在线文档，统一使用 Knife4j（基于 springdoc-openapi / OpenAPI3）。**所有 Controller 类必须有 `@Tag`，每个映射方法必须有 `@Operation`，每个路径变量/查询参数/请求头必须有 `@Parameter`，每个方法至少一条 `@ApiResponse` 描述成功返回**；请求体与响应体都不给参数加 `@Parameter`，请求 DTO 与响应 VO 的类及其每个字段必须用 `@Schema` 描述（`description` 必填，嵌套对象与集合元素同样要标）；`pom.xml` 必须开启 `-parameters`，否则参数名丢失。缺任一项视为不合规，不得交付。Swagger 注解包在 Boot 2.x 与 3.x 完全一致（`io.swagger.v3.oas.annotations.*`），换版本只换依赖坐标与 `javax`/`jakarta` 校验包，不换注解；禁止已停更的 springfox（Boot 2.6+ 启动崩溃、Boot 3.x 不兼容）。Boot 3.x 依赖必须带 `jakarta` 后缀；原版 `com.github.xiaoymin` 4.5.0 适配 Boot 2.6~3.3，Boot 3.4/3.5+ 换社区 fork `com.baizhukui` 5.x（drop-in，仅改 groupId）。生产环境必须用 `knife4j.production=true` 或鉴权关闭文档裸奔；强制清单 C1~C7、逐参数写法与自检命令详见 `references/api-doc.md`。
**SB-11**〔新建〕构建默认跳过测试（目的仅是打包提速，不降低测试要求）：新建工程在 `pom.xml` 的 `<properties>` 中配置 `<maven.test.skip>true</maven.test.skip>`，使 `mvn compile`/`package`/`install` 全程自动跳过测试的编译与执行，无需每次手动加 `-DskipTests`；运行测试不改 pom，命令行覆盖即可：`mvn test -Dmaven.test.skip=false`；配置细节详见 `references/testing.md`。
**SB-12**〔新建〕新建工程必须交付自述文件：工程根目录固定输出 `README.md`（全大写 + `.md`），章节骨架、按项目类型裁剪与填写红线统一遵循 `doc-writing` 技能的 `references/readme-template.md`（唯一真相源，未安装该技能时按其骨架生成）。本栈差异项：环境要求写 JDK/Maven/MySQL/Redis 实际版本；快速开始按「导入 SQL → 改 `application-dev.yml` → 激活 dev Profile 启动」给出当前终端可直接复制执行的命令；配置说明列 `spring.datasource.*` 及 Boot 3.x 的 `spring.data.redis.*`、Boot 2.x 的 `spring.redis.*` 等实际关键项；API 文档写实际访问地址 `http://localhost:{server.port}/doc.html` 并说明生产环境用 `knife4j.production=true` 关闭；部署指南写 `mvn package` + `java -jar` 与日志路径；纯后端工程省略前端/小程序启动小节。
**SB-13**〔新建〕工程编码统一 UTF-8（根治 Windows 控制台乱码）：新建工程必须在五处同时对齐 UTF-8——① 源文件（VSCode `files.encoding=utf8`）；② 构建（`pom.xml` 的 `project.build.sourceEncoding`）；③ HTTP（`application.yml` 的 `server.servlet.encoding`）；④ JVM 输出（`.vscode/launch.json` 的 `vmArgs` + `console: integratedTerminal`）；⑤ 终端代码页（终端 profile 启动即 `chcp 65001`），缺一处都可能残留乱码。控制台乱码根因是「JVM 输出编码（写入端）与终端代码页（解读端）不匹配」，`application.yml` 只管 HTTP、`pom.xml` 只管构建，均无法根治控制台乱码；Debug Console（`internalConsole`）中文乱码为已知无解限制，必须走集成终端。五处具体配置、按 JDK 版本（8~17 与 18+）的 `vmArgs` 差异、验证清单与常见坑详见 `env-troubleshooting` 技能的 `references/console-encoding.md`（唯一真相源；未安装该技能时按本条列出的五处自行落地）。
**SB-14**〔通用 + 新建 + 存量〕主键与雪花 ID 的 JS 精度防护：Entity 主键统一 `Long id`，`application.yml` 显式配置 `mybatis-plus.global-config.db-config.id-type: ASSIGN_ID`，禁止 `@TableId(type = IdType.AUTO)`。雪花 ID 为 19 位 Long，超过 JS `Number` 的安全整数上限 `2^53-1`，**新建工程必须在全局序列化层把 `Long`/`long` 统一输出为字符串**：注册 `Jackson2ObjectMapperBuilderCustomizer`，对 `Long.class` 与 `Long.TYPE` 分别 `serializerByType(..., ToStringSerializer.instance)`——两个都要注册，漏 `Long.TYPE` 则基本类型字段不生效；全局配置天然覆盖 VO、嵌套对象、集合元素与 `Map` 值，禁止逐字段打注解充当主方案（漏标即线上偶发「详情 404」），禁止用 `spring.jackson.generator.write-numbers-as-strings`（会把 `int`/`double` 一并转字符串），禁止依赖前端 `json-bigint` 兜底。必须配套类型约定：`Long` 只保留给「主键与关联 ID」，计数用 `int`/`Integer`、金额用 `BigDecimal`、时间用 `LocalDateTime`/`Date`，使全局转换的副作用收敛为「JSON 里的 ID 是字符串」这一条可写入接口文档的稳定契约；反序列化方向（字符串 ID → `Long` 入参）无需额外配置，Service/Mapper 签名仍保持 `Long`。存量项目已用逐字段 `@JsonSerialize(using = ToStringSerializer.class)` 的沿用现状，不为统一而改造。建表、多实例分配与原生 MyBatis 的主键规则遵循 `db-spec` 技能「主键策略规约」，配置代码、影响范围与验证方法见 `references/id-serialization.md`。
**SB-15**〔通用〕数据库脚本人工执行，禁止与应用启动绑定：建表、变更与初始化数据脚本一律由人手工执行——个人项目由开发者本人执行，公司项目由 DBA 审核后执行，应用启动不承担任何改库职责。**禁止**在 `pom.xml` 引入 `flyway-core`/`liquibase-core` 等迁移组件，**禁止** `spring.flyway.*`/`spring.liquibase.*` 配置，**禁止** `spring.sql.init.mode=always` 及启动钩子里执行 DDL/DML；Flyway/Liquibase 虽是 Spring Boot 官方推荐做法，也不构成引入理由。脚本放工程 `db/` 目录（布局见 `references/project-structure.md`），执行顺序写进 README 的「导入 SQL」步骤；脚本自身的 SQL 规约遵循 `db-spec` 技能「脚本交付规约」。
**SB-16**〔通用〕写接口幂等强制（`POST`/`PUT`/`PATCH` 业务接口全覆盖，登录/登出/刷新令牌/验证码等认证类接口除外）：所有这三类业务映射方法必须标注 `@Idempotent`，客户端必须携带 `Idempotency-Key`（8~128 位 `[A-Za-z0-9_-]`）与 `Content-Digest`（`sha-256=:<base64>:`，无 body 可省），缺失或不合规返回 400；`userId` 按项目实际鉴权方式获取，统一封装 `CurrentUserProvider`（Spring Security 的 principal、Sa-Token 的 `StpUtil`、自定义 `UserContext`；网关透传时读网关注入且入口已剥离同名头的标识），缺失按 `anonymous`，禁止直接信任客户端自报 header。实现固定为「无 Filter、服务端不读请求体 + `@Aspect` + Redisson `StringCodec` + `SET NX PX` + Lua 完成/释放」，指纹为 `SHA-256(method + URI + query + bodyDigest)`、段间 `0x00`；同 key 同指纹返回首次结果，同 key 不同指纹 422，处理中或结果未缓存 409。首次抢占必须写入独立 `executionId`，`complete` 与业务异常时的 `release`（Lua `DEL`）都必须同时校验指纹与 `executionId`，防止处理中记录过期后旧请求误删或覆盖新记录；`complete` 阶段失败只记 warn，不释放、不回滚。Redis 故障必须快速失败，禁止降级放行。缓存只存 body 不存状态码，幂等接口成功时统一返回 200，成功响应禁止用 `ResponseEntity`/`@ResponseStatus`，禁止异步返回与直接写 `HttpServletResponse`；业务失败必须抛异常，不能返回 `Result.fail` 当正常返回。完整时序、Redis 结构、实现代码与验收用例见 `references/idempotency.md`。
**SB-17**〔通用〕交付前必须显式运行测试：含核心业务逻辑的代码，交付前必须用 `mvn test -Dmaven.test.skip=false` 实际运行并通过对应测试，禁止只写不跑；执行纪律遵循 `test-execution` 技能。

## 新建工程骨架（强制产出清单）

新建 Entity 绑定的 CRUD 工程或业务模块时按下列骨架产出文件，缺一即视为不合规（`{Entity}` 换实际实体名，完整包布局见 `references/project-structure.md`）。纯编排、定时任务、消息消费等非 CRUD 模块按实际职责选择 Controller、Service、Mapper 等类型，不强制创造无用途的 Entity 或空目录：

```text
src/main/java/{basePackage}/
├── controller/{Entity}Controller.java
├── service/{Entity}Service.java             # 接口：extends IService<{Entity}>
├── service/impl/{Entity}ServiceImpl.java    # 实现：extends ServiceImpl<{Entity}Mapper, {Entity}>，@Service 只打在这里
├── mapper/{Entity}Mapper.java
├── entity/{Entity}.java
├── dto/  vo/  converter/                    # converter 按需创建，见下方说明
```

- 每个 `XxxService` 必须在 `service.impl` 有对应 `XxxServiceImpl`；Controller 与跨 Service 调用只注入接口，不注入实现类。
- `converter/` 按需创建：只有满足 SB-2 的抽类条件（同一转换 ≥2 处调用、被集合映射引用、存在非等价映射）时才建 `XxxConverter`，不为每个 Entity 预建转换类。
- 新建工程必须在 `pom.xml` 声明 lombok 依赖（`<optional>true</optional>`，版本交由 `spring-boot-dependencies` 管理、不写 version），否则 `@RequiredArgsConstructor` 无法编译。
- 新建工程使用 MyBatis-Plus 时必须在 `pom.xml` 声明对应档位的 starter（Boot 2.x 用 `mybatis-plus-boot-starter`，Boot 3.x 用 `mybatis-plus-spring-boot3-starter`，均不写死 version），否则 entity 绑定型 Service 无法 `extends IService`/`ServiceImpl`；纯 MyBatis 工程不声明。
- 正例 / 反例对照见 `references/project-structure.md` 的「Service 分层正反例」。

## 详细规范（按场景读取）

| 场景 | 参考文件 |
| ---- | -------- |
| 版本档位判定、依赖坐标/配置键/命名空间/API 的两档对照、第三方 starter 变体命名、JDK 语言特性边界 | `references/version-baseline.md` |
| 工程根目录布局(src/db/docs/.vscode/pom.xml/target)、包结构、包职责、类命名、对象转换分档与正反例、Service 分层正反例 | `references/project-structure.md` |
| RESTful URL、HTTP 方法、状态码、写接口幂等契约 | `references/api-design.md` |
| 接口幂等实现（POST/PUT/PATCH 强制、Idempotency-Key + Content-Digest、纯切面无 Filter、Redisson 状态机、指纹与 executionId、Lua、验收用例） | `references/idempotency.md` |
| 雪花 ID 的 JS 精度防护：全局 Long→字符串配置、类型收缩约定、影响范围、反序列化、文档对齐、存量兜底、验证 | `references/id-serialization.md` |
| API 文档（Knife4j/OpenAPI3）选型、接入、Controller 与 DTO/VO 注解、生产安全 | `references/api-doc.md` |
| 单元测试原则（AIR/BCDE）、命名、粒度与位置、覆盖要求、数据与外部依赖策略、代码可测性、构建默认跳过测试配置 | `references/testing.md` |
| 日志输出策略、Logback 配置、滚动/错误日志 | `references/logging.md` |
| 工程编码统一 UTF-8、Windows 控制台乱码根治、pom/application.yml/launch.json/VSCode 终端编码配置 | `env-troubleshooting` 技能的 `references/console-encoding.md`（未安装时按 SB-13 落地） |
| 代码安全（水平越权、CSRF、注入与 XSS 防御、敏感数据脱敏、接口防重放/防滥刷） | `references/security.md` |
| 新建工程 README 交付、章节骨架、按项目类型裁剪、填写红线 | `doc-writing` 技能的 `references/readme-template.md`（未安装该技能时按 SB-12 的骨架生成） |

## 交付前自检（按条款对账）

按 `spec-gate` 的三态判定收口：只列本次改动触及的条款，每条给「遵守（位置）/ 不适用（判据）/ 偏差（理由与裁决）」，未触及的条款不列；不适用必须指向触发条件，偏差未裁决不得交付。以下为各条款的检查要点：

1. [SB-8] `service` 包内每个类型都是接口，`service.impl` 有对应 `XxxServiceImpl` 且 `implements` 该接口；`@Service` 只出现在实现类上；entity 绑定型的接口已 `extends IService<T>`、实现已 `extends ServiceImpl<Mapper, T>`（泛型顺序 Mapper 在前），实现类内无多余的 `XxxMapper` 注入字段；业务编排型接口未误继承 `IService`。
2. [SB-8] Controller 及其他层只注入 Service 接口，代码中不出现 `XxxServiceImpl` 作为注入类型。
3. [SB-1] 所有依赖字段为 `private final`，类上有 `@RequiredArgsConstructor`、无手写构造器（参数注解场景除外），无字段注入、无 Setter 注入。
4. [SB-2][SB-3] Controller 无业务逻辑，入参为 DTO、出参为 VO 或统一响应体。
5. [SB-4] 日志使用 `@Slf4j` 与 `{}` 占位符，无 `System.out`、`e.printStackTrace()`、字符串拼接日志。
6. [SB-2] 不存在连续 ≥2 行 `target.setXxx(source.getXxx())` 的逐字段拷贝；满足抽类条件的转换（同一转换 ≥2 处调用、被集合映射引用、存在非等价映射）都在 `converter` 包的 `XxxConverter` 静态方法中，其余转换就地一行完成；`pom.xml` 未引入 MapStruct 与 Apache `commons-beanutils`。
7. [SB-9] 新建工程已产出 `src/main/resources/logback-spring.xml`（已 include `defaults.xml` 并使用内置 `${CONSOLE_LOG_PATTERN}`/`${FILE_LOG_PATTERN}`，CONSOLE + 滚动 FILE，`SizeAndTimeBasedRollingPolicy`），应用启动后 `logs/` 目录下日志文件已落盘。
8. [SB-10] 每个 Controller 类有 `@Tag`，每个映射方法有 `@Operation` 与至少一条 `@ApiResponse`，每个路径变量/查询参数/请求头有 `@Parameter`，请求体 DTO 与响应 VO 的类及其字段都有 `@Schema`，`pom.xml` 已开启 `-parameters`。
9. [SB-15] `pom.xml` 无 `flyway-core`/`liquibase-core` 依赖，`application*.yml` 无 `spring.flyway.*`/`spring.liquibase.*` 与 `spring.sql.init.mode=always`，不存在启动期自动执行 SQL 的代码；数据库脚本位于 `db/` 目录、由人工执行。
10. [版本基线] 依赖坐标、配置键与 import 命名空间与 `pom.xml` 判定的档位一致：3.x 工程无 `javax.*`、无 `mybatis-plus-boot-starter`、无 `spring.redis.*`；2.x 工程无 `jakarta.*`、无 3.x 专有 API（如 `RabbitTemplateCustomizer`），也未使用 `record`/`var`/文本块/`List.of`。
11. [SB-14] 主键为 `Long id` 且未使用 `IdType.AUTO`；新建工程存在全局 `Long`→字符串序列化配置（`Long.class` 与 `Long.TYPE` 均已注册），全工程 `Long` 字段仅用于主键与关联 ID，计数/金额/时间字段未被误声明为 `Long`；VO 的 ID 字段已用 `@Schema(..., type = "string")` 对齐实际输出；未使用 `write-numbers-as-strings` 配置。
12. [SB-16] 所有业务 `POST`/`PUT`/`PATCH` 映射方法（登录/登出/刷新令牌/验证码等认证类接口除外）均标注 `@Idempotent`，接口文档声明了必填的 `Idempotency-Key` 及带 body 时必填的 `Content-Digest` 头；`userId` 经 `CurrentUserProvider` 从项目实际登录态获取（缺失按 `anonymous`），未直接信任客户端自报 header；实现为纯切面（无 Filter、不读请求体），含 key 长度/字符集校验、摘要格式校验、Redisson `SET NX`、独立 `executionId` 与 Lua 完成/释放标记，完成/释放均校验指纹与 `executionId`，400/409/422 分支齐全；幂等接口未使用 `ResponseEntity`/`@ResponseStatus`/异步返回/直接写响应流，业务失败走异常而非 `Result.fail`；Redis 故障未降级放行；首次、重放、改指纹、并发、业务异常、结果超限、处理中过期、Redis 故障八类用例已实际验证。
13. [SB-5][SB-6][SB-7] 存在 `@ControllerAdvice` 全局异常处理且自定义业务异常继承 `RuntimeException`；外部输入已校验、用户资源已做归属权校验、SQL 全部 `#{}` 参数绑定、敏感字段未进日志；包名小写单数、单语义单词。
14. [SB-11][SB-12][SB-13] 新建工程：`pom.xml` 已配 `maven.test.skip`；根目录已产出 `README.md`（骨架遵循 `doc-writing` 的 `readme-template.md`）；UTF-8 五处已对齐且终端 `chcp 65001` 生效。
15. [SB-17] 含业务逻辑的代码已用 `mvn test -Dmaven.test.skip=false` 实际运行并通过，不是只写不跑。

本节只覆盖本栈结构层面的自检，属于生成者自证，不能单独作为可交付结论。台账与三态判定格式遵循 `spec-gate`；进入交付阶段后再加载 `code-gate`，按实际改动分级选择架构断言、变异测试、独立审查与证据格式；无需在编码开始前预载。
