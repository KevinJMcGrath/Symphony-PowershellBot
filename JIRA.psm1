#$jiraHost = "https://perzoinc.atlassian.net"
#$jiraAPIURL = "$jiraHost/rest/api/2"
#$jiraIssueURL = "$jiraHost/browse"

function Send-SimpleJIRAIssue
{
    param([psobject]$ProcessedMessage,
        [Parameter(Mandatory=$false)][bool]$ReplyToRoom = $false,
        [Parameter(Mandatory=$false)][bool]$ReplyToSender = $false
    )
    
    try
    {
        Write-Debug "Sending Simple JIRA Issue..."

        $ProcessedMessage.formattedMessage = ConvertFrom-SymphonyMarkup -MessageML $ProcessedMessage.originalMessage.message -ConvertToType JIRA -userList $ProcessedMessage.users
        
        $jiraResponse = Add-DefaultJIRAIssue -ProcessedMessage $ProcessedMessage

        if($jiraResponse.success)
        {
            $reply = Format-SymphonyMessage "JIRA URL: $(Format-SymphonyLink $jiraResponse.issueURL)"

            #Add-LogEntry -source "Activity" -message "JIRA sent" -addlParams @($reply, "Is room? $($ProcessedMessage.originalMessage.room.isRoom)", 
            #    "Room Id: $($ProcessedMessage.originalMessage.room.id)", "User Id: $($ProcessedMessage.originalMessage.fromUser)")
                        
            #Send reply to the room the submission was sent from
            if($ReplyToRoom -and $ProcessedMessage.originalMessage.room.isRoom)
            {                            
                Send-SymphonyMessage -streamId $ProcessedMessage.originalMessage.room.id -message $reply
            }
                        
            #Send reply to the user who sent the message
            if($ReplyToSender)
            {
                Send-SymphonyIM -userId $ProcessedMessage.originalMessage.fromUser -message $reply
            }

        }
        

    }
    catch [System.Net.WebException]
    {
        $params = @(
            "Exception: $($_.Exception.Message)"
            "Server Response: $($_)"
            "Stack Trace: $($Error[0].ScriptStackTrace)"
        )

        Add-LogEntry -source "Symphony" -message "Tracing Web Exception" -addlParams $params

        Write-Debug "$(Get-Date) - Symphony Web Exception Logged"

        $retVal.response = $_
        $retVal.success = $false
    }
    catch
    {
        Add-LogEntry -source "Symphony" -message "Tracing Exception" -addlParams @($_, "Stack Trace: $($Error[0].ScriptStackTrace)")

        Write-Debug "$(Get-Date) - Symphony General Exception Logged"

        $retVal.response = $_.Exception.Message
        $retVal.success = $false
    }

    

        

}

#Use this function to simply add the contents of any message to a 
#pre-definied JIRA project/issuetype/priority/etc. 
function Add-DefaultJIRAIssue
{
    param([Parameter(Mandatory=$true)][psobject]$ProcessedMessage)

    $message = $ProcessedMessage.formattedMessage
    $hashtags = $ProcessedMessage.hashtags

    #Default parameters - these must all be represented to ensure the required JIRA fields are completed.
    $project = "SOPS"
    $issueType = "Task"
    $priority = "Minor"

    #IMPORTANT - JIRA only seems to accept JIRA usernames for user fields - you cannot specify email
    #Set the default reporter to be an automation user
    $reporter = "kevin.mcgrath"

    #Use the first 50 characters of the message to populate the summary
    $summary = $message

    if ($message.Length -gt 50)
    {
        $summary = $message.Substring(0, 50)
    }
    
    
    #IMPORTANT - JIRA is prickly about what characters it will accept through the API. 
    #The powershell Cmdlet ConvertTo-JSON should escape the messages properly. If 
    #transcribing these scripts to another language, be sure to account for character escaping
    #for any text fields. 

    #IMPORTANT - JIRA's field names are case sensitive. Sending "issueType" will fail with a 404
    #but not indicate the problem is the naming of the field. Change to "issuetype" and the submission
    #will succeed.
    $description = $message

    #IMPORTANT - JIRA will throw an unhelpful (400) Bad Request error if any of these parameters
    #are formatted incorrectly. Special note is made of the "labels" section. This MUST be 
    #an array (e.g. ["item1","item2",...]), even if there is only one element. 
    #I force this by using the @() notation.
    $issue = @{
        fields = @{
            project = @{ key = $project }
            issuetype = @{ name = $issueType }
            priority = @{ name = $priority }
            reporter = @{ name = $reporter }
            summary = $summary
            description = $description
            labels = @($hashtags)
        }        
    }

    Send-SingleJIRAIssue $issue

}

function Send-SingleJIRAIssue
{
    param([psobject]$jiraIssue)

    Initialize-JIRAConfig

    $jiraCreateIssueEP = "$jiraAPIURL/issue/"

    $headers = Get-JIRAAuthorizationHeader

    #We need to specify "-Depth 4" here to force the Cmdlet to traverse the JSON fully
    $jiraJSON = $jiraIssue | ConvertTo-Json -Depth 4

    $retVal = @{
        success = $false
        response = $null
        issueURL = $jiraHost
    }

    try
    {
        $response = Invoke-RestMethod $jiraCreateIssueEP -Method POST -Headers $headers -Body $jiraJSON

        $retVal.success = $true
        $retVal.response = $response

        $retVal.issueURL = "$jiraIssueURL/$($response.key)"
    }
    catch [System.Net.WebException]
    {
        $params = @(
            "Exception: $($_.Exception.Message)"
            "Server Response: $($_)"            
            "Stack Trace: $($Error[0].ScriptStackTrace)"            
        )

        Add-LogEntry -source "JIRA" -message "Web Exception" -addlParams $params
        Add-LogEntry -source "JIRA" -message "Submitted JSON" -addlParams @($jiraCreateIssueEP, $jiraJSON)

        Write-Debug "$(Get-Date) - JIRA Web Exception Logged"

        $retVal.response = $_
        $retVal.success = $false
    }
    catch
    {
        Add-LogEntry -source "JIRA" -message "Exception" -addlParams @($_, "Stack Trace: $($Error[0].ScriptStackTrace)")

        Write-Debug "$(Get-Date) - JIRA General Exception Logged"

        $retVal.response = $_.Exception.Message
        $retVal.success = $false
    }

    $retVal
}

function Get-JIRAAuthorizationHeader
{
    #Prepare creds for REST call
    $jiraConfigObj = $global:ConfigData.modules | Where-Object { $_.name -eq "jira" }

    $credPair = "$($jiraConfigObj.username):$($jiraConfigObj.password)"
    $encodeCred = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))

    $basicAuthValue = "Basic $encodeCred"

    $headers = @{
        Authorization = $basicAuthValue
        "Content-Type" = "application/json"
    }

    $headers
}

function Initialize-JIRAConfig
{

    if($script:jiraHost -eq $null)
    {
        $jiraConfigObj = $global:ConfigData.modules | Where-Object { $_.name -eq "jira" }
        $script:jiraHost = $jiraConfigObj.baseURL
        $script:jiraAPIURL = "$script:jiraHost/rest/api/2"
        $script:jiraIssueURL = "$script:jiraHost/browse"
    }
}