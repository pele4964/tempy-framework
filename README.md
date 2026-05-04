# Tempy Framework

Tempy Framework e' il bootstrap del metodo di lavoro AI di Federico.

Installa su un PC nuovo:
- regole globali Codex;
- regole globali Claude Code;
- OpenSpec, se manca;
- backup automatico dei file globali gia' presenti.

Non installa regole di progetto.
Le regole di progetto restano dentro ogni singolo repository.

## Installazione Locale

Da repo clonato:

```powershell
git clone https://github.com/pele4964/tempy-framework.git
cd tempy-framework
pwsh .\install.ps1
```

## Installazione Remota

Dopo aver pubblicato il repo su GitHub:

```powershell
irm https://raw.githubusercontent.com/pele4964/tempy-framework/main/install.ps1 | iex
```

## Cosa Installa

Codex:

```text
C:\Users\<utente>\.codex\AGENTS.md
```

Claude Code:

```text
C:\Users\<utente>\.claude\CLAUDE.md
```

OpenSpec:

```powershell
npm install -g @fission-ai/openspec@latest
```

## Backup

Se i file globali esistono gia', vengono salvati in:

```text
C:\Users\<utente>\.codex\backups-tempy\
C:\Users\<utente>\.claude\backups-tempy\
```

## Opzioni

Saltare OpenSpec:

```powershell
pwsh .\install.ps1 -SkipOpenSpec
```

Non creare backup:

```powershell
pwsh .\install.ps1 -NoBackup
```

Usare un raw base diverso:

```powershell
pwsh .\install.ps1 -RepoRawBase "https://raw.githubusercontent.com/pele4964/tempy-framework/main"
```

## Prossimo Passo Per Pubblicarlo

1. Crea un repo GitHub chiamato `tempy-framework`.
2. Fai push del contenuto.
3. Installa da qualunque PC con il comando remoto.
