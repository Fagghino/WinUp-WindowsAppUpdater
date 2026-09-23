# UpdateAppUtils.psm1
# Legacy/standalone utility module for WinUp-WindowsAppUpdater.
#
# NOTE: This module is NOT imported by update.ps1 (which is self-contained).
# It is kept for standalone use, external scripting, or future refactoring.
# Functions here mirror those in update.ps1 but use 'winget export' instead
# of 'winget list' for the installed apps list.

function Get-InstalledApps {
    <#
    .SYNOPSIS
        Returns a list of apps installed via winget using 'winget export'.
    .OUTPUTS
        [System.Collections.Generic.List[PSCustomObject]] with Name, Id, Version.
    #>
    $tempFile = [System.IO.Path]::GetTempFileName() + ".json"
    $result   = [System.Collections.Generic.List[PSCustomObject]]::new()

    try {
        winget export -o $tempFile --source winget --accept-source-agreements | Out-Null
        if (Test-Path $tempFile) {
            $json = Get-Content $tempFile -Raw | ConvertFrom-Json
            if ($json -and $json.Sources -and $json.Sources[0].Packages) {
                foreach ($pkg in $json.Sources[0].Packages) {
                    $result.Add([PSCustomObject]@{
                        Name    = $pkg.PackageIdentifier
                        Id      = $pkg.PackageIdentifier
                        Version = $pkg.Version
                    })
                }
                return $result
            }
        }
    } catch {
        # Fallback: text parsing via 'winget list'
        $wingetOutput = winget list --source winget
        if (-not $wingetOutput -or $wingetOutput.Count -lt 2) { return $result }

        $header       = $wingetOutput[0]
        $data         = $wingetOutput | Select-Object -Skip 2
        $nameMatch    = [regex]::Match($header, '(Nome|Name)')
        $idMatch      = [regex]::Match($header, '\bId\b')
        $versionMatch = [regex]::Match($header, '(Versione|Version)')

        if (-not $nameMatch.Success -or -not $idMatch.Success -or -not $versionMatch.Success) {
            return $result
        }

        $nameIdx    = $nameMatch.Index
        $idIdx      = $idMatch.Index
        $versionIdx = $versionMatch.Index

        foreach ($line in $data) {
            if ($line.Trim() -eq "" -or $line -match '^-{5,}') { continue }
            try {
                $name    = $line.Substring($nameIdx, $idIdx - $nameIdx).Trim()
                $id      = $line.Substring($idIdx,   $versionIdx - $idIdx).Trim()
                $version = $line.Substring($versionIdx).Trim().Split(' ')[0]
                if ($name -and $id -and $version) {
                    $result.Add([PSCustomObject]@{
                        Name    = $name
                        Id      = $id
                        Version = $version
                    })
                }
            } catch { continue }
        }
        return $result
    } finally {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
    }
    # Reached only if export succeeded but returned no packages
    return $result
}

function Update-SelectedApps {
    <#
    .SYNOPSIS
        Updates the given list of apps via winget, appending output to a TextBox.
    .PARAMETER SelectedApps
        Array or List of PSCustomObjects with at least Name and Id properties.
    .PARAMETER LogBox
        A System.Windows.Forms.TextBox or RichTextBox to append log output to.
    #>
    param (
        [array]$SelectedApps,
        [System.Windows.Forms.TextBoxBase]$LogBox
    )
    foreach ($app in $SelectedApps) {
        $LogBox.AppendText("Aggiornamento di $($app.Name)...`r`n")
        try {
            $output = winget upgrade --id "$($app.Id)" `
                --accept-source-agreements `
                --accept-package-agreements 2>&1
            $LogBox.AppendText(($output -join "`r`n") + "`r`n")
        } catch {
            $LogBox.AppendText("Errore durante l'aggiornamento di $($app.Name): $_`r`n")
        }
    }
    $LogBox.AppendText("Aggiornamento completato.`r`n")
}

Export-ModuleMember -Function Get-InstalledApps, Update-SelectedApps
