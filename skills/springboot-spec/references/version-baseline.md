# 版本基线：Spring Boot 2.x 与 3.x 的写法分档

同一套代码与配置不跨大版本通用。本文件解决三件事：怎么判档、同一能力在两档分别写什么、哪些差异不在本表范围内（不得臆造）。

前提：判定结果必须贯穿依赖坐标、配置键、import 包名与可用 API 四项，缺一项就会出现「编译通过但启动失败」或「IDE 满屏弃用警告」。

## 一、判档方法

按顺序取值，命中即停：

1. `pom.xml` 中 `spring-boot-starter-parent` 的 `<parent><version>`；
2. 未继承 parent 时，`dependencyManagement` 中 `spring-boot-dependencies` 的版本；
3. 自定义属性 `<spring-boot.version>` / `<spring.boot.version>`；
4. 仍无法确定时，看 `spring-boot-starter-web` 等直接依赖的版本，或用 `mvn dependency:tree -Dincludes=org.springframework.boot` 看实际解析结果。

JDK 档位看 `<java.version>`、`<maven.compiler.source>`、`<maven.compiler.release>`；三者不一致时以 `release` 为准（Maven 编译实际生效的级别）。

| 档位 | Spring Boot | 最低 JDK | 判断特征 |
| ---- | ---- | ---- | ---- |
| 2.x（老项目） | 2.0 ~ 2.7 | 8 | 依赖里出现 `javax.*`、`mysql:mysql-connector-java`、`mybatis-plus-boot-starter` |
| 3.x（新项目） | 3.0 ~ 3.5 | 17 | 依赖里出现 `jakarta.*`、`com.mysql:mysql-connector-j`、`*-spring-boot3-starter` |

Boot 4.x 不在本表范围（依赖坐标与部分核心类有新一轮重命名），遇到时先查官方迁移文档，不要套用 3.x 结论。

## 二、依赖坐标

| 依赖 | 2.x | 3.x |
| ---- | ---- | ---- |
| MySQL 驱动 | `mysql:mysql-connector-java` | `com.mysql:mysql-connector-j` |
| MyBatis-Plus | `com.baomidou:mybatis-plus-boot-starter` | `com.baomidou:mybatis-plus-spring-boot3-starter` |
| Druid | `com.alibaba:druid-spring-boot-starter` | `com.alibaba:druid-spring-boot-3-starter` |
| 动态数据源 | `dynamic-datasource-spring-boot-starter` | `dynamic-datasource-spring-boot3-starter` |
| Knife4j | `knife4j-openapi3-spring-boot-starter` | `knife4j-openapi3-jakarta-spring-boot-starter`（Boot 3.4+ 换 `com.baizhukui` 5.x，见 `api-doc.md`） |
| Bean Validation | `javax.validation:validation-api`（随 web starter 传递） | `jakarta.validation:jakarta.validation-api` |
| Servlet API | `javax.servlet-api` | `jakarta.servlet-api` |
| lombok | 两档相同，版本交 `spring-boot-dependencies` 管理 | 同左 |

**通用规律**：Boot 3 的第三方 starter 普遍提供 `-boot3-` / `-3-starter` / `-jakarta-` 后缀的变体。表中没有的库，去该库官方 README 的兼容矩阵核对坐标；沿用 Boot 2 坐标通常表现为启动时 `NoClassDefFoundError: javax/...` 或自动配置不生效。

## 三、配置键

| 能力 | 2.x | 3.x |
| ---- | ---- | ---- |
| Redis | `spring.redis.*` | `spring.data.redis.*` |
| 发布确认 | `spring.rabbitmq.publisher-confirms: true`（2.0~2.1）<br>`spring.rabbitmq.publisher-confirm-type: correlated`（2.2+） | `spring.rabbitmq.publisher-confirm-type: correlated` |
| datasource / mybatis-plus / knife4j / management / logback | 键名相同，只换依赖坐标 | 同左 |
| 路径匹配 | `spring.mvc.pathmatch.matching-strategy`（2.6 起默认 `path-pattern-parser`） | 同左 |

## 四、命名空间与 API

| 项 | 2.x | 3.x |
| ---- | ---- | ---- |
| Bean Validation / Servlet / JPA / 注解 | `javax.*` | `jakarta.*` |
| Spring Security | 5.x：`WebSecurityConfigurerAdapter` 可用（2.7 对应版本已弃用），`authorizeRequests` / `antMatchers` | 6.x：`WebSecurityConfigurerAdapter` 已移除，统一 `SecurityFilterChain` Bean + lambda DSL，`authorizeHttpRequests` / `requestMatchers` |
| HTTP 客户端 | `RestTemplate` / `WebClient` | 同左，另可用 `RestClient`（3.2+） |
| 单测框架 | JUnit 4（2.1 及以前默认）/ JUnit 5（2.2+ 默认） | JUnit 5 |
| RabbitMQ 回调注册 | 自定义 `RabbitTemplate` Bean 或在 `InitializingBean` 中注册 | `RabbitTemplateCustomizer`（3.1+） |

RabbitMQ 的完整三档对照（发布确认键、`ReturnCallback` 五参与 `ReturnsCallback` 单参、注册方式）在 `rabbitmq-reliability` 技能的 `references/version-diff.md`，不在此重复。

## 五、JDK 语言特性

- JDK 8 档禁用：`record`、`sealed`、`var`、文本块、`List.of`/`Map.of`/`Set.of`、`Optional.isEmpty`、`Stream.toList()`、`String.isBlank`/`strip`/`repeat`、switch 表达式、`instanceof` 模式匹配。
- JDK 17 档可用上述写法，但命名、常量、集合与并发写法仍按 `java-spec` 执行，不因版本高就放松。
- 只改 IDE 语言级别、不改 pom 的编译级别，会导致本地能跑、CI 失败；以 `<maven.compiler.release>` 为准。

## 六、核对方式与边界

确认某个类或方法在目标版本是否存在，用实际 jar，不靠记忆：

```powershell
javap -classpath "$env:USERPROFILE\.m2\repository\org\springframework\boot\spring-boot-autoconfigure\<版本>\spring-boot-autoconfigure-<版本>.jar" org.springframework.boot.autoconfigure.amqp.RabbitProperties
```

```powershell
mvn dependency:tree -Dincludes=org.springframework.amqp
```

- 本表只覆盖高频项，不追求穷举；表中没有的库按官方兼容矩阵核对，禁止按印象给出坐标。
- 版本差异只在「坐标 / 配置键 / 命名空间 / API」四层内讨论；业务逻辑、分层与设计规范不因档位不同而变，两档共用同一套 `SKILL.md` 铁律。
- 因「IDE 标了弃用」而升级大版本不在本技能建议范围内：先看本档位是否已有替代 API，能就地改写法就不要动框架版本。
