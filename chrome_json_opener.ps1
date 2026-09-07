param(
    [Parameter(Position = 0)]
    [string]$JsonFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Find-Chrome {
    $candidates = @()
    $command = Get-Command "chrome.exe" -ErrorAction SilentlyContinue
    if ($command) { $candidates += $command.Source }

    $candidates += @(
        (Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe"),
        (Join-Path $env:ProgramFiles "Google\Chrome\Application\chrome.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Google\Chrome\Application\chrome.exe")
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }
    return $null
}

function Get-UrlList {
    param([string]$JsonText)

    try {
        $data = $JsonText | ConvertFrom-Json
    }
    catch {
        throw "Invalid JSON: $($_.Exception.Message)"
    }

    if ($null -ne $data -and $data.PSObject.Properties.Name -contains "urls") {
        $data = $data.urls
    }
    elseif ($null -ne $data -and $data.PSObject.Properties.Name -contains "links") {
        $data = $data.links
    }
    elseif ($null -ne $data -and $data.PSObject.Properties.Name -contains "url") {
        $data = @($data)
    }

    $items = @($data)
    if ($items.Count -eq 0) { throw "No URLs were found." }

    $urls = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $items.Count; $i++) {
        $item = $items[$i]
        if ($item -is [string]) {
            $url = $item.Trim()
        }
        elseif ($null -ne $item -and $item.PSObject.Properties.Name -contains "url") {
            $url = [string]$item.url
            $url = $url.Trim()
        }
        else {
            throw "Item $($i + 1) does not contain a URL string."
        }

        $uri = $null
        if (-not [Uri]::TryCreate($url, [UriKind]::Absolute, [ref]$uri) -or
            $uri.Scheme -notin @("http", "https") -or
            [string]::IsNullOrWhiteSpace($uri.Host)) {
            throw "Invalid URL at item $($i + 1): $url"
        }
        $urls.Add($url)
    }
    return $urls.ToArray()
}

function Open-UrlsInChrome {
    param([string[]]$Urls)

    $chrome = Find-Chrome
    if (-not $chrome) {
        throw "Google Chrome was not found. Install Chrome or add chrome.exe to PATH."
    }

    # Opening in chunks avoids an unnecessarily large command line for big JSON files.
    $chunkSize = 40
    for ($start = 0; $start -lt $Urls.Count; $start += $chunkSize) {
        $end = [Math]::Min($start + $chunkSize - 1, $Urls.Count - 1)
        $chunk = @($Urls[$start..$end])
        Start-Process -FilePath $chrome -ArgumentList (@("--new-tab") + $chunk) | Out-Null
    }
}

function Start-Cli {
    param([string]$Path)
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $urls = @(Get-UrlList $text)
    Open-UrlsInChrome $urls
    Write-Output "Opened $($urls.Count) URL(s) in Chrome."
}

if ($JsonFile) {
    try {
        Start-Cli $JsonFile
    }
    catch {
        Write-Error $_.Exception.Message
        exit 1
    }
    exit 0
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = "Chrome JSON URL Opener"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(820, 640)
$form.MinimumSize = New-Object System.Drawing.Size(650, 500)

$title = New-Object System.Windows.Forms.Label
$title.Text = "Chrome JSON URL Opener"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(16, 14)
$title.AutoSize = $true
$form.Controls.Add($title)

$hint = New-Object System.Windows.Forms.Label
$hint.Text = 'Format: {"urls": ["https://example.com", "https://..."]}  or  ["https://..."]'
$hint.Location = New-Object System.Drawing.Point(18, 48)
$hint.AutoSize = $true
$form.Controls.Add($hint)

$fileLabel = New-Object System.Windows.Forms.Label
$fileLabel.Text = "JSON file:"
$fileLabel.Location = New-Object System.Drawing.Point(18, 82)
$fileLabel.AutoSize = $true
$form.Controls.Add($fileLabel)

$fileBox = New-Object System.Windows.Forms.TextBox
$fileBox.Location = New-Object System.Drawing.Point(84, 79)
$fileBox.Size = New-Object System.Drawing.Size(535, 25)
$form.Controls.Add($fileBox)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = "Browse..."
$browseButton.Location = New-Object System.Drawing.Point(628, 77)
$browseButton.Size = New-Object System.Drawing.Size(82, 28)
$form.Controls.Add($browseButton)

$loadButton = New-Object System.Windows.Forms.Button
$loadButton.Text = "Load"
$loadButton.Location = New-Object System.Drawing.Point(716, 77)
$loadButton.Size = New-Object System.Drawing.Size(70, 28)
$form.Controls.Add($loadButton)

$pasteLabel = New-Object System.Windows.Forms.Label
$pasteLabel.Text = "Paste JSON:"
$pasteLabel.Location = New-Object System.Drawing.Point(18, 116)
$pasteLabel.AutoSize = $true
$form.Controls.Add($pasteLabel)

$jsonBox = New-Object System.Windows.Forms.TextBox
$jsonBox.Multiline = $true
$jsonBox.ScrollBars = "Both"
$jsonBox.WordWrap = $false
$jsonBox.AcceptsTab = $true
$jsonBox.Font = New-Object System.Drawing.Font("Consolas", 10)
$jsonBox.Location = New-Object System.Drawing.Point(18, 140)
$jsonBox.Size = New-Object System.Drawing.Size(768, 390)
$jsonBox.Anchor = "Top,Bottom,Left,Right"
$jsonBox.Text = @'
{
  "urls": [
    "https://example.com",
    "https://www.python.org/"
  ]
}
'@
$form.Controls.Add($jsonBox)

$status = New-Object System.Windows.Forms.Label
$status.Text = "Paste JSON or choose a JSON file."
$status.AutoSize = $true
$status.Location = New-Object System.Drawing.Point(18, 570)
$status.Anchor = "Bottom,Left"
$form.Controls.Add($status)

$validateButton = New-Object System.Windows.Forms.Button
$validateButton.Text = "Validate"
$validateButton.Location = New-Object System.Drawing.Point(598, 558)
$validateButton.Size = New-Object System.Drawing.Size(90, 32)
$validateButton.Anchor = "Bottom,Right"
$form.Controls.Add($validateButton)

$openButton = New-Object System.Windows.Forms.Button
$openButton.Text = "Open in Chrome"
$openButton.Location = New-Object System.Drawing.Point(694, 558)
$openButton.Size = New-Object System.Drawing.Size(92, 32)
$openButton.Anchor = "Bottom,Right"
$form.Controls.Add($openButton)

$readUrls = {
    try {
        $urls = @(Get-UrlList $jsonBox.Text)
        $status.Text = "Valid: $($urls.Count) URL(s)"
        return $urls
    }
    catch {
        $status.Text = "Please check the JSON or URLs."
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Chrome JSON URL Opener", "OK", "Error") | Out-Null
        return $null
    }
}

$browseButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
    $dialog.Title = "Choose a JSON file"
    if ($dialog.ShowDialog() -eq "OK") {
        $fileBox.Text = $dialog.FileName
        $loadButton.PerformClick()
    }
})

$loadButton.Add_Click({
    try {
        $text = Get-Content -LiteralPath $fileBox.Text -Raw -Encoding UTF8
        $count = @(Get-UrlList $text).Count
        $jsonBox.Text = $text
        $status.Text = "Loaded: $count URL(s)"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Chrome JSON URL Opener", "OK", "Error") | Out-Null
    }
})

$validateButton.Add_Click({ $null = & $readUrls })

$openButton.Add_Click({
    $urls = @(& $readUrls)
    if ($urls.Count -eq 0 -or $null -eq $urls[0]) { return }
    $answer = [System.Windows.Forms.MessageBox]::Show(
        "Open $($urls.Count) URL(s) in Chrome?", "Chrome JSON URL Opener", "YesNo", "Question"
    )
    if ($answer -ne "Yes") { return }
    try {
        Open-UrlsInChrome $urls
        $status.Text = "Opened $($urls.Count) URL(s) in Chrome."
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Chrome JSON URL Opener", "OK", "Error") | Out-Null
    }
})

$form.Add_KeyDown({
    if ($_.Control -and $_.KeyCode -eq "Enter") { $openButton.PerformClick() }
})
$form.KeyPreview = $true
[void]$form.ShowDialog()
