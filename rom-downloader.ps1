Import-Module ".\modules\log-module.psm1"

Add-Type -AssemblyName System.Windows.Forms

#-----------------------------------------------------------------------
# Function: Invite the user to enter source URLs for a given input file.
#-----------------------------------------------------------------------
function Enter-SourceUrls {
    param(
        [string]$InputFileName
    )
    $urls = @()
    do {
        $promptTitle   = "Enter URL for '$InputFileName'"
        $promptMessage = "Please enter a source URL for input file '$InputFileName' (leave blank when finished):"
        $urlInput      = $Host.UI.Prompt($promptTitle, $promptMessage, "URL")
        if (-not [string]::IsNullOrEmpty($urlInput["URL"])) {
            $urls += $urlInput
        }
    } while (-not [string]::IsNullOrEmpty($urlInput["URL"]))

    if ($urls.Count -eq 0) {
        Write-Log -Message "[$InputFileName] No URLs provided." -Level "ERROR"
        exit
    }
    return $urls
}

#-----------------------------------------------------------------------
# Function: Retrieve the content from a given URL.
#-----------------------------------------------------------------------
function Get-UrlContent {
    param(
        $Url
    )
    try {
        $response = Invoke-WebRequest -Uri $Url["URL"] -UseBasicParsing
        return $response.Content, $Url
    }
    catch {
        Write-Log -Message "[$global:currentInputName] Failed to fetch $($Url["URL"]): $($_.Exception.Message)" -Level "ERROR"
        return $null, $null
    }
}

#-----------------------------------------------------------------------
# Function: Allow the user to select a common download folder.
#-----------------------------------------------------------------------
function Select-DownloadFolder {
    Write-Host "`nSelect Download Folder" -ForegroundColor White
    Write-Host "Please choose the common destination folder for downloads..."

    $folderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowserDialog.Description = "Select download destination folder"
    $folderBrowserDialog.ShowNewFolderButton = $true

    if ($folderBrowserDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $folderBrowserDialog.SelectedPath
    }
    else {
        Write-Log -Message "No folder selected." -Level "ERROR"
        exit
    }
}

#-----------------------------------------------------------------------
# Function: Allow the user to select the main language.
#-----------------------------------------------------------------------
function Select-MainLanguage { 
    $sortedKeys = $countryLanguageMap.Keys | Sort-Object -Descending 
    $choices = foreach ($key in $sortedKeys) {
        $hotkey = $countryHotKeys[$key]
        $label  = "$($key): &$hotkey" 
        [Management.Automation.Host.ChoiceDescription]::new($label, "Language: $($countryLanguageMap[$key])")
    }

    $defaultChoice  = 0
    $selectedIndex  = $Host.UI.PromptForChoice("Select Main Language", "Choose your country:", $choices, $defaultChoice)

    Write-Log -Message "Main Language: $($countryLanguageMap[$sortedKeys[$selectedIndex]])"

    return $countryLanguageMap[$sortedKeys[$selectedIndex]]
}

#-----------------------------------------------------------------------
# Function: Confirm a yes/no question with the user.
#-----------------------------------------------------------------------
function Confirm-UserChoice {
    param(
        [string]$Title,
        [string]$Question,
        [string]$FirstLabel  = "Yes, confirm.",
        [string]$SecondLabel = "No, decline.",
        [Int16]$DefaultChoice = 1
    )
    $choices = @(
        [Management.Automation.Host.ChoiceDescription]::new('&Yes', $FirstLabel),
        [Management.Automation.Host.ChoiceDescription]::new('&No',  $SecondLabel)
    )
    
    return ($Host.UI.PromptForChoice($Title, $Question, $choices, $DefaultChoice) -eq 0)
}

#-----------------------------------------------------------------------
# Function: Convert and normalize a string (e.g., a game title) into a safe name.
#-----------------------------------------------------------------------
function ConvertTo-SafeName {
    param(
        [string]$Item
    )
    $lowerItem = $Item.ToLower()

    $tag       = ""
    if ($allowBetaDemo) {
        $match = [regex]::Match($lowerItem, $preReleasePattern)
        if ($match.Success) {
            $tag = $match.Groups["tag"].Value
        }
    }

    # Check for disc pattern e.g. (disc 1) or [disc 2]
    $discTag = ""
    $discMatch = [regex]::Match($lowerItem, "(?i)[\(\[]\s*disc\s*(?<disc>\d+)\s*[\)\]]")
    if ($discMatch.Success) {
        $discTag = "disck" + $discMatch.Groups["disc"].Value
    }

    $safeName = $lowerItem -replace "\(.*$", "" -replace "(\s?(T|t)he | of | or | is | a | an )", "" -replace "[^a-z0-9]", ""
    if ($tag -ne "") {
        $safeName += ($tag -replace "\s+", "") # Append beta/demo tag if present
    }
    if ($discTag -ne "") {
        $safeName += ($discTag -replace "\s+", "") # Append disc tag if found
    }
    
    return $safeName
}

