# update.ps1 -- WinUp v2.1.0
# GUI-based Windows application updater using winget
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# =============================================================================
# CONFIGURATION
# =============================================================================

function Get-Config {
    $defaults = @{ wingetSource = "winget"; logLevel = "info"; theme = "dark" }
    $configPath = Join-Path $PSScriptRoot "config.json"
    if (Test-Path $configPath) {
        try {
            $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
            if ($cfg.wingetSource) { $defaults.wingetSource = $cfg.wingetSource }
            if ($cfg.logLevel)     { $defaults.logLevel     = $cfg.logLevel }
            if ($cfg.theme)        { $defaults.theme        = $cfg.theme }
        } catch {}
    }
    return $defaults
}

$script:Config = Get-Config

# =============================================================================
# THEME -- Dark modern palette
# =============================================================================

$script:Theme = @{
    BgForm        = [System.Drawing.Color]::FromArgb(30,  30,  46)
    BgPanel       = [System.Drawing.Color]::FromArgb(36,  36,  54)
    BgButtonPanel = [System.Drawing.Color]::FromArgb(24,  24,  38)
    BgGrid        = [System.Drawing.Color]::FromArgb(30,  30,  46)
    BgGridAlt     = [System.Drawing.Color]::FromArgb(38,  38,  58)
    BgGridHeader  = [System.Drawing.Color]::FromArgb(20,  20,  34)
    BgLog         = [System.Drawing.Color]::FromArgb(18,  18,  30)
    BgSplitter    = [System.Drawing.Color]::FromArgb(78, 204, 163)
    TextPrimary   = [System.Drawing.Color]::FromArgb(224, 224, 240)
    TextMuted     = [System.Drawing.Color]::FromArgb(140, 140, 180)
    TextHeader    = [System.Drawing.Color]::FromArgb(255, 255, 255)
    AccentTeal    = [System.Drawing.Color]::FromArgb(78,  204, 163)
    AccentBlue    = [System.Drawing.Color]::FromArgb(91,  141, 239)
    AccentAmber   = [System.Drawing.Color]::FromArgb(247, 183,  49)
    AccentRed     = [System.Drawing.Color]::FromArgb(224,  92,  92)
    BorderColor   = [System.Drawing.Color]::FromArgb(60,  60,  90)
}

$script:Font      = New-Object System.Drawing.Font("Segoe UI", 9,  [System.Drawing.FontStyle]::Regular)
$script:FontBold  = New-Object System.Drawing.Font("Segoe UI", 9,  [System.Drawing.FontStyle]::Bold)
$script:FontSmall = New-Object System.Drawing.Font("Segoe UI", 8,  [System.Drawing.FontStyle]::Regular)

# =============================================================================
# HELPERS
# =============================================================================

function Test-WingetAvailable {
    try { $null = winget --version 2>$null; return $true } catch { return $false }
}

