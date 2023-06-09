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
$logsPerSecond = $Args[2]
$logSize = $Args[3]

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

function GenerateRandomBytes($logSize) {
    # insert FAKE prefix if LogSize > 5
    $Message = ""
    $i = 1
    if ($logSize -ge 5) {
        $Message = "FAKE "
        $i = 5
    }
    $random = New-Object System.Random
    for ($i; $i -lt $logSize; $i++) {
        $Message += [char]$random.Next(33, 126)
    }
    return $Message
}

CreateSource $AppSource
# Calculate the time delay between logs in milliseconds
$delayBetweenLogs = [math]::Round(1000 / $logsPerSecond - 0.001, 3) #0.001 = time to log
#$delayBetweenLogs = 1000 / $logsPerSecond 
echo $delayBetweenLogs
$startTime = Get-Date
Write-Output "Generating..."

# Generate random event logs
for ($logsGenerated = 0; $logsGenerated -lt $NumberOfLogs; $logsGenerated++) {
    $eventID = Get-Random -Minimum 1 -Maximum 65535

    # Generate random message data
    $messageBytes = New-Object byte[] $logSize
    $random = New-Object System.Random
    $random.NextBytes($messageBytes)

    # Create the event log entry
    $EventLogEntry = @{
        LogName      = 'Application'
        Source       = $AppSource
        EventID      = $eventID
        EntryType    = @("Information", "Warning", "Error") | Get-Random
        Message      = GenerateRandomBytes $logSize
    }

    Write-EventLog @EventLogEntry

    # Wait for the specified delay before generating the next log
    Start-Sleep -Milliseconds $delayBetweenLogs
}

function formatDuration($second) {
    if ($second -lt 60) {
        return "$second secs"
    }
    elseif ($second -lt 3600) {
        $second = [math]::Round(($second / 60), 0)
        return  "$second mins"
    }
    else {
        $second = [math]::Round(($second / 3600), 0)
        return  "$second hours"
    }
}

function formatSize($totalSize) {
    if ($totalSize -lt 1024) {
        return "$totalSize B"
    }
    elseif ($totalSize -lt 1048576) {
        $totalSize = [math]::Round(($totalSize / 1024), 0)
        return "$totalSize KB"
    }
    elseif ($totalSize -lt 1073741824) {
        $totalSize = [math]::Round(($totalSize / 1048576), 0)
        return "$totalSize MB"
    }
    else {
        $totalSize = [math]::Round(($totalSize / 1073741824), 0)
        return "$totalSize GB"
    }
}
function report() {
    $endTime = Get-Date

    $duration = $endTime - $startTime
    $durationSecs = [math]::Round($duration.TotalSeconds, 0) # for log file
    $duration = [math]::Round($duration.TotalSeconds, 1)

    $duration = formatDuration($durationSecs)
    $estimatedDurationSecs = [math]::Round(($logsGenerated / $logsPerSecond),0)
    $estimatedDuration = formatDuration($estimatedDurationSecs)

    $totalSize = $logsGenerated * $logSize
    $totalSizeBytes = $totalSize
    $totalSize = formatSize($totalSize)

    $realLogsPerSecond = [math]::Round(($logsGenerated / $durationSecs), 0)
    Write-Output "=== FAKE LOG REPORT ===
Logs generated     $logsGenerated
Wanted Logs/s      $logsPerSecond
Real Logs/s        $realLogsPerSecond
Total size         $totalSize
Estimated duration $estimatedDuration
Real Duration:     $duration"

    # Write to log file in the Docker volume in csv
    $result = "$logsGenerated,$realLogsPerSecond,$totalSizeBytes,$durationSecs"
    $result | Out-File -FilePath "C:\logs\$env:NAME.log" -Encoding UTF8
    exit 0
}

report