#-----------------------------------------------------------------------
# Function: Remove duplicates and convert an array of strings into safe names.
#-----------------------------------------------------------------------
function ConvertTo-UniqueSafeNames {
    param(
        [array]$InputArray
    )
    $uniqueItems = @{}
    foreach ($item in $InputArray) {
        $safeName = ConvertTo-SafeName $item
        if (-not [string]::IsNullOrWhiteSpace($safeName)) {
            $uniqueItems[$safeName] = $true
        }
    }
    return $uniqueItems.Keys
}

#-----------------------------------------------------------------------
# Function: Retrieve all links from an HTML string.
#-----------------------------------------------------------------------
function Get-LinksFromHtml {
    param(
        [string]$Html
    )
    $pattern = '<a[^>]*?href="([^"]*?)"[^>]*?>(.*?)<\/a>'
    return [regex]::Matches($Html, $pattern) | ForEach-Object {
        [PSCustomObject]@{
            Href = $_.Groups[1].Value
            Text = $_.Groups[2].Value
        }
    }
}

#-----------------------------------------------------------------------
# Function: Read an input file and return its non-empty lines.
#-----------------------------------------------------------------------
function Get-NonEmptyLinesFromFile {
    param(
        [string]$InputFilePath
    )
    try {
        return Get-Content -Path $InputFilePath | Where-Object { $_.Trim() -ne "" }
    }
    catch {
        Write-Log -Message "[$global:currentInputName] $($_.Exception.Message)" -Level "ERROR"
        exit
    }
}

#-----------------------------------------------------------------------
# Function: Determine the language priority based on a game name.
#-----------------------------------------------------------------------
function Get-LanguagePriority {
    param(
        [string]$GameName
    )
    $country = $countryLanguageMap.GetEnumerator() | Where-Object { $_.Value -eq $mainLanguage } | Select-Object -First 1

    if ($mainLanguage -ne 'En' -and $mainLanguage -ne 'Ja') {
        switch -regex ($GameName) {
            "\(.*$($country.Name).*\)" { 
                return 20
            }
            "(?i)\(\s*(?=.*\b$mainLanguage\b).*?\)" {
                if ($GameName -match "\(.*Europe.*\)") {
                    return 20
                }
                return 19
            }
            "\(.*Europe.*\)" {
                return 18
            }
            "\(.*World.*\)" {
                return 17
            }
            "\[W\]" {
                return 17
            }
        }
    }

    if ($allowEnglishGames) {
        switch -regex ($GameName) {
            "\(.*USA.*\)" {
                return 10
            }
            "\[U\]" {
                return 10
            }
            "(?i)\(\s*(?=.*\bEn\b).*?\)" {
                return 10
            }
            "\(.*World.*\)" {
                return 9
            }
            "\[W\]" {
                return 9
            }
        }
    }

    if ($allowJapaneseGames) {
        switch -regex ($GameName) {
            "\(.*Japan.*\)" {
                return 1
            }
            "\[J\]" {
                return 1
            }
            "(?i)\(\s*(?=.*\bJa\b).*?\)" {
                return 1
            }
        }
    }

    return 0
}

#-----------------------------------------------------------------------
# Function: Select the best links based on language priority while excluding beta/demo/proto versions.
#-----------------------------------------------------------------------
function Select-BestLinks {
    param(
        [array]$Links
    )
    $bestVersions = @{}
    foreach ($link in $Links) {
        if (-not $allowBetaDemo -and $link.Text -match $preReleasePattern) { continue }
        
        $safeName = ConvertTo-SafeName $link.Text
        $priority = Get-LanguagePriority $link.Text
        
        if ($priority -gt 0 -and (-not $bestVersions.ContainsKey($safeName) -or $priority -gt $bestVersions[$safeName].Priority)) {
            $bestVersions[$safeName] = @{
                Link     = $link
                Priority = $priority
            }
        }
    }
    return $bestVersions
}

