function Execute-SymphonyCommand
{
    param([psobject]$ProcessedMessage)

    Add-LogEntry -source "Activity" -message "Executing Command" -addlParams @($ProcessedMessage.originalMessage.command)

    $ProcessedMessage.formattedMessage = ConvertFrom-SymphonyMarkup -MessageML $ProcessedMessage.originalMessage.message -ConvertToType Text

    $cmd = $ProcessedMessage.originalMessage.command
    $params = Get-CommandParams $ProcessedMessage
    $streamId = $ProcessedMessage.originalMessage.streamId

    #Make sure people aren't trying to abuse the bot
    if (Get-InputSecurityCheck $params)
    {
        #Not the most robust way to handle this...makes extensibility hard. But time makes fools of us all
        switch($cmd.ToLower())
        {
            "/echo" { Invoke-SymphonyEcho -StreamId $streamId -EchoMessage $params; break }
            {$_ -in "/tr","/translate"} { Invoke-GoogleTranslate -StreamId $streamId -Message $params; break } #{$_ in ("item1","item2") } to allow 'aliases'
            /spam_me { }
            /quote { }
            /gif { }
            /jira { }
            /help { }
            default { break; }
        }
    }
    else
    {
        Invoke-SymphonyRemonstration -StreamId $streamId -Message $ProcessedMessage.formattedMessage
    }
}

function Get-CommandParams
{
    params([psobject]$ProcessedMessage)

    #TODO: Add more sophisticated tokenizing
    $cmdParams = ($ProcessedMessage.formattedMessage -replace $ProcessedMessage.originalMessage.command, '').Trim()

    $cmdParams
}