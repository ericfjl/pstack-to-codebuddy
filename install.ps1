#Requires -Version 5.1
<#
.SYNOPSIS
把 pstack 技能栈安装到指定项目的 .codebuddy 目录。Windows 用这个脚本，macOS / Linux 用 install.sh。
#>
param(
    [string]$Target = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
    Write-Host "[pstack] $Message"
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git 未安装或未加入 PATH。请先安装 Git for Windows。'
}

$Target = [System.IO.Path]::GetFullPath($Target)
if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
    throw "项目目录不存在: $Target"
}

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$TempRoot = [System.IO.Path]::GetTempPath()
$Src = if ($env:PSTACK_SRC) { $env:PSTACK_SRC } else { Join-Path $TempRoot 'pstack-src' }
$Upstream = Join-Path $Src 'pstack'
$UpstreamSkills = Join-Path $Upstream 'skills'

if (-not (Test-Path -LiteralPath $UpstreamSkills -PathType Container)) {
    Write-Step "下载 pstack 源码到 $Src"
    git clone --depth 1 --filter=blob:none --sparse https://github.com/cursor/plugins.git $Src
    if ($LASTEXITCODE -ne 0) { throw '克隆 cursor/plugins 失败。' }
    git -C $Src sparse-checkout set pstack
    if ($LASTEXITCODE -ne 0) { throw '设置 sparse-checkout 失败。' }
} else {
    Write-Step "复用已有源码: $Src"
}

$CB = Join-Path $Target '.codebuddy'
foreach ($Name in @('skills', 'rules', 'agents', 'pstack')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $CB $Name) | Out-Null
}

Write-Step '拷贝技能与上游文档'
Get-ChildItem -LiteralPath $UpstreamSkills -Force |
    Copy-Item -Destination (Join-Path $CB 'skills') -Recurse -Force

$PstackDir = Join-Path $CB 'pstack'
foreach ($Item in @('docs', 'agents', 'automations', 'assets', 'README.md', 'LICENSE', 'plugin.json')) {
    Copy-Item -LiteralPath (Join-Path $Upstream $Item) -Destination $PstackDir -Recurse -Force
}

Write-Step '拷贝适配规则与子代理'
$ConfigDir = Join-Path $Root 'config'
Get-ChildItem -LiteralPath (Join-Path $ConfigDir 'rules') -File -Filter '*.md' |
    Copy-Item -Destination (Join-Path $CB 'rules') -Force
Get-ChildItem -LiteralPath (Join-Path $ConfigDir 'agents') -File -Filter '*.md' |
    Copy-Item -Destination (Join-Path $CB 'agents') -Force

$Commit = (git -C $Src rev-parse HEAD 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $Commit) { $Commit = 'unknown' }
$Version = (Get-Content -LiteralPath (Join-Path $Upstream 'plugin.json') -Raw | ConvertFrom-Json).version
$VersionText = "# pstack 版本`n`n上游 commit: $Commit`npstack 版本: $Version`n安装日期: $(Get-Date -Format 'yyyy-MM-dd')`n"
[System.IO.File]::WriteAllText(
    (Join-Path $PstackDir 'VERSION.md'),
    $VersionText,
    (New-Object System.Text.UTF8Encoding($false))
)

$SkillsDir = Join-Path $CB 'skills'
$SkillCount = (Get-ChildItem -LiteralPath $SkillsDir -Directory).Count
$PlaybookCount = (Get-ChildItem -LiteralPath (Join-Path (Join-Path $SkillsDir 'poteto-mode') 'playbooks') -File -Filter '*.md').Count
$RuleCount = (Get-ChildItem -LiteralPath (Join-Path $CB 'rules') -File -Filter '*.md').Count
$AgentCount = (Get-ChildItem -LiteralPath (Join-Path $CB 'agents') -File -Filter '*.md').Count

Write-Step "安装完成: $CB"
Write-Host "技能 $SkillCount 个，剧本 $PlaybookCount 个，规则 $RuleCount 条，子代理 $AgentCount 个"
Write-Host '下一步: 重开 CodeBuddy，依次执行 /skills、/agents、/memory 检查。'
