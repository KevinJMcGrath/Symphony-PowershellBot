function Add-LogEntry
{
    param([string]$source, [string]$message, [array]$addlParams)

    if($script:logPath -eq $null) { $script:logPath = $global:ConfigData.loggingPath }

    $logdate = Get-Date -Format "yyyy_MM_dd"
    $logFile = "$script:logPath/ErrorLog_$($source)_$logdate.txt"

    #https://mattypenny.net/2016/02/10/get-a-list-of-powershell-date-format-outputs/
    $logTime = Get-Date -Format o #g

    Add-Content $logFile -Value "$logtime - $message - $($addlParams -join ' | ')"
}