# anotherme

跨 IDE 的个人知识与技能仓库。把沉淀的开发规范、成熟方案、样例代码组织为标准 **Agent Skill**（`SKILL.md` 格式），一次编写，通过目录联接（junction）实时安装到所有支持 skill 的 IDE / agent。

修改技能**内容**后，所有已安装的 IDE 立即生效、无需重装；仅当**新增 / 删除 / 重命名技能文件夹**时才需重跑安装脚本（详见下方“修改技能后的同步”小节）。

## 目录结构

```
.
├── docs\            # rule 资料库
│   ├── common_rule.md  # 唯一保留的 always_on rule（跨场景硬约束，已瘦身，随版本库跟踪）
│   └── archive\     # 已迁移为 skill 的历史 rule（存档，不再被 IDE 加载，不随版本库跟踪）
├── skills\          # 技能仓库（唯一真相源）
│   ├── gitflow\     # 示例技能：GitFlow 工作流规范
│   └── _template\   # 新建技能的模板（下划线开头，不会被安装）
└── scripts\
    ├── install.bat      # 安装：为各 IDE 创建指向 skills\ 的目录联接（末尾自动同步规则）
    ├── uninstall.bat    # 卸载：仅移除指向本仓库的联接，不碰其他内容
    ├── sync-rules.bat   # 规则同步入口（启动 sync-rules.ps1）
    └── sync-rules.ps1   # 规则同步实现：保留 .mdc 头部、重建 CLAUDE.md 标记块
```

## 当前技能清单

| 技能 | 来源 | 适用场景 |
| ---- | ---- | -------- |
| `gitflow` | git_rule | commit 规范、分支生命周期、发版/热修复流程 |
| `rabbitmq-reliability` | rabbitmq_rule | SpringBoot 接入 RabbitMQ，消息不丢不重，含完整样例代码与检查清单 |
| `springboot-spec` | springboot_rule | SpringBoot 工程结构、RESTful API、依赖注入、日志异常、单测、新建工程 README 交付 |
| `java-spec` | java_rule + vscode_rule | Java 编码强制规范；VSCode Maven 项目初始化配置 |
| `frontend-spec` | 阿里巴巴前端规约 | HTML / CSS / JS / TS / React / Node.js 编码规范，含通用格式与前端安全基线 |
| `solution-design` | common_rule（节选） | 需求方案设计：搜索先行禁止臆造、开源选型细则、输出要求 |
| `external-research` | common_rule（节选） | 外部信息检索：工具命令/版本兼容/配置项/报错排查等场景，官方来源优先，辅助资料须交叉验证 |
| `db-spec` | db_rule | 建表/索引/SQL/ORM 规约，附标准建表 DDL 模板 |
| `doc-writing` | doc_rule | Markdown 文档规范，附 README/CHANGELOG 模板（README 模板唯一真相源） |
| `wx-miniapp-spec` | wx_miniapp_rule | 微信小程序原生开发，Modern JS 语法强制约束、新建项目 README 交付约束 |
| `uniapp-spec` | uniapp_rule | uni-app（Vue3+Vite）跨端项目规范与项目生成约束（含 README 交付） |
| `ui-fidelity` | 新增 | 开源前端模板二次开发的界面保真（PC 后台 + 移动端）：模板接入侦察、基准页锚定、资产白名单、禁止清单、交付自检 |
| `test-execution` | 新增 | 测试范围决策与执行纪律：全量成本三档、变更分级与影响面推导、冒烟清单、止损信号、停止后排查、收尾清理自产进程与临时产物 |

## 支持的 IDE 与安装目录

| IDE      | skills 目录                         | 说明                               |
| -------- | ----------------------------------- | ---------------------------------- |
| CodeBuddy | `%USERPROFILE%\.codebuddy\skills` | 目录存在时自动安装                 |
| Qoder    | `%USERPROFILE%\.qoder\skills`      | 目录存在时自动安装                 |
| Qoder CN | `%USERPROFILE%\.qoder-cn\skills`  | 目录存在时自动安装                 |
| Claude Code | `%USERPROFILE%\.claude\skills` | 目录存在时自动安装；官方支持符号链接加载，JUNCTION 同效 |
| Codex（示例） | `%USERPROFILE%\.codex\skills` | 未来接入：在两个脚本的目标映射区各加一行即可 |

接入新的 IDE：只需在 `scripts\install.bat` 与 `uninstall.bat` 的目标映射区新增一行目录即可。

### 目录五花八门怎么办（分享给他人时）

脚本用的是 `%USERPROFILE%\.codebuddy`、`%USERPROFILE%\.qoder-cn` 这类**用户数据目录**，与 IDE 的**程序安装位置无关**——无论把 CodeBuddy / Qoder CN 装在 C 盘还是 D 盘，`%USERPROFILE%` 都会自动解析到接收者自己的主目录，标准安装**直接跑脚本即可，无需任何配置**。

