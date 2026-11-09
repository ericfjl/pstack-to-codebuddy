# pstack for CodeBuddy

把 Lauren Tan 的 pstack 技能栈装进 CodeBuddy。装完你会得到 58 个技能、23 个任务剧本、2 个子代理，以及一层把 Cursor 名称翻译成 CodeBuddy 名称的规则。

不用先懂 pstack 原理。按下面三步做完，就能用 `/poteto-mode` 提任务。

想看原理、字段映射和调研过程，读 [docs/technical-notes.md](docs/technical-notes.md)。

---

## 准备

- 已安装 CodeBuddy，IDE 或 CLI 都行
- 有终端和 git
- 能访问 github.com

---

## 三步装好

### 第 1 步：下载本仓库

```bash
git clone https://github.com/ericfjl/pstack-to-codebuddy.git
cd pstack-to-codebuddy
```

如果你已经在这个目录里，跳过这一步。

### 第 2 步：运行安装脚本

把路径换成你要装 pstack 的项目根目录。

```bash
./install.sh /path/to/your/project
```

脚本只做四件事，不会碰你的源代码。

1. 从 `cursor/plugins` 只下载 `pstack` 目录，在项目的 `.codebuddy/` 下生成约 7.5 MB 文件。
2. 把 58 个技能拷进项目的 `.codebuddy/skills/`。
3. 把本仓库 `config/` 里现成的 2 条规则和 2 个子代理拷进 `.codebuddy/`。
4. 把上游文档和 LICENSE 拷进 `.codebuddy/pstack/`，并写下版本号。

脚本会打印装好的技能数。第二次运行会复用已下载的源码，不会重复下载。

### 第 3 步：重开 CodeBuddy 并检查

在 CodeBuddy 里依次执行下面三条命令。

| 命令 | 应该看到 |
| --- | --- |
| `/skills` | 项目级技能里有 `poteto-mode`、`tdd`、`how` 等，共 58 个 |
| `/agents` | `poteto-agent`、`comment-sicko` |
| `/memory` | `pstack-codebuddy-harness`、`pstack-models` 两条规则已加载 |

三条都对，安装完成。

---

## 开始用

```
/poteto-mode 帮我查清楚登录流程是怎么工作的，只调查，不要改代码
```

`poteto-mode` 会自动挑一个剧本、拆步骤、按需调用其他技能。所有剧本在 `.codebuddy/skills/poteto-mode/playbooks/`。

常用命令：

| 命令 | 用途 |
| --- | --- |
| `/poteto-mode` | 严谨任务的主入口 |
| `/how`、`/why` | 只读理解代码 |
| `/tdd` | 先写失败测试再修 |
| `/no-comments` | 清理 AI 味注释 |
| `/unslop` | 清理 AI 味文案 |
| `/setup-pstack` | 按角色配模型，一般不用 |

模型默认已全部设为 `inherit-parent`，也就是跟着当前会话的模型走。不需要运行 `/setup-pstack`。

---

## 不想跑脚本，手动装

和脚本做的完全一样。在项目根目录之外执行，把 `TARGET` 换成你的项目路径。

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/cursor/plugins.git /tmp/pstack-src
git -C /tmp/pstack-src sparse-checkout set pstack
```

```bash
TARGET=/path/to/your/project
REPO=/path/to/pstack-to-codebuddy
mkdir -p "$TARGET/.codebuddy/skills" "$TARGET/.codebuddy/rules" "$TARGET/.codebuddy/agents" "$TARGET/.codebuddy/pstack"

cp -R /tmp/pstack-src/pstack/skills/. "$TARGET/.codebuddy/skills/"
cp -R /tmp/pstack-src/pstack/docs /tmp/pstack-src/pstack/agents \
      /tmp/pstack-src/pstack/automations /tmp/pstack-src/pstack/assets \
      /tmp/pstack-src/pstack/README.md /tmp/pstack-src/pstack/LICENSE \
      /tmp/pstack-src/pstack/plugin.json "$TARGET/.codebuddy/pstack/"

cp "$REPO/config/rules/"*.md "$TARGET/.codebuddy/rules/"
cp "$REPO/config/agents/"*.md "$TARGET/.codebuddy/agents/"
```

装完按第 3 步检查。

---

## 出问题了

| 现象 | 处理 |
| --- | --- |
| `/skills` 里看不到这些技能 | 确认 `.codebuddy` 在项目根目录，目录名没写错。重开一次会话。 |
| 提示某个模型 slug 无效 | 不要手填 Cursor 的模型名。配置里所有角色已经是 `inherit-parent`。 |
| 输出 `Skipped in CodeBuddy: ...` | 正常。这一步依赖 Cursor 的自动化或云端沙箱，CodeBuddy 没有，按约定跳过并继续。 |
| 想更新到新版 pstack | 删掉 `/tmp/pstack-src` 后重跑 `./install.sh`。 |
| 想卸载 | 删掉项目里的 `.codebuddy/skills/`、`.codebuddy/rules/pstack-*.md`、`.codebuddy/agents/poteto-agent.md`、`.codebuddy/agents/comment-sicko.md`。 |

---

## 边界

- `/arena`、`/swarm`、`/interrogate` 的多模型竞速不会真的切换模型。
- 隔夜自动化、Bugbot、Cursor 云端沙箱不能用。
- 技能和规则是软约束。验收请靠项目自己的测试、lint 和 CI。
- 本仓库不打包 pstack 技能文件。安装时由脚本从上游拉取，版本写在 `.codebuddy/pstack/VERSION.md`。

---

## 许可与来源

- 本仓库的文档、脚本和 `config/` 配置采用 MIT，见 [LICENSE](LICENSE)。
- pstack 技能文件来自 [cursor/plugins](https://github.com/cursor/plugins/tree/main/pstack)，MIT，作者 Lauren Tan。安装脚本会一并拷贝上游的 LICENSE。
- 参考文档：[CodeBuddy Skills](https://www.codebuddy.cn/docs/cli/skills)、[CodeBuddy 子代理](https://www.codebuddy.cn/docs/cli/sub-agents)、[CodeBuddy 记忆与规则](https://www.codebuddy.cn/docs/cli/memory)。
