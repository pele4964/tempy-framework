param(
    [switch]$SkipOpenSpec,
    [switch]$NoBackup,
    [string]$RepoRawBase = "https://raw.githubusercontent.com/<github-user>/tempy-framework/main"
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

    $openspec = Get-Command openspec -ErrorAction SilentlyContinue
    if ($openspec) {
        $version = (& openspec --version) 2>$null
        Write-Tempy "OpenSpec gia' presente: $version"
        return
    }

    Write-Tempy "OpenSpec non trovato. Installo @fission-ai/openspec@latest con npm..."
    & npm install -g "@fission-ai/openspec@latest"
    if ($LASTEXITCODE -ne 0) {
        throw "Installazione OpenSpec fallita."
    }

    $version = (& openspec --version) 2>$null
    Write-Tempy "OpenSpec installato: $version"
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
