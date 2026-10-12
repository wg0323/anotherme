# 单元测试规范

## 构建默认跳过测试（新建工程必配）

新建 SpringBoot 工程时，必须在 `pom.xml` 的 `<properties>` 中默认跳过测试，使 `mvn compile`、`mvn package`、`mvn install` 全程自动跳过测试的编译与执行，无需每次手动传参。

```xml
<properties>
    <!-- 跳过测试编译与执行；compile/package/install 均生效 -->
    <maven.test.skip>true</maven.test.skip>
</properties>
```

- **强制**：使用 `maven.test.skip=true`（同时跳过测试的**编译**与**执行**），而非仅 `skipTests=true`（只跳过执行、仍会编译测试代码）。这样才能在 `compile` 阶段也生效。
- **说明**：需要临时运行测试时（如 CI 流水线），命令行覆盖即可，无需改动 pom：`mvn test -Dmaven.test.skip=false` 或 `mvn install -Dmaven.test.skip=false`。
- **说明**：此配置仅改变默认构建行为，不影响 `src/test` 下测试代码本身的编写与命名规范；下述规范在编写测试时仍须遵守。

## 测试命名规范

- **强制**：测试类以 `Test` 结尾。
- **强制**：测试方法使用 `should_{预期结果}_when_{条件}` 或 `test_{方法名}_{场景}` 格式。
- **强制**：测试类与被测试类包结构一致。

```
src/main/java/com/example/user/service/impl/UserServiceImpl.java
src/test/java/com/example/user/service/impl/UserServiceImplTest.java
```

## 测试覆盖要求

- **强制**：核心业务逻辑代码覆盖率不低于 **80%**。
- **强制**：以下场景必须编写单元测试：
  - 复杂的业务逻辑。
  - 金额计算、状态流转。
  - 边界条件、异常分支。
  - 公共工具类方法。

## 运行测试的执行纪律

本节只管"怎么写测试"；实际运行测试（如 `mvn test -Dmaven.test.skip=false`）时的执行前预估、止损判定与卡住排查，遵循 `test-execution` 技能。
