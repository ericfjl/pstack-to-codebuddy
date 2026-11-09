---
description: pstack 各角色模型配置（覆盖技能默认值）。CodeBuddy 版统一回退到会话模型。
alwaysApply: true
---

# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# CodeBuddy 版：不写任何 Cursor / Claude 的 slug；`inherit-parent` 表示该角色运行在会话模型上。
# 想按角色配模型时，先用 /model 与 /agents 查本机可用模型，再改写对应行。
# budget: large (xhigh) — 仅作记录，CodeBuddy 未映射真实 slug。

feature, refactoring: inherit-parent
bug-fix: inherit-parent
perf-issue: inherit-parent
hillclimb: inherit-parent
judgment and prose: inherit-parent
hardest tasks: inherit-parent
how explorer: inherit-parent
how explainer: inherit-parent
why investigators: inherit-parent
why synthesizer: inherit-parent
reflect tooling: inherit-parent
reflect judgment, divergent, synthesizer: inherit-parent
arena runners: inherit-parent
arena cross-judge pool: inherit-parent
swarm workers: inherit-parent
architect runners: inherit-parent
interrogate reviewers: inherit-parent
