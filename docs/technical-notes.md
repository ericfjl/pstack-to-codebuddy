# 技术细节与研究稿

> 安装请看仓库根目录 README.md 与 install.sh。本文保留调研过程与字段映射细节，其中的迁移步骤是早期记录，不要照抄。数量、路径与字段以 `config/` 和实际产物为准。

---

# 把 pstack 搬进 CodeBuddy：一份可复现的跨编辑器技能栈迁移指南

> 整理日期：2026-11-09
> 适用对象：想把 Lauren Tan（@poteto）开源的 pstack 工程技能栈用到腾讯云 CodeBuddy（IDE / Code CLI）的开发者
> 核对基准：pstack `cursor/plugins` 仓库 main 分支（文档核对 commit `ab1f702ce8e8b6557edb56b09f52cde8bfb83f17`，2026-10-27；实操迁移 commit `6b0300214a09fd6029cfb7077043125758cd1fd2`，2026-11-06，版本 `0.15.36`）；CodeBuddy 官方文档 2026-11-09 版本

---

## TL;DR

- **能迁，而且比想象中简单**：pstack 的技能本体是纯 Markdown 的 `SKILL.md`，CodeBuddy 用的也是 Agent Skills 开放标准的 `SKILL.md`，格式天然对齐，绝大多数技能正文一个字都不用改。
- **迁移的正解不是「改技能」，而是「写适配层」**：pstack 官方已经为 Claude Code 内置了一份 `docs/harness/claude-code.md` 名称映射表。把这张表改成 CodeBuddy 版，放进 `.codebuddy/rules/`，让每个会话读一次，才是作者设计好的跨工具移植方式。
- **真正会失真的只有 Cursor 独有能力**：Cloud Agents、Automations、Bugbot、内置 PR 工具，以及依赖这些能力的多模型编排与隔夜自动化。
- **最省事的三条路**：① 社区镜像一键装；② 手动拷贝技能目录 + 写适配层（本文主线）；③ 直接用 CodeBuddy 的技能市场/导入能力。

---

## 一、为什么会有这个问题

pstack 是 Lauren Tan 在 Cursor 期间开源的一套 AI 编程技能栈（MIT，位于 Cursor 官方 `cursor/plugins` 仓库的 `pstack/` 目录）。它的目标不是让 AI 写更多代码，而是 **"write less, but higher quality code"**：先调查、再设计、再构建，改动必须在真实产物上验证，交付前还要过对抗式审查。

按本地固定版本统计，它包含：

| 组成 | 数量 | 说明 |
| --- | --- | --- |
| skill | 约 58 个 | 24 个 `principle-*`（工程原则）+ 34 个流程/验证/审查/解释类 |
| playbook | 23 个 | 位于 `skills/poteto-mode/playbooks/`，是普通 `.md` 文件 |
| subagent | 2 个 | `agents/poteto-agent.md`、`agents/comment-sicko.md` |
| automation | 1 个 | `automations/benny/`（休眠，非 slash skill） |

> pstack 迭代很快（0.15.x），数量与命令以仓库当前版本为准。

日常入口只有一个：`/poteto-mode`——描述目标，它自动匹配 playbook、把步骤放进 todo、按需调用其他技能。

问题在于：这套东西装在 Cursor 插件市场里，看起来是「Cursor 专属」。但拆开看，它是**一堆带 YAML frontmatter 的 Markdown 文件**，作者本人也在 README 里提供了 Claude Code 的安装方式和适配层文档。既然 CodeBuddy 同样按 `SKILL.md` 标准加载技能，迁移就有据可依。

---

## 二、两边的事实核对

