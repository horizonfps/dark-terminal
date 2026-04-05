$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$red    = "`e[38;2;200;0;30m"
$green  = "`e[38;2;0;230;64m"
$dim    = "`e[2m"
$reset  = "`e[0m"

function Log-Ok($msg)   { Write-Host "  ${green}[ok]${reset} $msg" }
function Log-Info($msg)  { Write-Host "  ${dim}[..]${reset} $msg" }
function Log-Fail($msg)  { Write-Host "  ${red}[!!]${reset} $msg" }

# ── 1. Install jq ──────────────────────────────────────
Log-Info "Checking jq..."
$jqPath = "$env:USERPROFILE\bin\jq.exe"
if (-not (Get-Command jq -ErrorAction SilentlyContinue) -and -not (Test-Path $jqPath)) {
    Log-Info "Downloading jq..."
    New-Item -ItemType Directory -Path "$env:USERPROFILE\bin" -Force | Out-Null
    Invoke-WebRequest -Uri "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-windows-amd64.exe" -OutFile $jqPath
    Log-Ok "jq installed to ~/bin/jq.exe"
} else {
    Log-Ok "jq already installed"
}

# ── 2. Install JetBrainsMono Nerd Font ──────────────────
Log-Info "Checking JetBrainsMono Nerd Font..."
$fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$fontCheck = Get-ChildItem $fontDir -Filter "JetBrainsMonoNerdFont*" -ErrorAction SilentlyContinue
if (-not $fontCheck) {
    Log-Info "Downloading JetBrainsMono Nerd Font..."
    $zipPath = "$env:TEMP\JetBrainsMono.zip"
    $extractPath = "$env:TEMP\JetBrainsMono"
    Invoke-WebRequest -Uri "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
    $fontFiles = @(
        "JetBrainsMonoNerdFont-Regular.ttf",
        "JetBrainsMonoNerdFont-Bold.ttf",
        "JetBrainsMonoNerdFont-Italic.ttf",
        "JetBrainsMonoNerdFont-BoldItalic.ttf"
    )
    foreach ($f in $fontFiles) {
        $src = Join-Path $extractPath $f
        if (Test-Path $src) {
            Copy-Item $src $fontDir -Force
        }
    }

    # Register in registry
    $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    $fonts = Get-ChildItem $fontDir -Filter "JetBrainsMonoNerdFont*.ttf"
    foreach ($f in $fonts) {
        $name = $f.BaseName + " (TrueType)"
        Set-ItemProperty -Path $regPath -Name $name -Value $f.FullName -Force
    }

    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    Log-Ok "JetBrainsMono Nerd Font installed ($($fonts.Count) variants)"
} else {
    Log-Ok "JetBrainsMono Nerd Font already installed"
}

# ── 3. Claude Code statusline ───────────────────────────
Log-Info "Installing Claude Code statusline..."
$claudeDir = "$env:USERPROFILE\.claude"
New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null

$statuslineSrc = Join-Path $scriptDir "assets\statusline.sh"
$statuslineDst = Join-Path $claudeDir "statusline.sh"

if (Test-Path "$statuslineDst") {
    Copy-Item $statuslineDst "$statuslineDst.bak" -Force
    Log-Info "Backed up existing statusline.sh"
}
Copy-Item $statuslineSrc $statuslineDst -Force

# Update claude settings.json for statusline
$claudeSettings = Join-Path $claudeDir "settings.json"
if (Test-Path $claudeSettings) {
    $settings = Get-Content $claudeSettings -Raw | ConvertFrom-Json
} else {
    $settings = @{}
}
$settings | Add-Member -NotePropertyName "statusLine" -NotePropertyValue @{
    type = "command"
    command = 'bash "$HOME/.claude/statusline.sh"'
} -Force
$settings | ConvertTo-Json -Depth 10 | Set-Content $claudeSettings -Encoding UTF8
Log-Ok "Claude Code statusline configured"

# ── 4. Windows Terminal settings ────────────────────────
Log-Info "Configuring Windows Terminal..."

$wtPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)

$wtSettings = $null
$wtPath = $null
foreach ($p in $wtPaths) {
    if (Test-Path $p) {
        $wtPath = $p
        break
    }
}

if (-not $wtPath) {
    Log-Fail "Windows Terminal settings.json not found"
} else {
    # Backup
    Copy-Item $wtPath "$wtPath.bak" -Force
    Log-Info "Backed up Windows Terminal settings"

    $wt = Get-Content $wtPath -Raw | ConvertFrom-Json

    # Add Hellfire scheme
    $schemeJson = Get-Content (Join-Path $scriptDir "assets\hellfire-scheme.json") -Raw | ConvertFrom-Json
    $existingScheme = $wt.schemes | Where-Object { $_.name -eq "Hellfire" }
    if ($existingScheme) {
        $wt.schemes = @($wt.schemes | Where-Object { $_.name -ne "Hellfire" }) + @($schemeJson)
    } else {
        if (-not $wt.schemes) { $wt.schemes = @() }
        $wt.schemes = @($wt.schemes) + @($schemeJson)
    }

    # Set defaults
    $defaults = @{
        antialiasingMode = "cleartype"
        colorScheme = "Hellfire"
        cursorColor = "#FF3C14"
        cursorShape = "filledBox"
        font = @{
            face = "JetBrainsMono Nerd Font"
            size = 11
            weight = "normal"
        }
        opacity = 85
        padding = "12, 12, 12, 12"
        scrollbarState = "visible"
        useAcrylic = $true
    }
    $wt.profiles.defaults = $defaults

    $wt | ConvertTo-Json -Depth 10 | Set-Content $wtPath -Encoding UTF8
    Log-Ok "Windows Terminal configured with Hellfire theme"
}

# ── 5. CMD AutoRun (global prompt + clean startup) ──────
Log-Info "Configuring CMD prompt globally..."
$regPath = "HKCU:\SOFTWARE\Microsoft\Command Processor"
New-Item -Path $regPath -Force -ErrorAction SilentlyContinue | Out-Null
$promptCmd = 'cls & prompt $_$E[2m$E[38;2;80;80;80m' + [char]0x250c + [char]0x2500 + '$E[0m$E[38;2;140;140;140m$P$E[0m$_$E[2m$E[38;2;80;80;80m' + [char]0x2514 + [char]0x2500 + '$E[0m$E[38;2;200;0;30m' + [char]0x203a + '$E[0m '
Set-ItemProperty -Path $regPath -Name "AutoRun" -Value $promptCmd -Force
Log-Ok "CMD prompt configured globally (AutoRun)"

# ── 6. Add ~/bin to PATH if needed ──────────────────────
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$binDir = "$env:USERPROFILE\bin"
if ($userPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$binDir;$userPath", "User")
    Log-Ok "Added ~/bin to user PATH"
} else {
    Log-Ok "~/bin already in PATH"
}

Write-Host ""
Write-Host "  ${green}Hellfire Terminal installed.${reset}"
Write-Host ""
Write-Host "  ${dim}Components:${reset}"
Write-Host "    - Hellfire color scheme (Windows Terminal)"
Write-Host "    - JetBrainsMono Nerd Font"
Write-Host "    - Dark aesthetic statusline (Claude Code)"
Write-Host "    - Hellfire CMD prompt (global AutoRun)"
Write-Host "    - jq (JSON processor)"
Write-Host ""
