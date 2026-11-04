# 架构约束规则（ArchUnit + Enforcer）

把 `java-spec`、`springboot-spec` 里"模型可能漏"的结构条款，变成"违反即构建失败"的断言。这是整套门禁里性价比最高的一层：写一次，之后每次 AI 生成都自动生效，且不需要你读代码。

## 边界

ArchUnit 只分析**字节码结构**：包与类的依赖、继承与实现、注解、命名。它不判方法体逻辑、不判运行时行为、不判业务语义。金额算错、事务边界错、越权，它一条都抓不到——那些归变异测试与独立审查。

## 接入

依赖（`scope` 必须是 `test`）：

```xml
<dependency>
    <groupId>com.tngtech.archunit</groupId>
    <artifactId>archunit-junit5</artifactId>
    <version>1.5.0</version>
    <scope>test</scope>
</dependency>
```

官方站 2026-08 发布 1.5.0；Maven Central 索引可能滞后，落地前用实际可拉取的版本替换。

测试类放在 `src/test/java` 与主包同级的 `ArchitectureTest.java`。因为 `pom.xml` 默认配了 `maven.test.skip`，验证时必须显式打开：

```bash
mvn test -Dmaven.test.skip=false -Dtest=ArchitectureTest
```

## 规则与现有条款的对应

| 现有条款 | 规则常量 | 手段 |
| --- | --- | --- |
| `springboot-spec` 铁律 3：Controller 不得越层调用 | `LAYERED_DEPENDENCY` | ArchUnit 分层 |
| 铁律 8：`service` 根包只放接口 | `SERVICE_ROOT_SHOULD_BE_INTERFACES` | ArchUnit |
| 铁律 8：`@Service` 只打在 `service.impl` | `SERVICE_ANNOTATION_ONLY_IN_IMPL` | ArchUnit |
| 铁律 1：禁止字段注入 | `NO_FIELD_INJECTION` | GeneralCodingRules |
| 铁律 4：禁止 `System.out` / `printStackTrace` | `NO_STANDARD_STREAMS` | GeneralCodingRules |
| 铁律 5：自定义业务异常继承 `RuntimeException` | `NO_GENERIC_EXCEPTIONS` | GeneralCodingRules |
| 铁律 10：Controller 必须 `@Tag` | `CONTROLLER_SHOULD_HAVE_TAG` | ArchUnit |
| 铁律 10：映射方法必须 `@Operation` | `CONTROLLER_METHOD_SHOULD_HAVE_OPERATION` | ArchUnit |
| 铁律 2：禁止 MapStruct | —— | maven-enforcer |

## 完整样例

```java
package com.example;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.library.GeneralCodingRules;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.methods;
import static com.tngtech.archunit.library.Architectures.layeredArchitecture;

@AnalyzeClasses(
        packages = "com.example",                          // 换成项目根包
        importOptions = ImportOption.DoNotIncludeTests.class)
class ArchitectureTest {

    @ArchTest
    static final ArchRule LAYERED_DEPENDENCY =
            layeredArchitecture().consideringAllDependencies()
                    .layer("Controller").definedBy("..controller..")
                    .layer("Service").definedBy("..service..")
                    .layer("Mapper").definedBy("..mapper..")
                    .whereLayer("Controller").mayNotBeAccessedByAnyLayer()
                    .whereLayer("Service").mayOnlyBeAccessedByLayers("Controller")
                    .whereLayer("Mapper").mayOnlyBeAccessedByLayers("Service")
                    .because("Controller 只调 Service，Service 只调 Mapper，禁止越层");

    @ArchTest
    static final ArchRule SERVICE_ROOT_SHOULD_BE_INTERFACES =
            classes().that().resideInAPackage("..service")
                    .should().beInterfaces()
                    .because("service 包只放接口，实现类放 service.impl");

    @ArchTest
    static final ArchRule SERVICE_ANNOTATION_ONLY_IN_IMPL =
            classes().that().areAnnotatedWith(Service.class)
                    .should().resideInAPackage("..service.impl..")
                    .because("@Service 只允许打在实现类上");

    @ArchTest
    static final ArchRule NO_FIELD_INJECTION =
            GeneralCodingRules.NO_CLASSES_SHOULD_USE_FIELD_INJECTION;

    @ArchTest
    static final ArchRule NO_STANDARD_STREAMS =
            GeneralCodingRules.NO_CLASSES_SHOULD_ACCESS_STANDARD_STREAMS;

    @ArchTest
    static final ArchRule NO_GENERIC_EXCEPTIONS =
            GeneralCodingRules.NO_CLASSES_SHOULD_THROW_GENERIC_EXCEPTIONS;

    @ArchTest
    static final ArchRule CONTROLLER_SHOULD_HAVE_TAG =
            classes().that().areAnnotatedWith(RestController.class)
                    .should().beAnnotatedWith(Tag.class)
                    .because("对外接口必须提供 Knife4j 文档分组");

    @ArchTest
    static final ArchRule CONTROLLER_METHOD_SHOULD_HAVE_OPERATION =
            methods().that().areDeclaredInClassesThat().areAnnotatedWith(RestController.class)
                    .and().arePublic()
                    .and().areMetaAnnotatedWith(RequestMapping.class)
                    .should().beAnnotatedWith(Operation.class)
                    .because("每个映射方法必须有一条 @Operation");
}
```

