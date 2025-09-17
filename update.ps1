# update.ps1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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

# Recupera solo le app con aggiornamento disponibile
function Get-UpgradableApps {
    $apps = winget upgrade --source winget | Select-Object -Skip 1
    $result = @()
    foreach ($line in $apps) {
        if ($line -match '^\s*(\S.*?)\s{2,}(\S.*?)\s{2,}(\S.*?)\s{2,}(\S.*?)\s*$') {
            $result += [PSCustomObject]@{
                Name = $matches[1]
                Id   = $matches[2]
                Version = $matches[3]
                Available = $matches[4]
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

function Show-UpdateGUI {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Aggiorna App con Winget"
    $form.Size = New-Object System.Drawing.Size(700, 700)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)

    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Size = New-Object System.Drawing.Size(650, 320)
    $checkedListBox.Location = New-Object System.Drawing.Point(20, 20)
    $checkedListBox.CheckOnClick = $true
    $checkedListBox.BackColor = [System.Drawing.Color]::White

    $logBox = New-Object System.Windows.Forms.TextBox
    $logBox.Multiline = $true
    $logBox.ScrollBars = "Vertical"
    $logBox.Size = New-Object System.Drawing.Size(650, 200)
    $logBox.Location = New-Object System.Drawing.Point(20, 350)
    $logBox.ReadOnly = $true
    $logBox.BackColor = [System.Drawing.Color]::WhiteSmoke

    # Pannello per i pulsanti
    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Size = New-Object System.Drawing.Size(650, 60)
    $buttonPanel.Location = New-Object System.Drawing.Point(20, 570)
    $buttonPanel.BackColor = [System.Drawing.Color]::FromArgb(230,230,230)

    $updateButton = New-Object System.Windows.Forms.Button
    $updateButton.Text = "Aggiorna"
    $updateButton.Size = New-Object System.Drawing.Size(110, 40)
    $updateButton.Location = New-Object System.Drawing.Point(10, 10)
    $updateButton.BackColor = [System.Drawing.Color]::LightGreen
    $updateButton.FlatStyle = 'Flat'

    $selectAllButton = New-Object System.Windows.Forms.Button
    $selectAllButton.Text = "Seleziona tutto"
    $selectAllButton.Size = New-Object System.Drawing.Size(120, 40)
    $selectAllButton.Location = New-Object System.Drawing.Point(130, 10)
    $selectAllButton.BackColor = [System.Drawing.Color]::LightSkyBlue
    $selectAllButton.FlatStyle = 'Flat'

    $deselectAllButton = New-Object System.Windows.Forms.Button
    $deselectAllButton.Text = "Deseleziona tutto"
    $deselectAllButton.Size = New-Object System.Drawing.Size(120, 40)
    $deselectAllButton.Location = New-Object System.Drawing.Point(260, 10)
    $deselectAllButton.BackColor = [System.Drawing.Color]::LightSkyBlue
    $deselectAllButton.FlatStyle = 'Flat'

    $showUpgradableButton = New-Object System.Windows.Forms.Button
    $showUpgradableButton.Text = "Mostra solo aggiornabili"
    $showUpgradableButton.Size = New-Object System.Drawing.Size(170, 40)
    $showUpgradableButton.Location = New-Object System.Drawing.Point(390, 10)
    $showUpgradableButton.BackColor = [System.Drawing.Color]::Orange
    $showUpgradableButton.FlatStyle = 'Flat'

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = "Chiudi"
    $closeButton.Size = New-Object System.Drawing.Size(100, 40)
    $closeButton.Location = New-Object System.Drawing.Point(570, 10)
    $closeButton.BackColor = [System.Drawing.Color]::Salmon
    $closeButton.FlatStyle = 'Flat'

    $buttonPanel.Controls.Add($updateButton)
    $buttonPanel.Controls.Add($selectAllButton)
    $buttonPanel.Controls.Add($deselectAllButton)
    $buttonPanel.Controls.Add($showUpgradableButton)
    $buttonPanel.Controls.Add($closeButton)

    $form.Controls.Add($checkedListBox)
    $form.Controls.Add($logBox)
    $form.Controls.Add($buttonPanel)

    $logBox.AppendText("Caricamento in corso...`r`n")
    $apps = $null
    $upgradableApps = $null
    $showingUpgradable = $false
    $loading = $true

    function RefreshAppList {
        $checkedListBox.Items.Clear()
        if ($showingUpgradable) {
            $logBox.AppendText("Recupero lista app aggiornabili...`r`n")
            $upgradableApps = Get-UpgradableApps
            if ($upgradableApps.Count -eq 0) {
                $logBox.AppendText("Nessuna app aggiornabile trovata!`r`n")
            }
            foreach ($app in $upgradableApps) {
                $checkedListBox.Items.Add("$($app.Name) [$($app.Id)]", $false)
            }
            $logBox.AppendText("Trovate $($upgradableApps.Count) app aggiornabili.`r`n")
        } else {
            if ($apps.Count -eq 0) {
                $logBox.AppendText("Nessuna app trovata!`r`n")
            }
            foreach ($app in $apps) {
                $checkedListBox.Items.Add("$($app.Name) [$($app.Id)]", $false)
            }
            $logBox.AppendText("Trovate $($apps.Count) app installate.`r`n")
        }
    }

    # Caricamento asincrono con BackgroundWorker
    $worker = New-Object System.ComponentModel.BackgroundWorker
    $worker.WorkerReportsProgress = $false
    $worker.add_DoWork({
        $script:apps = Get-InstalledApps
    })
    $worker.add_RunWorkerCompleted({
        $logBox.Clear()
        RefreshAppList
        $logBox.AppendText("Seleziona le app da aggiornare e premi 'Aggiorna'.`r`n")
        $script:loading = $false
    })
    $form.Add_Shown({ $worker.RunWorkerAsync() })

    $updateButton.Add_Click({
        if ($loading) { return }
        $selectedIndices = $checkedListBox.CheckedIndices
        if ($selectedIndices.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Seleziona almeno un'app da aggiornare.")
            return
        }
        $selectedApps = @()
        if ($showingUpgradable) {
            foreach ($i in $selectedIndices) {
                $selectedApps += $upgradableApps[$i]
            }
        } else {
            foreach ($i in $selectedIndices) {
                $selectedApps += $apps[$i]
            }
        }
        Update-SelectedApps -SelectedApps $selectedApps -LogBox $logBox
    })

    $selectAllButton.Add_Click({
        if ($loading) { return }
        for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
            $checkedListBox.SetItemChecked($i, $true)
        }
    })

    $deselectAllButton.Add_Click({
        if ($loading) { return }
        for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
            $checkedListBox.SetItemChecked($i, $false)
        }
    })

    $closeButton.Add_Click({
        $form.Close()
    })

    $showUpgradableButton.Add_Click({
        if ($loading) { return }
        $showingUpgradable = -not $showingUpgradable
        if ($showingUpgradable) {
            $showUpgradableButton.Text = "Mostra tutte le app"
        } else {
            $showUpgradableButton.Text = "Mostra solo aggiornabili"
        }
        RefreshAppList
    })

    $form.Topmost = $true
    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()
}

# Entry point
[void] (Show-UpdateGUI)
