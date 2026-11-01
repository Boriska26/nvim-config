# Windows PowerShell 5.1 / PowerShell 7. No downloaded scripts are executed.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$devkitLang = 'en'
if ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'ru') { $devkitLang = 'ru' }
function Say([string]$Ru, [string]$En) {
    if ($devkitLang -eq 'ru') { Write-Host $Ru } else { Write-Host $En }
}
function Usage {
    Say 'Использование: .\install.ps1 [-Main] [-Lang ru|en] [-Help]' 'Usage: .\install.ps1 [-Main] [-Lang ru|en] [-Help]'
    Say 'По умолчанию: отдельная конфигурация nvim-devkit; -Main выбирает nvim.' 'Default: isolated nvim-devkit configuration; -Main selects nvim.'
    Say '-Lang ru|en: язык сообщений. Существующие пути не перезаписываются.' '-Lang ru|en: message language. Existing paths are never overwritten.'
}
function InvalidArguments { Say 'Неверные аргументы.' 'Invalid arguments.'; Usage; exit 2 }
$devkitMain = $false
$devkitHelp = $false
$devkitSeenLang = $false
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ([string]$args[$i]) {
        '-Main' { if ($devkitMain) { InvalidArguments }; $devkitMain = $true }
        '-Help' { if ($devkitHelp) { InvalidArguments }; $devkitHelp = $true }
        '-Lang' {
            if ($devkitSeenLang -or $i + 1 -ge $args.Count) { InvalidArguments }
            $i++
            if ($args[$i] -cnotin @('ru', 'en')) { InvalidArguments }
            $devkitLang = [string]$args[$i]; $devkitSeenLang = $true
        }
        default { InvalidArguments }
    }
}
if ($devkitHelp) { Usage; exit 0 }
$devkitStage = $null
# Cleanup only our private staging tree; never traverse junctions or symlinks.
function RemoveOwnedTree([string]$Path) {
    foreach ($entry in [IO.Directory]::GetFileSystemEntries($Path)) {
        $attributes = [IO.File]::GetAttributes($entry)
        $directory = ($attributes -band [IO.FileAttributes]::Directory) -ne 0
        $link = ($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
        if ($directory -and -not $link) { RemoveOwnedTree $entry }
        elseif ($directory) { [IO.Directory]::Delete($entry) }
        else {
            if (-not $link) { [IO.File]::SetAttributes($entry, [IO.FileAttributes]::Normal) }
            [IO.File]::Delete($entry)
        }
    }
    [IO.Directory]::Delete($Path)
}
function StopInstall([string]$Ru, [string]$En) {
    $message = if ($devkitLang -eq 'ru') { $Ru } else { $En }
    throw $message
}
$devkitExit = 1
try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        StopInstall 'Этот установщик поддерживает только Windows.' 'This installer supports Windows only.'
    }
    $nvim = Get-Command nvim -CommandType Application -ErrorAction SilentlyContinue
    $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue
    if (-not $nvim) {
        StopInstall 'Установи Neovim 0.12.6+ из официального выпуска или проверенного пакета winget/Scoop/Chocolatey: https://github.com/neovim/neovim/releases' 'Install Neovim 0.12.6+ from an official release or verified winget/Scoop/Chocolatey package: https://github.com/neovim/neovim/releases'
    }
    if (-not $git) {
        StopInstall 'Установи Git for Windows и перезапусти терминал: https://git-scm.com/downloads/win' 'Install Git for Windows and restart the terminal: https://git-scm.com/downloads/win'
    }
    $versionOutput = (& $nvim.Source --version 2>$null) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch 'NVIM v(\d+\.\d+\.\d+)') {
        StopInstall 'Не удалось определить версию Neovim.' 'Could not determine the Neovim version.'
    }
    if ([version]$Matches[1] -lt [version]'0.12.6') {
        StopInstall 'Требуется Neovim 0.12.6+. Обнови пакет или установи официальный выпуск.' 'Neovim 0.12.6+ is required. Upgrade the package or install an official release.'
    }
    $base = $env:XDG_CONFIG_HOME
    if ([string]::IsNullOrWhiteSpace($base)) { $base = $env:LOCALAPPDATA }
    # IsPathRooted alone also accepts drive-relative C:foo and root-relative \foo.
    if ([string]::IsNullOrWhiteSpace($base) -or
        $base -notmatch '^(?:[A-Za-z]:[\\/]|[\\/]{2}[^\\/]+[\\/][^\\/]+(?:[\\/]|$))') {
        StopInstall 'LOCALAPPDATA/XDG_CONFIG_HOME должен задавать абсолютный каталог.' 'LOCALAPPDATA/XDG_CONFIG_HOME must specify an absolute directory.'
    }
    $app = if ($devkitMain) { 'nvim' } else { 'nvim-devkit' }
    $target = [IO.Path]::Combine([IO.Path]::GetFullPath($base), $app)
    # Get-Item also recognizes an existing reparse-point entry; never replace one.
    $existing = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    if ($existing) {
        if (Test-Path -LiteralPath (Join-Path $target 'lua/generators/init.lua')) {
            Say 'DevKit уже установлен; автоматического обновления нет.' 'DevKit is already installed; automatic updates are not supported.'
        }
        Write-Host $target
        StopInstall 'Путь уже существует. Самостоятельно сделай резервную копию или выбери изолированный режим без -Main.' 'Path already exists. Make a backup yourself or choose isolated mode without -Main.'
    }
    [void][IO.Directory]::CreateDirectory($base)
    $devkitStage = Join-Path $base ('.nvim-devkit-install.' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($devkitStage)
    $repo = 'https://github.com/Boriska26/nvim-config'
    Say 'Проверка опубликованных тегов…' 'Checking published tags…'
    $tagsFile = Join-Path $devkitStage 'tags'
    try {
        $ErrorActionPreference = 'Continue' # WinPS 5.1 treats native stderr as ErrorRecords.
        & $git.Source ls-remote --tags --refs $repo >$tagsFile 2>(Join-Path $devkitStage 'git.log')
        $gitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = 'Stop' }
    if ($gitCode -ne 0) { StopInstall 'Не удалось прочитать теги Git. Проверь сеть, прокси и GitHub.' 'Git tag query failed. Check network, proxy and GitHub access.' }
    $stable = @(foreach ($line in Get-Content -LiteralPath $tagsFile) {
        if ($line -match 'refs/tags/(v?(\d+\.\d+\.\d+))$') {
            [pscustomobject]@{ Ref = $Matches[1]; Version = [version]$Matches[2] }
        }
    })
    $ref = 'main'
    if ($stable.Count) { $ref = ($stable | Sort-Object Version, Ref | Select-Object -Last 1).Ref }
    else { Say 'Стабильных SemVer-тегов нет: будет установлена ветка main, а не стабильный релиз.' 'No stable SemVer tags found: installing main, not a stable release.' }
    Write-Host $ref
    $clone = Join-Path $devkitStage 'repo'
    try {
        $ErrorActionPreference = 'Continue'
        & $git.Source -c "core.hooksPath=$(Join-Path $devkitStage 'no-hooks')" -c core.fsmonitor=false clone --depth 1 --branch $ref -- $repo $clone *> (Join-Path $devkitStage 'git.log')
        $gitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = 'Stop' }
    if ($gitCode -ne 0) { StopInstall 'Клонирование не удалось; целевая конфигурация не создана.' 'Clone failed; target configuration was not created.' }
    if (-not (Test-Path -LiteralPath (Join-Path $clone 'init.lua') -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $clone 'lua/plugins/init.lua') -PathType Leaf)) {
        StopInstall 'В клоне нет ожидаемых файлов DevKit.' 'The clone lacks the expected DevKit files.'
    }
    if (-not $devkitMain) {
        $launch = Join-Path $clone '.devkit-launch'
        if (Test-Path -LiteralPath $launch) { StopInstall 'Конфликт каталога launcher.' 'Launcher directory conflict.' }
        [void][IO.Directory]::CreateDirectory($launch)
        $script = @'
$hadValue = Test-Path Env:NVIM_APPNAME
$previousValue = $env:NVIM_APPNAME
$ErrorActionPreference = 'Stop'
try {
    $env:NVIM_APPNAME = 'nvim-devkit'
    & nvim @args
    $result = $LASTEXITCODE
} finally {
    if ($hadValue) { $env:NVIM_APPNAME = $previousValue }
    else { Remove-Item Env:NVIM_APPNAME -ErrorAction SilentlyContinue }
}
exit $result
'@
        [IO.File]::WriteAllText((Join-Path $launch 'nvim-devkit.ps1'), $script, (New-Object Text.UTF8Encoding($false)))
    }
    # Directory.Move refuses existing destinations, including a concurrent installation.
    [IO.Directory]::Move($clone, $target)
    Say 'Установлено:' 'Installed:'
    Write-Host $target
    if (-not $devkitMain) {
        Write-Host '$env:NVIM_APPNAME = "nvim-devkit"; nvim'
        Write-Host (Join-Path $target '.devkit-launch/nvim-devkit.ps1')
        Write-Host 'Remove-Item Env:NVIM_APPNAME'
    } else { Write-Host '$env:NVIM_APPNAME = "nvim"; nvim' }
    Say 'Плагины не запускались. При первом запуске vim.pack предложит установку. Затем: :DevKitLang ru, :DevKitDoctor, :DevKitHelp.' 'Plugins were not launched. On first launch vim.pack prompts to install them. Then run :DevKitLang en, :DevKitDoctor, :DevKitHelp.'
    $devkitExit = 0
} catch {
    Say 'Установка не завершена. Существующая конфигурация не перезаписана.' 'Installation did not complete. Existing configuration was not overwritten.'
    Write-Host $_.Exception.Message
} finally {
    if ($devkitStage -and [IO.Directory]::Exists($devkitStage)) {
        try { RemoveOwnedTree $devkitStage }
        catch {
            Say "Не удалось очистить временный каталог: $devkitStage. Удали его вручную после проверки." "Could not clean staging directory: $devkitStage. Inspect and remove it manually."
            $devkitExit = 1
        }
    }
}
exit $devkitExit
