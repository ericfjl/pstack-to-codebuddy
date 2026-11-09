#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${PSTACK_SRC:-/tmp/pstack-src}"

if [ -z "$TARGET" ]; then
  echo "用法: ./install.sh /你的项目/绝对路径" >&2
  exit 1
fi

if [ ! -d "$TARGET" ]; then
  echo "目录不存在: $TARGET" >&2
  exit 1
fi

if [ ! -d "$SRC/pstack/skills" ]; then
  echo "正在下载 pstack 源码到 $SRC ..."
  git clone --depth 1 --filter=blob:none --sparse https://github.com/cursor/plugins.git "$SRC"
  git -C "$SRC" sparse-checkout set pstack
else
  echo "复用已有源码: $SRC"
fi

CB="$TARGET/.codebuddy"
mkdir -p "$CB/skills" "$CB/rules" "$CB/agents" "$CB/pstack"

cp -R "$SRC/pstack/skills/." "$CB/skills/"
cp -R "$SRC/pstack/docs" "$SRC/pstack/agents" "$SRC/pstack/automations" \
      "$SRC/pstack/assets" "$SRC/pstack/README.md" "$SRC/pstack/LICENSE" \
      "$SRC/pstack/plugin.json" "$CB/pstack/"
cp "$ROOT/config/rules/"*.md "$CB/rules/"
cp "$ROOT/config/agents/"*.md "$CB/agents/"

COMMIT="$(git -C "$SRC" rev-parse HEAD 2>/dev/null || echo unknown)"
VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$SRC/pstack/plugin.json")"
printf '# pstack 版本\n\n上游 commit: %s\npstack 版本: %s\n安装日期: %s\n' \
  "$COMMIT" "$VERSION" "$(date +%F)" > "$CB/pstack/VERSION.md"

echo "安装完成: $CB"
echo "技能 $(ls "$CB/skills" | wc -l | tr -d ' ') 个，剧本 $(ls "$CB/skills/poteto-mode/playbooks" | wc -l | tr -d ' ') 个"
echo "下一步: 重开 CodeBuddy，依次执行 /skills、/agents、/memory 检查。"
