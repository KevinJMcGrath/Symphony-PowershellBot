#region BotSession Class Definition
class BotSession 
{
    [string] $SessionToken
    [string] $KeyManagerToken
    [string] $DataFeedId
    [string] $BotUserId
    [datetime] $SessionExpirationDate

    #Constructor
    BotSession([string]$sessToken, [string]$kmToken) 
    {
        $this.SessionToken = $sessToken
        $this.KeyManagerToken = $kmToken
        $this.DataFeedId = ''
        $this.BotUserId = ''

        #Sessions last a week
        $this.SessionExpirationDate = (Get-Date).AddMinutes(7*24*60) 
    }

    [bool] IsValidSession()
    {
        return ($this.SessionToken -ne '' -and $this.SessionExpirationDate -ge (Get-Date))
    }

    [hashtable] GetAPIHeaders()
    {
        return @{ 
            sessionToken = $this.SessionToken
            keyManagerToken = $this.KeyManagerToken
        }
    }

}

#endregion

#region Varible Definitions

$global:botSession = $null

#endregion

#region Authentication Function

function Initialize-BotVariables
{
    if($script:botUserEmail -eq $null) { $script:botUserEmail = $global:ConfigData.botinfo.botEmail }
    if($script:certificatePassword -eq $null) { $script:certificatePassword = $global:ConfigData.botinfo.certificatePassword }
    if($script:certPath -eq $null) { $script:certPath = $global:ConfigData.botinfo.certificatePath } 

    if($script:authHost -eq $null) { $script:authHost = $global:ConfigData.symphonyinfo.authenticationHost }
    if($script:authPort -eq $null) { $script:authPort = $global:ConfigData.symphonyinfo.authenticationPort }
    if($script:apiHost -eq $null) { $script:apiHost = $global:ConfigData.symphonyinfo.apiHost }
    if($script:apiPort -eq $null) { $script:apiPort = $global:ConfigData.symphonyinfo.apiPort }

    $script:symHostAuthentication = "$($authHost):$authPort"
    $script:symHostAPI = "$($apiHost):$apiPort"

    $script:cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $script:cert.Import($script:certPath, $script:certificatePassword, 'DefaultKeySet')
}

function Get-BotUserAuth
{
    $authValid = $false

    Initialize-BotVariables

    try
    {
        if($global:botSession -eq $null -or -not $global:botSession.IsValidSession())
        {
            $sessionEP = "$symHostAuthentication/sessionauth/v1/authenticate"
            $kmEP = "$symHostAuthentication/keyauth/v1/authenticate"

            Write-Debug "Authenticating..."
    
            $response = Invoke-RestMethod $sessionEP -Method POST -ContentType 'application/json' -Certificate $cert
            $sessionToken = $response.token

            Write-Debug "Session token obtained."

            $response = Invoke-RestMethod $kmEP -Method POST -ContentType 'application/json' -Certificate $cert
            $kmToken = $response.token

            Write-Debug "Key Manager token obtained."
    
            $global:botSession = [BotSession]::new($sessionToken, $kmToken)
        }

        $authValid = $true
    }
    catch [System.Net.WebException]
    {
        $params = @(
            "Exception: $($_.Exception.Message)"
            "Server Response: $($_)"
            "Stack Trace: $($Error[0].ScriptStackTrace)"
        )

        Add-LogEntry -source "Symphony" -message "Web Exception" -addlParams $params

        Write-Debug "$(Get-Date) - Symphony Auth Exception Logged"

        $authValid = $false
    }
    catch
    {
        Add-LogEntry -source "Symphony" -message "Exception" -addlParams @($_, "Stack Trace: $($Error[0].ScriptStackTrace)")

        Write-Debug "$(Get-Date) - Symphony General Auth Exception Logged"

        $authValid = $false
    }

    $authValid
}

#endregion

#region Metadata Functions

function Get-IsBotUserId
{
    param([string]$userId)

    if ($userId -eq $global:botSession.BotUserId) { $true } else { $false }
}

function Get-BotUserId
{
    $userId = Get-SymphonyUserId -email $botUserEmail

    Write-Debug "User Id: $userId"

    $global:botSession.BotUserId = $userId

    $userId
}

function Get-SymphonyUserId
{
    param([string]$email)    

    $userIdEP = "$symHostAPI/pod/v1/user?email=$botUserEmail"
    
    $resp = Send-APIRequest -endpoint $userIdEP -method "GET"
    $userId = $resp.response.id

    $userId
}