注意 `resideInAPackage` 的两种写法：`..service` 精确匹配根包，`..service..` 会把 `service.impl` 一起匹配进来。写错会让"只放接口"这条规则误伤实现类。

方法级规则里的 `areMetaAnnotatedWith(RequestMapping.class)` 用来识别 `@GetMapping`/`@PostMapping` 等派生注解。ArchUnit 1.x 支持该谓词；若你的版本不支持，改为逐个列出具体映射注解，或用自定义 `ArchCondition`。

## Maven Enforcer 禁令

ArchUnit 管结构，管不了"依赖里混进了什么"。这类用 `maven-enforcer-plugin`：

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-enforcer-plugin</artifactId>
    <version>3.5.0</version>
    <executions>
        <execution>
            <id>ban-forbidden-dependencies</id>
            <goals><goal>enforce</goal></goals>
            <configuration>
                <rules>
                    <bannedDependencies>
                        <excludes>
                            <exclude>org.mapstruct:*</exclude>
                        </excludes>
                        <message>禁止引入 MapStruct：对象转换统一用 converter 包的静态方法</message>
                    </bannedDependencies>
                </rules>
            </configuration>
        </execution>
    </executions>
</plugin>
```

同理可禁 `org.springframework.boot:spring-boot-starter-log4j2`（统一 Logback）。每加一条禁令，写清"对应哪条技能条款"，否则半年后没人知道为什么禁。

## 存量代码：冻结而不是追缴

老项目第一次跑，往往一片红。直接关规则等于没做，硬改历史代码又不值得。用 `FreezingArchRule` 把当前违规冻结成基线，只对新增违规报错：

```java
@ArchTest
static final ArchRule NO_FIELD_INJECTION =
        FreezingArchRule.freeze(GeneralCodingRules.NO_CLASSES_SHOULD_USE_FIELD_INJECTION);
```

基线文件提交进版本库。后续只允许减少，不允许增加；冻结文件里的条目被消化掉就删掉对应行。存储路径与再冻结开关通过 `archunit.properties` 配置（键名以当前版本 User Guide 为准，常见为 `freeze.store.default.path`、`freeze.refreeze`）。

## 假绿的四个来源

**包扫描路径写错**。规则匹配到 0 个类时测试照样"通过"。ArchUnit 0.23 起默认对空匹配集报错，**不要**为了跑通去打开 `allowEmptyShould(true)`——那会把路径写错伪装成合规。

**没排除测试类**。测试类被扫进 `..service..`，会被判成"不是接口"。

**规则只写了类级**。`@Tag` 在类上、`@Operation` 在方法上，只写类级规则等于没查方法注解。

**用 `@ArchIgnore` 消红**。会在规则层面永久失效且无人复查。要豁免就写进冻结基线，让它可见、可追踪。

## 规则准入与退役

- 首次只上 5~8 条，每条注明"防哪一次真实事故"。写不出对应事故的规则不上。
- 新规则先进观察档：只输出报告不 fail build，跑两周确认误报率为 0 再转强制。
- 连续三个月零违规、且期间没有对应事故的规则，删掉。规则也是要付维护成本的。
- 规则被删或被放宽，必须在提交信息里写明原因，否则下一次 AI 会把它加回来。