function New-StyledButton {
    param(
        [string]$Text,
        [System.Drawing.Color]$AccentColor,
        [int]$Width  = 120,
        [int]$Height = 38
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text      = $Text
    $btn.Size      = New-Object System.Drawing.Size($Width, $Height)
    $btn.Font      = $script:FontBold
    $btn.ForeColor = $AccentColor
    $btn.BackColor = $script:Theme.BgButtonPanel
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderColor = $AccentColor
    $btn.FlatAppearance.BorderSize  = 1
    $btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(
        [Math]::Min($AccentColor.R + 30, 255),
        [Math]::Min($AccentColor.G + 30, 255),
        [Math]::Min($AccentColor.B + 30, 255)
    )
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $btn
}

# =============================================================================
# DATA FUNCTIONS
# =============================================================================

function Get-InstalledApps {
    try {
        $source        = $script:Config.wingetSource
        $wingetOutput  = winget list --source $source
        if (-not $wingetOutput -or $wingetOutput.Count -lt 2) {
            return [System.Collections.Generic.List[PSCustomObject]]::new()
        }

        $header         = $wingetOutput[0]
        $data           = $wingetOutput | Select-Object -Skip 2
        $nameMatch      = [regex]::Match($header, '(Nome|Name)')
        $idMatch        = [regex]::Match($header, '\bId\b')
        $versionMatch   = [regex]::Match($header, '(Versione|Version)')
        $availableMatch = [regex]::Match($header, '(Disponibile|Available)')

        if (-not $nameMatch.Success -or -not $idMatch.Success -or -not $versionMatch.Success) {
            return [System.Collections.Generic.List[PSCustomObject]]::new()
        }

        $nameIdx       = $nameMatch.Index
        $idIdx         = $idMatch.Index
        $versionIdx    = $versionMatch.Index
        $versionEndIdx = if ($availableMatch.Success) { $availableMatch.Index } else { $header.Length }

        $result = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($line in $data) {
            if ($line.Trim() -eq "" -or $line -match '^-{5,}') { continue }
            try {
                $name = $line.Substring($nameIdx, $idIdx - $nameIdx).Trim()
                $id   = $line.Substring($idIdx,   $versionIdx - $idIdx).Trim()
                $versionStr = ""
                if ($line.Length -gt $versionIdx) {
                    $rem = [Math]::Min($versionEndIdx - $versionIdx, $line.Length - $versionIdx)
                    if ($rem -gt 0) {
                        $versionStr = $line.Substring($versionIdx, $rem).Trim()
                        $versionStr = $versionStr.Split([char[]]@(' ', "`t"),
                            [StringSplitOptions]::RemoveEmptyEntries)[0]
                    }
                }
                if ($name -and $id) {
                    $result.Add([PSCustomObject]@{
                        Name    = $name
                        Id      = $id
                        Version = if ($versionStr) { $versionStr } else { "N/A" }
                    })
                }
            } catch { continue }
        }
        return $result
    } catch {
        return [System.Collections.Generic.List[PSCustomObject]]::new()
    }
}

function Get-UpgradableApps {
    $source = $script:Config.wingetSource
    $json   = $null
    try {
        $jsonRaw = winget upgrade --source $source --include-unknown --output json 2>$null
        if ($jsonRaw) { $json = $jsonRaw | ConvertFrom-Json }
    } catch {}

    $result = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ($json -and $json.Sources -and $json.Sources[0].Packages) {
        foreach ($pkg in $json.Sources[0].Packages) {
            $result.Add([PSCustomObject]@{
                Name      = $pkg.PackageName
                Id        = $pkg.PackageIdentifier
                Version   = $pkg.InstalledVersion
                Available = $pkg.AvailableVersion
            })
        }
        return $result
    }

    # Fallback: text parsing
    $apps = winget upgrade --source $source --include-unknown | Select-Object -Skip 1
    foreach ($line in $apps) {
        if ($line -match '^-{5,}') { continue }
        if ($line -match '^\s*(Nome|Name|Id|Versione|Version|Disponibile|Available|Per|Source)\s') { continue }
        if ($line -match '^\s*(\S.*?)\s{2,}(\S.*?)\s{2,}(\S.*?)\s+(\S.*?)\s*$') {
            $n = $matches[1]; $i = $matches[2]; $v = $matches[3]; $a = $matches[4]
            if ($n -and $i -and $v) {
                $result.Add([PSCustomObject]@{ Name = $n; Id = $i; Version = $v; Available = $a })
            }
        }
    }
    return $result
}

# =============================================================================
# GUI
# =============================================================================

function Show-UpdateGUI {

    # ---- WINGET CHECK -------------------------------------------------------
    if (-not (Test-WingetAvailable)) {
        [System.Windows.Forms.MessageBox]::Show(
            "winget non trovato.`n`nInstalla 'App Installer' dal Microsoft Store oppure scaricalo da:`nhttps://github.com/microsoft/winget-cli/releases",
            "winget non trovato",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }

    # ---- FORM ---------------------------------------------------------------
    $form = New-Object System.Windows.Forms.Form
    $form.Text          = "WinUp — Windows App Updater  v2.1.0"
    $form.Size          = New-Object System.Drawing.Size(960, 720)
    $form.MinimumSize   = New-Object System.Drawing.Size(720, 520)
    $form.StartPosition = "CenterScreen"
    $form.BackColor     = $script:Theme.BgForm
    $form.ForeColor     = $script:Theme.TextPrimary
    $form.Font          = $script:Font
    $form.MaximizeBox   = $true

    # ---- STATUS BAR ---------------------------------------------------------
    $statusBar = New-Object System.Windows.Forms.Panel
    $statusBar.Dock      = 'Bottom'
    $statusBar.Height    = 28
    $statusBar.BackColor = $script:Theme.BgButtonPanel
    $statusBar.Padding   = New-Object System.Windows.Forms.Padding(10, 0, 10, 0)

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Dock      = 'Fill'
    $statusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $statusLabel.Font      = $script:FontSmall
    $statusLabel.ForeColor = $script:Theme.TextMuted
    $statusLabel.Text      = "Pronto."
    $statusBar.Controls.Add($statusLabel)

    # ---- LOG PANEL ----------------------------------------------------------
    $bottomPanel = New-Object System.Windows.Forms.Panel
    $bottomPanel.Dock      = 'Fill'
    $bottomPanel.Padding   = New-Object System.Windows.Forms.Padding(10, 6, 10, 6)
    $bottomPanel.BackColor = $script:Theme.BgPanel

    $logBox = New-Object System.Windows.Forms.RichTextBox
    $logBox.Multiline   = $true
    $logBox.ScrollBars  = "Vertical"
    $logBox.ReadOnly    = $true
    $logBox.BackColor   = $script:Theme.BgLog
    $logBox.ForeColor   = $script:Theme.TextPrimary
    $logBox.Font        = New-Object System.Drawing.Font("Consolas", 9)
    $logBox.Dock        = 'Fill'
    $logBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $bottomPanel.Controls.Add($logBox)

    # ---- SPLITTER -----------------------------------------------------------
    $splitter = New-Object System.Windows.Forms.Splitter
    $splitter.Dock      = 'Top'
    $splitter.Height    = 4
    $splitter.BackColor = $script:Theme.BgSplitter

    # ---- BUTTON PANEL -------------------------------------------------------
    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Dock      = 'Top'
    $buttonPanel.Height    = 62
    $buttonPanel.BackColor = $script:Theme.BgButtonPanel
    $buttonPanel.Padding   = New-Object System.Windows.Forms.Padding(10, 11, 10, 11)

    $updateButton         = New-StyledButton -Text "Aggiorna"          -AccentColor $script:Theme.AccentTeal  -Width 110 -Height 38
    $selectAllButton      = New-StyledButton -Text "Seleziona tutto"   -AccentColor $script:Theme.AccentBlue  -Width 130 -Height 38
    $deselectAllButton    = New-StyledButton -Text "Deseleziona"       -AccentColor $script:Theme.AccentBlue  -Width 110 -Height 38
    $showUpgradableButton = New-StyledButton -Text "Mostra tutte"      -AccentColor $script:Theme.AccentAmber -Width 130 -Height 38
    $closeButton          = New-StyledButton -Text "Chiudi"            -AccentColor $script:Theme.AccentRed   -Width  90 -Height 38

    $updateButton.Location         = New-Object System.Drawing.Point(0,   0)
    $selectAllButton.Location      = New-Object System.Drawing.Point(118, 0)
    $deselectAllButton.Location    = New-Object System.Drawing.Point(256, 0)
    $showUpgradableButton.Location = New-Object System.Drawing.Point(374, 0)
    $closeButton.Location          = New-Object System.Drawing.Point(512, 0)

    $buttonPanel.Controls.AddRange(@(
        $updateButton, $selectAllButton, $deselectAllButton,
        $showUpgradableButton, $closeButton
    ))

    # ---- DATA GRID ----------------------------------------------------------
    $dataGridView = New-Object System.Windows.Forms.DataGridView
    $dataGridView.BackgroundColor = $script:Theme.BgGrid
    $dataGridView.GridColor       = $script:Theme.BorderColor

    $cellStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
    $cellStyle.BackColor          = $script:Theme.BgGrid
    $cellStyle.ForeColor          = $script:Theme.TextPrimary
    $cellStyle.SelectionBackColor = $script:Theme.AccentTeal
    $cellStyle.SelectionForeColor = [System.Drawing.Color]::FromArgb(20, 20, 34)
    $cellStyle.Font               = $script:Font
    $dataGridView.DefaultCellStyle = $cellStyle

    $altStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
    $altStyle.BackColor  = $script:Theme.BgGridAlt
    $altStyle.ForeColor  = $script:Theme.TextPrimary
    $dataGridView.AlternatingRowsDefaultCellStyle = $altStyle

    $headerStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
    $headerStyle.BackColor = $script:Theme.BgGridHeader
    $headerStyle.ForeColor = $script:Theme.TextHeader
    $headerStyle.Font      = $script:FontBold
    $headerStyle.Padding   = New-Object System.Windows.Forms.Padding(4)
    $dataGridView.ColumnHeadersDefaultCellStyle     = $headerStyle
    $dataGridView.ColumnHeadersHeight               = 32
    $dataGridView.ColumnHeadersHeightSizeMode       = 'DisableResizing'
    $dataGridView.EnableHeadersVisualStyles         = $false
    $dataGridView.BorderStyle                       = [System.Windows.Forms.BorderStyle]::None
    $dataGridView.AllowUserToAddRows                = $false
    $dataGridView.AllowUserToDeleteRows             = $false
    $dataGridView.AllowUserToResizeRows             = $false
    $dataGridView.RowHeadersVisible                 = $false
    $dataGridView.SelectionMode                     = 'FullRowSelect'
    $dataGridView.MultiSelect                       = $true
    $dataGridView.ReadOnly                          = $false
    $dataGridView.AutoSizeColumnsMode               = 'None'
    $dataGridView.Dock                              = 'Fill'
    $dataGridView.RowTemplate.Height                = 26

    # Columns
    $chkCol = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $chkCol.HeaderText  = ""
    $chkCol.Name        = "Select"
    $chkCol.Width       = 36
    $chkCol.AutoSizeMode= 'None'
    $chkCol.ReadOnly    = $false
    $dataGridView.Columns.Add($chkCol) | Out-Null

    $nameCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $nameCol.HeaderText   = "Nome Applicazione"
    $nameCol.Name         = "Name"
    $nameCol.ReadOnly     = $true
    $nameCol.AutoSizeMode = 'Fill'
    $nameCol.FillWeight   = 40
    $dataGridView.Columns.Add($nameCol) | Out-Null

    $idCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $idCol.HeaderText   = "Package ID"
    $idCol.Name         = "ID"
    $idCol.ReadOnly     = $true
    $idCol.AutoSizeMode = 'Fill'
    $idCol.FillWeight   = 30
    $dataGridView.Columns.Add($idCol) | Out-Null

    $curVerCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $curVerCol.HeaderText   = "Installata"
    $curVerCol.Name         = "CurrentVersion"
    $curVerCol.ReadOnly     = $true
    $curVerCol.AutoSizeMode = 'AllCells'
    $dataGridView.Columns.Add($curVerCol) | Out-Null

    $avaVerCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $avaVerCol.HeaderText   = "Disponibile"
    $avaVerCol.Name         = "AvailableVersion"
    $avaVerCol.ReadOnly     = $true
    $avaVerCol.AutoSizeMode = 'AllCells'
    $dataGridView.Columns.Add($avaVerCol) | Out-Null

    # ---- TOP PANEL ----------------------------------------------------------
    $topPanel = New-Object System.Windows.Forms.Panel
    $topPanel.Dock      = 'Top'
    $topPanel.Height    = 320
    $topPanel.Padding   = New-Object System.Windows.Forms.Padding(10, 8, 10, 0)
    $topPanel.BackColor = $script:Theme.BgPanel
    $topPanel.Controls.Add($dataGridView)

    # ---- ADD TO FORM (bottom-up for Dock) -----------------------------------
    $form.Controls.Add($bottomPanel)
    $form.Controls.Add($statusBar)
    $form.Controls.Add($buttonPanel)
    $form.Controls.Add($splitter)
    $form.Controls.Add($topPanel)

    # ---- STATE --------------------------------------------------------------
    $script:apps              = $null
    $script:upgradableApps    = $null
    $script:showingUpgradable = $true
    $script:loading           = $true
    $script:updating          = $false

    # ---- REFRESH GRID -------------------------------------------------------
    function RefreshAppList {
        $dataGridView.Rows.Clear()

        if ($script:showingUpgradable) {
            $dataGridView.Columns["Select"].Visible = $true
            $updateButton.Enabled       = $true
            $selectAllButton.Enabled    = $true
            $deselectAllButton.Enabled  = $true
            $showUpgradableButton.Text  = "Mostra tutte"
            $showUpgradableButton.ForeColor = $script:Theme.AccentAmber
            $showUpgradableButton.FlatAppearance.BorderColor = $script:Theme.AccentAmber

            $appList = $script:upgradableApps
            foreach ($app in $appList) {
                $row = $dataGridView.Rows.Add()
                $dataGridView.Rows[$row].Cells["Select"].Value          = $false
                $dataGridView.Rows[$row].Cells["Name"].Value            = $app.Name
                $dataGridView.Rows[$row].Cells["ID"].Value              = $app.Id
                $dataGridView.Rows[$row].Cells["CurrentVersion"].Value  = $app.Version
                $dataGridView.Rows[$row].Cells["AvailableVersion"].Value= $app.Available
            }
            $count = if ($appList) { $appList.Count } else { 0 }
            if ($count -eq 0) {
                $statusLabel.Text = "Sistema aggiornato - nessuna app da aggiornare."
            } else {
                $statusLabel.Text = "$count app aggiornabili trovate."
            }
        } else {
            $dataGridView.Columns["Select"].Visible = $false
            $updateButton.Enabled       = $false
            $selectAllButton.Enabled    = $false
            $deselectAllButton.Enabled  = $false
            $showUpgradableButton.Text  = "Solo aggiornabili"
            $showUpgradableButton.ForeColor = $script:Theme.AccentTeal
            $showUpgradableButton.FlatAppearance.BorderColor = $script:Theme.AccentTeal

            $appList = $script:apps
            foreach ($app in $appList) {
                $row = $dataGridView.Rows.Add()
                $dataGridView.Rows[$row].Cells["Name"].Value            = if ($app.Name)    { $app.Name }    else { "-" }
                $dataGridView.Rows[$row].Cells["ID"].Value              = if ($app.Id)      { $app.Id }      else { "-" }
                $dataGridView.Rows[$row].Cells["CurrentVersion"].Value  = if ($app.Version) { $app.Version } else { "-" }
                $dataGridView.Rows[$row].Cells["AvailableVersion"].Value= "-"
            }
            $count = if ($appList) { $appList.Count } else { 0 }
            $statusLabel.Text = "$count app installate trovate (sola lettura)."
        }
    }

    # ---- LOAD TIMER (one-shot) ----------------------------------------------
    # BackgroundWorker non funziona in PS perche il DoWork gira in un runspace
    # separato dove le funzioni del main script non esistono.
    # Soluzione: Timer one-shot che fa caricare nel thread UI dopo il render.
    $loadTimer = New-Object System.Windows.Forms.Timer
    $loadTimer.Interval = 150   # ms -- abbastanza per far renderizzare il form

    $loadTimer.add_Tick({
        $loadTimer.Stop()
        $loadTimer.Dispose()
        try {
            $script:upgradableApps = Get-UpgradableApps
        } catch {
            $script:upgradableApps = [System.Collections.Generic.List[PSCustomObject]]::new()
            $logBox.AppendText("Errore durante il recupero: $_`n")
        }
        $logBox.AppendText("Caricamento completato.`n")
        $logBox.AppendText("Seleziona le app da aggiornare e premi 'Aggiorna'.`n")
        RefreshAppList
        $script:loading               = $false
        $showUpgradableButton.Enabled = $true
        $closeButton.Enabled          = $true
    })

    $form.Add_Shown({
        $statusLabel.Text = "Recupero app aggiornabili..."
        $logBox.AppendText("Recupero lista app aggiornabili...`n")
        $showUpgradableButton.Enabled = $false
        $closeButton.Enabled          = $false
        $loadTimer.Start()
    })


    # ---- UPDATE VIA PROCESS -------------------------------------------------
    # BackgroundWorker ha lo stesso problema di runspace anche qui.
    # Soluzione: winget come processo esterno con OutputDataReceived sul thread UI.
    function Start-AppUpdate {
        param([System.Collections.Generic.List[PSCustomObject]]$AppsToUpdate)

        if ($AppsToUpdate.Count -eq 0) {
            $script:updating              = $false
            $statusLabel.Text             = "Aggiornamento completato."
            $logBox.SelectionColor        = $script:Theme.AccentTeal
            $logBox.AppendText("`nAggiornamento completato.`n")
            $logBox.SelectionColor        = $script:Theme.TextPrimary
            $updateButton.Enabled         = $true
            $selectAllButton.Enabled      = $true
            $deselectAllButton.Enabled    = $true
            $showUpgradableButton.Enabled = $true
            $closeButton.Enabled          = $true
            return
        }

        $app     = $AppsToUpdate[0]
        $remaining = [System.Collections.Generic.List[PSCustomObject]]::new()
        for ($i = 1; $i -lt $AppsToUpdate.Count; $i++) { $remaining.Add($AppsToUpdate[$i]) }

        $logBox.SelectionColor = $script:Theme.AccentTeal
        $logBox.AppendText("Aggiornamento: $($app.Name)...`n")
        $logBox.SelectionColor = $script:Theme.TextPrimary
        $statusLabel.Text = "Aggiornamento: $($app.Name)..."

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = "winget"
        $psi.Arguments              = "upgrade --id `"$($app.Id)`" --source $($script:Config.wingetSource) --accept-source-agreements --accept-package-agreements"
        $psi.UseShellExecute        = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.CreateNoWindow         = $true

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $proc.EnableRaisingEvents = $true

        # Capture form reference for Invoke
        $formRef = $form

        $proc.add_OutputDataReceived({
            param($s, $ev)
            if ($null -ne $ev.Data) {
                $line = $ev.Data
                $formRef.Invoke([Action]{
                    $logBox.AppendText($line + "`n")
                    $logBox.ScrollToCaret()
                }) | Out-Null
            }
        })
        $proc.add_ErrorDataReceived({
            param($s, $ev)
            if ($null -ne $ev.Data) {
                $line = $ev.Data
                $formRef.Invoke([Action]{
                    $logBox.SelectionColor = $script:Theme.AccentRed
                    $logBox.AppendText($line + "`n")
                    $logBox.SelectionColor = $script:Theme.TextPrimary
                }) | Out-Null
            }
        })
        $proc.add_Exited({
            $formRef.Invoke([Action]{
                Start-AppUpdate -AppsToUpdate $remaining
            }) | Out-Null
        })

        try {
            $proc.Start()        | Out-Null
            $proc.BeginOutputReadLine()
            $proc.BeginErrorReadLine()
        } catch {
            $logBox.SelectionColor = $script:Theme.AccentRed
            $logBox.AppendText("Errore avvio processo: $_`n")
            $logBox.SelectionColor = $script:Theme.TextPrimary
            Start-AppUpdate -AppsToUpdate $remaining
        }
    }


    # ---- BUTTON EVENTS ------------------------------------------------------

    $updateButton.Add_Click({
        if ($script:loading -or $script:updating) { return }

        $selectedApps = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($row in $dataGridView.Rows) {
            if ($row.Cells["Select"].Value -eq $true) {
                $cellId = $row.Cells["ID"].Value
                if ($script:showingUpgradable) {
                    $app = $script:upgradableApps | Where-Object { $_.Id -eq $cellId } | Select-Object -First 1
                } else {
                    $app = $script:apps | Where-Object { $_.Id -eq $cellId } | Select-Object -First 1
                }
                if ($app) { $selectedApps.Add($app) }
            }
        }

        if ($selectedApps.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "Seleziona almeno un'app da aggiornare.",
                "Nessuna selezione",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
            return
        }

        $script:updating = $true
        $cnt = $selectedApps.Count
        $statusLabel.Text = "Aggiornamento di $cnt app in corso..."
        $logBox.AppendText("`n--- Avvio aggiornamento di $cnt app ---`n")

        $updateButton.Enabled         = $false
        $selectAllButton.Enabled      = $false
        $deselectAllButton.Enabled    = $false
        $showUpgradableButton.Enabled = $false
        $closeButton.Enabled          = $false

        Start-AppUpdate -AppsToUpdate $selectedApps
    })

    $selectAllButton.Add_Click({
        if ($script:loading -or $script:updating) { return }
        foreach ($row in $dataGridView.Rows) { $row.Cells["Select"].Value = $true }
    })

    $deselectAllButton.Add_Click({
        if ($script:loading -or $script:updating) { return }
        foreach ($row in $dataGridView.Rows) { $row.Cells["Select"].Value = $false }
    })

    $showUpgradableButton.Add_Click({
        if ($script:loading -or $script:updating) { return }
        $script:showingUpgradable = -not $script:showingUpgradable

        if (-not $script:showingUpgradable -and -not $script:apps) {
            $statusLabel.Text = "Recupero app installate..."
            $logBox.AppendText("Recupero lista app installate...`n")
            $script:apps = Get-InstalledApps
            $logBox.AppendText("Trovate $($script:apps.Count) app installate.`n")
        }
        RefreshAppList
    })

    $closeButton.Add_Click({ $form.Close() })

    # ---- SHOW ---------------------------------------------------------------
    [void]$form.ShowDialog()

    $script:Font.Dispose()
    $script:FontBold.Dispose()
    $script:FontSmall.Dispose()
}

# =============================================================================
# ENTRY POINT
# =============================================================================
[void](Show-UpdateGUI)