#-----------------------------------------------------------------------
# Function: Save files from the selected links into the destination folder.
#-----------------------------------------------------------------------
function Save-DownloadedFiles {
    param(
        [array]$DownloadLinks,
        [hashtable]$FilteredLinks,
        [string]$DestinationFolder,
        [bool]$CrossCheck
    )
    if ($CrossCheck) {
        $existingFiles = ConvertTo-UniqueSafeNames @(Get-ChildItem -Path $DestinationFolder -File | ForEach-Object Name)
    }
    else {
        $existingFiles = @()
    }

    $downloadTasks = @()
    foreach ($safeGameName in $DownloadLinks) {
        if ($FilteredLinks.ContainsKey($safeGameName)) {
            $link     = $FilteredLinks[$safeGameName].Link
            $gameName = $link.Text
            if ($CrossCheck -and ($safeGameName -in $existingFiles)) {
                Write-Host "  ~ Skipped $gameName"
                Write-Log -Message "[$global:currentInputName] '$gameName' is already downloaded, skipping." -Level "INFO"
            }
            else {
                $downloadTasks += [PSCustomObject]@{
                    Url      = $link.Href
                    OutFile  = "$DestinationFolder\$([IO.Path]::GetFileName($gameName))"
                    LinkText = $gameName
                }
            }
        }
    }

    $downloadTasks | ForEach-Object -Parallel {
        Import-Module ".\modules\log-module.psm1"
        try {
            Invoke-WebRequest -Uri $_.Url -OutFile $_.OutFile -TimeoutSec 300
            Write-Host "  + Downloaded $($_.LinkText)"
            Write-Log -Message "[$using:global:currentInputName] '$($_.LinkText)' downloaded"
        }
        catch {
            Write-Log -Message "[$using:global:currentInputName] Failed to download $($_.LinkText): $($_.Exception.Message)" -Level "ERROR"
        }
    } -ThrottleLimit $throttleLimit
}

