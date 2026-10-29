# API 文档（Knife4j + OpenAPI3）

## 选型基线

- **强制**：对外 HTTP 接口必须提供在线 API 文档，统一采用 **Knife4j**（基于 `springdoc-openapi` / **OpenAPI3** 规范的国产增强 UI），访问入口 `http://{ip}:{port}/doc.html`。
- **强制**：Spring Boot 2.x 与 3.x **一律走 OpenAPI3 线**，注解统一使用 `@Tag` / `@Operation` / `@Schema`；**禁止使用已停止维护的 `springfox`（OpenAPI2）**——它在 Spring Boot 2.6+ 会因路径匹配策略变更启动崩溃，在 Boot 3.x 完全不兼容。
- **说明**：Knife4j 已内置对应版本的 `springdoc-openapi`，**无需**再单独引入 `springdoc-openapi-*` 依赖。
- **说明**：存量老项目若仍在用 `springfox` + `@Api/@ApiOperation`，按本文件迁移到 OpenAPI3，不要在新代码里继续用 springfox。

## 版本适配（依赖选型）

| Spring Boot | JDK | groupId | artifactId | 版本 |
| ---- | ---- | ---- | ---- | ---- |
| 2.6 ~ 2.7（2.x 末代主线） | 8+ | `com.github.xiaoymin` | `knife4j-openapi3-spring-boot-starter` | `4.5.0` |
| 3.0 ~ 3.3 | 17+ | `com.github.xiaoymin` | `knife4j-openapi3-jakarta-spring-boot-starter` | `4.5.0` |
| 3.4 / 3.5+ | 17+ | `com.baizhukui` | `knife4j-openapi3-jakarta-spring-boot-starter` | `5.x`（如 `5.4.0`，以 knife4jnext.com 最新为准） |

**关键结论**：

- **Boot 3.x 必须选带 `jakarta` 后缀的 artifactId**（javax → jakarta 命名空间变更），否则启动报错。
- 原版 `com.github.xiaoymin:4.5.0` 官方仅标注适配到 Boot 3.0，在 Boot **3.4/3.5** 会因内置 springdoc 版本过旧出现「文档打不开 / 接口无法识别 / 404」；此时切换到社区活跃维护的 fork `com.baizhukui`（knife4j-next）`5.x` 即可——**drop-in 替换，仅改 groupId**：Java 包名（`com.github.xiaoymin.knife4j.*`）、`doc.html` 入口、全部注解与 `knife4j.*` 配置键均保持不变，业务代码无需改动。

## 接入步骤

### 第一步：引入依赖（`pom.xml`，按 Boot 版本三选一）

```xml
<!-- Spring Boot 2.6 ~ 2.7 -->
<dependency>
    <groupId>com.github.xiaoymin</groupId>
    <artifactId>knife4j-openapi3-spring-boot-starter</artifactId>
    <version>4.5.0</version>
</dependency>

<!-- Spring Boot 3.0 ~ 3.3 -->
<dependency>
    <groupId>com.github.xiaoymin</groupId>
    <artifactId>knife4j-openapi3-jakarta-spring-boot-starter</artifactId>
    <version>4.5.0</version>
</dependency>

<!-- Spring Boot 3.4 / 3.5+：社区 fork，仅 groupId 不同 -->
<dependency>
    <groupId>com.baizhukui</groupId>
    <artifactId>knife4j-openapi3-jakarta-spring-boot-starter</artifactId>
    <version>5.4.0</version>
</dependency>
```

### 第二步：配置 `application.yml`（2.x / 3.x 通用）

```yaml
knife4j:
  enable: true                 # 开启 Knife4j 增强
  setting:
    language: zh_cn            # 界面语言，默认即 zh_cn

springdoc:
  api-docs:
    enabled: true
    path: /v3/api-docs         # OpenAPI JSON 路径（默认值）
  swagger-ui:
    path: /swagger-ui.html     # springdoc 原生 UI；Knife4j 增强 UI 走 /doc.html
  packages-to-scan: com.example.user.controller   # 收窄扫描范围，避免全量扫描拖慢启动
  group-configs:               # 多分组（可选，按需拆分模块）
    - group: 用户模块
      packages-to-scan: com.example.user.controller
    - group: 订单模块
      packages-to-scan: com.example.order.controller
```

### 第三步：声明文档标题/版本（`OpenAPI` Bean）

