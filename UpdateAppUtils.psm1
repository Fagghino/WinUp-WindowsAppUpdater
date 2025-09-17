# Modulo PowerShell per funzioni aggiuntive

function Get-InstalledApps {
    $apps = winget list --source winget | Select-Object -Skip 1
    $result = @()
    foreach ($line in $apps) {
        if ($line -match '^\s*(\S.*?)\s{2,}(\S.*?)\s{2,}(\S.*?)\s*$') {
            $result += [PSCustomObject]@{
                Name = $matches[1]
                Id   = $matches[2]
                Version = $matches[3]
            }
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