唯一需要手动干预的是**便携版 / 手动迁移过数据目录**的情况：此时 skills 目录不在 `%USERPROFILE%\.xxx\skills` 下。用 `--only` + `--dir` 显式指定即可（`--dir` 必须配合 `--only`）：

```bat
:: 例：CodeBuddy 便携版的数据目录在 D 盘
scripts\install.bat --only=codebuddy --dir="D:\PortableApps\CodeBuddy\data\skills"

:: 例：Qoder CN 数据目录被迁到了 E 盘
scripts\install.bat --only=qodercn --dir="E:\qoder-cn-data\skills"

:: 卸载时用同样的 --only + --dir 定位
scripts\uninstall.bat --only=qodercn --dir="E:\qoder-cn-data\skills"
```

标准安装的接收者探测不到某 IDE 时，脚本会自动跳过并提示上面的 `--dir` 用法。这些参数都是**可选增量**：不传时行为与从前完全一致。

## 使用方法

```bat
:: 安装全部技能到所有已探测到的 IDE
scripts\install.bat

:: 只安装到指定 IDE（codebuddy | qoder | qodercn | claude）
scripts\install.bat --only=qoder

:: 目标已存在同名联接（指向其他位置）时强制重建
scripts\install.bat --force

:: IDE 数据目录不在默认位置（便携版/迁移过）时手动指定
scripts\install.bat --only=codebuddy --dir="D:\PortableApps\CodeBuddy\data\skills"

:: 卸载（只移除指向本仓库的联接，绝不误删真实目录）
scripts\uninstall.bat

:: 同步通用规则到各 IDE 规则目录（规则是副本安装，改完 common_rule.md 要跑一次）
scripts\sync-rules.bat

:: 只检查哪些副本过期，不写文件
scripts\sync-rules.bat --check
```

安装后各 IDE 目录下出现的是目录联接（JUNCTION），特征：

```
2026-09-01  10:00    <JUNCTION>     gitflow [d:\MyProducts\anotherme\skills\gitflow]
```

## 通用规则（common_rule.md）的安装与使用

`docs\common_rule.md` 是仓库中唯一保留的 **always_on 通用规则**（中文回复、代码质量准则、外部信息检索主干、安全与授权边界等跨场景硬约束）。与按需触发的技能不同，它常驻每次会话的上下文，因此保持精简；该文件**随版本库跟踪，克隆即可获得**。

规则与技能的安装方式不同：技能是目录联接（改内容即时生效），规则是**文件副本**，改完源文件必须重新同步。`install.bat` 跑完会自动调用 `scripts\sync-rules.bat`；只改了 `docs\common_rule.md` 时单独跑它即可。推荐安装为**用户级规则**（对本机全部项目生效）：

| IDE | 规则位置 | 同步方式 |
| --- | -------- | ---- |
| Qoder | `%USERPROFILE%\.qoder\rules\common_rule.md` | 自动（整文件覆盖） |
| Qoder CN | `%USERPROFILE%\.qoder-cn\rules\common_rule.md` | 自动（整文件覆盖，目录缺失时自动创建） |
| CodeBuddy | `%USERPROFILE%\.codebuddy\rules\<规则名>.mdc` | 自动（保留 IDE frontmatter，只替换正文） |
| Claude Code | `%USERPROFILE%\.claude\CLAUDE.md` | 自动（整文件重建，首行写入 auto-generated 标记） |

```bat
:: 同步（幂等：内容相同则跳过）
scripts\sync-rules.bat

:: 只检查哪些副本过期，不写文件
scripts\sync-rules.bat --check

:: 只同步某一个 IDE（codebuddy | qoder | qodercn | claude）
scripts\sync-rules.bat --only=qoder

:: 强制覆盖 CLAUDE.md（其中带非本仓库生成的内容时会拒绝）
scripts\sync-rules.bat --force
```

- Qoder / Qoder CN 的 frontmatter（`trigger: always_on`）与源文件完全一致，整文件覆盖最省事；
- CodeBuddy 的 `.mdc` 会保留 `enabled`/`updatedAt`/`provider` 等 IDE 自管字段，只替换正文；规则文件靠正文里的 `springboot-spec` 识别，不依赖文件名（文件名可能被本地化成中文）；
- `CLAUDE.md` 整文件由本仓库生成，首行是 `<!-- auto-generated ... -->` 标记。若其中还有别的内容（判断依据：既无标记、也不像规则副本），脚本默认**拒绝覆盖**，需显式 `--force`；
- 同步后需重启 IDE / 开新会话，规则才会重新注入。