| 能力 | pstack / Cursor | CodeBuddy（官方） |
| --- | --- | --- |
| 技能文件格式 | 每个技能一个目录 + `SKILL.md` | 完全相同，`.codebuddy/skills/<name>/SKILL.md` |
| 技能目录 | `.cursor/skills/`、`~/.cursor/skills/`（插件安装时另有前缀） | 项目级 `.codebuddy/skills/`，用户级 `~/.codebuddy/skills/` |
| 触发方式 | 从 `/` 菜单选中技能后附加到消息 | AI 按 `description` 自动识别调用；也可 `/skill-name` 手动触发；`/skills` 面板查看已加载列表 |
| 斜杠命令 | 插件命令，跨工具时变 `/pstack:<name>` | 用户级/项目级自定义命令，位于 `.codebuddy/commands/`，可引用 skill |
| frontmatter 字段 | Cursor 插件约定 | `name`、`description`、`allowed-tools`、`disable-model-invocation`、`user-invocable`、`context: fork`、`agent`、`model`、`hooks` |
| 子代理 | `subagent_type`、`readonly`、`environment: "cloud"` | `context: fork` + `agent`（`general-purpose` / `Explore` / `Plan` / `.codebuddy/agents/` 自定义） |
| 规则 / 记忆 | `.cursor/rules/*.mdc` | `CODEBUDDY.md`（或 `AGENTS.md`）、`.codebuddy/rules/*.md`、`~/.codebuddy/rules/*.md` |
| 模型分工 | `pstack-models.mdc`，按角色配不同模型 | `model` 字段仅在 `context: fork` 时生效；可用自定义模型接入 |
| 多模型并行编排 | `/arena`、`/swarm`、`/interrogate` | 无原生等价物，需自行编排 |
| 自动化 / 云端沙箱 | Cursor Automations、Cloud Agents、Bugbot | 无原生等价物 |
| 兼容性别名 | — | 识别 `${CLAUDE_PLUGIN_ROOT}`、`${CLAUDE_SKILL_DIR}`、`${CLAUDE_SESSION_ID}` 作为 `${CODEBUDDY_*}` 的等价别名 |

最后一行是个好消息：pstack 的 Claude Code 适配层里那些 `~/.claude/...` 占位符，CodeBuddy 至少在变量层面能认，改写成本更低。

---

## 三、已有工作调研：没人做过 CodeBuddy 版，但路基已经铺好

截至整理日期，**没有检索到公开的 pstack → CodeBuddy 专门迁移教程**。但以下四件事让这件事几乎是「填空」：

