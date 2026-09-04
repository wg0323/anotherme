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

| 标注位置 | OpenAPI3 注解（**用**） | 旧 OpenAPI2 / springfox（**禁用**） |
| ---- | ---- | ---- |
| Controller 类 | `@Tag(name, description)` | `@Api` |
| 接口方法 | `@Operation(summary, description)` | `@ApiOperation` |
| 方法参数 | `@Parameter(name, description, required)` | `@ApiParam` / `@ApiImplicitParam` |
| 请求体/模型类 | `@Schema(description)` | `@ApiModel` |
| 模型字段 | `@Schema(description, example)` | `@ApiModelProperty` |
| 响应 | `@ApiResponse(responseCode, description)` | `@ApiResponses`（旧包） |

Knife4j 增强注解（包 `com.github.xiaoymin.knife4j.annotations`）：

- `@ApiSupport(order = n)`：类/Tag 层级排序。
- `@ApiOperationSupport(order = n)`：接口方法排序。
- `@DynamicParameter` / `@DynamicResponseParameters`：动态请求/响应参数。

### Controller 示例

```java
@Tag(name = "用户管理", description = "用户的增删改查")
@ApiSupport(order = 1)
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @Operation(summary = "创建用户", description = "注册一个新用户")
    @ApiOperationSupport(order = 1)
    @PostMapping
    public Result<Long> create(@Valid @RequestBody UserCreateDTO dto) {
        return Result.ok(userService.create(dto));
    }

    @Operation(summary = "查询用户详情")
    @Parameter(name = "id", description = "用户ID", required = true)
    @GetMapping("/{id}")
    public Result<UserVO> detail(@PathVariable Long id) {
        return Result.ok(userService.detail(id));
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
