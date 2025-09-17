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
    $form.Size = New-Object System.Drawing.Size(600, 600)
    $form.StartPosition = "CenterScreen"

    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Size = New-Object System.Drawing.Size(550, 300)
    $checkedListBox.Location = New-Object System.Drawing.Point(10, 10)
    $checkedListBox.CheckOnClick = $true

    $logBox = New-Object System.Windows.Forms.TextBox
    $logBox.Multiline = $true
    $logBox.ScrollBars = "Vertical"
    $logBox.Size = New-Object System.Drawing.Size(550, 180)
    $logBox.Location = New-Object System.Drawing.Point(10, 320)
    $logBox.ReadOnly = $true

    $updateButton = New-Object System.Windows.Forms.Button
    $updateButton.Text = "Aggiorna"
    $updateButton.Size = New-Object System.Drawing.Size(100, 30)
    $updateButton.Location = New-Object System.Drawing.Point(10, 510)

    $form.Controls.Add($checkedListBox)
    $form.Controls.Add($logBox)
    $form.Controls.Add($updateButton)

    $logBox.AppendText("Recupero lista app installate...`r`n")
    $apps = Get-InstalledApps
    foreach ($app in $apps) {
        $checkedListBox.Items.Add("$($app.Name) [$($app.Id)]", $false)
    }
    $logBox.AppendText("Seleziona le app da aggiornare e premi 'Aggiorna'.`r`n")

    $updateButton.Add_Click({
        $selectedIndices = $checkedListBox.CheckedIndices
        if ($selectedIndices.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Seleziona almeno un'app da aggiornare.")
            return
        }
        $selectedApps = @()
        foreach ($i in $selectedIndices) {
            $selectedApps += $apps[$i]
        }
        Update-SelectedApps -SelectedApps $selectedApps -LogBox $logBox
    })

    $form.Topmost = $true
    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()
}

# Entry point
Show-UpdateGUI
