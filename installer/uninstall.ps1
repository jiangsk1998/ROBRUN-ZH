#requires -Version 5.1
<#
    ROB RUN 简体中文汉化包 - 卸载脚本
    把 *.original_bak 还原回语言包位置。
#>
param(
    [string]$GamePath = '',
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

function Wait-Exit {
    if (-not $NoPause) { Read-Host '按回车退出' }
}

$BundleName = 'localization-string-tables-english(unitedstates)(en-us)_assets_all.bundle'
$RelDir     = 'ROB RUN_Data\StreamingAssets\aa\StandaloneWindows64'
$Root       = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ''
Write-Host ('=' * 48) -ForegroundColor Cyan
Write-Host '  ROB RUN 简体中文汉化包 - 卸载' -ForegroundColor Cyan
Write-Host ('=' * 48) -ForegroundColor Cyan

$proc = Get-Process -Name 'ROB RUN', 'start_protected_game' -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host '[提示] 游戏正在运行，请先退出游戏。' -ForegroundColor Yellow
    Wait-Exit
    exit 1
}

function Find-Target {
    if ($GamePath) {
        foreach ($p in @((Join-Path $GamePath $RelDir), $GamePath)) {
            if (Test-Path -LiteralPath (Join-Path $p ($BundleName + '.original_bak'))) { return $p }
            if (Test-Path -LiteralPath (Join-Path $p $BundleName)) { return $p }
        }
        return $null
    }
    $roots = New-Object System.Collections.Generic.List[string]
    foreach ($key in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
        try {
            $p = (Get-ItemProperty -Path $key -ErrorAction Stop).SteamPath
            if ($p) {
                $roots.Add(($p -replace '/', '\'))
                $vdf = Join-Path ($p -replace '/', '\') 'steamapps\libraryfolders.vdf'
                if (Test-Path -LiteralPath $vdf) {
                    $text = Get-Content -LiteralPath $vdf -Raw -Encoding UTF8
                    foreach ($m in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
                        $roots.Add(($m.Groups[1].Value -replace '\\\\', '\'))
                    }
                }
            }
        } catch {}
    }
    foreach ($lib in $roots) {
        $dir = Join-Path $lib ('steamapps\common\Rob Run\' + $RelDir)
        if (Test-Path -LiteralPath (Join-Path $dir ($BundleName + '.original_bak'))) { return $dir }
    }
    return $null
}

$target = Find-Target
if (-not $target) {
    Write-Host ''
    Write-Host '[提示] 没有找到汉化备份（可能从未安装过，或游戏目录已被移动）。' -ForegroundColor Yellow
    Write-Host '如需修复，请在 Steam 里对 ROB RUN 执行「验证游戏文件的完整性」。' -ForegroundColor Yellow
    Write-Host ''
    Wait-Exit
    exit 1
}

$Dest   = Join-Path $target $BundleName
$Backup = Join-Path $target ($BundleName + '.original_bak')

Copy-Item -LiteralPath $Backup -Destination $Dest -Force
Remove-Item -LiteralPath $Backup -Force

Write-Host ''
Write-Host "[成功] 已还原英文原版（$target）" -ForegroundColor Green
Write-Host ''
Wait-Exit
