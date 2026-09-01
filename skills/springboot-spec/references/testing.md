# 单元测试规范

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
