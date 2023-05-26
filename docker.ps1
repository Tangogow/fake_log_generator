$action = $Args[0]
$rangemin = $Args[1]
$rangemax = $Args[2]
$nblogs = $Args[3]
$lps = $Args[4]
$size = $Args[5]
$ip = "172.22.39."
$name = "flg"
$image = "flg"
$volume = "C:\ProgramData\Docker\volumes\logs\_data"

Function usage {
    Write-Output "
Usage: .\docker.ps1 <start|stop|restart|create|rm|recreate|run|exec|logs> <rangemin> <rangemax> [<number_of_logs> <logs_per_seconde> <size_of_logs>]
Example: 
    .\docker.ps1 run 1 20                   Create and start 20 containers
    .\docker.ps1 exec 1 20 10000 100 100    Generate 10000 logs of 100 bytes at the rate of 100 logs/s 
    .\docker.ps1 logs 1 20                  Wait for the logs to come and report
    .\docker.ps1 rm 1 20                    Kill and remove containers"
}

$actionArray = @("start", "stop", "restart", "create", "rm", "recreate", "run", "exec", "logs")

If ($actionArray -notcontains $action) {
    Write-Error "Wrong action command:" $action
    usage
}

If ($rangemax -eq $null) {
    $rangemax = $rangemin
}
If ($rangemin -lt 1 -and $rangemin -match "^\d+$" -or $rangemax -lt 1 -and $rangemax -match "^\d+$") {
    Write-Error "Wrong range. Need postive integers"
    usage
}
ElseIf ($rangemin -gt $rangemax) {
    Write-Error "Wrong range. Rangemax should be higher than rangemin"
    usage
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

If ($action -eq "exec") {
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
            $values = $line.Split(',')
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
    Write-Output "$action container $i"
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
        docker kill $name$i
        docker rm $name$i
    }
    ElseIf ($action -eq "create") {
        docker create --name $name$i --ip $ip$i -v logs:"c:\logs" -e NAME=$name$i -ti $image
    }
    ElseIf ($action -eq "recreate") {
        docker kill $name$i
        docker rm $name$i
        docker run --name $name$i --ip $ip$i -v logs:"c:\logs" -e NAME=$name$i -tid $image
    }
    ElseIf ($action -eq "run") {
        docker kill $name$i > $null
        docker rm $name$i > $null
        docker run --name $name$i --ip $ip$i -v logs:"c:\logs" -e NAME=$name$i -tid $image
    }
    ElseIf ($action -eq "exec") {
        docker exec -d $name$i powershell C:\genlog.ps1 MyApp $nblogs $lps $size
    }
}
if ($action -eq "run") {
    docker ps
}