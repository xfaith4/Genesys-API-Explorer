### BEGIN FILE: Private\Add-TimelineEvent.ps1
function Add-TimelineEvent {
        param(
            [Parameter(Mandatory = $true)]
            [datetime]$StartTime,

            [Parameter(Mandatory = $false)]
            [datetime]$EndTime,

            [Parameter(Mandatory = $true)]
            [string]$Source,

            [Parameter(Mandatory = $true)]
            [string]$EventType,

            [Parameter(Mandatory = $false)]
            [string]$Participant,

            [Parameter(Mandatory = $false)]
            [string]$Queue,

            [Parameter(Mandatory = $false)]
            [string]$User,

            [Parameter(Mandatory = $false)]
            [string]$Direction,

            [Parameter(Mandatory = $false)]
            [string]$DisconnectType,

            [Parameter(Mandatory = $false)]
            [hashtable]$Extra
        )

        $events.Add([pscustomobject]@{
            ConversationId = $ConversationId
            StartTime      = $StartTime
            EndTime        = $EndTime
            Source         = $Source
            EventType      = $EventType
            Participant    = $Participant
            Queue          = $Queue
            User           = $User
            Direction      = $Direction
            DisconnectType = $DisconnectType
            Extra          = $Extra
        }) | Out-Null
    }
### END FILE: Private\Add-TimelineEvent.ps1
