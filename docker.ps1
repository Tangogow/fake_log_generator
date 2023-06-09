$action = $Args[0]
$rangemin = $Args[1]
$rangemax = $Args[2]
$nblogs = $Args[3]
$lps = $Args[4]
$size = $Args[5]
$ip = "172.22.39."
$name = "flg"
$image = "flg"
$eventApp = "MyApp" # If new App, it will create it
$volume = "C:\ProgramData\Docker\volumes\logs\_data"

Function usage {
    Write-Output "
Usage: .\docker.ps1 <start|stop|restart|create|rm|recreate|run|exec|gen|logs> <rangemin> <rangemax> [<number_of_logs> <logs_per_seconde> <size_of_logs>]
Example: 
    .\docker.ps1 run 1 20                   Create and start 20 containers
    .\docker.ps1 gen 1 20 10000 100 100     Generate 10000 logs of 100 bytes at the rate of 100 logs/s 
    .\docker.ps1 logs 1 20                  Wait for the logs to come and report.
    
Other command:
    .\docker.ps1 rm 1 20                    Kill and remove containers
    .\docker.ps1 restart 1 10               Restart the container from 1 to 10
    .\docker.ps1 exec 5 10 ""echo hello""   Injecting command into container 5 to 10 (background mode)"
    exit 1
}

$actionArray = @("start", "stop", "restart", "create", "rm", "recreate", "run", "exec", "gen", "logs")

If ($actionArray -notcontains $action) {
    Write-Error "Wrong action command:" $action
    usage
}

If ($action -eq "exec") {
    $execCommand = $Args[3]
    $nblogs = ""
}

If ($rangemax -eq $null) {
    $rangemax = $rangemin
}
If ($rangemin -lt 1 -or $rangemax -lt 1) {
    Write-Error "Wrong range. Need postive integers"
    usage
}
ElseIf ($rangemin -gt $rangemax) {
    Write-Error "Wrong range. Rangemax should be higher than rangemin"
    usage
}
if ($action -eq "gen") {
    if ($nblogs -lt 1 -and $nblogs -match "^\d+$" -or $lps -lt 1 -and $lps -match "^\d+$"  -or $size -lt 1 -and $size -match "^\d+$") {
        Write-Error "Wrong number of logs and/or logs per second and/or size. Need postive integers"
        usage
    }
}

$logsGenerated = 0
$realLogsPerSecond = 0
$totalSizeBytes = 0
$durationSecs = 0
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

If ($action -eq "gen") {
    Remove-Item -Path "$volume\*" -Force -Recurse -ErrorAction SilentlyContinue
}
ElseIf ($action -eq "logs") {
    while ((Get-ChildItem -Path $volume).Count -ne ($rangemax - $rangemin + 1)) {
        Write-Host "Waiting for logs... Logs present: " (Get-ChildItem -Path $volume).Count 
        Start-Sleep -Seconds 1
    }

    $files = Get-ChildItem -Path $volume -File
    foreach ($file in $files) {
        $content = Get-Content $file.FullName
        foreach ($line in $content) {
            $values = $line.Split(',') # parsing csv into array
            if ($values.Length -eq 4) {
                $logsGenerated += [int]$values[0]
                $realLogsPerSecond += [int]$values[1]
                $totalSizeBytes += [int]$values[2]
                if ([int]$values[3] -gt $durationSecs) {
                    $durationSecs += [int]$values[3]
                }
            }
        }
    }
    $TotalSize = formatSize($totalSizeBytes)
    $Duration = formatDuration($durationSecs)

    Write-Output "=== FAKE LOG REPORT ===
Logs generated     $LogsGenerated
Real Logs/s        $RealLogsPerSecond
Total size         $TotalSize
Real Duration      $Duration"
    exit 0
}

For ($i = $rangemin; $i -le $rangemax; $i++) {
    If ($action -eq "start") {
        docker start $name$i
    }
    ElseIf ($action -eq "stop") {
        docker stop $name$i
    }
    ElseIf ($action -eq "restart") {
        docker restart $name$i
    }
    ElseIf ($action -eq "rm") {
        docker kill $name$i > $null
        docker rm $name$i > $null
        Write-Output "Container $name$i killed"
    }
    ElseIf ($action -eq "create") {
        echo $ip$i
        docker create --name $name$i --ip $ip$i -v logs:"c:\logs" -e NAME=$name$i -ti $image
        Write-Output "Container $name$i created"
    }
    ElseIf ($action -eq "recreate") {
        docker kill $name$i > $null
        docker rm $name$i > $null
        docker run --name $name$i --ip $ip$i -v logs:"c:\logs" -e NAME=$name$i -tid $image
        Write-Output "Container $name$i recreated"
    }
    ElseIf ($action -eq "run") {
        docker kill $name$i > $null
        docker rm $name$i > $null
        docker run --name $name$i --ip $ip$i -v logs:"c:\logs" -e NAME=$name$i -tid $image
        Write-Output "Container $name$i created and running"
    }
    ElseIf ($action -eq "exec") {
        docker exec -d $name$i powershell $execCommand
        Write-Output "Command $execCommand injected in container $name$i"
    }
    ElseIf ($action -eq "gen") {
        docker exec -d $name$i powershell C:\genlog.ps1 $eventApp $nblogs $lps $size
        Write-Output "Generating logs in container $name$i "
    }
}
if ($action -eq "run" -or $action -eq "create") {
    docker ps
}