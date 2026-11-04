# 测试有效性验证

回答一个问题：**AI 写的测试，真的在测东西吗？**

行覆盖率只能证明代码被执行过，不能证明结果被检查过。AI 完全可能写出"调用一遍、断言非空、全绿收工"的测试——覆盖率高，缺陷照样漏。

## 覆盖率的三层欺骗

| 层次 | 现象 | 例子 |
| --- | --- | --- |
| 执行了但没断言 | 覆盖率涨了，行为没验证 | `assertNotNull(result)`、`assertDoesNotThrow(() -> ...)` |
| 断言了但不是关键点 | 断言的是返回对象非空，不是金额与状态 | 扣款 100 只断言"返回成功"，不断言余额 |
| 断言的逻辑和实现同源 | 测试照实现写，实现错测试也错 | 实现把税率写成 0.13，测试也断言 0.13 |

前两层可以用审查抓，第三层只能靠**变异测试**——它不问"你断言了什么"，而是问"把代码改坏一点，你的测试会不会红"。

## 变异测试

原理：PIT 在字节码里注入小改动（把 `>` 改成 `>=`、删掉一次方法调用、把返回值改成 `null`），然后跑测试。测试失败叫"杀死"，测试仍通过叫"存活"。存活的变异体就是测试的盲区。

### 配置

```xml
<plugin>
    <groupId>org.pitest</groupId>
    <artifactId>pitest-maven</artifactId>
    <version>1.20.2</version>
    <dependencies>
        <dependency>
            <groupId>org.pitest</groupId>
            <artifactId>pitest-junit5-plugin</artifactId>
            <version>1.2.3</version>
        </dependency>
    </dependencies>
    <configuration>
        <targetClasses>
            <param>com.example.*.service.*</param>
        </targetClasses>
        <targetTests>
            <param>com.example.*.service.*Test</param>
        </targetTests>
        <mutationThreshold>70</mutationThreshold>
        <outputFormats>
            <outputFormat>HTML</outputFormat>
        </outputFormats>
        <threads>4</threads>
    </configuration>
</plugin>
```

`pitest` 与 `pitest-junit5-plugin` 必须版本匹配，且与 JDK 版本兼容；上面的版本号是示例，落地前查 Maven Central 当前版本。

```bash
mvn org.pitest:pitest-maven:mutationCoverage
```

报告在 `target/pit-reports/`，可以直接打开 `index.html`。

### 成本控制

变异测试是全套门禁里最慢的一项，必须限范围：

- **只跑 B 级核心包**，用 `targetClasses` 精确限定到 `service` 或 `domain`，不跑全项目。
- **只跑纯单元测试**。带 `@SpringBootTest` 的测试在 PIT 下启动上下文极慢，且 PIT 会改字节码，容易互相干扰。集成测试用冒烟覆盖，不进变异测试。
- **排除样板代码**。DTO、Entity、配置类、`converter` 的纯字段拷贝，排除掉，它们的变异体没有意义。
- **不进日常构建**，只在 B 级改动交付前、或发版前跑一次。

### 怎么读报告

不要只看总分。重点看**存活变异体列表**，逐个判断：

- 测试缺口 → 补测试；
- 等价变异体（改了但语义不变，如 `i++` 改 `i = i + 1`）→ 忽略；
- 不可达分支 → 说明是死代码，删掉比补测试更划算。

阈值参考：核心业务模块 70%，纯工具类可以更低。低于 50% 说明这批测试基本是摆设。

## 契约比对

### API 契约

最小版：把 OpenAPI 文档导出成文件提交进版本库，改动后看 diff。

```bash
# 启动应用后导出
curl -s http://localhost:8080/v3/api-docs -o docs/api/openapi.json

# 与上一版比较
git diff docs/api/openapi.json
```

自动版：用 `openapi-diff` 一类的 CLI 判"是否破坏性变更"（删字段、改类型、加必填），接进门禁。个人项目用 `git diff` 加人眼判断通常够用，但发布前必须看一眼。

### DB 契约

```bash
mvn flyway:validate
```

它校验已执行脚本的 checksum，能抓"改了历史上已跑过的脚本"——这是 AI 最容易犯的错之一（本地改完忘了别人已经执行过）。它抓不到"脚本能不能在新库上跑通"，后者要在影子库执行一次 `flyway:migrate`。

### 消息契约

MQ 消息体变更没有工具能自动比对，只能靠人工。改消息体时在交付证据里写清：字段增删、消费端是否已兼容、是否需要双写过渡期。

## 测试反模式清单

生成或审查测试代码时逐条对照，命中即视为测试无效：

- 只有 `assertNotNull` / `assertDoesNotThrow`，没有对结果的实质断言。
- 把被测类的核心依赖全部 mock，导致所有分支走进同一条桩路径。
- 用 `try { ... } catch (Exception ignored) {}` 包住断言，失败被吞。
- 断言写死实现细节（内部调用次数、私有方法顺序），重构即红。
- 只测正常路径，`E（Error）` 与边界值一条没有。
- 时间、随机数、线程调度未固定，跑两次结果不同。
- 用例之间共享静态可变状态，单独跑绿、一起跑红。
- 为了凑覆盖率写"调用一遍"的测试，`Tests run` 好看但零信息量。

## 什么时候可以不做

A 级改动、纯 DTO/Entity、纯配置、纯样式，不做变异测试。做了也是给自己找活。

判断标准只有一条：**这段代码写错，会不会有人受损或需要人工补救。** 会，就是 B 级，就需要变异测试或独立审查。
