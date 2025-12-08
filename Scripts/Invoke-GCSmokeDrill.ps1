### BEGIN FILE: Invoke-GCSmokeDrill.ps1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUri,

    [Parameter(Mandatory = $true)]
    [string]$AccessToken,

    [Parameter(Mandatory = $true)]
    [string]$Interval,

    [Parameter(Mandatory = $false)]
    [string]$DivisionId,

    [Parameter(Mandatory = $false)]
    [string[]]$QueueIds,

    [Parameter(Mandatory = $false)]
    [int]$TopNQueues = 10,

    [Parameter(Mandatory = $false)]
    [int]$TopNConversations = 25,

    # Path to your WPF timeline UI script (updated version below)
    [Parameter(Mandatory = $false)]
    [string]$TimelineScriptPath = ".\Show-GCConversationTimelineUI.ps1"
)

# Quick sanity checks so we fail early instead of silently doing nothing.
foreach ($fn in 'Get-GCQueueSmokeReport','Get-GCQueueHotConversations') {
    if (-not (Get-Command -Name $fn -ErrorAction SilentlyContinue)) {
        throw "Required function '$fn' is not available. Import your Genesys toolbox module first."
    }
}

if (-not (Test-Path -LiteralPath $TimelineScriptPath)) {
    throw "Timeline script not found at '$TimelineScriptPath'. Update -TimelineScriptPath to point at Show-GCConversationTimelineUI.ps1."
}

# 1) Produce smoke report (queues/agents)
Write-Host "Generating queue smoke report for interval $Interval ..." -ForegroundColor Cyan

$report = Get-GCQueueSmokeReport `
    -BaseUri $BaseUri `
    -AccessToken $AccessToken `
    -Interval $Interval `
    -DivisionId $DivisionId `
    -QueueIds $QueueIds `
    -TopN $TopNQueues

if (-not $report -or -not $report.QueueTop) {
    Write-Warning "No queue data returned. Nothing to drill into."
    return
}

# 2) Let you pick a queue via Out-GridView (double-click to select)
$queueView = $report.QueueTop |
    Select-Object QueueName, QueueId, Offered, Abandoned, AbandonRate, ErrorRate, AvgHandle, AvgWait |
    Out-GridView -Title "Queue Smoke Report (double-click a queue to drill)" -PassThru

if (-not $queueView) {
    Write-Host "No queue selected. Exiting."
    return
}

$selectedQueueId   = $queueView.QueueId
$selectedQueueName = $queueView.QueueName

Write-Host "Selected queue: $selectedQueueName [$selectedQueueId]" -ForegroundColor Yellow

# 3) Get hot conversations for that queue
$hotConvs = Get-GCQueueHotConversations `
    -BaseUri $BaseUri `
    -AccessToken $AccessToken `
    -QueueId $selectedQueueId `
    -Interval $Interval `
    -TopN $TopNConversations

if (-not $hotConvs -or $hotConvs.Count -eq 0) {
    Write-Warning "No 'hot' conversations detected for $selectedQueueName in $Interval."
    return
}

# Present a trimmed grid of the suspicious conversations.
$convView = $hotConvs |
    Select-Object ConversationId, SmokeScore, ErrorSegments, ShortCalls, QueueSegments, StartTime, DurationSeconds, QueueIds |
    Out-GridView -Title "Hot Conversations for $selectedQueueName (double-click to open timeline)" -PassThru

if (-not $convView) {
    Write-Host "No conversation selected. Exiting."
    return
}

$selectedConvId = $convView.ConversationId
Write-Host "Opening timeline for conversation $selectedConvId ..." -ForegroundColor Yellow

# 4) Launch the WPF UI, preloading the conversationID
#    We pass BaseUri, AccessToken, and ConversationId so the window opens ready to go.
& $TimelineScriptPath `
    -BaseUri $BaseUri `
    -AccessToken $AccessToken `
    -ConversationId $selectedConvId
### END FILE: Invoke-GCSmokeDrill.ps1
