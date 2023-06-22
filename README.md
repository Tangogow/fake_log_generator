# Fake Windows Logs Generator

Generate logs to benchmark the performance of your SIEM or IDS.

*If you want to know how many requests your system and network can handle before your SIEM goes slow ?* Let's launch 10.000 linux containers and generate 100MB of logs every minute on each, and find out !

# Description

This tool's purpose is to stress test, SIEM, IDS, SOAR in terms of performance by the number and size of logs, not to trigger any detection. (most of the generated logs are either random logs or random bytes)

This tool uses Docker container to simulate a large number of machines with their own IP and generate fake logs which are retrieved by any SIEM/IDS with the pulling method. 
The container does not send the logs, it's the SIEM who's pulling it on port 514.

Another purpose is to benchmark your network and/or your on premise infrastructure, and see if your bandwidth is sufficient enough to handle heavy loads.

*This tool is originally intended to launched from a high capacity server.*

# How to start

1. Build the image with `docker build -t gwl .`
2. Then create the docker network with: ` docker network create --driver nat --gateway 172.0.255.254 --label gwl --subnet 172.0.0.0/16 gwl`
2. Launch your Docker cluster with
 ```bash
.\docker.ps1 run 1 20                  # Create and start 20 containers
```
3. Connect all your containers with your SIEM (you can each container or use WEC on the host)
4. Launch the generation
```bash
.\docker.ps1 gen 1 20 10000 100 100     # Generate 10000 logs of 100 bytes at the rate of 100 logs/s on each container
.\docker.ps1 logs 1 20                  #  Wait for the logs to come and report.
```
5. You can attach a tty to any individual container with `docker attach gwl<number>` and check the logs with
```powershell
Get-EventLog -LogName Application -Newest 5
``` 

# Limitation

They are several limitation.

You might be bottlenecked at different place:
1. Your machine (CPU, OS and disk IO's)
2. Your bandwith (switch, router, cables, network cards)
3. Your software (SIEM, IDS, Database)

# Hardware

A server with 128 vCPU and 250GB of RAM will allow you to simulate 300 Windows Server 2019

# Dependecies

- Docker