function QueryUser
{
    param([string]$userId)

    $user = New-Object PSObject -Property @{
        "id" = "-1"
        "firstName" = "Susan"
        "lastName" = "Walters-Nobody"
        "email" = "swn@symphony.com"
        "name" = "Susan Walters-Nobody"
        "company" = "Symphony" }
    

    if ($userId -ne $null -and $userId -ne '')
    {
    
        $userQEP = "$symHostAPI/pod/v2/user?uid=$userId&local=true"

        $resp = Send-APIRequest $userQEP -method "GET"
        $response = $resp.response

        $user = New-Object PSObject -Property @{
            "id" = $response.id
            "firstName" = $response.firstName
            "lastName" = $response.lastName
            "email" = $response.emailAddress
            "name" = $response.displayName 
            "company" = $response.company 
        }
    }

    $user
}

function QueryStream
{
    param([string]$streamId)

    $room = New-Object PSObject -Property @{
        "id" = $streamId
        "name" = "1:1 or MIM"
        "desc" = ""
        "isRoom" = $false }

    try
    {
        $streamQEP = "$symHostAPI/pod/v2/room/$streamId/info"

        #$resp = Send-APIRequest $streamQEP -method "GET"
        $response = Invoke-RestMethod $streamQEP -Method GET -ContentType 'application/json' -Certificate $cert -Headers $global:botSession.GetAPIHeaders()         

        $room = New-Object PSObject -Property @{
            "id" = $streamId
            "name" = $response.roomAttributes.name
            "desc" = $response.roomAttributes.description 
            "isRoom" = $true }
    }
    catch
    {
        #the Stream Info api throws a 400 code if the stream isn't a room. This is super dumb
        #Write-Debug "Room parse didn't work, probably a 1:1"
    }

    $room
}

#endregion

#region Send Message Functions

function Send-SymphonyIM
{
    param([string]$userId, [string]$message)

    Add-LogEntry -source "Activity" -message "Sending IM" -addlParams @($userId, $message)
    
    if($userId -ne $null)
    {
        #Add-LogEntry -source "Activity" -message "Opening IM" -addlParams @($userId)

        $imId = Open-SymphonyIM -userId $userId   
        
        #Add-LogEntry -source "Activity" -message "IM Open" -addlParams @($imId)     

        if ($imId -ne $null)
        {
            Send-SymphonyMessage -streamId $imId -message $message
        }
    }
}

function Open-SymphonyIM
{
    param ([string]$userId)

    $createIMEP = "$symHostAPI/pod/v1/im/create"

    $msgBody = "[$userId]"
    
    #Add-LogEntry -source "Activity" -message "Opening IM" -addlParams @($userId, $createIMEP, $msgBody)

    $resp = Send-APIRequest -endpoint $createIMEP -method "POST" -bodyJSON $msgBody

    $resp.response.id
}

function Send-SymphonyMessage
{
    param
    (        
        [string]$streamId,
        [string]$message        
    )

    if (-not $message.StartsWith("<messageML>"))
    {
        $message = Format-SymphonyMessage $message
    }

    $roomEP = "$symHostAPI/agent/v2/stream/$streamId/message/create"

    $msgBody = @{}
    $msgBody.Add("message", $message)
    $msgBody.Add("format", "MESSAGEML")

    $msgBodyJSON = $msgBody | ConvertTo-Json    

    #Add-LogEntry -source "Activity" -message "Sending Sym Message" -addlParams @($streamId, $message, $msgBodyJSON)

    $resp = Send-APIRequest -endpoint $roomEP -method "POST" -bodyJSON $msgBodyJSON
}

#endregion

#region DataFeed Functions

function Initialize-DataFeed
{
    $initValid = $false

    if (Get-BotUserAuth)
    {
        if (Get-BotUserId -ne '')
        {
            $createDataFeedEP = "$symHostAPI/agent/v1/datafeed/create"    
    
            $resp = Send-APIRequest -endpoint $createDataFeedEP -method "POST"   
            
            if ($resp.success)
            { 
    
                $dataFeedId = $resp.response.id

                Write-Debug "Creating DataFeed: $dataFeedId"

                $global:botSession.DataFeedId = $dataFeedId

                $initValid = $true
            }
        }
    }

    $initValid
}

