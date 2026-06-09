# SmartWrite Installer — Windows Version (PowerShell)
# Requires: Git, jq (recommended)

$RepoOwner = "zandercpzed"
$ObsidianConfig = "$env:APPDATA\obsidian\obsidian.json"

Write-Host "=== SmartWrite Installer (Windows) ===" -ForegroundColor Cyan

# Check dependencies
if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Git is not installed. Please install it from https://git-scm.com/" -ForegroundColor Red
    exit
}

if (!(Get-Command jq -ErrorAction SilentlyContinue)) {
    Write-Host "Warning: jq is not installed. Using basic parsing (less reliable)." -ForegroundColor Yellow
    Write-Host "Tip: Install jq via 'winget install jqlang.jq' for a better experience."
}

# 1. Discover Plugins
Write-Host "`n[1/4] Discovering SmartWrite plugins from GitHub..." -ForegroundColor Blue
$ReposUrl = "https://api.github.com/users/$RepoOwner/repos?per_page=100"
$Repos = Invoke-RestMethod -Uri $ReposUrl | Where-Object { $_.name -match "^smartwrite(r)?-.*" -and $_.name -ne "smartwrite-installer" }

if (!$Repos) {
    Write-Host "Failed to discover plugins." -ForegroundColor Red
    exit
}

$Plugins = @()
foreach ($repo in $Repos) {
    Write-Host "  -> Found repository: $($repo.name)"
    
    # Try main branch, then master if main fails
    $Manifest = $null
    foreach ($branch in @("main", "master")) {
        $ManifestUrl = "https://raw.githubusercontent.com/$RepoOwner/$($repo.name)/$branch/manifest.json"
        try {
            $Manifest = Invoke-RestMethod -Uri $ManifestUrl
            if ($Manifest.id) {
                Write-Host "     (Found manifest in '$branch' branch)" -ForegroundColor Gray
                break
            }
        } catch {
            $Manifest = $null
        }
    }

    if ($Manifest) {
        $Plugins += [PSCustomObject]@{
            id = $Manifest.id
            name = $Manifest.name
            description = $Manifest.description
            repo_url = "https://github.com/$RepoOwner/$($repo.name).git"
        }
    } else {
        Write-Host "     (Skipping: No manifest.json found in main or master branches)" -ForegroundColor Gray
    }
}

# 2. Detect Vaults
Write-Host "`n[2/4] Detecting Obsidian Vaults..." -ForegroundColor Blue
$Vaults = @()
if (Test-Path $ObsidianConfig) {
    $ConfigJson = Get-Content $ObsidianConfig | ConvertFrom-Json
    foreach ($vault in $ConfigJson.vaults.PSObject.Properties.Value) {
        if (Test-Path $vault.path) {
            $Vaults += $vault.path
        }
    }
}

if ($Vaults.Count -eq 0) {
    $ManualPath = Read-Host "Enter full path to your Obsidian Vault"
    if (Test-Path $ManualPath) { $Vaults += $ManualPath } else { Write-Host "Invalid path."; exit }
}

Write-Host "Found $($Vaults.Count) vault(s):"
for ($i=0; $i -lt $Vaults.Count; $i++) { Write-Host "[$i] $($Vaults[$i])" }
$Selections = Read-Host "Enter vault numbers (space separated)"
$SelectedVaults = $Selections.Split(" ") | ForEach-Object { $Vaults[[int]$_] }

# 3. Select Plugins
Write-Host "`n[3/4] Available Plugins:" -ForegroundColor Blue
for ($i=0; $i -lt $Plugins.Count; $i++) { Write-Host "[$i] $($Plugins[$i].name) - $($Plugins[$i].description)" }
$PSelections = Read-Host "Enter plugin numbers (space separated)"
$SelectedPlugins = $PSelections.Split(" ") | ForEach-Object { $Plugins[[int]$_] }

# 4. Install
Write-Host "`n[4/4] Installing..." -ForegroundColor Blue
foreach ($vault in $SelectedVaults) {
    $PluginDir = Join-Path $vault ".obsidian\plugins"
    if (!(Test-Path $PluginDir)) { New-Item -ItemType Directory -Path $PluginDir }
    
    foreach ($plugin in $SelectedPlugins) {
        $TargetDir = Join-Path $PluginDir $plugin.id
        Write-Host "  Installing $($plugin.name) in $(Split-Path $vault -Leaf)..." -ForegroundColor Green
        
        if (Test-Path $TargetDir) {
            Write-Host "    Updating repository..." -ForegroundColor Gray
            Set-Location $TargetDir
            git pull
        } else {
            Write-Host "    Cloning repository..." -ForegroundColor Gray
            git clone $plugin.repo_url $TargetDir
            Set-Location $TargetDir
        }

        # Build Check (Check for main.js)
        $MainJs = Join-Path $TargetDir "main.js"
        if (!(Test-Path $MainJs)) {
            Write-Host "    ⚠ Plugin needs to be compiled (no main.js found)." -ForegroundColor Cyan
            if (Get-Command npm -ErrorAction SilentlyContinue) {
                Write-Host "    Running npm install..." -ForegroundColor Gray
                Set-Location $TargetDir
                npm install --silent
                Write-Host "    Running npm run build..." -ForegroundColor Gray
                npm run build --silent
            } else {
                Write-Host "    Warning: npm not found. Plugin may not work without main.js." -ForegroundColor Yellow
            }
        }
        Write-Host "    Done." -ForegroundColor Green
    }
}

Write-Host "`nInstallation Complete! Restart Obsidian." -ForegroundColor Green
