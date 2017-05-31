function Invoke-SymphonyRemonstration
{
    param([string]$StreamId, [string]$Message)

    $msg = "I detected an attempt to inject a script block into a command paramter. Please don't do that."
    $reply = Format-SymphonyMessage $msg

    Add-LogEntry -source "Activity" -message "Script Injection Detected" -addlParams @($StreamId, $Message)

    Send-SymphonyMessage -streamId $StreamId -message $reply
}

function Invoke-SymphonyEcho
{
    param([string]$StreamId, [string]$EchoMessage)

    Write-Debug "Invoking echo: $EchoMessage"

    Add-LogEntry -source "Activity" -message "Sending Echo" -addlParams @($StreamId, $EchoMessage, $reply)

    Send-SymphonyMessage -streamId $StreamId -message $EchoMessage
}

function Invoke-GoogleTranslate
{
    param([string]$StreamId, [string]$Message)

    try
    {
        Write-Debug "Invoking Google Translate..."

        $tParam = [System.Net.WebUtility]::UrlEncode($Message) 
        $transEP = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=en&dt=t&q=$tParam"    

        $transResp = Invoke-RestMethod $transEP -Method Get     
    
        $translation = $transResp[0][0][0]
        $languageCode = $transResp[2]

        Add-LogEntry -source "Activity" -message "Sending Translation" -addlParams @($StreamId, $Message, $translation, $languageCode)

        $reply = "I think you said: $translation ($languageCode)"
    
        Send-SymphonyMessage -streamId $StreamId -message $reply
    }
    catch [System.Net.WebException]
    {
        $params = @(
            "StreamId: $StreamId"
            "SourceMessage: $Message"
            "Exception: $($_.Exception.Message)"
            "Server Response: $($_)"
        )

        Add-LogEntry -source "Commands" -message "Web Exception" -addlParams $params
    }
    catch
    {
        Add-LogEntry -source "Commands" -message "Exception" -addlParams @($_.Exception.Message)
    }
}

#IMPORTANT - Yahoo broke their finance webservice. This function will no longer work
function Invoke-YahooQuote
{
    param([string]$StreamId, [string]$Symbol)

    $ua = "Mozilla/5.0 (Linux; Android 6.0.1; MotoG3 Build/MPI24.107-55) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.81 Mobile Safari/537.36"

    $headers = @{}
    $headers.Add("User-Agent", $ua)

    $yahooEP = "http://finance.yahoo.com/webservice/v1/symbols/$symbol/quote?format=json"

    $quote = @{}

    try
    {

        $response = Invoke-WebRequest -Uri $yahooEP -Method GET -Headers $headers | ConvertFrom-Json    

        if ($response.list.meta.count -gt 0)
        {
            $obj = $response.list.resources[0].resource.fields
            $quote.Add("Name", $obj.name)
            $quote.Add("Price", $obj.price)
            $quote.Add("message", "success")
        }

    }
    catch [System.Net.WebException]
    {
        $params = @(
            "StreamId: $StreamId"
            "SourceMessage: $Symbol"
            "Exception: $($_.Exception.Message)"
            "Server Response: $($_)"
        )

        Add-LogEntry -source "Commands" -message "Web Exception" -addlParams $params
    }
    catch
    {
        Add-LogEntry -source "Commands" -message "Exception" -addlParams @($_.Exception.Message)
    }
}