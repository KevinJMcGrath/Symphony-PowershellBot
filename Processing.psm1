function Start-SymphonyProcessor
{
    param([psobject]$messageDetail)

    #Add-LogEntry -source "Activity" -message "Job Started" -addlParams @($messageDetail.message)
    #Add-LogEntry -source "Activity" -message "Is Command?" -addlParams @($messageDetail.isCommand)

    $hashtags = Get-HashtagArray $messageDetail.message
    $cashtags = Get-CashtagArray $messageDetail.message
    $users = Get-UserHashtable $messageDetail.message    

    $messageObj = New-Object PSObject -Property @{
        hashtags = $hashtags
        cashtags = $cashtags
        users = $users
        originalMessage = $messageDetail
        formattedMessage = ""
    }

    if(-not $messageDetail.isCommand)
    {
        Start-HashtagProcessing -ProcessedMessage $messageObj
        #Start-CashtagProcessing -ProcessedMessage $messageObj
    }
    else
    {
        Start-CommandProcessing -ProcessedMessage $messageObj
    }
}

function Start-HashtagProcessing
{
    param([psobject]$ProcessedMessage)

    #Add-LogEntry -source "Activity" -message "Processing Hashtags" -addlParams $ProcessedMessage.hashtags

    #Example of how to parse the hashtags for a message and if a valid hashtag is found, 
    #send the message to a JIRA issue
    if(Get-ContainsValidHashtag $ProcessedMessage.hashtags)
    {
        Send-SimpleJIRAIssue -ProcessedMessage $ProcessedMessage -ReplyToRoom $true -ReplyToSender $true
    }

}

function Start-CashtagProcessing
{
    param([psobject]$ProcessedMessage)

}

function Start-CommandProcessing
{
    param([psobject]$ProcessedMessage)

    Execute-SymphonyCommand -ProcessedMessage $ProcessedMessage

}