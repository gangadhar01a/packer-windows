<# # Documentation {{{
  .Synopsis
  Installs CIC
#> # }}}
[CmdletBinding(SupportsShouldProcess=$true)]
Param(
  [Parameter(Mandatory=$false)]
  [string] $User        = 'vagrant',
  [Parameter(Mandatory=$false)]
  [string] $Password    = 'vagrant',
  [Parameter(Mandatory=$false)]
  [string] $InstallPath = 'C:\I3\IC',
  [Parameter(Mandatory=$false)]
  [string] $SourceDriveLetter,
  [Parameter(Mandatory=$false)]
  [switch] $Wait,
  [Parameter(Mandatory=$false)]
  [switch] $Reboot
)
begin
{
  Write-Output "Script started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  $Now        = Get-Date -Format 'yyyyMMddHHmmss'
  $Product    = 'Interaction Center Server'
  $msi_prefix = 'icserver'
  $Log        = "C:\Windows\Logs\${msi_prefix}-${Now}.log"
}
process
{
  function Show-Elapsed([Diagnostics.StopWatch] $watch) # {{{
  {
    $elapsed = ''
        if ($watch.Elapsed.Days    -gt 1) { $elapsed += " $($watch.Elapsed.Days) days" }
    elseif ($watch.Elapsed.Days    -gt 0) { $elapsed += " $($watch.Elapsed.Days) day"  }
        if ($watch.Elapsed.Hours   -gt 1) { $elapsed += " $($watch.Elapsed.Hours) hours" }
    elseif ($watch.Elapsed.Hours   -gt 0) { $elapsed += " $($watch.Elapsed.Hours) hour"  }
        if ($watch.Elapsed.Minutes -gt 1) { $elapsed += " $($watch.Elapsed.Minutes) minutes" }
    elseif ($watch.Elapsed.Minutes -gt 0) { $elapsed += " $($watch.Elapsed.Minutes) minute"  }
        if ($watch.Elapsed.Seconds -gt 0) { $elapsed += " $($watch.Elapsed.Seconds) seconds" }
    return $elapsed
  } # }}}

# Prerequisites: {{{
# Prerequisite: Product is not installed {{{2
  if (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object DisplayName -match "${Product}.*")
  {
    Write-Output "$Product is already installed"
    exit
  }
# 2}}}

# Prerequisite: Powershell 3 {{{2
  if($PSVersionTable.PSVersion.Major -lt 3)
  {
    Write-Error "Powershell version 3 or more recent is required"
    Start-Sleep 2
    Write-Output "Script ended at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    exit 1
  }
# 2}}}

# Prerequisite: Find the source! {{{2
  if ([string]::IsNullOrEmpty($SourceDriveLetter))
  {
    if (Test-Path $env:USERPROFILE/mounted.info)
    {
      $SourceDriveLetter = Get-Content $env:USERPROFILE/mounted.info
      Write-Verbose "Got drive letter from a previous mount: $SourceDriveLetter"
    }
    else
    {
      $SourceDriveLetter = ls function:[d-z]: -n | ?{ Test-Path "$_\Installs\ServerComponents" } | Select -First 1
      if ([string]::IsNullOrEmpty($SourceDriveLetter))
      {
        Write-Error "No drive containing installation for $Product was mounted"
        exit 3
      }
      Write-Verbose "Calculated drive letter: $SourceDriveLetter"
    }
  }
  $InstallSource = (Get-ChildItem -Path "${SourceDriveLetter}\Installs\ServerComponents" -Filter "${msi_prefix}_*.msi").FullName
  if (! (Test-Path $InstallSource))
  {
    Write-Error "$Product Installation source not found in $SourceDriveLetter"
    Start-Sleep 2
    Write-Output "Script ended at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    exit 2
  }
  if ($InstallSource -match '.*\\ICServer_([0-9]+)_R([0-9]+)\.msi')
  {
    $ProductVersion = $matches[1]
    $ProductRelease = $matches[2]
    Write-Output "Installing $Product ${ProducVersion}R${ProductRelease} from $InstallSource"
  }
  else
  {
    Write-Error "Cannot find version and release of $Product in $InstallSource"
    Start-Sleep 2
    Write-Output "Script ended at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    exit 2
  }
# 2}}}

# Prerequisite: .Net {{{2
  # For now, we always need .Net 3.5
  if ((Get-WindowsFeature -Name Net-Framework-Core -Verbose:$false).InstallState -ne 'Installed')
  {
    Write-Output ".Net 3.5 install state: $((Get-WindowsFeature -Name Net-Framework-Core -Verbose:$false).InstallState)"
    Write-Output "Installing .Net 3.5"
    Install-WindowsFeature -Name Net-Framework-Core
    if (! $?)
    {
      Write-Error "ERROR $LastExitCode while installing .Net 3.5"
      Write-Output "Script ended at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
      Start-Sleep 10
      exit $LastExitCode
    }
  }
  else
  {
    Write-Output ".Net 3.5 is installed"
  }
  if ($ProductVersion -ge 2016)
  {
    Write-Output "Checking if .Net 4.5.2 or more is installed"
    # We need .Net >= 4.5.2
    $dotnet_info = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction SilentlyContinue
    if ($dotnet_info -eq $null -or $dotnet_info.Release -lt 379893)
    {
      if (Test-Path "${SourceDriveLetter}\ThirdPartyInstalls\Microsoft\DotNET4.5.2\dotNetFx452_Full_x86_x64.exe")
      {
        Write-Output "Installing .Net 4.5.2 from the ISO"
        & ${SourceDriveLetter}ThirdPartyInstalls\Microsoft\DotNET4.5.2\dotNetFx452_Full_x86_x64.exe /Passive /norestart /Log C:\Windows\Logs\dotnet-4.5.2.log.txt
      }
      else
      {
        Write-Output "Installing .Net 4.5.2 from the Internet"
        choco install -y dotnet4.5.2
      }
    }
    else
    {
      Write-Output ".Net 4.5.2 or better is installed"
    }
  }
# 2}}}

# Prerequisites }}}

  Write-Output "Installing $Product"
  #TODO: Capture the domain if it is in $User
  $Domain = $env:COMPUTERNAME

  $parms  = '/i',"${InstallSource}"
  $parms += "PROMPTEDUSER=$User"
  $parms += "PROMPTEDDOMAIN=$Domain"
  $parms += "PROMPTEDPASSWORD=$Password"
  $parms += "INTERACTIVEINTELLIGENCE=$InstallPath"
  $parms += "TRACING_LOGS=$InstallPath\Logs"
  $parms += 'STARTEDBYEXEORIUPDATE=1'
  $parms += 'CANCELBIG4COPY=1'
  $parms += 'OVERRIDEKBREQUIREMENT=1'
  $parms += 'REBOOT=ReallySuppress'
  $parms += '/l*v'
  $parms += "$Log"
  $parms += '/qn'
  $parms += '/norestart'

  Write-Verbose "Arguments: $($parms -join ',')"
  if ($PSCmdlet.ShouldProcess($_.ProductName, "Running msiexec /install"))
  {
    if ($Wait)
    {
      $watch   = [Diagnostics.StopWatch]::StartNew()
      $process = Start-Process -FilePath msiexec -ArgumentList $parms -Wait -PassThru
      $watch.Stop()
      $elapsed = Show-Elapsed($watch)
      if ($process.ExitCode -eq 0)
      {
        Write-Output "$Product installed successfully in $elapsed!"
        $exit_code = 0
      }
      elseif ($process.ExitCode -eq 3010)
      {
        Write-Output "$Product installed successfully in $elapsed!"
        $exit_code = 0
        if ($Reboot)
        {
          Write-Output "Restarting..."
          Write-Output "Script ended at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
          Restart-Computer
          Start-Sleep 30
        }
        else
        {
          Write-Warning "Rebooting is needed before using $Product"
        }
      }
      else
      {
        Write-Error "Failure: Error= $($process.ExitCode), Logs=$Log, Execution time=$elapsed"
        $exit_code = $process.ExitCode
      }
    }
    else
    {
      $process = Start-Process -FilePath msiexec -ArgumentList $parms -PassThru
      # Give some time for the msiexec process to start
      Start-Sleep 30
      Write-Output "$Product is being installed"
      if ($process.HasExited)
      {
      $exit_code = $process.ExitCode
      #if ($exit_code -ne 0)
      #{
        #Write-Error "$Product failed to start installing itself. Error: $exit_code."
        Write-Output "Install process exit code: [${exit_code}]."
        $exit_code = 0
      #}
      }
      else
      {
        Write-Output "Installing..."
      }
    }

# The ICServer MSI tends to not finish properly even if successful   
#  $process = Start-Process -FilePath msiexec -ArgumentList $parms -PassThru   
  
#  # Let's wait for things to start and be well under way    
#  Start-Sleep 30    

#  # Check for MSI Exec processes    
#  # When there is 0 or 1 MSI process left, we should be good to continue    
#  do    
#  {   
#    Start-Sleep 10   
#    $process_count = @(Get-Process | Where ProcessName -eq 'msiexec').Count    
#    Write-Verbose "  Still $process_count MSI processes running [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')]"   
#  }    
#  while ($process_count -gt 1)   
#  Write-Verbose "  No more MSI running"    

#  # Check for successful installation    
#  if (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object DisplayName -eq $Product)    
#  {    
#    Write-Verbose "$Product is installed"    
#  }    
#  else   
#  {    
#    #TODO: Should we return values or raise exceptions?    
#    Write-Error "Failed to install $Product"   
#    return -2    
#  }
  }
}
end
{
  Write-Output "Script ended at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  Start-Sleep 5
  exit $exit_code
}
