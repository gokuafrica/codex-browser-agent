param(
    [string]$Browser = "auto"
)

$ErrorActionPreference = "Stop"

$PluginName = "codex-browser-agent"
$LegacyPluginNames = @("playwright-browser-agent")
$ProfileDir = Join-Path $env:USERPROFILE ".playwright-mcp-profile"
$PluginDir = Join-Path $env:USERPROFILE "plugins\$PluginName"
$MarketplacePath = Join-Path $env:USERPROFILE ".agents\plugins\marketplace.json"
$CodexSkillsDir = Join-Path $env:USERPROFILE ".codex\skills"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PluginSourceDir = Join-Path $ScriptDir "plugin"

function Get-NodeMajorVersion {
    $version = & node -e "process.stdout.write(String(parseInt(process.version.slice(1), 10)))" 2>$null
    return [int]$version
}

function Find-BrowserCandidates {
    @(
        @{ Key = "msedge"; Label = "Microsoft Edge"; Paths = @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
            "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe"
        )},
        @{ Key = "chrome"; Label = "Google Chrome"; Paths = @(
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
        )},
        @{ Key = "firefox"; Label = "Firefox"; Paths = @(
            "${env:ProgramFiles}\Mozilla Firefox\firefox.exe",
            "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
        )}
    )
}

