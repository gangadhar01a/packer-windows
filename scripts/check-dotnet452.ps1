<# # Documentation {{{
  .Synopsis
  Installs .Net 3.5
#> # }}}
[CmdletBinding(SupportsShouldProcess=$true)]
Param(
)
begin
{
  Write-Output "Script started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  $Now = Get-Date -Format 'yyyyMMddHHmmss'
}
process
{
  function Show-Elapsed([Diagnostics.StopWatch] $watch) # {{{
  {
    $elapsed = ''
    if ($watch.Elapsed.Days    -gt 0) { $elapsed += " $($watch.Elapsed.Days) days" }
    if ($watch.Elapsed.Hours   -gt 0) { $elapsed += " $($watch.Elapsed.Hours) hours" }
    if ($watch.Elapsed.Minutes -gt 0) { $elapsed += " $($watch.Elapsed.Minutes) minutes" }
    if ($watch.Elapsed.Seconds -gt 0) { $elapsed += " $($watch.Elapsed.Seconds) seconds" }
    return $elapsed
  } # }}}

# Prerequisites: {{{
# Prerequisite: Powershell 3 {{{2
  if($PSVersionTable.PSVersion.Major -lt 3)
  {
      Write-Error "Powershell version 3 or more recent is required"
      Write-Output "Script ended at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
      Start-Sleep 2
      exit 1
  }
# 2}}}
# Prerequisites }}}

  # Checking for dotnet 4.5.2
      $dotnet_info = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction SilentlyContinue
  if ($dotnet_info -eq $null -or $dotnet_info.Release -lt 379893)
  {
    Write-Error "Failure while installing .Net 4.5.2"
    Write-Output "Script ended at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Start-Sleep 5
    exit 1
  }
}
end
{
  Write-Output "Script ended at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  Start-Sleep 5
  exit $LastExitCode
}
