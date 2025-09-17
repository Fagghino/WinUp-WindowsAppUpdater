# Modulo PowerShell per funzioni aggiuntive

function Get-InstalledApps {
    $wingetOutput = winget list --source winget
    if (-not $wingetOutput -or $wingetOutput.Count -lt 2) { return @() }
    $header = $wingetOutput[0]
    $data = $wingetOutput | Select-Object -Skip 1
    # Supporta header in italiano e inglese
    $nameIdx = $header.IndexOf('Name')
    $idIdx = $header.IndexOf('Id')
    $versionIdx = $header.IndexOf('Version')
    if ($nameIdx -lt 0) { $nameIdx = $header.IndexOf('Nome') }
    if ($versionIdx -lt 0) { $versionIdx = $header.IndexOf('Versione') }
    # "Disponibile"/"Available" non serve per la lista base
    if ($nameIdx -lt 0 -or $idIdx -lt 0 -or $versionIdx -lt 0) { return @() }
    $result = @()
    foreach ($line in $data) {
        if ($line.Trim() -eq "") { continue }
        $name = $line.Substring($nameIdx, $idIdx - $nameIdx).Trim()
        $id = $line.Substring($idIdx, $versionIdx - $idIdx).Trim()
        # Prendi la versione fino alla fine della riga
        $version = $line.Substring($versionIdx).Trim().Split(' ')[0]
        $result += [PSCustomObject]@{
            Name = $name
            Id = $id
            Version = $version
        }
    }
    return $result
}

function Update-SelectedApps {
    param (
        [array]$SelectedApps,
        [System.Windows.Forms.TextBox]$LogBox
    )
    foreach ($app in $SelectedApps) {
        $LogBox.AppendText("Aggiornamento di $($app.Name)...`r`n")
        try {
            $output = winget upgrade --id "$($app.Id)" --accept-source-agreements --accept-package-agreements 2>&1
            $LogBox.AppendText($output + "`r`n")
        } catch {
            $LogBox.AppendText("Errore durante l'aggiornamento di $($app.Name): $_`r`n")
        }
    }
    $LogBox.AppendText("Aggiornamento completato.`r`n")
}

Export-ModuleMember -Function Get-InstalledApps,Update-SelectedApps
