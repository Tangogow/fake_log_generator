FROM mcr.microsoft.com/windows:ltsc2019
 
EXPOSE 514

COPY "load\*" "c:\\"
WORKDIR "c:\\"
SHELL ["powershell", "-command"]
RUN Set-ExecutionPolicy Unrestricted
#RUN iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
#RUN choco install python3 --version 3.11 -y
#RUN [Environment]::SetEnvironmentVariable('Path', '$env:Path;C:\Python311\Scripts\ ', 'User')
#RUN pip install ansible
#RUN ".\genlog.ps1 0 Application MyApp 0 0 0"
ENTRYPOINT ["powershell"]