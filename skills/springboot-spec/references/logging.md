# 日志输出与 Logback 配置

## 输出基线策略

- **默认**：控制台 + 滚动日志文件（按**时间 + 大小**切分）。
- **仅当明确要求关注/分离错误日志时**：在默认基础上追加一个独立的 ERROR 日志文件。
- **配置文件（强制）**：固定产出 `src/main/resources/logback-spring.xml`，禁用 `logback.xml`（后者会在 Spring Boot 初始化前直接加载，`<springProfile>`/`<springProperty>` 全部失效）。`application.yml` 的 `logging.*` 只负责路径与级别覆盖，不能替代 XML 交付物。
- **XML 结构（强制）**：必须 `include org/springframework/boot/logging/logback/defaults.xml`，encoder 的 pattern 使用内置 `${CONSOLE_LOG_PATTERN}` / `${FILE_LOG_PATTERN}`，禁止自定义 `LOG_PATTERN` 变量（否则丢掉 Spring Boot 的默认格式与颜色规则，`logging.pattern.*` 也会失效）。
- **代码层日志写法**：见 `SKILL.md` 核心铁律第 4 条（SLF4J + `{}` 占位符 + 异常对象末位传参）。

## 版本适配（JDK 8 / Spring Boot 2.x 与 JDK 17+ / Spring Boot 3.x）

| 维度 | JDK 8 → Spring Boot 2.x（Logback 1.2.x） | JDK 17+ → Spring Boot 3.x（Logback 1.4.x/1.5.x） |
| ---- | ---- | ---- |
| `SizeAndTimeBasedRollingPolicy` | ✅ 可用（Logback 1.1.7+ 即有） | ✅ 可用 |
| `SizeAndTimeBasedFNATP`（旧写法） | ⚠️ 仍可运行但早已弃用 | ❌ Logback 1.5.8+ 已重命名移除，Spring Boot 3.3.4+/3.4+ 抛 `ClassNotFoundException` 启动失败 |
| 纯 YAML `logging.logback.rollingpolicy.*` | ✅ 需 Spring Boot **2.2+** | ✅ |
| `logging.file.name` / `logging.file.path` | ✅ 需 Spring Boot **2.2+**（2.0/2.1 用旧的 `logging.file` / `logging.path`） | ✅ |

**结论**：`SizeAndTimeBasedRollingPolicy` 是 JDK 8 与 JDK 17+ **通用且唯一推荐**的写法——JDK 8 环境无需为了兼容而保留旧的 `SizeAndTimeBasedFNATP`。本文件所有配置在 Spring Boot 2.2+（含 2.7.x，JDK 8 的最后主线）与 3.x 上均可直接使用。

> 若必须停留在 Spring Boot 2.0/2.1：把 `logging.file.name` 换成 `logging.file`，把 `logging.logback.rollingpolicy.max-file-size/max-history` 换成 `logging.file.max-size/max-history`；或直接采用本文件的 `logback-spring.xml` 方案（XML 写法不受这些属性版本影响）。

## Spring Boot 内置变量（可直接在 XML 中使用）

| 变量 | 来源属性 | 说明 |
| ---- | -------- | ---- |
| `${LOG_FILE}` | `logging.file.name` | 主日志文件全路径 |
| `${LOG_PATH}` | `logging.file.path` | 日志目录 |
| `${CONSOLE_LOG_PATTERN}` / `${FILE_LOG_PATTERN}` | `logging.pattern.*` / `defaults.xml` | 控制台/文件输出格式 |

> 不要再自定义与内置变量同名的 `springProperty`（如 `name="LOG_PATH" source="logging.file.name"`），否则会与 Spring Boot 内置含义冲突且往往未被引用。

## 方案一：默认输出（控制台 + 文件，时间 + 大小切分）

### 交付物：logback-spring.xml（新建工程必须产出）

XML 是唯一交付物，appender、滚动策略、编码全部在 XML 内定义（模板见「XML 模板」一节）；下面的 `application.yml` 片段只是可选的路径/级别覆盖，缺失不影响 XML 生效。

### 可选覆盖：application.yml（只管路径与级别）

```yaml
logging:
  level:
    root: info
  # 注意：自定义 logback-spring.xml 后，logging.logback.rollingpolicy.* 不再生效，
  # 滚动策略只能在 XML 中定义，YAML 里禁止重复配置
```

### XML 模板（方案一与方案二共用）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>

    <!-- 引入 Spring Boot 默认变量：CONSOLE_LOG_PATTERN、FILE_LOG_PATTERN 等 -->
    <include resource="org/springframework/boot/logging/logback/defaults.xml"/>

    <!-- 控制台输出 -->
    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>${CONSOLE_LOG_PATTERN}</pattern>
            <charset>UTF-8</charset>
        </encoder>
    </appender>

    <!-- 文件输出：时间 + 大小滚动。路径写死，避免未配 logging.file.name 时 ${LOG_FILE} 解析为空 -->
    <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>logs/app.log</file>
        <rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
            <!-- 时间 + 大小滚动，fileNamePattern 必须包含 %i -->
            <fileNamePattern>logs/app.%d{yyyy-MM-dd}.%i.log.gz</fileNamePattern>
            <maxFileSize>10MB</maxFileSize>
            <maxHistory>90</maxHistory>
            <totalSizeCap>1GB</totalSizeCap>
        </rollingPolicy>
        <encoder>
            <pattern>${FILE_LOG_PATTERN}</pattern>
            <charset>UTF-8</charset>
        </encoder>
    </appender>

    <!-- root 级别会被 application.yml 的 logging.level.root 覆盖，此处仅作兜底默认 -->
    <root level="INFO">
        <appender-ref ref="CONSOLE"/>
        <appender-ref ref="FILE"/>
    </root>