> **OpenAPI3 下 `knife4j.openapi.title` / `version` 无效**（那是 openapi2/springfox 专用键）。标题、版本、描述必须通过 `OpenAPI` Bean 的 `info` 设置。

```java
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("用户中心 API 文档")
                        .version("1.0.0")
                        .description("用户中心对外接口文档"));
    }
}
```

> 需要全局 JWT/Bearer 调试时，在同一 Bean 上追加 `.components(...)` 注册 `SecurityScheme` 并 `.addSecurityItem(...)`；密钥类信息不要写进文档描述。

### 第四步：访问

启动应用后浏览器打开 `http://localhost:8080/doc.html` 即可看到增强文档与在线调试界面。

## 注解规范（OpenAPI3）

### Controller 强制清单（最高优先级）

生成或修改任何 Controller 代码时逐条满足，缺一即视为不合规，不得交付。

| 编号 | 位置 | 强制要求 | 注解 |
| ---- | ---- | -------- | ---- |
| C1 | Controller 类 | 必须有；`name` 写业务模块名，`description` 写职责边界 | `@Tag(name, description)` |
| C2 | 每个映射方法 | 必须有；`summary` 写“做什么事”（动宾短语），`description` 写前置条件、副作用、权限要求 | `@Operation(summary, description)` |
| C3 | 路径变量、查询参数、请求头 | 逐参数必须有；`description` 写含义与取值范围，`required` 与业务一致 | `@Parameter(description, required)` |
| C4 | 请求体 | 不给参数加 `@Parameter`；类与每个字段都用 `@Schema` 描述，语义写在 `@Operation(description)` | `@Schema` |
| C5 | 返回值 | 每个方法至少一条成功响应；`responseCode` 用该接口实际返回码（对齐 `api-design.md`），schema 交给自动推断 | `@ApiResponse(responseCode, description)` |
| C6 | 编译参数 | `pom.xml` 必须开启 `-parameters`，否则参数名丢失、文档里出现 `arg0` | `<parameters>true</parameters>` |

两条最容易写错的细节：

- **C4 的注解同名冲突**：`io.swagger.v3.oas.annotations.parameters.RequestBody` 与 Spring 的 `@RequestBody` 同名，同一文件无法同时 import。需要单独描述请求体时写全限定名，禁止同时 import 两个 `RequestBody`。
- **C5 不要把 schema 写死**：写 `content = @Content(schema = @Schema(implementation = XxxVO.class))` 会把统一响应体 `Result<XxxVO>` 的 schema 覆盖为 `XxxVO`，与实际返回不符。默认不写 `content`，仅当需要刻意覆盖时才写。

多个响应可直接重复 `@ApiResponse`（swagger-core 2.x 起可重复），也可用 `@ApiResponses` 包裹，二者等价。

C6 的配置写法（Spring Boot 3.2+ 换用自定义父 pom、或未继承 `spring-boot-starter-parent` 时必须显式声明；继承了该 parent 时它已配置，显式声明幂等无害）：

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-compiler-plugin</artifactId>
    <configuration>
        <parameters>true</parameters>
    </configuration>
