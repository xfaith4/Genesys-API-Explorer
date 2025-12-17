### BEGIN FILE: tests\ConversationDetails.Offline.Tests.ps1
# Requires: Pester 5+
# Run: Invoke-Pester -Path .\tests

BeforeAll {
    . "$PSScriptRoot\..\tools\Import-LocalOpsInsights.ps1"

    # Offline invoker that returns fixtures based on method+path.
    Set-GCInvoker -Invoker {
        param([hashtable]$Request)

        # Only fixture we need for PR2 offline:
        # POST https://api.usw2.pure.cloud/api/v2/analytics/conversations/details/query
        if ($Request.Method -eq 'POST' -and $Request.Uri -match '/api/v2/analytics/conversations/details/query$') {
            $fixturePath = Join-Path $PSScriptRoot 'fixtures\ConversationDetails.sample.json'
            return (Get-Content -LiteralPath $fixturePath -Raw) | ConvertFrom-Json
        }

        throw "No fixture mapped for: $($Request.Method) $($Request.Uri)"
    }
}

Describe 'Offline Conversation Details fixture' {
    It 'returns conversations and cursor from fixture' {
        $q = @{
            interval = '2024-02-06T00:00:00.000Z/2024-02-07T00:00:00.000Z'
            order = 'asc'
            orderBy = 'conversationStart'
            paging = @{ pageSize = 10; pageNumber = 1 }
        }

        $resp = Get-GCConversationDetails -Query $q
        $resp.conversations.Count | Should -Be 10
        $resp.cursor | Should -Not -BeNullOrEmpty
    }
}
### END FILE
