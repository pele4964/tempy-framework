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

function Read-JsonObject {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{}
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return [pscustomobject]@{}
    }

    return $raw | ConvertFrom-Json
}

function Set-ObjectProperty {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Value
    )

    if ($Object.PSObject.Properties.Name -contains $Name) {
        $Object.$Name = $Value
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Merge-UniqueArray {
    param(
        [object[]]$Existing,
        [object[]]$ToAdd
    )

    $result = New-Object System.Collections.Generic.List[string]
    foreach ($item in @($Existing) + @($ToAdd)) {
        if ($null -eq $item) {
            continue
        }
        $text = ([string]$item).Trim()
        if ($text -and (-not $result.Contains($text))) {
            [void]$result.Add($text)
        }
    }
    return $result.ToArray()
}

function Write-JsonObject {
    param(
        [string]$Path,
        [object]$Object
    )

    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $Object | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-ClaudeAllowRules {
    return @(
        "Read", "Write", "Edit", "MultiEdit", "Glob", "Grep", "LS",
        "Agent", "Task", "TodoWrite", "WebFetch", "WebSearch",
        "Bash", "Bash(*)", "PowerShell", "PowerShell(*)",
        "PowerShell(git *)", "PowerShell(openspec *)", "PowerShell(python *)",
        "PowerShell(cmd *)", "PowerShell(Get-*)", "PowerShell(Select-*)",
        "PowerShell(Get-Process *)", "PowerShell(Stop-Process *)",
        "PowerShell(Start-Process *)", "PowerShell(Start-Sleep *)",
        "PowerShell(Resolve-Path *)", "PowerShell(Test-Path *)",
        "PowerShell(Get-Content *)", "PowerShell(Set-Content *)",
        "PowerShell(Get-ChildItem *)", "PowerShell(Select-String *)",
        "PowerShell(Format-List *)", "PowerShell(Measure-Object *)",
        "PowerShell(npm *)", "PowerShell(node *)", "PowerShell(msbuild *)",
        "PowerShell(openspec validate --all)",
        "PowerShell(python ops\verifica_schema.py)",
        "Bash(git:*)", "Bash(openspec:*)", "Bash(python:*)", "Bash(cmd:*)",
        "Bash(powershell:*)", "Bash(powershell.exe:*)", "Bash(npm:*)",
        "Bash(node:*)", "Bash(msbuild:*)",
        "mcp__*"
    )
}

function Install-ClaudeCodePermissions {
    param([string]$UserProfilePath)

    $settingsPath = Join-Path $UserProfilePath ".claude\settings.json"
    $settings = Read-JsonObject -Path $settingsPath

    if (-not ($settings.PSObject.Properties.Name -contains "permissions")) {
        Set-ObjectProperty -Object $settings -Name "permissions" -Value ([pscustomobject]@{})
    }

    $permissions = $settings.permissions
    $allow = @()
    if ($permissions.PSObject.Properties.Name -contains "allow") {
        $allow = @($permissions.allow)
    }
    Set-ObjectProperty -Object $permissions -Name "allow" -Value (Merge-UniqueArray -Existing $allow -ToAdd (Get-ClaudeAllowRules))
    Set-ObjectProperty -Object $permissions -Name "defaultMode" -Value "bypassPermissions"

    if ($permissions.PSObject.Properties.Name -contains "ask") {
        $permissions.PSObject.Properties.Remove("ask")
    }

    $additional = @()
    if ($permissions.PSObject.Properties.Name -contains "additionalDirectories") {
        $additional = @($permissions.additionalDirectories)
    }
    $defaultDirs = @(
        (Join-Path $UserProfilePath "Documents"),
        (Join-Path $UserProfilePath ".claude"),
        (Join-Path $UserProfilePath ".codex")
    )
    Set-ObjectProperty -Object $permissions -Name "additionalDirectories" -Value (Merge-UniqueArray -Existing $additional -ToAdd $defaultDirs)
    Set-ObjectProperty -Object $settings -Name "skipDangerousModePermissionPrompt" -Value $true

    Write-JsonObject -Path $settingsPath -Object $settings
    Write-Tempy "Permessi Claude Code aggiornati: $settingsPath"
}

function Install-VSCodeClaudeSettings {
    param([string]$UserProfilePath)

    $appData = $env:APPDATA
    if (-not $appData) {
        $appData = Join-Path $UserProfilePath "AppData\Roaming"
    }

    $settingsPath = Join-Path $appData "Code\User\settings.json"
    $settings = Read-JsonObject -Path $settingsPath
    Set-ObjectProperty -Object $settings -Name "claudeCode.allowDangerouslySkipPermissions" -Value $true
    Set-ObjectProperty -Object $settings -Name "claudeCode.initialPermissionMode" -Value "bypassPermissions"
    Write-JsonObject -Path $settingsPath -Object $settings
    Write-Tempy "Impostazioni VSCode Claude aggiornate: $settingsPath"
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
Install-ClaudeCodePermissions -UserProfilePath $userProfile
Install-VSCodeClaudeSettings -UserProfilePath $userProfile
Install-OpenSpec

Write-Tempy "Installazione completata."
Write-Tempy "Apri una nuova chat/terminal session per far ricaricare le istruzioni."