</plugin>
```

背景：Spring Framework 6.1 删除了基于字节码推断参数名的 `LocalVariableTableParameterNameDiscoverer`，不再传 `-parameters` 时参数名丢失，文档里会出现 `arg0`、`arg1`。

### 版本与注解包映射

“是否换注解”与“是否换依赖”是两件事，先分清再动手：

| Spring Boot | JDK | Knife4j 依赖（groupId:artifactId） | Swagger 注解包 | Bean Validation 包 |
| ---- | ---- | ---- | ---- | ---- |
| 2.6 ~ 2.7 | 8 / 11 / 17 | `com.github.xiaoymin:knife4j-openapi3-spring-boot-starter:4.5.0`（内置 springdoc 1.x） | `io.swagger.v3.oas.annotations.*` | `javax.validation.constraints.*` |
| 3.0 ~ 3.3 | 17+ | `com.github.xiaoymin:knife4j-openapi3-jakarta-spring-boot-starter:4.5.0`（springdoc 2.x） | 同上，不变 | `jakarta.validation.constraints.*` |
| 3.4 / 3.5+ | 17 / 21 | `com.baizhukui:knife4j-openapi3-jakarta-spring-boot-starter:5.x` | 同上，不变 | `jakarta.validation.constraints.*` |

**结论：三条线的 Swagger 注解包完全一致**（都来自 swagger-core v3），升级 Boot 或 JDK 时**只换依赖坐标与校验/Servlet 命名空间，不换注解**。把 `@Tag/@Operation/@Parameter/@ApiResponse/@Schema` 当成 Boot 3 专用，是常见误解。

必填字段优先用 Bean Validation（`@NotBlank`/`@NotNull`）表达，springdoc 自动识别，跨版本安全；要用 `@Schema(requiredMode = Schema.RequiredMode.REQUIRED)` 需 swagger-core ≥ 2.2.5（springdoc 1.7+ 与 2.x 均满足），旧的 `required = true` 已弃用，新代码不得再写。

### 注解对照

| 标注位置 | OpenAPI3 注解（**用**） | 旧 OpenAPI2 / springfox（**禁用**） |
| ---- | ---- | ---- |
| Controller 类 | `@Tag(name, description)` | `@Api` |
| 接口方法 | `@Operation(summary, description)` | `@ApiOperation` |
| 方法参数 | `@Parameter(description, required)`（写在参数上；写在方法级时才需要 `name`） | `@ApiParam` / `@ApiImplicitParam` |
| 请求体/模型类 | `@Schema(description)` | `@ApiModel` |
| 模型字段 | `@Schema(description, example)` | `@ApiModelProperty` |
| 响应 | `@ApiResponse(responseCode, description)` | `@ApiResponses`（旧包 `io.swagger.annotations`） |

Knife4j 增强注解（包 `com.github.xiaoymin.knife4j.annotations`）：

- `@ApiSupport(order = n)`：类/Tag 层级排序。
- `@ApiOperationSupport(order = n)`：接口方法排序。
- `@DynamicParameter` / `@DynamicResponseParameters`：动态请求/响应参数。

### Controller 示例

以下示例同时覆盖 C1～C6，Spring Boot 3.x + JDK 17 可直接使用；Spring Boot 2.x + JDK 8 仅需把 `jakarta.validation.*` 换回 `javax.validation.*`。

```java
@Tag(name = "用户管理", description = "用户的创建、查询、更新与删除")
@ApiSupport(order = 1)
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @Operation(summary = "创建用户", description = "注册新用户；用户名重复时返回 409")
    @ApiOperationSupport(order = 1)
    @ApiResponse(responseCode = "201", description = "创建成功，返回新用户 ID")
    @ApiResponse(responseCode = "409", description = "用户名已存在")
    @PostMapping
    public Result<Long> create(@Valid @RequestBody UserCreateDTO dto) {
        return Result.ok(userService.create(dto));
    }

    @Operation(summary = "查询用户详情", description = "按用户 ID 查询；用户不存在返回 404")
    @ApiOperationSupport(order = 2)
    @ApiResponse(responseCode = "200", description = "查询成功，返回用户详情")
    @ApiResponse(responseCode = "404", description = "用户不存在")
    @GetMapping("/{id}")
    public Result<UserVO> detail(
            @Parameter(description = "用户 ID", required = true) @PathVariable Long id) {
        return Result.ok(userService.detail(id));
    }

    @Operation(summary = "分页查询用户", description = "按用户名模糊匹配，按创建时间倒序")
    @ApiResponse(responseCode = "200", description = "查询成功，返回分页数据")
    @GetMapping
    public Result<PageResult<UserVO>> page(
            @Parameter(description = "用户名关键字，可为空") @RequestParam(required = false) String username,
            @Parameter(description = "页码，从 1 开始", required = true) @RequestParam(defaultValue = "1") Integer page,
            @Parameter(description = "每页条数，最大 100", required = true) @RequestParam(defaultValue = "10") Integer size,
            @Parameter(description = "租户标识，网关透传", required = false) @RequestHeader("X-Tenant-Id") String tenantId) {
        return Result.ok(userService.page(username, page, size));
    }
}
```

### DTO 示例

```java
@Schema(description = "用户创建请求")
public class UserCreateDTO {

    @Schema(description = "用户名", example = "zhangsan")
    @NotBlank(message = "用户名不能为空")
    private String username;

