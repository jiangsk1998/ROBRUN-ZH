#requires -Version 5.1
<#
    ROB RUN 简体中文汉化包 - 安装脚本

    用法:
        双击「安装汉化.bat」
        或   powershell -ExecutionPolicy Bypass -File install.ps1 [-GamePath "D:\Steam\steamapps\common\Rob Run"]

    行为:
        1. 自动定位 Steam 库中的 Rob Run（读注册表 + libraryfolders.vdf，逐个库尝试）
        2. 首次安装时把原版语言包备份为 *.original_bak（不会重复备份）
        3. 用汉化版 bundle 覆盖游戏内的英文语言包
#>
param(
    [string]$GamePath = '',
    # 自动化场景：不等待按键
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$BundleName = 'localization-string-tables-english(unitedstates)(en-us)_assets_all.bundle'
$RelDir     = 'ROB RUN_Data\StreamingAssets\aa\StandaloneWindows64'
$Root       = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Title($text) {
    Write-Host ''
    Write-Host ('=' * 48) -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host ('=' * 48) -ForegroundColor Cyan
}

function Wait-Exit {
    if (-not $NoPause) { Read-Host '按回车退出' }
}

function Fail($msg, $hint) {
    Write-Host ''
    Write-Host "[错误] $msg" -ForegroundColor Red
    if ($hint) { Write-Host $hint -ForegroundColor Yellow }
    Write-Host ''
    Wait-Exit
    exit 1
}

Write-Title 'ROB RUN 简体中文汉化包 - 安装'

# ---------- 1. 找到汉化文件 ----------
$candidates = @(
    (Join-Path $Root ('bundle\' + $BundleName)),        # 发布包结构
    (Join-Path $Root ('..\patch\' + $BundleName))      # 仓库结构
)
$Source = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $Source) { Fail "找不到汉化文件 $BundleName" '请确认解压完整，bundle 目录需要和本脚本放在一起。' }

# ---------- 2. 定位游戏目录 ----------
function Get-SteamLibraries {
    $libs = New-Object System.Collections.Generic.List[string]
    $steamRoots = New-Object System.Collections.Generic.List[string]

    foreach ($key in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
        try {
            $p = (Get-ItemProperty -Path $key -ErrorAction Stop).SteamPath
            if ($p) { $steamRoots.Add(($p -replace '/', '\')) }
        } catch {}
    }
    foreach ($base in @('C:\Program Files (x86)\Steam', 'C:\Program Files\Steam')) {
        if (Test-Path $base) { $steamRoots.Add($base) }
    }

    foreach ($root in $steamRoots) {
        if (-not (Test-Path $root)) { continue }
        $libs.Add($root)
        $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            try {
                $text = Get-Content -LiteralPath $vdf -Raw -Encoding UTF8
                foreach ($m in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
                    $p = $m.Groups[1].Value -replace '\\\\', '\'
                    if ($p -and -not $libs.Contains($p)) { $libs.Add($p) }
                }
            } catch {}
        }
    }
    # 兜底：扫一遍常见盘符
    foreach ($d in @('C', 'D', 'E', 'F', 'G')) {
        $p = "${d}:\SteamLibrary"
        if (Test-Path $p) { if (-not $libs.Contains($p)) { $libs.Add($p) } }
        $p2 = "${d}:\game"
        if (Test-Path $p2) { if (-not $libs.Contains($p2)) { $libs.Add($p2) } }
    }
    return $libs
}

$Target = $null
if ($GamePath) {
    if (Test-Path -LiteralPath (Join-Path $GamePath $BundleName)) {
        $Target = Join-Path $GamePath $RelDir
    } elseif (Test-Path -LiteralPath (Join-Path $GamePath $RelDir)) {
        $Target = Join-Path $GamePath $RelDir
    } else {
        Fail "指定的游戏目录无效: $GamePath" '请传入 Rob Run 的安装根目录（里面应有 ROB RUN_Data 或 ROB RUN.exe）。'
    }
} else {
    foreach ($lib in (Get-SteamLibraries)) {
        $dir = Join-Path $lib ('steamapps\common\Rob Run\' + $RelDir)
        if (Test-Path -LiteralPath (Join-Path $dir $BundleName)) { $Target = $dir; break }
    }
}

if (-not $Target) {
    Fail '没有找到 ROB RUN 的游戏目录。' @"
请先确认游戏已通过 Steam 安装，然后任选一种方式：
  a) 重新运行并手动指定路径：
     powershell -ExecutionPolicy Bypass -File install.ps1 -GamePath "你的\steamapps\common\Rob Run"
  b) 手动复制：
     把 bundle\$BundleName 复制到
     <Steam库>\steamapps\common\Rob Run\$RelDir\
"@
}

Write-Host ''
Write-Host '游戏目录：' -NoNewline
Write-Host $Target -ForegroundColor Green

# ---------- 3. 检查游戏是否在跑 ----------
$proc = Get-Process -Name 'ROB RUN', 'start_protected_game' -ErrorAction SilentlyContinue
if ($proc) { Fail '检测到游戏正在运行。' '请先完全退出 ROB RUN（包括启动器），再重新运行本脚本。' }

# ---------- 4. 备份 + 覆盖 ----------
$Dest   = Join-Path $Target $BundleName
$Backup = Join-Path $Target ($BundleName + '.original_bak')

if (-not (Test-Path -LiteralPath $Dest)) {
    Fail "游戏内找不到语言包：$Dest" '游戏文件可能不完整，建议先在 Steam 里「验证游戏文件完整性」。'
}

if (Test-Path -LiteralPath $Backup) {
    Write-Host '已存在原版备份，跳过备份（保留最初的原版文件）' -ForegroundColor DarkGray
} else {
    Copy-Item -LiteralPath $Dest -Destination $Backup -Force
    Write-Host '已备份原版语言包 -> *.original_bak' -ForegroundColor DarkGray
}

Copy-Item -LiteralPath $Source -Destination $Dest -Force

# ---------- 5. 结果 ----------
$srcSize = (Get-Item -LiteralPath $Source).Length
$dstSize = (Get-Item -LiteralPath $Dest).Length
if ($srcSize -ne $dstSize) {
    Fail '复制后的文件大小不一致，可能被安全软件拦截。' '请把游戏目录加入杀毒软件信任区后重试。'
}

Write-Host ''
Write-Host '[成功] 汉化已安装。' -ForegroundColor Green
Write-Host '现在从 Steam 库启动 ROB RUN，界面就是中文了。'
Write-Host ''
Write-Host '还原英文：运行「卸载汉化.bat」' -ForegroundColor DarkGray
Write-Host '注意：游戏大更新后语言包会被覆盖，重跑一次本脚本即可。' -ForegroundColor DarkGray
Write-Host ''
Wait-Exit
