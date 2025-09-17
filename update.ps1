# update.ps1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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
    $form.Size = New-Object System.Drawing.Size(650, 650)
    $form.StartPosition = "CenterScreen"

    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Size = New-Object System.Drawing.Size(600, 300)
    $checkedListBox.Location = New-Object System.Drawing.Point(10, 10)
    $checkedListBox.CheckOnClick = $true

    $logBox = New-Object System.Windows.Forms.TextBox
    $logBox.Multiline = $true
    $logBox.ScrollBars = "Vertical"
    $logBox.Size = New-Object System.Drawing.Size(600, 180)
    $logBox.Location = New-Object System.Drawing.Point(10, 320)
    $logBox.ReadOnly = $true

    $updateButton = New-Object System.Windows.Forms.Button
    $updateButton.Text = "Aggiorna"
    $updateButton.Size = New-Object System.Drawing.Size(100, 30)
    $updateButton.Location = New-Object System.Drawing.Point(10, 510)

    $selectAllButton = New-Object System.Windows.Forms.Button
    $selectAllButton.Text = "Seleziona tutto"
    $selectAllButton.Size = New-Object System.Drawing.Size(120, 30)
    $selectAllButton.Location = New-Object System.Drawing.Point(120, 510)

    $deselectAllButton = New-Object System.Windows.Forms.Button
    $deselectAllButton.Text = "Deseleziona tutto"
    $deselectAllButton.Size = New-Object System.Drawing.Size(120, 30)
    $deselectAllButton.Location = New-Object System.Drawing.Point(250, 510)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = "Chiudi"
    $closeButton.Size = New-Object System.Drawing.Size(100, 30)
    $closeButton.Location = New-Object System.Drawing.Point(380, 510)

    $showUpgradableButton = New-Object System.Windows.Forms.Button
    $showUpgradableButton.Text = "Mostra solo aggiornabili"
    $showUpgradableButton.Size = New-Object System.Drawing.Size(200, 30)
    $showUpgradableButton.Location = New-Object System.Drawing.Point(490, 510)

    $form.Controls.Add($checkedListBox)
    $form.Controls.Add($logBox)
    $form.Controls.Add($updateButton)
    $form.Controls.Add($selectAllButton)
    $form.Controls.Add($deselectAllButton)
    $form.Controls.Add($closeButton)
    $form.Controls.Add($showUpgradableButton)

    $logBox.AppendText("Recupero lista app installate...`r`n")
    $apps = Get-InstalledApps
    $upgradableApps = $null
    $showingUpgradable = $false

    function RefreshAppList {
        $checkedListBox.Items.Clear()
        if ($showingUpgradable) {
            if (-not $upgradableApps) {
                $logBox.AppendText("Recupero lista app aggiornabili...`r`n")
                $upgradableApps = Get-UpgradableApps
            }
            foreach ($app in $upgradableApps) {
                $checkedListBox.Items.Add("$($app.Name) [$($app.Id)]", $false)
            }
        } else {
            foreach ($app in $apps) {
                $checkedListBox.Items.Add("$($app.Name) [$($app.Id)]", $false)
            }
        }
    }

    RefreshAppList
    $logBox.AppendText("Seleziona le app da aggiornare e premi 'Aggiorna'.`r`n")

    $updateButton.Add_Click({
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
        for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
            $checkedListBox.SetItemChecked($i, $true)
        }
    })

    $deselectAllButton.Add_Click({
        for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
            $checkedListBox.SetItemChecked($i, $false)
        }
    })

    $closeButton.Add_Click({
        $form.Close()
    })

    $showUpgradableButton.Add_Click({
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
Show-UpdateGUI