1. **官方 Claude Code 适配层**：`pstack/docs/harness/claude-code.md` 是一张完整的名称映射表（工具、子代理字段、模型 slug、setup 写入路径、Cursor 独有功能如何跳过）。它证明了作者的设计意图是「技能正文保持不变，另加一层 harness」。
2. **社区非 Cursor 镜像**：`backnotprop/pstack`，可用 `npx skills add backnotprop/pstack` 安装到遵循 Agent Skills 标准的工具；第三方技能收录站（learn-skills.dev）已按单个技能收录，例如 `npx skills add https://github.com/backnotprop/pstack --skill poteto-help`。注意这是社区维护，非官方，建议固定 commit 使用。
3. **同类技能包已有 CodeBuddy 先例**：`superpowers-zh` 明确支持 CodeBuddy，`npx superpowers-zh --tool codebuddy` 会把技能装进 `.codebuddy/skills/`，并生成 `CODEBUDDY.md` 引导文件——说明「Markdown 技能包 → CodeBuddy」这条路是通的。
4. **CodeBuddy 自带技能生态**：官方 Skills 体系完整（项目级/用户级目录、`/skills` 面板、`skillOverrides` 可见性控制、`allowed-tools` 白名单、frontmatter hooks）；另有国内 AI Skills 社区 [SkillHub](https://skillhub.cn/) 以及 [SkillKit](https://skillkit.io/agents/codebuddy)、[skillry.dev](https://skillry.dev/skills/agent/codebuddy) 等收录站可直接分发 `SKILL.md`。社区实测里，编码规范类单技能（Karpathy Guidelines、Frontend Design、Security Review 等）适配良好，但**尚无 pstack 这种成体系的六阶段工作流技能栈**。

---

## 四、三条迁移路线

| 路线 | 做法 | 适合 | 代价 |
| --- | --- | --- | --- |
| A. 官方 harness 思路（推荐） | 手动拷贝技能目录 + 写一份 `pstack-codebuddy-harness.md` 映射表 | 要长期维护、要跟进 pstack 上游更新、要写文档/做内容 | 一次性写适配层 |
| B. 社区镜像一键装 | `npx skills add backnotprop/pstack` 或让 CodeBuddy 直接导入 GitHub 仓库地址 | 想先试跑看看 | 依赖第三方镜像，版本不可控 |
| C. 技能市场 / IDE 导入 | 在 SkillHub / IDE 技能市场搜索或上传技能文件夹 | 只想用几个零散技能 | 拿不到 playbook 之间完整的调度关系 |

下文按路线 A 展开。

---

## 五、迁移步骤（可复现）

### 第 1 步：获取源码并固定版本

```bash
git clone --depth 1 https://github.com/cursor/plugins.git /tmp/cursor-plugins
cd /tmp/cursor-plugins && git log -1 --format='%H %ad %s' --date=short
```

把 commit 记进你的文档或 `VERSION` 文件——pstack 更新频繁，不固定版本会导致「同一份教程，两周后步骤对不上」。

### 第 2 步：建立 CodeBuddy 目录

```bash
cd <你的项目根目录>
mkdir -p .codebuddy/skills .codebuddy/rules
```

### 第 3 步：拷贝技能（推荐一次全量）

如果只是试跑，可以先挑 10 个左右；但**要让 `poteto-mode` 真正跑通，建议一次全量拷贝**——它的 `Non-negotiables` 会引用 `swarm`、`arena`、`interrogate`、`architect`、`unslop`、`technical-writing` 等大量技能，只搬子集会让路由在半路断掉。全量拷贝是安全的：上游 58 个技能里 57 个自带 `disable-model-invocation: true`，CodeBuddy 只会让它们由 `/<name>` 手动触发，不会自动接管日常会话。

```bash
P=/tmp/cursor-plugins/pstack
mkdir -p .codebuddy/skills .codebuddy/agents .codebuddy/rules .codebuddy/pstack
cp -R $P/skills/. .codebuddy/skills/
cp -R $P/docs $P/automations $P/assets $P/README.md $P/LICENSE $P/plugin.json \
      .codebuddy/pstack/
```

要点：

- `poteto-mode/` 必须**整个目录**拷，`playbooks/`（23 个剧本）和 `references/` 就在它下面。
- 全仓库 `skills/` 约 4.6 MB，含 10 个 `references/` 目录；文档副本约 2.8 MB，总计 7.5 MB，随 Git 提交无压力。
- `arena` / `swarm` / `interrogate` / `automate-me` 仍建议**先别主动调用**：它们依赖 Cursor 的多模型与自动化编排，在 CodeBuddy 侧会由适配层降级为「跳过 + 说明」。留着文件只是为了让引用不失效。
- 保留 `LICENSE` 与 `plugin.json`，并在 `.codebuddy/pstack/VERSION.md` 里记下 commit，方便后续增量更新。

### 第 4 步：写 CodeBuddy 版 harness（关键一步）

以官方 Claude Code 适配层为模板，另存为项目规则：

```bash
cp /tmp/cursor-plugins/pstack/docs/harness/claude-code.md \
   .codebuddy/rules/pstack-codebuddy-harness.md
```

然后按下表改写映射（`.codebuddy/rules/*.md` 会在每个会话自动加载，正好对应官方 harness 里「每个会话读一次本文件」的要求）：

| pstack / Cursor 名称 | CodeBuddy 写法 |
| --- | --- |
| `.cursor/skills/`、`~/.cursor/skills/` | `.codebuddy/skills/`、`~/.codebuddy/skills/` |
| `.cursor/rules/*.mdc`、始终生效规则 | `CODEBUDDY.md`，或 `.codebuddy/rules/*.md`（支持 `alwaysApply` / `paths` 条件触发） |
| `pstack-models.mdc`、`~/.claude/rules/pstack-models.md` | `.codebuddy/rules/pstack-models.md`（项目级，随 Git 共享）或 `~/.codebuddy/rules/pstack-models.md`（用户级全局生效），启动时自动注入 |
| `Task` 调用子代理 | `context: fork` + `agent`；或在 `.codebuddy/agents/` 定义自定义子代理 |
| `readonly: true` | `agent: Explore`，且任务说明里写明「不要编辑文件」，事后检查 `git status` |
| `environment: "cloud"` | 无云端沙箱，改用本地 `git worktree add` 隔离，并写明 worker 要检出的分支/commit |
| `run_in_background: true` | 子代理默认后台运行、完成时通知，省略该字段 |
| 运行另一个技能（`/name`） | 用 `/skill-name` 手动触发；或在技能内 `Read ${CODEBUDDY_SKILL_DIR}/../<name>/SKILL.md` 显式读取 |
| `Grep` / `Glob` | 会话有则用；没有就用带 `rg` 的 `Bash` |
| `AskQuestion` | CLI 无等价工具时用纯文本提问 |
| 打开任务清单 | 会话提供 `TodoWrite` 就用；否则把清单写在回复里并逐阶段更新 |
| 模型 slug（`claude-opus-5-5-xhigh`、`grok-*` 等） | `model` 仅在 `context: fork` 时生效，且只接受 CodeBuddy 支持的模型 ID；无法映射时省略并注明「回退到会话模型」 |
| `${CLAUDE_SKILL_DIR}` 等 | CodeBuddy 识别为别名，但建议统一改成 `${CODEBUDDY_SKILL_DIR}` |
| `https://github.com/cursor/plugins/blob/main/pstack/<path>` | 读本地已拷贝的 `<pstack>/<path>`，不要联网抓取；给用户链接时再贴 URL |
| Cursor Automations / Bugbot / Cloud Agents | 无等价物。按官方 harness 约定，在回复里写一行 `Skipped in CodeBuddy: <step>. <reason>.`，然后继续下一步，不要停下来问人 |
| 内置 PR 工具 | 用 `gh pr create` 等 forge 命令，不算跳过 |

另外两条与 CodeBuddy 特性相关的约定，建议一并写进 harness：

- **不要让技能自动接管所有会话**：上游 57/58 个技能**已经自带** `disable-model-invocation: true`，CodeBuddy 语义一致（只由 `/<name>` 手动触发），迁移时确认它没被删即可，无需重复添加。唯一例外是 `setup-pstack`。`principle-*` 这类背景原则若想从 `/` 菜单隐藏，可再加 `user-invocable: false`，不影响被其他技能引用。
- **忽略未知字段**：`poteto-mode` 的 `icon: crown`、`color: yellow` 是 Cursor 插件元数据，CodeBuddy 不识别，忽略即可，不影响加载。
- **只读技能用白名单兜底**：例如 `how` / `why` / `recall` 设 `allowed-tools: Read, Grep, Glob`，比纯提示词约束更硬。
- **外部技能不要依赖 hooks**：`.codebuddy/skills/` 属于非可信来源，frontmatter `hooks` 默认不注册；验证门禁请交给测试 / lint / CI。

> 上下文预算提醒：`.codebuddy/rules/` 下的所有 `.md` 每会话都会加载。若 harness 太长，可放进 `CODEBUDDY.md` 用 `@path/to/file` 导入，或用 `alwaysApply: false` + `paths` 做成条件规则。

### 第 5 步：迁移 2 个子代理

把 `agents/*.md` 改写成 `.codebuddy/agents/` 下的自定义子代理。CodeBuddy 子代理的 frontmatter 是 `name`、`description`、`tools`、`model`、`skills`、`background`、`effort`、`disable-model-invocation` 等，比 Cursor 的字段更丰富：

- `poteto-agent`：用 `skills: poteto-mode` 让它启动即加载主技能，正文里 `~/.cursor/plugins/` 的查找路径改为 `.codebuddy/skills/poteto-mode/SKILL.md`；`is_background: true` → `background: true`。
- `comment-sicko`：只读审查员，用 `tools: Read, Grep, Glob, Bash` 并明确「Bash 只跑 `git diff` 等只读命令、绝不编辑文件」；也可用内置的 `Explore` 代理替代。

### 第 6 步：改掉 setup 的模型配置写入路径

`/setup-pstack` 在 Cursor 写 `~/.cursor/rules/pstack-models.mdc`，在 Claude Code 写 `~/.claude/rules/pstack-models.md`。CodeBuddy 版写 `.codebuddy/rules/pstack-models.md`（项目级；需全局生效再复制到 `~/.codebuddy/rules/`），保留 `# budget` 行与每个角色一行。

关键差异：Cursor 的真实模型 slug（`grok-4.7-xhigh-fast`、`claude-opus-5-5-xhigh` 等）CodeBuddy 不识别，**不能照抄**。把所有角色写成 `inherit-parent`（回退会话模型），并用 `/model`、`/agents` 探测本机可用模型；`model` 字段仅在 `context: fork` 时生效，effort 用子代理 frontmatter 的 `effort` 字段表达。

### 第 7 步：验证

1. 重启会话，执行 `/skills`，确认项目级技能列表里出现了 `poteto-mode`、`tdd` 等，并记录各自 token 数。
2. 执行 `/memory`，确认 harness 与 `pstack-models` 规则已加载。
3. 试跑一个小任务，例如：
   ```
   /poteto-mode 帮我查清楚这个仓库里 X 功能是怎么工作的，只做调查，不要改代码。
   ```
   预期：命中 `investigation` playbook → 只读调查 → 输出带文件引用的结论；且不产生任何文件改动。
4. 再跑一个构建类任务，确认「先写失败测试 → 实现 → 跑真实测试 → 查 diff」这条验收链完整。
5. 检查 `git status`，确认被跳过的 Cursor 独有步骤都留下了 `Skipped in CodeBuddy:` 记录。

---

## 六、已知边界（发布前请如实告知读者）

| 边界 | 说明 |
| --- | --- |
| 多模型竞速不可用 | `/arena`、`/swarm`、`/interrogate` 依赖 Cursor 的多模型编排，CodeBuddy 侧需自行写多 Agent 调度，不能直接照搬 |
| 隔夜自动化不可用 | Cursor Automations / Cloud Agents 无等价物；`autopilot-*`、`babysit` 类 playbook 只能手工模拟 |
| 验证能力要自己补 | pstack 的精髓是「让 agent 看见真实产物」（浏览器截图、console 日志、CI 门禁）。这些不是 Markdown 能带来的，需要给 CodeBuddy 配浏览器控制 / MCP，并以项目自身的测试、lint、CI 作为硬门禁 |
| 软约束 ≠ 硬约束 | skills 和 rules 是提示词层的约束，模型可以违反。真正可靠的做法是把反复出现的问题固化成 lint / CI 规则 |
| frontmatter hooks 有安全闸门 | 来自 `.codebuddy/skills/`、项目本地或插件市场的 Skill 属于非可信来源，其 `hooks` 默认不注册（需 `allowUntrustedFrontmatterHooks`）。不要依赖它来实现验证门禁 |
| 版本与许可 | pstack 为 MIT；若把技能文件再分发到自己的仓库，请保留 LICENSE 与作者署名。本文为独立整理，不含 pstack 原文 |

---

## 七、给内容创作者的三个可讲的点

1. **反直觉**：一个「Cursor 官方插件」，拆开其实是一堆 Markdown——AI 编程工具的护城河正在从「IDE 功能」转向「可移植的工程方法论」。
2. **方法比工具重要**：作者亲自写了 Claude Code 适配层，说明跨工具迁移的正确姿势是加一层名称映射，而不是改提示词。
3. **诚实的边界**：能搬的是调查、设计、TDD、审查、验收的工作流；搬不动的是云端沙箱与自动化。把边界写清楚，比宣称「完美移植」更有价值。

---

## 附：本次迁移实操记录（2026-11-09）

已按本文路线 A 在真实工作区完成一次迁移，结果与文档的三处修正均来自这次实操。

| 项 | 结果 |
| --- | --- |
| 上游 | `cursor/plugins` main @ `6b0300214a09fd6029cfb7077043125758cd1fd2`，pstack `0.15.36` |
| 获取方式 | `git clone --depth 1 --filter=blob:none --sparse` + `git sparse-checkout set pstack`（`raw.githubusercontent.com` 在本环境被阻断，但 git 协议可用） |
| 技能 | 58 个全部拷入 `.codebuddy/skills/`，含 23 个 playbook、10 个 `references/` 目录，正文零修改 |
| 适配层 | `.codebuddy/rules/pstack-codebuddy-harness.md`（工具 / 子代理 / 模型 / setup / 路径 / Cursor 独有功能 / frontmatter 差异 / 验证要求 8 组映射） |
| 模型规则 | `.codebuddy/rules/pstack-models.md`，18 个角色全部 `inherit-parent` |
| 子代理 | `.codebuddy/agents/poteto-agent.md`、`comment-sicko.md`，按 CodeBuddy frontmatter 转换 |
| 版本与许可 | `.codebuddy/pstack/VERSION.md`、`LICENSE`（MIT） |
| 总体量 | 7.5 MB |
| 校验 | 62 个 Markdown 文件 frontmatter 全部合法；58/58 技能含 `SKILL.md`；playbook 23/23；`disable-model-invocation: true` 57/58 |

**与初版设想不同的三点**

1. 由「首批拷 10 个」改为「一次全量 58 个」：`poteto-mode` 的 `Non-negotiables` 会引用几乎所有技能，缺文件会让工作流半路断掉。
2. 不需要手动补 `disable-model-invocation: true`：上游已带，CodeBuddy 语义一致。
3. 模型规则落在项目级而非 `~/.codebuddy/rules/`：避免污染用户全局配置，且可随仓库共享。

**尚未完成的验证**：迁移只完成了文件层落地和静态校验。`/skills`、`/agents`、`/memory` 三个面板的实际加载情况，以及 `/poteto-mode` 的真实试跑，需要在 CodeBuddy 会话内执行第 7 步的清单确认。

---

## 八、参考资料

**一手来源**

- pstack 官方源码（MIT）：https://github.com/cursor/plugins/tree/main/pstack
- pstack 插件市场页：https://cursor.com/marketplace/cursor/pstack
- pstack 官方 Claude Code 适配层：`pstack/docs/harness/claude-code.md`
- CodeBuddy Code Skills 官方文档：https://www.codebuddy.cn/docs/cli/skills
- CodeBuddy 记忆与规则官方文档：https://www.codebuddy.cn/docs/cli/memory
- CodeBuddy IDE 使用指南概览：https://www.codebuddy.ai/docs/zh/ide/User-guide/Overview

**社区与生态**

- 非 Cursor 环境镜像：https://github.com/backnotprop/pstack
- superpowers-zh（含 CodeBuddy 安装说明）：https://github.com/xizhuomengcontin/superpowers-zh/blob/main/docs/README.codebuddy.md
- SkillHub：https://skillhub.cn/
- SkillKit CodeBuddy 技能目录：https://skillkit.io/agents/codebuddy
- Skillry CodeBuddy 技能目录：https://skillry.dev/skills/agent/codebuddy
- 国内 AI 编程助手 Skills 生态适配测评（社区实测，含 SkillHub 与 CLI 安装方式）：https://aicoding.csdn.net/6a55b02710ee7a33f28d3f8b.html

> 文中数量、路径与字段均以核对日期的官方文档与仓库版本为准；工具迭代较快，落地前请重新核对一次 `/skills` 与 `/memory` 的实际输出。
