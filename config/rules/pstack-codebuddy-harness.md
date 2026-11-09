---
description: pstack 在 CodeBuddy 中的适配层。每个会话读一次，把技能里出现的 Cursor 名称按本文件映射为 CodeBuddy 名称。
alwaysApply: true
---

# pstack in CodeBuddy

pstack 技能使用 Cursor 名称。在 CodeBuddy 中，每个会话读一次本文件，然后用下面的表格把技能里出现的每个 Cursor 名称映射过去。`<skills>` 指当前项目的 `.codebuddy/skills/`；`<pstack>` 指 `.codebuddy/pstack/`（官方 README、`docs/`、原始 harness 与 LICENSE 的只读副本）。如果某个 Cursor 字段在表里没有对应行，就去掉它并说明原因。**绝不传入工具 schema 拒绝的字段或值。**

移植版本：`cursor/plugins` main @ `6b0300214a09fd6029cfb7077043125758cd1fd2`（2026-11-06），pstack `0.15.36`，MIT。技能文件保持原样，本文件是唯一需要维护的适配层。

## 工具

| Cursor | CodeBuddy |
| --- | --- |
| `Task` | `Agent` 工具（或在 SKILL.md 用 `context: fork` + `agent`）。`subagent_type` 字段名保留。 |
| `AskQuestion` | 无等价工具时用纯文本提问；不要虚构工具名。 |
| 打开任务清单 | 会话提供 `TodoWrite` 就用它；否则把清单放在回复里，并在每个阶段更新。 |
| 运行另一个 pstack 技能（`/name` 或 "the **name** skill"） | `Read <skills>/<name>/SKILL.md` 并照它执行。本项目已拷贝全部 58 个技能，**不要联网抓取**。告诉用户手动输入时写 `/<name>`，不加 `/pstack:` 前缀。 |
| `Grep`、`Glob` | CodeBuddy 有则直接用；会话没有时用带 `rg` 的 `Bash`。 |
| `Read <pstack>/skills/<name>/SKILL.md` | `Read <skills>/<name>/SKILL.md`。 |
| `https://github.com/cursor/plugins/blob/main/pstack/<path>` | 读 `<pstack>/<path>` 本地副本；只在需要给用户链接时贴 URL。 |

## 子代理字段

| Cursor | CodeBuddy |
| --- | --- |
| `subagent_type: generalPurpose` | `subagent_type: "general-purpose"` |
| `poteto-agent`、`comment-sicko` | 同名项目子代理，定义在 `.codebuddy/agents/`，按名委派即可；`/agents` 面板可查看。 |
| `readonly: true` | `subagent_type: "Explore"`（严格只读）。任务说明里仍写明「不要编辑文件」，事后检查 `git status`。 |
| `readonly: false` | `general-purpose`，继承会话的 MCP 工具。 |
| `environment: "cloud"` | 无云端沙箱：用 `git worktree add` 建本地独立工作树，并在任务说明里写明要检出的分支或提交。 |
| `environment: "local"` | 省略。 |
| `cloud_base_branch: <b>` | 告诉 worker 先检出 `<b>`。 |
| `run_in_background: true` | 省略；确需后台时在 `Agent` 工具传 `run_in_background: true`，用 `TaskOutput` 取结果。 |
| `resume` | 用 `agentId` 传 `resume`；不可用时新开一个子代理，把之前结果贴进任务说明。 |
| `file_attachments` | 在任务说明里列出这些路径。 |
| `is_background: true`（agent frontmatter） | 子代理 frontmatter 用 `background: true`。 |

补充：子代理可用 `skills:` 字段启动即加载技能；嵌套深度封顶 5 层，显式列出 `tools: Agent` 才能继续嵌套。

## 模型

| Cursor | CodeBuddy |
| --- | --- |
| `claude-<family>-<version>-<effort>[-fast]`、`grok-*`、`gpt-*` 等 slug | CodeBuddy 不识别这些 slug。**省略 `model`**，让子代理回退到会话模型，并在回复里说明这一回退。绝不写未经确认的 slug。 |
| `auto` 或 `inherit-parent` | `model: inherit` 或省略 `model`。 |
| 角色值 `<model> <effort>`，例如 `opus high` | 省略 `model`；effort 需要用子代理 frontmatter 的 `effort` 字段（`minimal` / `low` / `medium` / `high` / `xhigh` / `max`）表达。skill 的 `model` 字段仅在 `context: fork` 时生效。 |
| `pstack-models.mdc` 规则、`~/.cursor/rules/pstack-models.mdc`、`~/.claude/rules/pstack-models.md` | `.codebuddy/rules/pstack-models.md`（本次落地为项目级规则，随 Git 共享）。规则在每个会话自动加载；若文件或角色行缺失，一律用 `inherit-parent`。 |
| 想按角色配不同模型 | 用 `/model` 与 `/agents` 查看本机真实可用模型，再在 `.codebuddy/settings.json` 的 `subagents.agents.<name>.model` 中配置，或让 `/setup-pstack` 改写模型规则。 |

## setup-pstack

CodeBuddy 会把 `.codebuddy/rules/` 下的每个 `.md` 加载进每个新会话，所以 `setup-pstack` 的角色配置应写到那里。照技能的步骤执行，但做以下改动：

