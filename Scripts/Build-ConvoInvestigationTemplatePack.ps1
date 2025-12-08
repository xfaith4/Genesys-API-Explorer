### BEGIN FILE: Build-ConvoInvestigationTemplatePack.ps1
[CmdletBinding()]
param(
    # Where to write the curated pack that will be merged with the big generated file
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\GenesysApiTemplates.ConversationInvestigation.curated.json"
)

# Always capture a fixed Created timestamp for this run so the templates are consistent
$created = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

# Use a strongly-typed list for better performance and clarity
$templates = [System.Collections.Generic.List[object]]::new()

# Helper to add a template with minimal repetition
function Add-Template {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Group,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters
    )

    if (-not $Parameters) {
        $Parameters = [ordered]@{}
    }

    $template = [ordered]@{
        Name       = $Name
        Method     = $Method.ToUpperInvariant()
        Path       = $Path
        Group      = $Group
        Parameters = $Parameters
        Created    = $created
    }

    [void]$templates.Add($template)
}

# ----------------------------------------------------------
# Core conversation and analytics endpoints (your list)
# ----------------------------------------------------------

# 1) Raw conversation object
Add-Template -Name  'Get Conversation (Core)' `
             -Method 'GET' `
             -Path   '/api/v2/conversations/{conversationId}' `
             -Group  'Conversations' `
             -Parameters ([ordered]@{
                 conversationId = 'conversation-id-goes-here'
             })

# 2) Analytics: multiple conversations by id (synchronous GET)
Add-Template -Name  'Analytics - Conversations Details (Multiple IDs)' `
             -Method 'GET' `
             -Path   '/api/v2/analytics/conversations/details' `
             -Group  'Analytics' `
             -Parameters ([ordered]@{
                 # Expect your HTTP client to treat this as a query parameter
                 # e.g. ?id=conv-id-1&id=conv-id-2
                 id = 'conversation-id-1,conversation-id-2'
             })

# 3) Analytics: conversation details sync query (Queue + Interval)
$detailsSyncBody = @"
{
  "interval": "2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z",
  "order": "asc",
  "orderBy": "conversationStart",
  "paging": {
    "pageSize": 100,
    "pageNumber": 1
  },
  "segmentFilters": [],
  "conversationFilters": [
    {
      "type": "or",
      "predicates": [
        {
          "dimension": "queueId",
          "value": "queue-id-goes-here"
        }
      ]
    }
  ]
}
"@

Add-Template -Name  'Analytics - Conversation Details Sync (By Queue + Interval)' `
             -Method 'POST' `
             -Path   '/api/v2/analytics/conversations/details/query' `
             -Group  'Analytics' `
             -Parameters ([ordered]@{
                 body = $detailsSyncBody
             })

# 4) Analytics: conversation details async job (Queue + Interval)
$detailsJobBody = @"
{
  "interval": "2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z",
  "order": "asc",
  "orderBy": "conversationStart",
  "paging": {
    "pageSize": 100,
    "pageNumber": 1
  },
  "segmentFilters": [],
  "conversationFilters": [
    {
      "type": "or",
      "predicates": [
        {
          "dimension": "queueId",
          "value": "queue-id-goes-here"
        }
      ]
    }
  ]
}
"@

Add-Template -Name  'Analytics - Conversation Details Job (Create)' `
             -Method 'POST' `
             -Path   '/api/v2/analytics/conversations/details/jobs' `
             -Group  'Analytics' `
             -Parameters ([ordered]@{
                 body = $detailsJobBody
             })

# 5) Analytics: async job status
Add-Template -Name  'Analytics - Conversation Details Job (Status)' `
             -Method 'GET' `
             -Path   '/api/v2/analytics/conversations/details/jobs/{jobId}' `
             -Group  'Analytics' `
             -Parameters ([ordered]@{
                 jobId = 'job-id-goes-here'
             })

# 6) Analytics: async job results page
Add-Template -Name  'Analytics - Conversation Details Job (Results Page)' `
             -Method 'GET' `
             -Path   '/api/v2/analytics/conversations/details/jobs/{jobId}/results' `
             -Group  'Analytics' `
             -Parameters ([ordered]@{
                 jobId = 'job-id-goes-here'
                 # Your HTTP client would likely treat this as query params: pageNumber/pageSize
                 pageNumber = '1'
                 pageSize   = '100'
             })

# 7) Analytics: conversation by id (richer metrics)
Add-Template -Name  'Analytics - Conversation Details (By ID)' `
             -Method 'GET' `
             -Path   '/api/v2/analytics/conversations/{conversationId}/details' `
             -Group  'Analytics' `
             -Parameters ([ordered]@{
                 conversationId = 'conversation-id-goes-here'
             })

