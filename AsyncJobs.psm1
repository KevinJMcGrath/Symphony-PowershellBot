function Start-SymphonyProcessorAsync
{
    param([psobject]$MessageObj, [string]$ScriptPath)

    $outer = {
        [cmdletbinding()]
        param([hashtable] $Options)

        $global:DebugPreference = "Continue"

        $scriptDir = $Options.ModulePath

        $messageDetail = $Options.MessageObj

        #Adding individual import statements to ensure the module code is loaded
        #TODO: switch to an on-use module import structure
        Import-Module "$scriptDir/ConfigLoader.psm1" -Force
        Import-Module "$scriptDir/Symphony.psm1" -Force #-Verbose 
        Import-Module "$scriptDir/Parsing.psm1" -Force
        Import-Module "$scriptDir/Logging.psm1" -Force
        Import-Module "$scriptDir/Processing.psm1" -Force
        Import-Module "$scriptDir/JIRA.psm1" -Force
        Import-Module "$scriptDir/CommandInterpreter.psm1" -Force
        Import-Module "$scriptDir/CommandDefinitions.psm1" -Force

        $global:ConfigData = Get-ConfigData $scriptDir
        #Re-init Symphony settings. There's a better way to do this
        Initialize-BotVariables

        #I don't think I need to use the Execute operator (&) here 
        & Start-SymphonyProcessor $messageDetail
    }

    $jobOptions = @{
        ModulePath = $ScriptPath
        MessageObj = $MessageObj
    }

    Write-Host "Script directory: $ScriptPath"

    $fdt = Get-Date -Format FileDateTimeUniversal
    $jobParams = @{
        Name = "processor_$fdt"
        ScriptBlock = $outer
        ArgumentList = $jobOptions
    }

    $myJob = Start-Job @jobParams

    $myJob
}