# Aggiorna App con Winget

Questo script PowerShell permette di selezionare e aggiornare facilmente le applicazioni installate tramite una semplice interfaccia grafica.

## Utilizzo rapido

Esegui direttamente da terminale PowerShell:

```
irm https://raw.githubusercontent.com/Fagghino/Bot-Auto-Update/main/update.ps1 | iex
```

## Funzionalità
- Recupera la lista delle app installate tramite winget
- Mostra una GUI con checklist per selezionare le app da aggiornare
- Aggiorna solo le app selezionate
- Mostra log e avanzamento

## Requisiti
- Windows 10/11
- PowerShell 5.1+
- winget installato e configurato nel PATH

## Personalizzazione
Il codice è modulare: puoi aggiungere nuove funzioni o modificare la GUI facilmente.

## Note
- Per problemi con i permessi, esegui PowerShell come amministratore.
- Per suggerimenti o miglioramenti, apri una issue su GitHub.
