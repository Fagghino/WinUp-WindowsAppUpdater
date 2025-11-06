# update.ps1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-InstalledApps {
    try {
        # Usa winget list senza filtro source per ottenere tutte le app con versioni
        $wingetOutput = winget list
        if (-not $wingetOutput -or $wingetOutput.Count -lt 2) { return @() }
        
        # Trova l'header e le sue posizioni delle colonne
        $header = $wingetOutput[0]
        $separatorLine = $wingetOutput[1]  # Linea con i trattini
        $data = $wingetOutput | Select-Object -Skip 2  # Salta header e separatore
        
        # Trova le posizioni delle colonne usando la linea separatore
        $nameMatch = [regex]::Match($header, '(Nome|Name)')
        $idMatch = [regex]::Match($header, '\bId\b')
        $versionMatch = [regex]::Match($header, '(Versione|Version)')
        $availableMatch = [regex]::Match($header, '(Disponibile|Available)')
        
        if (-not $nameMatch.Success -or -not $idMatch.Success -or -not $versionMatch.Success) { 
            return @() 
        }
        
        $nameIdx = $nameMatch.Index
        $idIdx = $idMatch.Index
        $versionIdx = $versionMatch.Index
        
        # Determina dove finisce la colonna Version
        $versionEndIdx = if ($availableMatch.Success) { $availableMatch.Index } else { $header.Length }
        
        $result = @()
        foreach ($line in $data) {
            if ($line.Trim() -eq "" -or $line -match '^-{5,}') { continue }
            
            try {
                $name = $line.Substring($nameIdx, $idIdx - $nameIdx).Trim()
                $id = $line.Substring($idIdx, $versionIdx - $idIdx).Trim()
                
                # Estrai versione correttamente
                $versionStr = ""
                if ($line.Length -gt $versionIdx) {
                    $remainingLength = [Math]::Min($versionEndIdx - $versionIdx, $line.Length - $versionIdx)
                    if ($remainingLength -gt 0) {
                        $versionStr = $line.Substring($versionIdx, $remainingLength).Trim()
                        # Prendi solo la prima parte (la versione) se ci sono più colonne
                        $versionStr = $versionStr.Split([char[]]@(' ', "`t"), [StringSplitOptions]::RemoveEmptyEntries)[0]
                    }
                }
                
                if ($name -and $id) {
                    $result += [PSCustomObject]@{
                        Name = $name
                        Id = $id
                        Version = if ($versionStr) { $versionStr } else { "N/A" }
                    }
                }
            } catch {
                continue
            }
        }
        return $result
    } catch {
        return @()
    }
}

