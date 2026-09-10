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
11. 新建工程默认跳过测试：`pom.xml` 的 `<properties>` 中必须配置 `<maven.test.skip>true</maven.test.skip>`，使 `mvn compile`/`package`/`install` 全程自动跳过测试编译与执行，无需每次手动加 `-DskipTests`；需要临时运行测试（如 CI）时用 `-Dmaven.test.skip=false` 命令行覆盖即可，不改动 pom；详见 `references/testing.md`。
12. 新建工程必须交付自述文件：工程根目录固定输出 `README.md`（全大写 + `.md`，禁止 `readme.md`/`README.MD`/`README_CN.md`/`项目说明.md` 等变体）；章节顺序固定为「项目名称 + 一句话描述 → 📋 目录 → 项目简介（含核心功能任务列表）→ 技术栈（分类/技术/版本表格）→ 项目结构（树形 + 目录职责）→ 环境要求 → 快速开始 → 配置说明（配置项/说明/默认值表格）→ 部署指南 → API 文档 → 常见问题」，`更新日志`/`许可证` 仅在仓库确有 `CHANGELOG.md`/`LICENSE` 时保留，否则整节删除、禁止悬空链接；本栈差异项：环境要求写 JDK/Maven/MySQL/Redis 实际版本，快速开始按「导入 SQL → 改 `application-dev.yml` → `mvn spring-boot:run`」给出可直接复制执行的命令，配置说明列 `spring.datasource.*`、`redis.*` 等实际关键项，API 文档写实际访问地址 `http://localhost:{server.port}/doc.html` 并说明生产环境用 `knife4j.production=true` 关闭，部署指南写 `mvn package` + `java -jar` 与日志路径，纯后端工程省略前端/小程序启动小节；无实质内容的章节整节删除，禁止「待补充」空章节与占位假数据；完整模板见 `doc-writing` 技能的 `references/readme-template.md`，未安装该技能时按本条骨架生成。

## 详细规范（按场景读取）

| 场景 | 参考文件 |
| ---- | -------- |
| 工程根目录布局(src/db/docs/.vscode/pom.xml/target)、包结构、包职责、类命名 | `references/project-structure.md` |
| RESTful URL、HTTP 方法、状态码 | `references/api-design.md` |
| API 文档（Knife4j/OpenAPI3）选型、接入、注解、生产安全 | `references/api-doc.md` |
| 单元测试命名、覆盖要求、构建默认跳过测试配置 | `references/testing.md` |
| 日志输出策略、Logback 配置、滚动/错误日志 | `references/logging.md` |
| 新建工程 README 交付、章节骨架、按项目类型裁剪、填写红线 | `doc-writing` 技能的 `references/readme-template.md`（未安装该技能时按核心铁律 12 的骨架生成） |
