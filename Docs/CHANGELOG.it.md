# 📝 Changelog — WinUp — Windows App Updater (Italiano)

Tutte le modifiche rilevanti a questo progetto sono documentate in questo file.

Il formato è basato su [Keep a Changelog](https://keepachangelog.com/it/1.1.0/),
e questo progetto aderisce al [Versionamento Semantico](https://semver.org/lang/it/).

> 🇬🇧 English version available in [`CHANGELOG.en.md`](CHANGELOG.en.md)

## [Non rilasciato]

### Aggiunto
- Barra di ricerca per filtrare rapidamente le app nella tabella.
- Notifiche di sistema per aggiornamenti disponibili.
- Lista esclusioni per saltare app specifiche dagli aggiornamenti.
- Export CSV/Excel della lista app e storico aggiornamenti.
- Supporto multi-source completo (winget + msstore + personalizzati).
- Logging strutturato con rotazione file.

## [2.1.0] - 2026-09-23

### Aggiunto
- **Tema scuro UI:** Revisione visiva completa con palette colori moderna (`#1E1E2E` base, accento teal `#4ECCA3`).
- **Motore aggiornamento asincrono:** Processo di streaming `System.Diagnostics.Process` con log in tempo reale — la GUI non si blocca mai durante gli aggiornamenti.
- **Verifica disponibilità winget:** All'avvio viene verificato che winget sia installato, con dialogo di errore chiaro se non trovato.
- **Integrazione `config.json`:** Impostazioni `wingetSource`, `logLevel` e `theme` lette e applicate all'avvio.
- **Barra di stato:** Barra inferiore indicante lo stato corrente (es. "X app aggiornabili trovate").
- **Tipografia uniforme:** Font Segoe UI su tutti i controlli, Consolas nella console di log.
- **Documentazione bilingue:** `README.md` (Inglese) + `Docs/README.it.md` (Italiano).
- **Changelog separati:** `Docs/CHANGELOG.en.md` (Inglese) + `Docs/CHANGELOG.it.md` (Italiano).
- **`.gitattributes`:** Aggiunto per normalizzazione LF/CRLF e hint GitHub Linguist.

### Modificato
- **Stile moderno dei pulsanti:** Sostituiti i colori di sistema con pulsanti curati e colori d'accento per categoria.
- **Ottimizzazioni `UpdateAppUtils.psm1`:** Documentato come modulo legacy/standalone; array `$result +=` sostituiti con `List[PSCustomObject]` per performance O(n).
- **Sicurezza parsing regex:** Righe header e separatore saltate esplicitamente in `Get-UpgradableApps` per prevenire falsi positivi.
- **Documentazione README:** Riscritto in inglese, eliminate sezioni duplicate e affermazioni obsolete sulla cache.

### Corretto
- **Duplicazione dati all'avvio:** `Get-UpgradableApps` viene invocato una sola volta dopo il rendering della UI e riutilizzato al refresh.
- **Output log da array a stringa:** Risolto bug di concatenazione array `$output` usando un join con a capo.
- **Loop di layout ridondante:** Rimosso ciclo AutoSizeMode non operativo nell'inizializzazione del DataGridView.
- **Codice non raggiungibile nel modulo:** Rimosso `return @()` non raggiungibile dopo il blocco `finally` in `UpdateAppUtils.psm1`.
- **Isolamento runspace PowerShell:** Sostituito `BackgroundWorker` con inizializzazione UI a timer ed eventi di processo per garantire thread safety in PowerShell.

## [2.0.0] - 2025-11-01

### Aggiunto
- **Interfaccia tabellare:** `DataGridView` al posto del vecchio `CheckedListBox`.
- **Colonne dati:** Seleziona, Nome, ID, Versione Attuale e Versione Disponibile.
- **Colonne auto-sizing:** Larghezza si adatta automaticamente al contenuto delle celle.
- **Finestra ridimensionabile:** Dimensione minima impostata e supporto massimizzazione.
- **Splitter dinamico:** Ridimensionamento manuale tra pannello tabella e console log.
- **Layout responsive:** Sistema `Dock` per adattamento automatico dei pannelli.
- **Vista aggiornabili prioritaria:** Mostra app aggiornabili all'avvio.
- **Controlli contestuali:** Checkbox e pulsanti abilitati/disabilitati in modalità sola lettura.

### Modificato
- **Parser versioni:** Logica di parsing corretta per l'output di `winget list`.
- **Localizzazione header:** Riconoscimento automatico header colonne in italiano e inglese.
- **Limiti colonne:** Calcolo posizionale dei caratteri basato sugli offset dell'header.

### Corretto
- **Livello finestra:** Rimosso `$form.Topmost = $true` per non forzare la finestra sempre in primo piano.
- **Visualizzazione versioni app complete:** Corretta la visualizzazione versione nella lista completa app.
- **Gestione valori null:** Gestione sicura per valori di celle vuote o nulli in DataGridView.
- **Sovrapposizione pannelli:** Layout dock pulito per prevenire sovrapposizioni durante il ridimensionamento.

## [1.0.0] - 2025-01-01

### Aggiunto
- Interfaccia CheckedListBox per la selezione dei pacchetti.
- Elenco delle applicazioni installate tramite `winget list`.
- Selezione multipla ed esecuzione batch degli aggiornamenti.
- Casella di testo per visualizzazione log in tempo reale.
- Pulsanti di azione base (Aggiorna, Seleziona tutto, Deseleziona tutto).
- Supporto al file di configurazione `config.json` per sorgente e livello di log.
- Modulo helper `UpdateAppUtils.psm1`.
- Gestione errori con blocchi try/catch.

[Non rilasciato]: https://github.com/Fagghino/BOT-AGGIORNA-APP/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/Fagghino/BOT-AGGIORNA-APP/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/Fagghino/BOT-AGGIORNA-APP/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/Fagghino/BOT-AGGIORNA-APP/releases/tag/v1.0.0