#-----------------------------------------------------------------------
# Main function: Orchestrates the URL collection and download workflow.
#-----------------------------------------------------------------------
function Invoke-DownloadWorkflow {
    $destinationFolder = Select-DownloadFolder
    Write-Log -Message "Script start"
    Write-Log -Message "Download folder selected: $destinationFolder"

    # Retrieve all input files from the roms-lists folder
    $inputFiles = Get-ChildItem -Path $romsListsFolder -Filter *.txt
    if ($inputFiles.Count -eq 0) {
        Write-Log -Message "No input files found in $romsListsFolder" -Level "ERROR"
        exit
    }

    ## PHASE 1: URL Collection and Cross-Check Preference for Each Input File
    $inputsData = @()
    foreach ($file in $inputFiles) {
        $global:currentInputName = $file.BaseName

        Write-Host "`n========================================"
        Write-Host "URL Collection for Input File: $($file.Name)"
        Write-Host "========================================"
        
        $urls = Enter-SourceUrls -InputFileName $global:currentInputName

        $crossCheckChoice = Confirm-UserChoice -Title "Cross-Check Existing Files" `
                                               -Question "Would you like to check the download folder for existing files for this input?" `
                                               -FirstLabel "Yes, perform cross-check." `
                                               -SecondLabel "No cross-check." `
                                               -DefaultChoice 0

        $inputsData += [PSCustomObject]@{
            File       = $file
            Urls       = $urls
            CrossCheck = $crossCheckChoice
        }
    }

    ## PHASE 2: Processing and Downloading for Each Input File
    foreach ($inputData in $inputsData) {
        $global:currentInputName = $inputData.File.BaseName

        Write-Host "`n========================================"
        Write-Host "Download Phase for Input File: $($inputData.File.Name)"
        Write-Host "========================================"
        Write-Log -Message "[$global:currentInputName] Processing input file $($inputData.File.Name)"
        
        $inputLines      = Get-NonEmptyLinesFromFile -InputFilePath $inputData.File.FullName
        $cleanInputArray = ConvertTo-UniqueSafeNames @($inputLines)

        # Create a subfolder within the destination folder named after the input file
        $subDestinationFolder = Join-Path $destinationFolder $global:currentInputName
        if (-not (Test-Path -Path $subDestinationFolder)) {
            New-Item -Path $subDestinationFolder -ItemType Directory | Out-Null
        }
        Write-Log -Message "[$global:currentInputName] Download subfolder: $subDestinationFolder"

        # Process the collected URLs for the current input file
        $allLinks = @()
        foreach ($url in $inputData.Urls) {
            $html, $responseUrl = Get-UrlContent $url
            if (-not $html) { continue }
            $baseUri = [Uri]$responseUrl["URL"]

            $links = Get-LinksFromHtml $html | ForEach-Object {
                try {
                    $href = $_.Href.Trim()
                    if ([string]::IsNullOrWhiteSpace($href)) { continue }
                    $absoluteUri = New-Object Uri -ArgumentList $baseUri, $href
                    $_.Href = $absoluteUri.AbsoluteUri
                    $_
                }
                catch {
                    Write-Warning "[$global:currentInputName] Invalid URL: $($baseUri.AbsoluteUri) + $href | $($_.Exception.Message)"
                    continue
                }
            } | Where-Object { $_ }

            $links = $links | ForEach-Object {
                $_ | Add-Member -MemberType NoteProperty -Name "CleanText" -Value (ConvertTo-SafeName $_.Text) -Force -PassThru
            }
            $allLinks += $links
        }

        $filteredLinks = Select-BestLinks $allLinks
        Save-DownloadedFiles -DownloadLinks $cleanInputArray `
                             -FilteredLinks $filteredLinks `
                             -DestinationFolder $subDestinationFolder `
                             -CrossCheck $inputData.CrossCheck
    }

    Write-Host "`nAll operations completed. Enjoy!"
}

#-----------------------------------------------------------------------------#
#                            Main Script Execution                            #
#-----------------------------------------------------------------------------#
Write-Host @"
----------------------------------------------------------------------------
|\/\/\/\|    Hello! This script processes multiple input files.    |/\/\/\/|
|\/\/\/\|     For each file, it collects URLs and then crawls      |/\/\/\/|
|\/\/\/\|    public sites to download files matching your entries. |/\/\/\/|
|\/\/\/\|  Downloads are neatly organized into subfolders named    |/\/\/\/|
|\/\/\/\|              after each input file.                      |/\/\/\/|
|\/\/\/\|                                                          |/\/\/\/|
|\/\/\/\|               Sit back, relax, and enjoy!                |/\/\/\/|
----------------------------------------------------------------------------
"@

# Folder containing the input files (e.g., gb.txt, gba.txt, etc.)
$romsListsFolder = "./roms-lists"

# Mapping countries to language abbreviations (add more if needed)
$countryLanguageMap = @{
    'USA'         = 'En'
    'France'      = 'Fr'
    'Italy'       = 'It'
    'Germany'     = 'De'
    'Japan'       = 'Ja'
    'Spain'       = 'Es'
    'Netherlands' = 'Nl'
    'Sweden'      = 'Sv'
    'Denmark'     = 'Da'
}

# Dictionary for unique shortcuts
$countryHotKeys = @{
    'USA'         = 'U'
    'France'      = 'F'
    'Italy'       = 'I'
    'Germany'     = 'G'
    'Japan'       = 'J'
    'Spain'       = 'S'
    'Netherlands' = 'N'
    'Sweden'      = 'W'   # Using W for Sweden
    'Denmark'     = 'D'
}

# Regex pattern matching Beta/Demo/Proto and Rev versions
$preReleasePattern = "(?i)[\(\[].*?(?<tag>(?:beta|demo|proto|rev)(?:\s*\d+)?).*?[\)\]]"

# Global default values
$defaultThrottleLimit = 5
$allowEnglishGames    = $true
$allowJapaneseGames   = $true

# User inputs for download settings
$mainLanguage = Select-MainLanguage

Write-Host "`nSet Parallel Download Limit" -ForegroundColor White
Write-Host "Maximum number of simultaneous downloads ?"
if (!($throttleLimit = Read-Host "(default is `"$defaultThrottleLimit`")")) { 
    $throttleLimit = $defaultThrottleLimit 
}

Write-Log -Message "Throttle Limit: $throttleLimit"

if ($mainLanguage -ne 'En') {
    $allowEnglishGames = Confirm-UserChoice -Title "USA Alternative games" `
                                            -Question "Do you allow English games to be downloaded if main language not found ?" `
                                            -DefaultChoice 0
    if ($allowEnglishGames) {
        Write-Log -Message "USA Games Allowed"
    }
}

if ($mainLanguage -ne 'Ja') {
    $allowJapaneseGames = Confirm-UserChoice -Title "Japanese games" `
                                             -Question "Do you want to download Japanese games ?"
    if ($allowJapaneseGames) {
        Write-Log -Message "Japanese Games Allowed"
    }
}

$allowBetaDemo = Confirm-UserChoice -Title "Allow pre-release versions" `
                                    -Question "Do you want to download Beta/Demo/Proto versions ?"
if ($allowBetaDemo) {
    Write-Log -Message "Pre-release Games Allowed"
}

Invoke-DownloadWorkflow
