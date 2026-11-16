#requires -Version 5.1
<#
    ROB RUN 简体中文汉化包 - 卸载脚本
    把 *.original_bak 还原回语言包位置。

    用法:
        双击「卸载汉化.bat」（推荐）
        或   powershell -ExecutionPolicy Bypass -File uninstall.ps1 [-GamePath "D:\Steam\steamapps\common\Rob Run"]
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
$LogPath    = Join-Path $env:TEMP 'ROBRUN-ZH-uninstall.log'

try { Start-Transcript -LiteralPath $LogPath -Force | Out-Null } catch {}

function Wait-Exit {
    if (-not $NoPause) {
        Write-Host ''
        Write-Host '按回车键退出...' -ForegroundColor DarkGray
        try { [void](Read-Host) } catch {}
    }
}

function Stop-Log { try { Stop-Transcript | Out-Null } catch {} }

function Fail($msg, $hint) {
    Write-Host ''
    Write-Host "[提示] $msg" -ForegroundColor Yellow
    if ($hint) { Write-Host $hint -ForegroundColor Yellow }
    Write-Host ''
    Write-Host "日志：$LogPath" -ForegroundColor DarkGray
    Stop-Log
    Wait-Exit
    exit 1
}

Write-Host ''
Write-Host ('=' * 48) -ForegroundColor Cyan
Write-Host '  ROB RUN 简体中文汉化包 - 卸载' -ForegroundColor Cyan
Write-Host ('=' * 48) -ForegroundColor Cyan

try {
    $running = @()
    foreach ($n in @('ROB RUN', 'start_protected_game')) {
        if (Get-Process -Name $n -ErrorAction SilentlyContinue) { $running += $n }
    }
    if ($running.Count -gt 0) {
        Fail ("游戏正在运行（$($running -join ', ')）。") '请先完全退出游戏，再重新运行本脚本。'
    }

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
        foreach ($d in @('C', 'D', 'E', 'F', 'G', 'H')) {
            foreach ($name in @('SteamLibrary', 'game', 'Games', 'Steam')) {
                $p = "${d}:\$name"
                if (Test-Path -LiteralPath $p) { if (-not $libs.Contains($p)) { $libs.Add($p) } }
            }
        }
        return $libs
    }

    $target = $null
    if ($GamePath) {
        $GamePath = $GamePath.TrimEnd('\')
        foreach ($p in @((Join-Path $GamePath $RelDir), $GamePath, (Join-Path $GamePath $RelDir))) {
            if (Test-Path -LiteralPath (Join-Path $p ($BundleName + '.original_bak'))) { $target = $p; break }
        }
    } else {
        foreach ($lib in (Get-SteamLibraries)) {
            $dir = Join-Path $lib ('steamapps\common\Rob Run\' + $RelDir)
            if (Test-Path -LiteralPath (Join-Path $dir ($BundleName + '.original_bak'))) { $target = $dir; break }
        }
    }

    if (-not $target) {
        Fail '没有找到汉化备份（可能从未安装过，或游戏目录已被移动）。' '如需修复，请在 Steam 里对 ROB RUN 执行「验证游戏文件的完整性」。'
    }

    $Dest   = Join-Path $target $BundleName
    $Backup = Join-Path $target ($BundleName + '.original_bak')

    Copy-Item -LiteralPath $Backup -Destination $Dest -Force
    Remove-Item -LiteralPath $Backup -Force

    Write-Host ''
    Write-Host "[成功] 已还原英文原版（$target）" -ForegroundColor Green
    Write-Host ''
    Stop-Log
    Wait-Exit
    exit 0

} catch {
    Write-Host ''
    Write-Host '[错误] 卸载过程中出现异常：' -ForegroundColor Red
    Write-Host ("  " + $_.Exception.Message) -ForegroundColor Red
    if ($_.Exception.Message -match '拒绝访问|Access|Unauthorized') {
        Write-Host '看起来是权限不足：请右键「卸载汉化.bat」->「以管理员身份运行」。' -ForegroundColor Yellow
    }
    Write-Host ''
    Write-Host "完整日志：$LogPath" -ForegroundColor DarkGray
    Stop-Log
    Wait-Exit
    exit 1
}
