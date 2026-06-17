param(
    [switch]$SkipOpenSpec,
    [switch]$NoBackup,
    [string]$RepoRawBase = "https://raw.githubusercontent.com/pele4964/tempy-framework/main"
)

$ErrorActionPreference = "Stop"

function Write-Tempy {
    param([string]$Message)
    Write-Host "[Tempy Framework] $Message"
}

function Get-ScriptRoot {
    if ($PSScriptRoot) {
        return $PSScriptRoot
    }

    if ($MyInvocation.MyCommand.Path) {
        return Split-Path -Parent $MyInvocation.MyCommand.Path
    }

    return ""
}

function Get-TemplateText {
    param(
        [string]$RelativePath
    )

    $scriptRoot = Get-ScriptRoot
    if ($scriptRoot) {
        $localPath = Join-Path $scriptRoot $RelativePath
        if (Test-Path -LiteralPath $localPath) {
            return Get-Content -LiteralPath $localPath -Raw -Encoding UTF8
        }
    }

    if ($RepoRawBase -like "*<github-user>*") {
        throw "RepoRawBase non configurato. Prima di usare installazione remota, sostituisci <github-user> in install.ps1 oppure passa -RepoRawBase."
    }

    $remotePath = $RelativePath -replace "\\", "/"
    $uri = "$RepoRawBase/$remotePath"
    Write-Tempy "Scarico template remoto: $uri"
    return Invoke-RestMethod -Uri $uri
}

function Backup-ExistingFile {
    param([string]$Path)

    if ($NoBackup) {
        return
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $directory = Split-Path -Parent $Path
    $fileName = Split-Path -Leaf $Path
    $backupDirectory = Join-Path $directory "backups-tempy"
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = Join-Path $backupDirectory "$fileName.$timestamp.bak"

    New-Item -ItemType Directory -Force -Path $backupDirectory | Out-Null
    Copy-Item -LiteralPath $Path -Destination $backupPath -Force
    Write-Tempy "Backup creato: $backupPath"
}

function Install-TextFile {
    param(
        [string]$Content,
        [string]$Destination
    )

    $directory = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    Backup-ExistingFile -Path $Destination
    Set-Content -LiteralPath $Destination -Value $Content -Encoding UTF8
    Write-Tempy "Installato: $Destination"
}

function Normalize-VersionText {
    param([object]$VersionText)

    if (-not $VersionText) {
        return ""
    }

    $text = (($VersionText | Select-Object -First 1) -as [string]).Trim()
    if ($text -match "(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z\.-]+)?)") {
        return $Matches[1]
    }

    return $text
}

function Get-InstalledOpenSpecVersion {
    $openspec = Get-Command openspec -ErrorAction SilentlyContinue
    if (-not $openspec) {
        return ""
    }

    $versionOutput = (& openspec --version) 2>$null
    if ($LASTEXITCODE -ne 0) {
        return ""
    }

    return Normalize-VersionText -VersionText $versionOutput
}

function Get-LatestOpenSpecVersion {
    $versionOutput = (& npm view "@fission-ai/openspec" version) 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Impossibile leggere la versione latest di @fission-ai/openspec da npm."
    }

    $version = Normalize-VersionText -VersionText $versionOutput
    if (-not $version) {
        throw "Versione latest di OpenSpec non leggibile dalla risposta npm."
    }

    return $version
}

function Install-LatestOpenSpec {
    param([string]$Reason)

    Write-Tempy "$Reason Installo @fission-ai/openspec@latest con npm..."
    & npm install -g "@fission-ai/openspec@latest"
    if ($LASTEXITCODE -ne 0) {
        throw "Installazione/aggiornamento OpenSpec fallito."
    }

    $version = Get-InstalledOpenSpecVersion
    if (-not $version) {
        throw "OpenSpec installato ma versione non verificabile."
    }

    Write-Tempy "OpenSpec pronto: $version"
}

function Install-OpenSpec {
    if ($SkipOpenSpec) {
        Write-Tempy "OpenSpec saltato per richiesta esplicita."
        return
    }

    $npm = Get-Command npm -ErrorAction SilentlyContinue
    if (-not $npm) {
        Write-Warning "npm non trovato. Installa Node.js/npm e rilancia questo installer per installare OpenSpec."
        return
    }

    $latestVersion = Get-LatestOpenSpecVersion
    $installedVersion = Get-InstalledOpenSpecVersion

    if (-not $installedVersion) {
        Install-LatestOpenSpec -Reason "OpenSpec non trovato."
        return
    }

    if ($installedVersion -eq $latestVersion) {
        Write-Tempy "OpenSpec gia' aggiornato: $installedVersion"
        return
    }

    Install-LatestOpenSpec -Reason "OpenSpec presente ma non aggiornato ($installedVersion -> $latestVersion)."
}

Write-Tempy "Avvio installazione."

$userProfile = $env:USERPROFILE
if (-not $userProfile) {
    throw "USERPROFILE non trovato. Impossibile calcolare le cartelle globali utente."
}

$codexTemplate = Get-TemplateText -RelativePath "templates\codex\AGENTS.md"
$claudeTemplate = Get-TemplateText -RelativePath "templates\claude\CLAUDE.md"

Install-TextFile -Content $codexTemplate -Destination (Join-Path $userProfile ".codex\AGENTS.md")
Install-TextFile -Content $claudeTemplate -Destination (Join-Path $userProfile ".claude\CLAUDE.md")
Install-OpenSpec

Write-Tempy "Installazione completata."
Write-Tempy "Apri una nuova chat/terminal session per far ricaricare le istruzioni."
