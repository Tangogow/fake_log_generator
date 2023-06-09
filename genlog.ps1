# Need admin perms to read docker volumes files
#if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSCommandPath`" `"$Args`"" -Verb RunAs; exit } $Argv = $Args.Split(" ")

$action = $Args[0]
$rangeMin = $Args[1]
$rangeMax = $Args[2]
$logNumber = $Args[3]
$logPerSecond = $Args[4]
$logSize = $Args[5]
$ip = "172.22.39."
$name = "gwl"
$image = "gwl"
$eventApp = "MyApp" # If new App, it will create it
$volume = "C:\ProgramData\Docker\volumes\logs\_data"

Function usage {
    Write-Output "
Usage: .\docker.ps1 <start|stop|restart|create|rm|recreate|run|exec|gen|logs> <rangemin> <rangemax> [<number_of_logs> <logs_per_seconde> <size_of_logs>]
Example: 
    .\docker.ps1 run 1 20                   Create and start 20 containers
    .\docker.ps1 gen 1 20 10000 100 100     Generate 10000 logs of 100 bytes at the rate of 100 logs/s on each container
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
    $logNumber = ""
}

If ($rangeMax -eq $null) {
    $rangeMax = $rangeMin
}
If ($rangeMin -lt 1 -or $rangeMax -lt 1) {
    Write-Error "Wrong range. Need postive integers"
    usage
}
ElseIf ($rangeMin -gt $rangeMax) {
    Write-Error "Wrong range. Rangemax should be higher than rangemin"
    usage
}
If ($action -eq "gen") {
    If ($logNumber -lt 1 -or $logPerSecond -lt 1 -or $logSize -lt 1) {
        Write-Error "Wrong number of logs and/or logs per second and/or size. Need postive integers"
        usage
    }
}

$logsGenerated = 0
$realLogsPerSecond = 0
$totalSizeBytes = 0
$durationSecs = 0

function formatDuration($seconds) {
    if ($seconds -lt 60) {
        return "$seconds secs"
    }
    elseif ($seconds -lt 3600) {
        $seconds = [math]::Round(($seconds / 60), 0)
        return  "$seconds mins"
    }
    else {
        $seconds = [math]::Round(($seconds / 3600), 0)
        return  "$seconds hours"
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

If ($action -eq "gen") {
    Remove-Item -Path "$volume\*" -Force -Recurse
}
ElseIf ($action -eq "logs") {
    while ((Get-ChildItem -Path $volume).Count -ne ($rangeMax - $rangeMin + 1)) {
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
    $totalSize = formatSize($totalSizeBytes)
    $duration = formatDuration($durationSecs)

    Write-Output "=== FAKE LOG REPORT ===
Logs generated     $LogsGenerated
Logs/s             $RealLogsPerSecond
Total size         $totalSize
Duration           $duration"
    exit 0
}

For ($i = $rangeMin; $i -le $rangeMax; $i++) {
    If ($action -eq "start") {
        docker start $name$i
        Write-Output "Container $name$i started"
    }
    ElseIf ($action -eq "stop") {
        docker stop $name$i
        Write-Output "Container $name$i stopped"
    }
    ElseIf ($action -eq "restart") {
        docker restart $name$i
        Write-Output "Container $name$i restart"
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
        docker run --name $name$i --ip $ip$i -v logs:"c:\logs" -e NAME=$name$i -tid $image > $null
        Write-Output "Container $name$i created and running"
    }
    ElseIf ($action -eq "exec") {
        docker exec -d $name$i powershell $execCommand
        Write-Output "Command $execCommand injected in container $name$i"
    }
    ElseIf ($action -eq "gen") {
        docker exec -d $name$i powershell C:\genevent.ps1 $eventApp $logNumber $logPerSecond $logSize
        Write-Output "Generating logs in container $name$i "
    }
}
if ($action -eq "run" -or $action -eq "create") {
    docker ps
}