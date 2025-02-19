$logFilePath = "./logs/$(Get-Date -Format 'yyyy-MM-dd').log"

if (-not (Test-Path "./logs")) {
    New-Item -ItemType Directory -Path "./logs" -Force
}

if (-not (Test-Path $logFilePath)) {
    Out-File -FilePath $logFilePath -Encoding utf8
}

#-----------------------------------------------------------------------
# Function: Write a message to the log file
#-----------------------------------------------------------------------
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    # Construct the log message with a timestamp and log level
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    
    # If the log level is ERROR, also output an error message to the console
    if ($Level -eq "ERROR") {
        Write-Error $logMessage
    }

    # Append the log message to the log file
    Add-Content -Path $logFilePath -Value $logMessage
}

Export-ModuleMember -Function Write-Log
