# Modulo PowerShell per funzioni aggiuntive

function Get-InstalledApps {
    $tempFile = [System.IO.Path]::GetTempFileName() + ".json"
    try {
        winget export -o $tempFile --source winget --accept-source-agreements | Out-Null
        if (Test-Path $tempFile) {
            $json = Get-Content $tempFile -Raw | ConvertFrom-Json
            if ($json -and $json.Sources -and $json.Sources[0].Packages) {
                $result = @()
                foreach ($pkg in $json.Sources[0].Packages) {
                    $result += [PSCustomObject]@{
                        Name = $pkg.PackageIdentifier
                        Id = $pkg.PackageIdentifier
                        Version = $pkg.Version
                    }
                }
                return $result
            }
        }
    } catch {
        # Fallback al parsing di testo se export fallisce
        $wingetOutput = winget list --source winget
        if (-not $wingetOutput -or $wingetOutput.Count -lt 2) { return @() }
        $header = $wingetOutput[0]
        $data = $wingetOutput | Select-Object -Skip 1
        $nameMatch = [regex]::Match($header, '(Nome|Name)')
        $idMatch = [regex]::Match($header, '\bId\b')
        $versionMatch = [regex]::Match($header, '(Versione|Version)')
        if (-not $nameMatch.Success -or -not $idMatch.Success -or -not $versionMatch.Success) { return @() }
        $nameIdx = $nameMatch.Index
        $idIdx = $idMatch.Index
        $versionIdx = $versionMatch.Index
        $result = @()
        foreach ($line in $data) {
            if ($line.Trim() -eq "" -or $line -match '^-{5,}') { continue }
            try {
                $name = $line.Substring($nameIdx, $idIdx - $nameIdx).Trim()
                $id = $line.Substring($idIdx, $versionIdx - $idIdx).Trim()
                $version = $line.Substring($versionIdx).Trim().Split(' ')[0]
                if ($name -and $id -and $version) {
                    $result += [PSCustomObject]@{
                        Name = $name
                        Id = $id
                        Version = $version
                    }
                }
            } catch {
                continue
            }
        }
        return $result
    } finally {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
    }
    return @()
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