> 只想对单个项目生效时，可改用项目级规则目录（如 `<项目>\.qoder\rules\`、`<项目>\.codebuddy\rules\` 或 `<项目>\CLAUDE.md`）。

## 修改技能后的同步

采用目录联接（JUNCTION）后，各 IDE 的 `skills` 目录实时指向本仓库的 `skills\`，同步方式取决于改动类型：

| 改动类型 | 是否需操作 | 说明 |
| -------- | ---------- | ---- |
| 修改技能内容（`SKILL.md` 正文、`references/*` 等文件内容） | 否 | 保存即生效，所有 IDE 自动同步 |
| 修改 `docs\common_rule.md`（always_on 规则） | 是 | 规则是副本安装，运行 `scripts\sync-rules.bat`（`install.bat` 末尾也会自动调用） |
| 新增 / 删除 / 重命名技能文件夹 | 是 | 联接按文件夹逐个创建，需重跑脚本 |

- **改内容**：无需任何操作。唯一例外——修改了 `SKILL.md` frontmatter 里的 `description`（IDE 启动时缓存的常驻触发信息）时，需重载窗口 / 重启 IDE / 开新会话才会刷新。
- **增删 / 改名文件夹**：重新运行安装脚本重建联接。

```bat
:: 新增技能后：为新文件夹创建联接（已存在的自动跳过，幂等安全）
scripts\install.bat

:: 删除或重命名技能后：先清理旧联接，再重新安装
scripts\uninstall.bat
scripts\install.bat
```

## 技能的使用方式（触发方式）

日常开发中**不需要任何特殊命令或 prompt**，有两种触发方式：

### 1. 自动触发（主力方式）

各 IDE 只把每个技能的 `name + description` 常驻上下文（几十个 token）。当你的请求命中 description 中的场景词时，agent 会自动加载该技能的完整内容并遵照执行，无需手动干预。

示例：
- “帮我写一条提交信息” → 自动触发 `gitflow`
- “项目要接入 RabbitMQ” → 自动触发 `rabbitmq-reliability`
- “设计一张订单表” → 自动触发 `db-spec`

### 2. 手动触发（强制生效）

- 在对话框直接输入斜杠命令：`/gitflow`、`/db-spec` 等；
- 或在自然语言中点名：“按我的 gitflow 规范检查一下这个提交”。

适用于自动触发不稳定、或想确保某个规范必然生效的场景。

### 加载流程（渐进式）

技能被触发后，先加载 `SKILL.md` 正文（核心规则与速查表）；仅当涉及具体场景时，才按正文的指引表读取 `references/` 下对应的细则文件，避免占用过多上下文。

### 触发效果的调优

- 若某场景下技能未被触发，往它的 `description` 里补充你实际会用的说法（如“上线”“紧急修复”）；
- 由于是联接安装，修改保存后即时生效，无需重新运行安装脚本；
- 注意：skill 是按需触发，不保证 100% 命中。判定发生在**加载之前**——常驻上下文只有 `name + description`，正文此时还读不到，因此在正文或 description 里写“必须使用本技能”改变不了这一步。必须始终生效的跨场景硬约束（如回复语言、安全规范）应直接写成 always_on rule 正文；确实需要保留为 skill 的（编码规范这类正文较长、需渐进加载的），用下面的门禁表兜底。

### 规范类技能的兜底：门禁表

规范类技能（写代码就该遵守的那一类）在本仓库额外有一层兜底：`docs\common_rule.md` 的「规范技能强制加载（门禁）」一节，按**即将产出的文件类型**而非用户措辞，列出「对象 → 必须先加载的技能」映射，并声明该加载不参与任何收益、复杂度、简洁性裁决。

- 判定依据从“请求是否命中场景词”改为“要产出什么文件”，短任务与小改动没有豁免空间；
- 若某次仍被跳过，先核对门禁表里对应行是否存在、技能名是否写错，再去补 `description` 关键词；
- 门禁表属于 `common_rule.md`，是**副本安装**，改后需重新复制到各 IDE 规则目录才生效（见上文“通用规则（common_rule.md）的安装与使用”）。

## 新增一个技能

1. 复制 `skills\_template` 文件夹，重命名为技能名（全小写 + 连字符，如 `db-spec`）。
2. 编辑 `SKILL.md`：
   - frontmatter 的 `name` 必须与文件夹同名；
   - `description` 决定技能何时被触发（常驻上下文的部分），写清触发场景与边界；
   - 正文只放高频核心规则（建议 60 行以内），细节放入 `references/` 按需读取。
3. 运行 `scripts\install.bat` 完成挂载。

## 编写原则

- **渐进式加载**：SKILL.md 是入口，保持精简；大段规范、样例代码、成熟方案拆到 `references/` 子文件，在正文用表格指引。
- **指令式表达**：规则写成对 agent 的直接指令，不用角色设定话术。
- **可扩展**：技能目录内可自由添加 `references/`、`examples/`、`scripts/` 等，联接方式不受影响。