- **检测**：用 `/model` 和 `/agents` 列出的可用模型作为唯一可信来源。检测不到任何可用 slug 时，把所有角色写成 `inherit-parent`，不要向用户索要 Cursor 的模型 slug。
- **默认值**：技能里的 `claude-opus-5-5-xhigh`、`grok-4.7-xhigh-fast` 等默认值全部映射为 `inherit-parent`。
- **写入**：写 `.codebuddy/rules/pstack-models.md`，不带 `.mdc` 扩展名，不带 `alwaysApply: false`，保留注释行、`# budget` 行和每个角色一行，整个文件覆盖重写。需要全局生效时，另复制一份到 `~/.codebuddy/rules/`。**绝不要把角色行放进 `CODEBUDDY.md` 或 `AGENTS.md`。**

## 路径

| Cursor / Claude Code | CodeBuddy |
| --- | --- |
| `.cursor/skills/`、`~/.cursor/skills/`、`.claude/skills/` | `.codebuddy/skills/`、`~/.codebuddy/skills/` |
| `~/.cursor/plugins/`、`.cursor-plugin/plugin.json` | `<pstack>/`（上游只读副本），插件清单在 `.codebuddy/pstack/plugin.json`，原始子代理定义在 `.codebuddy/pstack/agents/` |
| `.cursor/rules/*.mdc`、`CLAUDE.md`、`AGENTS.md` | `CODEBUDDY.md`、`.codebuddy/CODEBUDDY.md`、`.codebuddy/rules/*.md` |
| `~/.claude/projects/.../<session>.jsonl` 转录 | `~/.codebuddy/projects/{projectDir}/{sessionId}/`，子代理转录在其 `subagents/agent-{agentId}.jsonl` |
| `${CLAUDE_PLUGIN_ROOT}`、`${CLAUDE_SKILL_DIR}`、`${CLAUDE_SESSION_ID}` | 优先用 `${CODEBUDDY_PLUGIN_ROOT}`、`${CODEBUDDY_SKILL_DIR}`、`${CODEBUDDY_SESSION_ID}`；CodeBuddy 也识别 `CLAUDE_*` 作为等价别名。 |

## 仅 Cursor 有的功能

CodeBuddy 没有 Cursor Automations、Bugbot、Cursor cloud agents，也没有内置的 PR 工具。当某个步骤需要其中之一时，在回复里写一行 `Skipped in CodeBuddy: <step>. <reason>.`，然后继续下一步。不要停下来、不要询问、不要重试。当后面的步骤需要被跳过步骤产出的东西（比如一个 URL 或一个密钥）时，留一个占位符，并在那一行里写明它的名字。

| Cursor | CodeBuddy |
| --- | --- |
| Cursor Automations：例程、`update_state`、`api2.cursor.sh/automations` webhook、例程唤醒、`SendToUser` 密钥请求 | 用那一行跳过。 |
| Bugbot | PR 上的 Bugbot 评论是普通评审讨论串，用步骤给出的 forge 命令分诊；没有 Bugbot 检查或评论时，跳过启动/等待/配置 Bugbot 的步骤。 |
| Cursor cloud agents | `environment: "cloud"` 映射到 git worktree；跳过需要云端 agent 本身的步骤（仪表盘状态、它自己的机器）。 |
| 内置 PR 工具 | 用 `gh pr create` 等 forge 命令，不算跳过，不写那一行。 |
| `cursor-team-kit` 的 `/deslop`、`control-cli`、`control-ui` | 本次未移植。写跳过行，并改用项目自身的测试 / lint / CI 与浏览器控制来完成等价验证。 |
| Cursor 内置 `create-skill` | 用 CodeBuddy 的 skill-creator（若可用），或直接按 `SKILL.md` 格式手写。 |

## 本次移植的 frontmatter 约定

- 58 个技能中 57 个原本就带 `disable-model-invocation: true`。CodeBuddy 语义一致：只由 `/<name>` 手动触发、不自动接管会话。**保留，不要删。**
- `setup-pstack` 无该字段，允许按 `description` 自动识别。
- `poteto-mode` 另有 `icon: crown`、`color: yellow`，CodeBuddy 不识别，忽略即可，不影响加载。
- `principle-*` 是背景知识。若想从 `/` 菜单隐藏，可加 `user-invocable: false`；不影响被其他技能引用。
- 外部来源技能（`.codebuddy/skills/`）的 frontmatter `hooks` 受 admin-trusted 闸门限制，默认不注册。**不要依赖 hooks 做验证门禁**，用项目测试 / lint / CI。
- 只读类技能（`how`、`why`、`recall`）可加 `allowed-tools: Read, Grep, Glob` 作为硬约束。

## 验证要求（不可被跳过）

pstack 的核心是「验证即基础设施」。在 CodeBuddy 中：

- 「证明能跑」必须针对真实产物：跑测试或脚本、看真实输出、查 `git diff`；不能只说「编译过了」。
- 写代码的 agent 永远不自己批准自己的工作；交付前用独立视角复查 diff。
- 需要 UI / 浏览器验证时使用浏览器控制或 MCP；没有就写跳过行，并明确说明哪部分**未经验证**。
- 同一个错误被纠正两次时，把它上抽为 lint / CI 规则，而不是再加一段文字约束。