# 8) Analytics: aggregates (Queue + Interval)
$aggregatesBody = @"
{
  "interval": "2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z",
  "groupBy": [
    "queueId"
  ],
  "metrics": [
    "nOffered",
    "nHandled",
    "nAbandoned",
    "tHandle",
    "tTalk",
    "tWait"
  ],
  "filter": {
    "type": "and",
    "predicates": [
      {
        "dimension": "queueId",
        "value": "queue-id-goes-here"
      }
    ]
  }
}
"@

Add-Template -Name  'Analytics - Conversation Aggregates (By Queue + Interval)' `
             -Method 'POST' `
             -Path   '/api/v2/analytics/conversations/aggregates/query' `
             -Group  'Analytics' `
             -Parameters ([ordered]@{
                 body = $aggregatesBody
             })

# 9) Speech and Text Analytics: conversation-level object
Add-Template -Name  'Speech & Text - Conversation Analytics' `
             -Method 'GET' `
             -Path   '/api/v2/speechandtextanalytics/conversations/{conversationId}' `
             -Group  'SpeechAndTextAnalytics' `
             -Parameters ([ordered]@{
                 conversationId = 'conversation-id-goes-here'
             })

# 10) Recording metadata
Add-Template -Name  'Recording - Conversation Recording Metadata' `
             -Method 'GET' `
             -Path   '/api/v2/conversations/{conversationId}/recordingmetadata' `
             -Group  'Recording' `
             -Parameters ([ordered]@{
                 conversationId = 'conversation-id-goes-here'
             })

# 11) Sentiment data
Add-Template -Name  'Speech & Text - Conversation Sentiments' `
             -Method 'GET' `
             -Path   '/api/v2/speechandtextanalytics/conversations/{conversationId}/sentiments' `
             -Group  'SpeechAndTextAnalytics' `
             -Parameters ([ordered]@{
                 conversationId = 'conversation-id-goes-here'
             })

# 12) SIP messages for a conversation
Add-Template -Name  'Telephony - SIP Messages for Conversation' `
             -Method 'GET' `
             -Path   '/api/v2/telephony/sipmessages/conversations/{conversationId}' `
             -Group  'Telephony' `
             -Parameters ([ordered]@{
                 conversationId = 'conversation-id-goes-here'
             })

# 13) Queue details
Add-Template -Name  'Routing - Queue Details' `
             -Method 'GET' `
             -Path   '/api/v2/routing/queues/{queueId}' `
             -Group  'Routing' `
             -Parameters ([ordered]@{
                 queueId = 'queue-id-goes-here'
             })

# 14) Queue members
Add-Template -Name  'Routing - Queue Members' `
             -Method 'GET' `
             -Path   '/api/v2/routing/queues/{queueId}/members' `
             -Group  'Routing' `
             -Parameters ([ordered]@{
                 queueId = 'queue-id-goes-here'
                 # Likely used as query params in your HTTP client
                 pageNumber = '1'
                 pageSize   = '100'
             })

# 15) User routing skills
Add-Template -Name  'Users - Routing Skills' `
             -Method 'GET' `
             -Path   '/api/v2/users/{userId}/routingskills' `
             -Group  'Users' `
             -Parameters ([ordered]@{
                 userId = 'user-id-goes-here'
             })

# 16) User presence (single)
Add-Template -Name  'Users - Presence (PURECLOUD)' `
             -Method 'GET' `
             -Path   '/api/v2/users/{userId}/presences/purecloud' `
             -Group  'Users' `
             -Parameters ([ordered]@{
                 userId = 'user-id-goes-here'
             })

# 17) User presence bulk
Add-Template -Name  'Users - Presence Bulk (PURECLOUD)' `
             -Method 'GET' `
             -Path   '/api/v2/users/presences/purecloud/bulk' `
             -Group  'Users' `
             -Parameters ([ordered]@{
                 # Your HTTP client likely maps this to POST body or query;
                 # this is just a placeholder list of user IDs.
                 userIds = 'user-id-1,user-id-2,user-id-3'
             })

# 18) User routing status
Add-Template -Name  'Users - Routing Status' `
             -Method 'GET' `
             -Path   '/api/v2/users/{userId}/routingstatus' `
             -Group  'Users' `
             -Parameters ([ordered]@{
                 userId = 'user-id-goes-here'
             })

# 19) Analytics: user details job status
Add-Template -Name  'Analytics - User Details Job (Status)' `
             -Method 'GET' `
             -Path   '/api/v2/analytics/users/details/jobs/{jobId}' `
             -Group  'Analytics' `
             -Parameters ([ordered]@{
                 jobId = 'job-id-goes-here'
             })

# ----------------------------------------------------------
# Write curated pack to disk
# ----------------------------------------------------------

$templates |
    ConvertTo-Json -Depth 10 |
    Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host "Conversation Investigation template pack written to '$($OutputPath)'. Count: $($templates.Count)"
### END FILE: Build-ConvoInvestigationTemplatePack.ps1
