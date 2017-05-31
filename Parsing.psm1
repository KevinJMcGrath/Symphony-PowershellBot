function Get-IsValidUser
{
    param([psobject]$user)

    #Fill this variable with a CSV list of email addresses to serve as a whitelist. 
    $whitelist = @( )
        
    $isValid = $false

    if($whitelist.Count -gt 0)
    {
        if($user -ne $null)
        {
            if($user.email -ne $null)
            {
                $isValid = ($whitelist -contains $user.email)
            }
        }
    }
    else
    {
        #If the whitelist is empty, permit all users
        $isValid = $true
    }

    $isValid
}

function ConvertFrom-SymphonyMarkup
{
    param([string]$MessageML, 
        [ValidateSet('JIRA','Text')][string]$ConvertToType,
        [Parameter(Mandatory=$false)][array]$userList
    )

    #Add-LogEntry -source "Activity" -message "Starting message formatting" -addlParams @($MessageML)

    $xml = [xml]$messageML

    $outputText = (Select-Xml -Content $MessageML -XPath "//messageML").ToString()
    $newline = " `n "

    if ($ConvertToType -eq "JIRA")
    {
        $newline = " \n "
    }

    if ($xml.FirstChild.Name -eq "messageML")
    {
        foreach($node in $xml.FirstChild.ChildNodes)
        {
            $replaceText = ''

            switch($node.Name)
            {
                b { $replaceText = " *$($node.InnerText)* "; break }
                i { $replaceText = " _$($node.InnerText)_ "; break }
                a { $replaceText = " $($node.Attributes[0].Value) "; break }
                hash { $replaceText = " #$($node.Attributes[0].Value) "; break }
                cash { $replaceText = " `$$($node.Attributes[0].Value) "; break }
                mention { 
                    if ($userList -ne $null -and $userList.Count -gt 0)
                    {
                        $uid = $node.Attributes[0].Value

                        if($userList.ContainsKey($uid))
                        {
                            $user = $userList.$uid
                            
                            $replaceText = " @$($user.Name) "
                        }
                        else
                        {
                            $replaceText = " @$uid "
                        }
                    }
                    
                    break 
                }
                chime { $replaceText = " *chime* "; break }
                br { $replaceText = $newline; break }
                ol { 
                    $replaceText = $newline

                    foreach($listNode in $node.ChildNodes)
                    {
                        $replaceText += "# $($listNode.InnerText) $newline"
                    }

                    break;
                }
                ul { 
                    $replaceText = $newline

                    foreach($listNode in $node.ChildNodes)
                    {
                        $replaceText += "* $($listNode.InnerText) $newline"
                    }

                    break;
                }
                table {
                    $replaceText = $newline

                    $rowIndex = 0
                    foreach($rowNode in $node.ChildNodes)
                    {
                        if ($rowIndex -eq 0)
                        {
                            $delimiter = "||"
                        }
                        else
                        {
                            $delimiter = "|"
                        }

                        $replaceText += $delimiter

                        foreach($cellNode in $rowNode.ChildNodes)
                        {
                            $replaceText += "$($cellNode.InnerText)$delimiter"
                        }

                        $replaceText += $newline

                        $rowIndex++
                    }

                    break;
                }
                default {
                     $replaceText = " $($node.InnerText) "; break }
            }
                        
            $outputText = $outputText -replace $node.OuterXml, $replaceText
        }
    }

    #Add-LogEntry -source "Activity" -message "Finished parsing tags for replacement" -addlParams @($outputText)

    #Replace multiple spaces with a single space
    $outputText = $outputText -replace '\s+', ' '

    #Replace invalid characters in the message
    if($ConvertToType -eq 'JIRA')
    {
        #This regex specifies a range of characters that are considered "control"
        #https://jira.atlassian.com/browse/CWD-160?page=com.atlassian.streams.streams-jira-plugin%3Aactivity-stream-issue-tab
        $outputText = $outputText -replace '[\x7E-\xA0]', ''   
    }

    #Add-LogEntry -source "Activity" -message "Finished parsing message" -addlParams @($outputText)

    $outputText

}


function Get-HashtagArray
{
    param($messageML)    

    $tagList = @()

    $hashtags = Select-Xml -Content $messageML -XPath "//hash"
    
    $tagList = $hashtags | ForEach-Object { "#$($_.Node.tag.Trim())" }

    $tagList
}

function Get-CashtagArray
{
    param($messageML)    

    $tagList = @()

    $hashtags = Select-Xml -Content $messageML -XPath "//cash"
    
    $tagList = $hashtags | ForEach-Object { "#$($_.Node.tag.Trim())" }

    $tagList
}

function Get-UserHashtable
{
    param($messageML)

    $userList = @{}

    $mentions = Select-Xml -Content $messageML -XPath "//mention"

    $mentions | ForEach-Object { 

        $key = $_.Node.uid

        if(-not $userList.ContainsKey($key))
        {
            $userList.Add( $key, (QueryUser -userId $key))
        }
    }

    $userList
}

#One could use this function to determine if a hashtag is valid for a given system
#and then process the message differently given the input hashtags.
#Take care to understand what would happen if a message contained tags for multiple 
#paths. 
function Get-ContainsValidHashtag
{
    param([array]$hashtags)

    $htWhitelist = @("bug","bugs","defect","defects","problem","problems","feature","features", "newfeaturerequest",
        "featurerequest","feature_request","newfeature","new_feature","missing","needed","required",
        "usability","useability","performance","unstable","awkward","feedback"        
    )
    
    $isValid = $false
    
    #if we find at least one hashtag in the post that matches the whitelist, return true
    if ($hashtags -ne $null -and $hashtags.Count -gt 0)
    {
        foreach($ht in $hashtags)
        {
            $tag =  $ht.tolower() -replace '#', ''
            if ($htWhitelist -contains $tag)
            {
                $isValid = $true
                return $isValid
            }
        }
    }

    $isValid
}

function Get-InputSecurityCheck
{
    param([string]$input)

    #Apparently the AntiXss class was removed from .NET 5 >(
    $output = $input #[System.Web.AntiXss.AntiXssEncoder]::UrlEncode($input)

    $isValid = ($output | Select-String "<script>") -eq $null

    $isValid
}