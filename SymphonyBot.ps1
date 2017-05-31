$DebugPreference = "Continue"

$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

#Importing Modules imports the code for the session, not just the script. 
#These functions are available to the sub-modules as well
#The -Force paramter forces the script to reload the modules on each run.
#If you're making changes to the modules, include -Force until you're satisfied. 
#Once removed, the modules will stay loaded in memory for the duration of the session. 
#TODO: Add Auto-Module checking
Import-Module "$scriptDir/Symphony.psm1" -Force #-Verbose 
Import-Module "$scriptDir/Parsing.psm1" -Force
Import-Module "$scriptDir/Logging.psm1" -Force
Import-Module "$scriptDir/Processing.psm1" -Force
Import-Module "$scriptDir/JIRA.psm1" -Force
Import-Module "$scriptDir/AsyncJobs.psm1" -Force
Import-Module "$scriptDir/ConfigLoader.psm1" -Force

$global:ConfigData = Get-ConfigData -ScriptRunningPath $scriptDir

$errIndex = 0
$reauthIndex = 0
$loopControl = $true
$initialized = $false
$backgroundJobs = @()

while($loopControl)
{
    if (-not $initialized -or -not (Get-IsValidSymphonySession) ) 
    { 
        #Authenticate the bot, obtain the bot's userId and create the datafeed
        $initialized = Initialize-DataFeed 
    }

    if ($initialized)
    {        
        #This is where we query the datafeed API looking for the latest messages
        $messageDetail = Read-DataFeed

        if ($messageDetail -ne $false)
        {
            $errIndex = 0
            $reauthIndex = 0

            #Check user whitelist
            $isValidUser = Get-IsValidUser $messageDetail.user
            #Ignore messages that the bot sends (preventing loops)
            $isBotUser = Get-IsBotUserId $messageDetail.fromUser

            if($messageDetail.type -eq "V2Message" -and $isValidUser -and -not $isBotUser)
            {
                #sync start message processing
                #Start-SymphonyProcessor $messageDetail

                #async start message processing

                #Allow for the possibility to store the job object in a collection to pass to Receive-Job 
                #if the jobs have data that needs to be returned to the console. For the moment, I'm 
                #not bothering, since I'm not returning data to the bot itself.
                #$backgroundJobs += Start-SymphonyProcessorAsync -MessageDetail $messageDetail

                $asyncJob = Start-SymphonyProcessorAsync -MessageObj $messageDetail

            }
        }
        else
        {
            #Attempting to handle error looping gracefully. This should attempt to poll the datafeed 10 times before giving 
            #up and doing a re-authentication. If re-auth fails 3 times, give up and kill the loop
            $errIndex++

            if ($errIndex -lt 5)
            {
                Write-Debug "Error obtaining datafeed. Will retry in 5 seconds. (Attempt $errIndex)"
                sleep -Seconds 5
            }
            elseif ($reauthIndex -lt 3)
            {
                Write-Debug "Could not re-establish connection with DataFeed. Attempting re-authentication."
                $initialized = $false
                $reauthIndex++                
            }
            else
            {
                Write-Debug "Communication could not be established with Symphony. Halting script."
                $loopControl = $false
            }
        }
    }
    else
    {
        <#If any of the initialization procedure fails, there's probably an issue with the API,
            so we halt the execution of the script.
        #>
        Write-Debug "Authentication procedure failed. Halting script."
        $loopControl = $false
    }

    #Remove jobs that are no longer running
    Get-Job | Where-Object { $_.State -inotin ("NotStarted", "Running")} | Remove-Job
}