    @Schema(description = "年龄", example = "18")
    @Min(value = 0, message = "年龄不能为负")
    private Integer age;
}
```

> 字段「是否必填」优先用 Bean Validation（`@NotBlank`/`@NotNull` 等）表达，springdoc 会自动识别；如需在文档上额外标注，用 `@Schema(requiredMode = Schema.RequiredMode.REQUIRED)`（较老版本为已弃用的 `required = true`）。

### 参数注解归属

不同来源的参数，注解位置不同，不可一刀切：

| 参数来源 | Spring 注解 | Swagger 注解 | 关键点 |
| --- | --- | --- | --- |
| 路径变量 | `@PathVariable` | `@Parameter(description, required = true)` | 路径变量恒为必填 |
| 查询参数 | `@RequestParam` | `@Parameter(description)` | 非必填必须显式写 `required = false`；springdoc 1.x 中 GET 参数默认按必填展示（官方 FAQ） |
| 请求头 | `@RequestHeader` | `@Parameter(description, required)` | 鉴权类头写 required=true，透传类头写 false |
| 请求体 | `@RequestBody` | 不给参数加；描述写在 DTO 的 `@Schema` 与 `@Operation(description)` | 禁止与 Swagger 的 `RequestBody` 同名注解共文件 import |
| 分页/排序 POJO | `@ParameterObject` | 不给参数加 | 只在 POJO 字段上用 `@Schema`；不支持嵌套对象展开 |
| 无参方法 | — | 仍需 `@Operation` + `@ApiResponse` | 不能因无参数就省掉方法级注解 |

### 自检与验收

生成 Controller 后按以下顺序核对，任一项不通过即视为不合规：

```bat
:: 1. 列出所有 Controller 文件
findstr /s /m /c:"@RestController" src\main\java\*.java

:: 2. 统计映射方法数（不含类级 @RequestMapping）
findstr /s /c:"@GetMapping" /c:"@PostMapping" /c:"@PutMapping" /c:"@PatchMapping" /c:"@DeleteMapping" src\main\java\*.java | find /c "Mapping"

:: 3. 统计 @Operation 数，结果应等于第 2 步（或更大，含隐藏接口）
findstr /s /c:"@Operation" src\main\java\*.java | find /c "@Operation"
```

启动后打开 `/v3/api-docs`（Knife4j 为 `doc.html`），逐项确认：

1. 每个 tag 的 `description` 非空，每个 operation 的 `summary` 非空。
2. 每个参数都有 `description`，不出现 `arg0`、`param1` 这类自动生成名（出现即 C6 未生效）。
3. 每个 operation 的 `responses` 至少包含一条成功码，且没有 schema 解析异常。
4. 页面无 500：schema 解析报错多见于 swagger-core 版本与 `requiredMode` 不匹配，按“常见坑”排查。

## 生产环境安全

- **强制**：生产环境禁止文档裸奔。二选一或叠加：
  - `knife4j.production: true`——直接屏蔽 `doc.html` / `v3/api-docs` 等资源（最简单）。
  - `knife4j.basic`（HTTP Basic）或 Spring Security——保留文档但加访问控制。
- **强制**：文档账号密码等敏感配置从环境变量注入，禁止硬编码（呼应核心铁律第 6 条数据安全）。

```yaml
knife4j:
  production: true             # 生产屏蔽文档
  # 或改为鉴权访问：
  basic:
    enable: true
    username: admin
    password: ${DOC_PASSWORD}  # 从环境变量注入
```

## 常见坑

- **Boot 3.x 忘记加 `jakarta`**：用了非 jakarta 的 `knife4j-openapi3-spring-boot-starter`（内置 springdoc 1.x）会启动失败；3.x 必须用 `-jakarta-` 版。
- **继续用 springfox**：Boot 2.6+ 报 `Failed to start bean 'documentationPluginsBootstrapper' ... NullPointerException`（默认路径匹配由 `AntPathMatcher` 改为 `PathPatternParser`）。不要用 `spring.mvc.pathmatch.matching-strategy=ant_path_matcher` 去硬救 springfox（治标不治本，且与 Actuator 冲突），应直接迁移到 OpenAPI3 线。
- **Boot 3.4/3.5 + 原版 4.5.0**：springdoc 版本过旧导致 `doc.html` 打不开或接口无法识别；改用 `com.baizhukui` 5.x（drop-in），或保留 4.5.0 但 `<exclusions>` 排除并强制升级到匹配的 springdoc 版本。
- **标题/版本不生效**：OpenAPI3 下 `knife4j.openapi.*` 无效，必须用 `OpenAPI` Bean 的 `info` 设置。
- **WebMvc 与 WebFlux starter 混用**：二者不能同时引入，按应用类型（Servlet / 响应式）二选一。
- **扫描范围过大**：不配 `springdoc.packages-to-scan` 会全量扫描，拖慢启动且暴露无关端点，务必收窄到 controller 包。