function Read-DataFeed
{

    $dataFeedId = $botSession.DataFeedId
    $datafeedEP = "$symHostAPI/agent/v2/datafeed/$dataFeedId/read"
    #$response = Invoke-RestMethod $datafeedEP -Method GET -ContentType 'application/json' -Certificate $cert -Headers $botSession.GetAPIHeaders()

    $resp = Send-APIRequest $datafeedEP -method "GET"
    $response = $resp.response

    if($resp.success)
    {
        #Clear the contents of messageDetail so it doesn't resend the item over and over. 
        $messageDetail = $null

        #If stream Id is null, it's probably just an empty ping from the datafeed
        if ($response.streamId -ne $null)
        {
            $user = QueryUser $response.fromUserId
            $room = QueryStream $response.streamId

            $node = Select-Xml -Content $response.message -XPath "//messageML"
            $text = $node.ToString()

            #split the incoming message on whitespace
            $firstToken = ($text -split '\s+')[0].toLower()

            $messageDetail = New-Object PSObject -Property @{
                "messageId" = $response.id
                "fromUser" = [string]$response.fromUserId
                "streamId" = $response.streamId
                "message" = $response.message
                "type" = $response.v2messageType 
                "user" = $user
                "room" = $room
                "attachments" = $response.attachments 
                "command" = '' 
                "isCommand" = $false}

            #Determine if the first token is a slash-command
            if ($firstToken.StartsWith("/"))
            {
                $messageDetail.command = $firstToken
                $messageDetail.isCommand = $true
            }

            $lineOut = "$(Get-Date) - User: $($user.name) ($($messageDetail.fromUser)), Stream: "
            
            if($messageDetail.room.isRoom)
            {
                $lineOut += "$($messageDetail.room.name) "
            }

            $lineOut += "($($messageDetail.streamId))"

            Write-Debug $lineOut
        }

    }
    else { $messageDetail = $false }

    $messageDetail
}

#endregion

#region Utility Functions

function Send-APIRequest
{
    param(
        [Parameter(Mandatory=$true)][string]$endpoint, 
        [Parameter(Mandatory=$true)][string]$method,
        [Parameter(Mandatory=$false)][string]$bodyJSON)

    $retVal = @{
        success = $false
        response = $null
    }

    #IMPORTANT - When attempting to use Powershell in async (Start-Job) the session is completely new. 
    #That means the bot as to re-auth in order to send messages OR I have to send the bot session object
    #to the new session. I should do the later, but for now, I'll stick with the former. 
    Get-BotUserAuth

    <#Add-LogEntry -source "Activity" -message "Sending API Request" -addlParams @($endpoint)
    Add-LogEntry -source "Activity" -message "Sending API Request" -addlParams @($method)
    Add-LogEntry -source "Activity" -message "Sending API Request" -addlParams @($($cert -ne $null))
    Add-LogEntry -source "Activity" -message "Sending API Request" -addlParams @($bodyJSON)
    Add-LogEntry -source "Activity" -message "Sending API Request" -addlParams @($($botSession.GetAPIHeaders() | ConvertTo-Json))#>

    try
    {
        if (-not [string]::IsNullOrEmpty($bodyJSON))
        {            
            $retVal.response = Invoke-RestMethod $endpoint -Method $method -ContentType 'application/json' -Certificate $cert -Headers $global:botSession.GetAPIHeaders() -Body $bodyJSON
        }
        else
        {
            $retVal.response = Invoke-RestMethod $endpoint -Method $method -ContentType 'application/json' -Certificate $cert -Headers $global:botSession.GetAPIHeaders()
        }
        
        
        $retVal.success = $true
    }
    catch [System.Net.WebException]
    {
        $params = @(
            "Exception: $($_.Exception.Message)"
            "Server Response: $($_)"
            "Stack Trace: $($Error[0].ScriptStackTrace)"
        )

        Add-LogEntry -source "Symphony" -message "Web Exception" -addlParams $params

        Write-Debug "$(Get-Date) - Symphony Web Exception Logged"

        $retVal.response = $_
        $retVal.success = $false
    }
    catch
    {
        Add-LogEntry -source "Symphony" -message "Exception" -addlParams @($_, "Stack Trace: $($Error[0].ScriptStackTrace)")

        Write-Debug "$(Get-Date) - Symphony General Exception Logged"

        $retVal.response = $_.Exception.Message
        $retVal.success = $false
    }

    $retVal
}

function Get-IsValidSymphonySession
{
    $isValid = ($global:botSession -ne $null -and $global:botSession.IsValidSession)

    $isValid
}

function Format-SymphonyMessage
{
    param([string]$message)

    $message = "<messageML>$message</messageML>"

    $message
}

function Format-SymphonyLink
{
    param([string]$url)

    $url = "<a href=`"$url`"/>"

    $url
}

#endregion
