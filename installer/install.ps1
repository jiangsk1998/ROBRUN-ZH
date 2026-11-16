#requires -Version 5.1
<#
    ROB RUN 简体中文汉化包 - 安装脚本

    用法:
        双击「安装汉化.bat」（推荐）
        或   powershell -ExecutionPolicy Bypass -File install.ps1 [-GamePath "D:\Steam\steamapps\common\Rob Run"]

    行为:
        1. 自动定位 Steam 库中的 Rob Run（读注册表 + libraryfolders.vdf + 常见盘符）
        2. 首次安装时把原版语言包备份为 *.original_bak（不会重复备份）
        3. 用汉化版 bundle 覆盖游戏内的英文语言包
        4. 全过程写入日志：%TEMP%\ROBRUN-ZH-install.log
#>
param(
    [string]$GamePath = '',
    # 由 .bat 调用时使用：不在脚本内等待按键（由 .bat 统一 pause）
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$BundleName = 'localization-string-tables-english(unitedstates)(en-us)_assets_all.bundle'
$RelDir     = 'ROB RUN_Data\StreamingAssets\aa\StandaloneWindows64'
$Root       = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogPath    = Join-Path $env:TEMP 'ROBRUN-ZH-install.log'

try { Start-Transcript -LiteralPath $LogPath -Force | Out-Null } catch {}

function Write-Title($text) {
    Write-Host ''
    Write-Host ('=' * 48) -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host ('=' * 48) -ForegroundColor Cyan
}

function Wait-Exit {
    if (-not $NoPause) {
        Write-Host ''
        Write-Host '按回车键退出...' -ForegroundColor DarkGray
        try { [void](Read-Host) } catch {}
    }
}

function Stop-Log {
    try { Stop-Transcript | Out-Null } catch {}
}

function Fail($msg, $hint) {
    Write-Host ''
    Write-Host "[错误] $msg" -ForegroundColor Red
    if ($hint) { Write-Host $hint -ForegroundColor Yellow }
    Write-Host ''
    Write-Host "日志：$LogPath" -ForegroundColor DarkGray
    Stop-Log
    Wait-Exit
    exit 1
}

Write-Title 'ROB RUN 简体中文汉化包 - 安装'
Write-Host "脚本位置：$Root" -ForegroundColor DarkGray

try {
    # ---------- 1. 找到汉化文件 ----------
    $candidates = @(
        (Join-Path $Root ('bundle\' + $BundleName)),         # 发布包结构
        (Join-Path $Root $BundleName),                        # 直接放在同一目录
        (Join-Path $Root ('..\bundle\' + $BundleName)),       # 仓库结构（备用）
        (Join-Path $Root ('..\patch\' + $BundleName))         # 仓库结构
    )
    $Source = $null
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { $Source = (Resolve-Path -LiteralPath $c).Path; break }
    }
    if (-not $Source) {
        Fail "找不到汉化文件 $BundleName" @"
请确认压缩包已完整解压（不要直接在压缩包里双击运行），
解压后目录里应该有 bundle 文件夹和 install.ps1。
已尝试查找：
$($candidates -join "`n")
"@
    }
    Write-Host "汉化文件：$Source" -ForegroundColor DarkGray

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
            if (Test-Path -LiteralPath $base) { $steamRoots.Add($base) }
        }

        foreach ($r in $steamRoots) {
            if (-not (Test-Path -LiteralPath $r)) { continue }
            if (-not $libs.Contains($r)) { $libs.Add($r) }
            $vdf = Join-Path $r 'steamapps\libraryfolders.vdf'
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
        # 兜底：常见游戏盘
        foreach ($d in @('C', 'D', 'E', 'F', 'G', 'H')) {
            foreach ($name in @('SteamLibrary', 'game', 'Games', 'Steam')) {
                $p = "${d}:\$name"
                if (Test-Path -LiteralPath $p) {
                    if (-not $libs.Contains($p)) { $libs.Add($p) }
                }
            }
        }
        return $libs
    }

    $Target = $null
    if ($GamePath) {
        $GamePath = $GamePath.TrimEnd('\')
        if (Test-Path -LiteralPath (Join-Path $GamePath $BundleName)) {
            $Target = $GamePath
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
请先确认游戏已通过 Steam 安装（能正常启动过一次），然后任选一种方式：
  a) 手动指定路径重跑：
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
    $running = @()
    foreach ($n in @('ROB RUN', 'start_protected_game')) {
        $p = Get-Process -Name $n -ErrorAction SilentlyContinue
        if ($p) { $running += $n }
    }
    if ($running.Count -gt 0) {
        Fail ("检测到游戏正在运行（$($running -join ', ')）。") '请先完全退出 ROB RUN（包括启动器 / Steam 里的“停止”），再重新运行本脚本。'
    }

    # ---------- 4. 备份 + 覆盖 ----------
    $Dest   = Join-Path $Target $BundleName
    $Backup = Join-Path $Target ($BundleName + '.original_bak')

    if (-not (Test-Path -LiteralPath $Dest)) {
        Fail "游戏内找不到语言包：$Dest" '游戏文件可能不完整，建议先在 Steam 里「验证游戏文件完整性」后重试。'
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
        Fail '复制后的文件大小不一致，可能被安全软件拦截。' '请把游戏目录（或其所在盘符）加入杀毒软件信任区后重试。'
    }

    Write-Host ''
    Write-Host '[成功] 汉化已安装。' -ForegroundColor Green
    Write-Host '现在从 Steam 库启动 ROB RUN，界面就是中文了。'
    Write-Host ''
    Write-Host '还原英文：运行「卸载汉化.bat」' -ForegroundColor DarkGray
    Write-Host '注意：游戏大更新后语言包会被覆盖，重跑一次本脚本即可。' -ForegroundColor DarkGray
    Write-Host ''
    Stop-Log
    Wait-Exit
    exit 0

} catch {
    Write-Host ''
    Write-Host '[错误] 安装过程中出现异常：' -ForegroundColor Red
    Write-Host ("  " + $_.Exception.Message) -ForegroundColor Red
    if ($_.Exception.Message -match '拒绝访问|Access|Unauthorized') {
        Write-Host '看起来是权限不足：请右键「安装汉化.bat」->「以管理员身份运行」。' -ForegroundColor Yellow
    }
    Write-Host ''
    Write-Host "完整日志：$LogPath" -ForegroundColor DarkGray
    Stop-Log
    Wait-Exit
    exit 1
}
