# Symphony-PowershellBot
A model bot built in Powershell demonstrating monitoring of a Symphony datafeed. Includes examples of monitoring messages for hashtags and slash commands.


## Requirements

This bot was built in Powershell. It was designed to run on a Windows-based OS. The script requires:

* Powershell v5 or greater
* A user with Powershell scripting experience
* .NET v4.5
* A Symphony bot user with local client Certificate and password
* Your Symphony POD's Authentication and Agent endpoints and ports

## Installation

To install the bot:

1. Ensure Powershell is installed on the client or server that will host the bot
1. Make sure the host's Powershell security settings allow scripts to be run
    1. Run Powershell or Powershell ISE as an Adminstrator
    1. Execute the following cmdlet at the prompt: `Set-ExecutionPolicy RemoteSigned`
    1. Follow the prompts
1. Download the zip or clone the repository locally
1. Edit config.json

```JSON
{
    "botinfo": {
        "botEmail": "bot.user@symphony.com",
        "certificatePath": "C:\\Github\\Symphony-PowershellBot\\Certificate\\bot.user.p12",
        "certificatePassword": "myB0tP4ssw0rd!"
    },
    "symphonyinfo": {
        "authenticationHost": "https://mycompany-api.symphony.com",
        "authenticationPort": "8444",
        "apiHost": "https://mycompany.symphony.com",
        "apiPort": "443"
    },
    "loggingPath": "C:\\Github\\Symphony-PowershellBot\\Logging",
    "modules": [
        {
            "name": "jira",
            "enabled": true,
            "username": "bob.smith",  
            "password": "jiraP4ssw0rd!",
            "baseURL": "https://mycompany.atlassian.net"
        }
    ]    
}
```

## Caveats and Provisos

1. Be sure to check all values in config.json and replace any temporary placeholders with actual values.
1. If adding a new integration module, follow the example shown in JIRA.psm1. 
    1. Be sure to add a new entry under the "modules" section of config.json if you wish to use the ConfigLoader
    1. Import new modules for processing by adding an `Import-Module` statement to AsyncJobs.psm1. E.g.: `Import-Module "$scriptDir/MyModule.psm1" -Force`
    1. If the new module is actioned by checking for hashtags or cashtags, check Processing.psm1 for examples (E.g. `Send-SimpleJIRAIssue`)
    1. If the new nodule is actioned by slash command, check CommandInterpreter.psm1 for examples (E.g. Invoke-GoogleTranslate)
    1. Add an Activity Log statement while debugging async modules: `Add-LogEntry -source "Activity" -message "My New Command" -addlParams @('watchedValue-1','watchedValue-2',...,'watchedValue-n')`
1. The bot will attempt to re-authenticate on error a few times before giving up (to avoid spamming the endpoints). It may be useful to add monitoring to the script or an email function for notification if the script is running on a "headless" instance.


##TODO

1. Refactor AsyncJobs.psm1 to only import the module relevant to the command being executed
1. Add Email module for notifications
1. Refactor Integration modules to tighten up loading of config.json settings
1. Add module examples for other systems: Salesforce, Netsuite, Trello, Pushbullet
1. Add more slash command examples
1. Re-organize module files 
1. Add message queueing to account for high-traffic rooms
1. Add module help
1. Add status commands