# Admin privilege
#if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSCommandPath`" `"$Args`"" -Verb RunAs; exit } $Argv = $Args.Split(" ")

if ($args.length -ne 4) {
  Write-Output "Usage: .\genlog.ps1 <AppSource> <NumberOfLogs> <LogsPerSecond> <LogSize>`n
You may be restricted by the number of logs per second, depending on your OS and disk IO's
AppSource: any string (ie: MyApp)
LogsPerSecond: in seconds (if 0 = fast as possible)
LogSize: in bytes for each log entry"
  exit 1
}

$AppSource = $Args[0]
$NumberOfLogs = $Args[1]
$LogsPerSecond = $Args[2]
$LogSize = $Args[3]

function CreateSource($AppSource) {
    $isPresent = (Get-WmiObject -Class Win32_NTEventLOgFile | 
    Select-Object FileName, Sources |
    ForEach-Object -Begin { $hash = @{}} -Process { $hash[$_.FileName] = $_.Sources } -end { $Hash })["Application"] |
    Select-String -Pattern $AppSource

    if ($isPresent -eq $null) {
        Write-Output "Creating source : $AppSource in Application"
        New-EventLog -LogName 'Application' -Source $AppSource
    }
}

function GenerateRandomBytes($LogSize) {
    # insert FAKE prefix if LogSize > 5
    $Message = ""
    $i = 1
    if ($LogSize -ge 5) {
        $Message = "FAKE "
        $i = 5
    }
    $Random = New-Object System.Random
    for ($i; $i -lt $LogSize; $i++) {
        $Message += [char]$Random.Next(33, 126)
    }
    return $Message
}

CreateSource $AppSource
# Calculate the time delay between logs in milliseconds
$DelayBetweenLogs = [math]::Round(1000 / $LogsPerSecond - 0.001, 3) #0.001 = time to log
#$DelayBetweenLogs = 1000 / $LogsPerSecond 
echo $DelayBetweenLogs
$StartTime = Get-Date
Write-Output "Generating..."

# Generate random event logs
for ($LogsGenerated = 0; $LogsGenerated -lt $NumberOfLogs; $LogsGenerated++) {
    $EventID = Get-Random -Minimum 1 -Maximum 65535

    # Generate random message data
    $MessageBytes = New-Object byte[] $LogSize
    $Random = New-Object System.Random
    $Random.NextBytes($MessageBytes)

    
    # Create the event log entry
    $EventLogEntry = @{
        LogName      = 'Application'
        Source       = $AppSource
        EventID      = $EventID
        EntryType    = @("Information", "Warning", "Error") | Get-Random
        Message      = GenerateRandomBytes $LogSize
    }

    Write-EventLog @EventLogEntry

    # Wait for the specified delay before generating the next log
    Start-Sleep -Milliseconds $DelayBetweenLogs
}

function formatDuration($Seconds) {
    if ($Seconds -lt 60) {
        return "$Seconds secs"
    }
    elseif ($Seconds -lt 3600) {
        $Seconds = [math]::Round(($Seconds / 60), 0)
        return  "$Seconds mins"
    }
    else {
        $Seconds = [math]::Round(($Seconds / 3600), 0)
        return  "$Seconds hours"
    }
}

function formatSize($TotalSize) {
    if ($TotalSize -lt 1024) {
        return "$TotalSize B"
    }
    elseif ($TotalSize -lt 1048576) {
        $TotalSize = [math]::Round(($TotalSize / 1024), 0)
        return "$TotalSize KB"
    }
    elseif ($TotalSize -lt 1073741824) {
        $TotalSize = [math]::Round(($TotalSize / 1048576), 0)
        return "$TotalSize MB"
    }
    else {
        $TotalSize = [math]::Round(($TotalSize / 1073741824), 0)
        return "$TotalSize GB"
    }
}
function report() {
    $EndTime = Get-Date

    $Duration = $EndTime - $StartTime
    $DurationSecs = [math]::Round($Duration.TotalSeconds, 0) # for log file
    $Duration = [math]::Round($Duration.TotalSeconds, 1)

    $Duration = formatDuration($DurationSecs)
    $EstimatedDurationSecs = [math]::Round(($LogsGenerated / $LogsPerSecond),0)
    $EstimatedDuration = formatDuration($EstimatedDurationSecs)

    $TotalSize = $LogsGenerated * $LogSize
    $TotalSizeBytes = $TotalSize
    $TotalSize = formatSize($TotalSize)

    $RealLogsPerSecond = [math]::Round(($LogsGenerated / $DurationSecs), 0)
    Write-Output "=== FAKE LOG REPORT ===
Logs generated     $LogsGenerated
Wanted Logs/s      $LogsPerSecond
Real Logs/s        $RealLogsPerSecond
Total size         $TotalSize
Estimated duration $EstimatedDuration
Real Duration:     $Duration"

    # Write to log file in the Docker volume
    $result = "$LogsGenerated,$RealLogsPerSecond,$TotalSizeBytes,$DurationSecs"
    $result | Out-File -FilePath "C:\logs\$env:NAME.log" -Encoding UTF8
    exit 0
}

report