# Recupera solo le app con aggiornamento disponibile
function Get-UpgradableApps {
    # Prova parsing JSON (winget >= 1.4)
    $json = $null
    try {
        $jsonRaw = winget upgrade --source winget --include-unknown --output json 2>$null
        if ($jsonRaw) {
            $json = $jsonRaw | ConvertFrom-Json
        }
    } catch {}
    $result = @()
    if ($json -and $json.Sources -and $json.Sources[0].Packages) {
        foreach ($pkg in $json.Sources[0].Packages) {
            $result += [PSCustomObject]@{
                Name      = $pkg.PackageName
                Id        = $pkg.PackageIdentifier
                Version   = $pkg.InstalledVersion
                Available = $pkg.AvailableVersion
            }
        }
        return $result
    }
    # Fallback: parsing testuale/regex
    $apps = winget upgrade --source winget --include-unknown | Select-Object -Skip 1
    foreach ($line in $apps) {
        if ($line -match '^\s*(\S.*?)\s{2,}(\S.*?)\s{2,}(\S.*?)\s+(\S.*?)\s*$') {
            $name = $matches[1]
            $id = $matches[2]
            $version = $matches[3]
            $available = $matches[4]
            if ($name -and $id -and $version -and $name -notmatch '^(Nome|Name|Id|Versione|Version|Disponibile|Per)$') {
                $result += [PSCustomObject]@{
                    Name     = $name
                    Id       = $id
                    Version  = $version
                    Available= $available
                }
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
    $form.Size = New-Object System.Drawing.Size(900, 700)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
    $form.MinimumSize = New-Object System.Drawing.Size(700, 500)
    $form.MaximizeBox = $true

    # DataGridView al posto di CheckedListBox per visualizzazione tabellare
    $dataGridView = New-Object System.Windows.Forms.DataGridView
    $dataGridView.BackColor = [System.Drawing.Color]::White
    $dataGridView.AllowUserToAddRows = $false
    $dataGridView.AllowUserToDeleteRows = $false
    $dataGridView.AllowUserToResizeRows = $false
    $dataGridView.RowHeadersVisible = $false
    $dataGridView.SelectionMode = 'FullRowSelect'
    $dataGridView.MultiSelect = $true
    $dataGridView.ReadOnly = $false
    $dataGridView.AutoSizeColumnsMode = 'None'  # Cambiato da Fill a None per gestire manualmente
    $dataGridView.Dock = 'Fill'
    
    # Creazione colonne
    $checkBoxColumn = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $checkBoxColumn.HeaderText = "Seleziona"
    $checkBoxColumn.Name = "Select"
    $checkBoxColumn.Width = 70
    $checkBoxColumn.AutoSizeMode = 'None'
    $checkBoxColumn.ReadOnly = $false
    $dataGridView.Columns.Add($checkBoxColumn) | Out-Null
    
    $nameColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $nameColumn.HeaderText = "Nome"
    $nameColumn.Name = "Name"
    $nameColumn.ReadOnly = $true
    $nameColumn.AutoSizeMode = 'AllCells'  # Adatta al contenuto
    $dataGridView.Columns.Add($nameColumn) | Out-Null
    
    $idColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $idColumn.HeaderText = "ID"
    $idColumn.Name = "ID"
    $idColumn.ReadOnly = $true
    $idColumn.AutoSizeMode = 'AllCells'  # Adatta al contenuto
    $dataGridView.Columns.Add($idColumn) | Out-Null
    
    $currentVersionColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $currentVersionColumn.HeaderText = "Versione Attuale"
    $currentVersionColumn.Name = "CurrentVersion"
    $currentVersionColumn.ReadOnly = $true
    $currentVersionColumn.AutoSizeMode = 'AllCells'  # Adatta al contenuto
    $dataGridView.Columns.Add($currentVersionColumn) | Out-Null
    
    $availableVersionColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $availableVersionColumn.HeaderText = "Versione Disponibile"
    $availableVersionColumn.Name = "AvailableVersion"
    $availableVersionColumn.ReadOnly = $true
    $availableVersionColumn.AutoSizeMode = 'AllCells'  # Adatta al contenuto
    $dataGridView.Columns.Add($availableVersionColumn) | Out-Null

    # Pannello superiore per DataGridView
    $topPanel = New-Object System.Windows.Forms.Panel
    $topPanel.Dock = 'Top'
    $topPanel.Height = 320
    $topPanel.Padding = New-Object System.Windows.Forms.Padding(10)
    $topPanel.Controls.Add($dataGridView)

    # Splitter per ridimensionamento
    $splitter = New-Object System.Windows.Forms.Splitter
    $splitter.Dock = 'Top'
    $splitter.Height = 5
    $splitter.BackColor = [System.Drawing.Color]::Gray

    # Pannello per i pulsanti
    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Dock = 'Top'
    $buttonPanel.Height = 60
    $buttonPanel.BackColor = [System.Drawing.Color]::FromArgb(230,230,230)

    $updateButton = New-Object System.Windows.Forms.Button
    $updateButton.Text = "Aggiorna"
    $updateButton.Size = New-Object System.Drawing.Size(110, 40)
    $updateButton.Location = New-Object System.Drawing.Point(10, 10)
    $updateButton.BackColor = [System.Drawing.Color]::LightGreen
    $updateButton.FlatStyle = 'Flat'
    $updateButton.Enabled = $true

    $selectAllButton = New-Object System.Windows.Forms.Button
    $selectAllButton.Text = "Seleziona tutto"
    $selectAllButton.Size = New-Object System.Drawing.Size(120, 40)
    $selectAllButton.Location = New-Object System.Drawing.Point(130, 10)
    $selectAllButton.BackColor = [System.Drawing.Color]::LightSkyBlue
    $selectAllButton.FlatStyle = 'Flat'
    $selectAllButton.Enabled = $true

    $deselectAllButton = New-Object System.Windows.Forms.Button
    $deselectAllButton.Text = "Deseleziona tutto"
    $deselectAllButton.Size = New-Object System.Drawing.Size(120, 40)
    $deselectAllButton.Location = New-Object System.Drawing.Point(260, 10)
    $deselectAllButton.BackColor = [System.Drawing.Color]::LightSkyBlue
    $deselectAllButton.FlatStyle = 'Flat'
    $deselectAllButton.Enabled = $true

    $showUpgradableButton = New-Object System.Windows.Forms.Button
    $showUpgradableButton.Text = "Mostra tutte le app"  # Modificato: ora parte mostrando le app aggiornabili
    $showUpgradableButton.Size = New-Object System.Drawing.Size(170, 40)
    $showUpgradableButton.Location = New-Object System.Drawing.Point(390, 10)
    $showUpgradableButton.BackColor = [System.Drawing.Color]::Orange
    $showUpgradableButton.FlatStyle = 'Flat'
    $showUpgradableButton.Enabled = $true

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = "Chiudi"
    $closeButton.Size = New-Object System.Drawing.Size(100, 40)
    $closeButton.Location = New-Object System.Drawing.Point(570, 10)
    $closeButton.BackColor = [System.Drawing.Color]::Salmon
    $closeButton.FlatStyle = 'Flat'
    $closeButton.Enabled = $true

    $buttonPanel.Controls.Add($updateButton)
    $buttonPanel.Controls.Add($selectAllButton)
    $buttonPanel.Controls.Add($deselectAllButton)
    $buttonPanel.Controls.Add($showUpgradableButton)
    $buttonPanel.Controls.Add($closeButton)

    # Pannello inferiore per LogBox
    $bottomPanel = New-Object System.Windows.Forms.Panel
    $bottomPanel.Dock = 'Fill'
    $bottomPanel.Padding = New-Object System.Windows.Forms.Padding(10)
    
    $logBox = New-Object System.Windows.Forms.TextBox
    $logBox.Multiline = $true
    $logBox.ScrollBars = "Vertical"
    $logBox.ReadOnly = $true
    $logBox.BackColor = [System.Drawing.Color]::WhiteSmoke
    $logBox.Dock = 'Fill'
    
    $bottomPanel.Controls.Add($logBox)

    # Aggiungi controlli al form nell'ordine corretto (dal basso verso l'alto per il Dock)
    $form.Controls.Add($bottomPanel)
    $form.Controls.Add($buttonPanel)
    $form.Controls.Add($splitter)
    $form.Controls.Add($topPanel)

    $logBox.AppendText("Caricamento in corso...`r`n")
    $script:apps = $null
    $script:upgradableApps = $null
    $script:showingUpgradable = $true  # Modificato: mostra app aggiornabili all'avvio
    $script:loading = $true

    function RefreshAppList {
        $dataGridView.Rows.Clear()
        if ($script:showingUpgradable) {
            # Mostra colonna checkbox per app aggiornabili
            $dataGridView.Columns["Select"].Visible = $true
            $updateButton.Enabled = $true
            $selectAllButton.Enabled = $true
            $deselectAllButton.Enabled = $true
            
            $logBox.AppendText("Recupero lista app aggiornabili...`r`n")
            $script:upgradableApps = Get-UpgradableApps
            if ($script:upgradableApps.Count -eq 0) {
                $logBox.AppendText("Nessuna app aggiornabile trovata!`r`n")
            }
            foreach ($app in $script:upgradableApps) {
                $row = $dataGridView.Rows.Add()
                $dataGridView.Rows[$row].Cells["Select"].Value = $false
                $dataGridView.Rows[$row].Cells["Name"].Value = $app.Name
                $dataGridView.Rows[$row].Cells["ID"].Value = $app.Id
                $dataGridView.Rows[$row].Cells["CurrentVersion"].Value = $app.Version
                $dataGridView.Rows[$row].Cells["AvailableVersion"].Value = $app.Available
            }
            $logBox.AppendText("Trovate $($script:upgradableApps.Count) app aggiornabili.`r`n")
        } else {
            # Nascondi colonna checkbox per tutte le app (solo visualizzazione)
            $dataGridView.Columns["Select"].Visible = $false
            $updateButton.Enabled = $false
            $selectAllButton.Enabled = $false
            $deselectAllButton.Enabled = $false
            
            $logBox.AppendText("Recupero lista app installate...`r`n")
            $script:apps = Get-InstalledApps
            if ($script:apps.Count -eq 0) {
                $logBox.AppendText("Nessuna app trovata! Verifica che winget sia installato e funzionante.`r`n")
            } else {
                $logBox.AppendText("Trovate $($script:apps.Count) app installate.`r`n")
            }
            foreach ($app in $script:apps) {
                $row = $dataGridView.Rows.Add()
                $dataGridView.Rows[$row].Cells["Name"].Value = if ($app.Name) { $app.Name } else { "-" }
                $dataGridView.Rows[$row].Cells["ID"].Value = if ($app.Id) { $app.Id } else { "-" }
                $dataGridView.Rows[$row].Cells["CurrentVersion"].Value = if ($app.Version) { $app.Version } else { "-" }
                $dataGridView.Rows[$row].Cells["AvailableVersion"].Value = "-"
            }
        }
        
        # Adatta automaticamente le colonne al contenuto dopo il caricamento
        foreach ($column in $dataGridView.Columns) {
            if ($column.AutoSizeMode -eq 'AllCells') {
                $column.AutoSizeMode = 'AllCells'  # Forza il ricalcolo
            }
        }
    }

    # Caricamento asincrono con BackgroundWorker
    $worker = New-Object System.ComponentModel.BackgroundWorker
    $worker.WorkerReportsProgress = $false
    $worker.add_DoWork({
        # Modificato: carica le app aggiornabili all'avvio invece di tutte le app
        $script:upgradableApps = Get-UpgradableApps
    })
    $worker.add_RunWorkerCompleted({
        $logBox.Clear()
        RefreshAppList
        $logBox.AppendText("Seleziona le app da aggiornare e premi 'Aggiorna'.`r`n")
        $script:loading = $false
        # Abilita pulsanti dopo caricamento (RefreshAppList gestisce update/select/deselect)
        $showUpgradableButton.Enabled = $true
        $closeButton.Enabled = $true
    })
    $form.Add_Shown({ $worker.RunWorkerAsync() })

    $updateButton.Add_Click({
        if ($script:loading) { return }
        $selectedApps = @()
        foreach ($row in $dataGridView.Rows) {
            if ($row.Cells["Select"].Value -eq $true) {
                if ($script:showingUpgradable) {
                    $app = $script:upgradableApps | Where-Object { $_.Id -eq $row.Cells["ID"].Value }
                    if ($app) { $selectedApps += $app }
                } else {
                    $app = $script:apps | Where-Object { $_.Id -eq $row.Cells["ID"].Value }
                    if ($app) { $selectedApps += $app }
                }
            }
        }
        if ($selectedApps.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Seleziona almeno un'app da aggiornare.")
            return
        }
        Update-SelectedApps -SelectedApps $selectedApps -LogBox $logBox
    })

    $selectAllButton.Add_Click({
        if ($script:loading) { return }
        foreach ($row in $dataGridView.Rows) {
            $row.Cells["Select"].Value = $true
        }
    })

    $deselectAllButton.Add_Click({
        if ($script:loading) { return }
        foreach ($row in $dataGridView.Rows) {
            $row.Cells["Select"].Value = $false
        }
    })

    $closeButton.Add_Click({
        $form.Close()
    })

    $showUpgradableButton.Add_Click({
        if ($script:loading) { return }
        $script:showingUpgradable = -not $script:showingUpgradable
        if ($script:showingUpgradable) {
            $showUpgradableButton.Text = "Mostra tutte le app"
        } else {
            $showUpgradableButton.Text = "Mostra solo aggiornabili"
        }
        RefreshAppList
    })

    # FIXATO: Rimosso $form.Topmost = $true che causava il form sempre in primo piano
    # e impediva di ridurlo ad icona o spostarlo correttamente
    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()
}

# Entry point
[void] (Show-UpdateGUI)