function Resolve-BrowserPath([string]$BrowserKey) {
    $candidate = Find-BrowserCandidates | Where-Object { $_.Key -eq $BrowserKey }
    if (-not $candidate) { return $null }
    foreach ($path in $candidate.Paths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

function Get-ProfileBrowserKey {
    $lastBrowserPath = Join-Path $ProfileDir "Last Browser"
    if (-not (Test-Path $lastBrowserPath)) {
        return $null
    }

    try {
        $content = Get-Content -LiteralPath $lastBrowserPath -Raw -Encoding Unicode
        if ($content -match "msedge\.exe") { return "msedge" }
        if ($content -match "chrome\.exe") { return "chrome" }
        if ($content -match "firefox\.exe") { return "firefox" }
    } catch {
        return $null
    }

    return $null
}

function Choose-BrowserKey([string]$RequestedBrowser) {
    $installed = @()
    foreach ($candidate in Find-BrowserCandidates) {
        $resolved = Resolve-BrowserPath $candidate.Key
        if ($resolved) {
            $installed += [PSCustomObject]@{ Key = $candidate.Key; Label = $candidate.Label; Path = $resolved }
        }
    }

    if ($installed.Count -eq 0) {
        throw "No supported browser found. Install Chrome, Edge, or Firefox."
    }

    if ($RequestedBrowser -and $RequestedBrowser -ne "auto") {
        $match = @($installed | Where-Object { $_.Key -eq $RequestedBrowser })
        if (-not $match) {
            throw "Requested browser '$RequestedBrowser' is not installed."
        }
        return $match[0]
    }

    $profileBrowser = Get-ProfileBrowserKey
    if ($profileBrowser) {
        $profileMatch = @($installed | Where-Object { $_.Key -eq $profileBrowser })
        if ($profileMatch) {
            return $profileMatch[0]
        }
    }

    return $installed[0]
}

function Write-JsonFile([string]$Path, $Object) {
    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $Object | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Update-Marketplace([string]$Path, [string]$PluginName) {
    $rootDir = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $rootDir -Force | Out-Null

    if (Test-Path $Path) {
        $marketplace = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } else {
        $marketplace = [ordered]@{
            name = "anwesh-local"
            interface = [ordered]@{
                displayName = "Anwesh Local Plugins"
            }
            plugins = @()
        }
    }

    if (-not $marketplace.plugins) {
        $marketplace | Add-Member -NotePropertyName plugins -NotePropertyValue @()
    }

    $marketplace.plugins = @($marketplace.plugins | Where-Object { $LegacyPluginNames -notcontains $_.name })

    $existing = @($marketplace.plugins | Where-Object { $_.name -eq $PluginName })
    if ($existing.Count -eq 0) {
        $entry = [ordered]@{
            name = $PluginName
            source = [ordered]@{
                source = "local"
                path = "./plugins/$PluginName"
            }
            policy = [ordered]@{
                installation = "INSTALLED_BY_DEFAULT"
                authentication = "ON_INSTALL"
            }
            category = "Productivity"
        }
        $marketplace.plugins += $entry
    } else {
        foreach ($entry in $existing) {
            $entry.source = [ordered]@{
                source = "local"
                path = "./plugins/$PluginName"
            }
            $entry.policy = [ordered]@{
                installation = "INSTALLED_BY_DEFAULT"
                authentication = "ON_INSTALL"
            }
            $entry.category = "Productivity"
        }
    }

    Write-JsonFile -Path $Path -Object $marketplace
}

function Remove-LegacyPlugins {
    foreach ($legacyName in $LegacyPluginNames) {
        $legacyDir = Join-Path $env:USERPROFILE "plugins\$legacyName"
        if (Test-Path $legacyDir) {
            Remove-Item -LiteralPath $legacyDir -Recurse -Force
        }
    }
}

function Rename-LegacyFallbackSkill {
    $legacySkillDir = Join-Path $CodexSkillsDir "playwright-browser"
    $fallbackSkillDir = Join-Path $CodexSkillsDir "playwright-browser-fallback"
    if ((Test-Path $legacySkillDir) -and (-not (Test-Path $fallbackSkillDir))) {
        Move-Item -LiteralPath $legacySkillDir -Destination $fallbackSkillDir
    }
}

Write-Host "`n=== Codex Browser Agent Installer ===" -ForegroundColor Cyan

Write-Host "`n[1/4] Checking prerequisites..." -ForegroundColor Yellow
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js was not found on PATH."
}
if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    throw "npx was not found on PATH."
}
$nodeMajor = Get-NodeMajorVersion
if ($nodeMajor -lt 18) {
    throw "Node.js v18+ is required. Found major version $nodeMajor."
}
Write-Host "  Node.js OK" -ForegroundColor Green

Write-Host "`n[2/4] Selecting browser..." -ForegroundColor Yellow
$selectedBrowser = Choose-BrowserKey $Browser
Write-Host "  Using: $($selectedBrowser.Label)" -ForegroundColor Green

Write-Host "`n[3/4] Installing plugin bundle..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path -Parent $PluginDir) -Force | Out-Null
Remove-LegacyPlugins
Rename-LegacyFallbackSkill
if (Test-Path $PluginDir) {
    Remove-Item -LiteralPath $PluginDir -Recurse -Force
}
Copy-Item -LiteralPath $PluginSourceDir -Destination $PluginDir -Recurse -Force

$mcpConfig = [ordered]@{
    mcpServers = [ordered]@{
        playwright = [ordered]@{
            type = "local"
            command = @(
                "npx",
                "-y",
                "@playwright/mcp@latest",
                "--browser",
                $selectedBrowser.Key,
                "--user-data-dir",
                $ProfileDir
            )
            note = "Installed by codex-browser-agent. Uses a persistent Playwright profile so future Codex sessions can reuse browser login state."
        }
    }
}
Write-JsonFile -Path (Join-Path $PluginDir ".mcp.json") -Object $mcpConfig
Write-Host "  Plugin installed to: $PluginDir" -ForegroundColor Green

Write-Host "`n[4/4] Updating Codex marketplace..." -ForegroundColor Yellow
Update-Marketplace -Path $MarketplacePath -PluginName $PluginName
Write-Host "  Marketplace updated: $MarketplacePath" -ForegroundColor Green

Write-Host "`n=== Installation Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Start a new Codex session"
Write-Host '  2. Try: Use $codex-browser-agent to open example.com'
Write-Host "  3. If a site needs login, complete it in the browser window once"
Write-Host '  4. Avoid explicitly invoking $playwright-browser; that name is reserved for shell fallback behavior'
Write-Host ""
Write-Host "Plugin path: $PluginDir" -ForegroundColor DarkGray
Write-Host "Profile path: $ProfileDir" -ForegroundColor DarkGray
