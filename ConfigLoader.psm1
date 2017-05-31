function Get-ConfigData
{
    param([string]$ScriptRunningPath)
        
    Get-Content "$ScriptRunningPath\config.json" | ConvertFrom-Json    
    
}