</configuration>
```

## 方案二：需要单独关注错误日志（控制台 + 文件 + 独立 ERROR 文件）

在方案一基础上追加一个 ERROR appender，用 `LevelFilter` 精确过滤 ERROR 级别。

```yaml
logging:
  file:
    name: ./logs/app.log        # 方案二 XML 用 ${LOG_FILE} 时需要
  # 自定义错误日志路径（非 Spring Boot 标准属性，通过 springProperty 读取）
  error:
    file:
      name: ./logs/app-error.log
  level:
    root: info
  # 滚动策略在 XML 中定义，logging.logback.rollingpolicy.* 在自定义 XML 下不生效
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>

    <include resource="org/springframework/boot/logging/logback/defaults.xml"/>

    <!-- 错误日志文件路径：来自自定义键 logging.error.file.name -->
    <springProperty scope="context" name="ERROR_LOG_FILE" source="logging.error.file.name"
                    defaultValue="./logs/app-error.log"/>

    <!-- 控制台输出 -->
    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>${CONSOLE_LOG_PATTERN}</pattern>
            <charset>UTF-8</charset>
        </encoder>
    </appender>

    <!-- 主文件输出：时间 + 大小滚动 -->
    <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>${LOG_FILE}</file>
        <rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
            <fileNamePattern>${LOG_FILE}.%d{yyyy-MM-dd}.%i</fileNamePattern>
            <maxFileSize>10MB</maxFileSize>
            <maxHistory>90</maxHistory>
            <totalSizeCap>1GB</totalSizeCap>
        </rollingPolicy>
        <encoder>
            <pattern>${FILE_LOG_PATTERN}</pattern>
            <charset>UTF-8</charset>
        </encoder>
    </appender>

    <!-- 独立错误日志：只记录 ERROR 级别，同样按时间 + 大小滚动 -->
    <appender name="ERROR_FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <filter class="ch.qos.logback.classic.filter.LevelFilter">
            <level>ERROR</level>
            <onMatch>ACCEPT</onMatch>
            <onMismatch>DENY</onMismatch>
        </filter>
        <file>${ERROR_LOG_FILE}</file>
        <rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
            <fileNamePattern>${ERROR_LOG_FILE}.%d{yyyy-MM-dd}.%i</fileNamePattern>
            <maxFileSize>10MB</maxFileSize>
            <maxHistory>90</maxHistory>
            <totalSizeCap>1GB</totalSizeCap>
        </rollingPolicy>
        <encoder>
            <pattern>${FILE_LOG_PATTERN}</pattern>
            <charset>UTF-8</charset>
        </encoder>
    </appender>

    <root level="INFO">
        <appender-ref ref="CONSOLE"/>
        <appender-ref ref="FILE"/>
        <appender-ref ref="ERROR_FILE"/>
    </root>
</configuration>
```

## 过滤器选型（错误日志用哪个 Filter）

- **只记录某个精确级别**（如仅 ERROR）：`LevelFilter`，`onMatch=ACCEPT` + `onMismatch=DENY`。
- **限制「某级别及以上」**（如控制台只显示 WARN 及以上、拒绝 DEBUG）：`ThresholdFilter`。

## 常见坑

- **统一用 `SizeAndTimeBasedRollingPolicy`，禁用 `SizeAndTimeBasedFNATP`**：后者在 JDK 8 / Spring Boot 2.x（Logback 1.2.x）下虽仍可运行但早已弃用；在 JDK 17+ / Spring Boot 3.3.4+（Logback 1.5.8+ 重命名移除）会抛 `ClassNotFoundException: ch.qos.logback.core.rolling.SizeAndTimeBasedFNATP` 导致启动失败。`SizeAndTimeBasedRollingPolicy` 跨版本通用（`maxFileSize`/`maxHistory`/`totalSizeCap` 为其直接子元素）。
- **`SizeAndTimeBasedRollingPolicy` 的 `fileNamePattern` 必须含 `%i`**，否则报 `Missing integer token, that is %i, in FileNamePattern ...`。
- **XML 里的 `<root level>`/`<logger level>` 会被 `application.yml` 的 `logging.level.*` 覆盖**（由 `SpringBootJoranConfigurator` 在加载后应用），XML 中的级别只作兜底默认，改级别应改 YAML。
- **元素名统一小写**（`<file>`、`<fileNamePattern>`），与 Spring Boot 内置片段保持一致；Logback 虽大小写不敏感，但混用易误导。
- **大小切分有延迟（仅 JDK 17+ / Spring Boot 3.x，Logback 1.3.12+/1.4.12+）**：出于性能，文件体积检查默认每 60 秒一次，活动文件可能短暂超过 `maxFileSize` 才滚动，且归档在下一条日志到达时才触发；JDK 8 / Spring Boot 2.x（Logback 1.2.x）为每条日志即时检查，无此延迟。
