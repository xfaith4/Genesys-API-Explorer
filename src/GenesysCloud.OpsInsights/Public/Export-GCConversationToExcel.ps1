function Export-GCConversationToExcel {
    <#
      .SYNOPSIS
        Export conversation objects (typically from Analytics Conversation Details) to XLSX/CSV/JSON.

      .DESCRIPTION
        - Prefers ImportExcel for XLSX export (if installed)
        - Falls back to CSV automatically if ImportExcel is unavailable
        - Writes UTF-8 for CSV/JSON
        - Safe for PS 5.1 + 7+

      .PARAMETER Conversation
        One or more conversation objects (pipeline supported).

      .PARAMETER OutputPath
        Output file path. If omitted, a timestamped file is created in the current directory.

      .PARAMETER Format
        Xlsx (default), Csv, or Json.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Conversation,

        [Parameter()]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeRawData
    )


    # Check if ImportExcel module is available
    $hasImportExcel = $false
    try {
        $hasImportExcel = [bool](Get-Module -ListAvailable -Name ImportExcel)
    }
    catch { 
        $hasImportExcel = $false 
    }

    if (-not $hasImportExcel) {
        Write-Warning "ImportExcel module not found. Falling back to CSV exports."
        
        # --- CSV fallback (portable, zero-deps) ---
        $outDir = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($OutputPath))
        if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($OutputPath)

        # Timeline
        $timeline = $ConversationData.TimelineEvents
        $timelineCsv = Join-Path $outDir ($baseName + '_Timeline.csv')
        $timeline | Export-Csv -Path $timelineCsv -NoTypeInformation -Encoding UTF8

        # Core + Analytics (raw payloads flattened to JSON where needed)
        if ($ConversationData.Raw) {
            $coreJson = Join-Path $outDir ($baseName + '_Core.json')
            ($ConversationData.Raw.CoreConversation | ConvertTo-Json -Depth 30) | Set-Content -Path $coreJson -Encoding UTF8

            $analyticsJson = Join-Path $outDir ($baseName + '_AnalyticsDetails.json')
            ($ConversationData.Raw.AnalyticsDetails | ConvertTo-Json -Depth 30) | Set-Content -Path $analyticsJson -Encoding UTF8
        }

        Write-Host ("CSV/JSON fallback export created under: {0}" -f $outDir)
        return
    }

    # Check if ImportExcel module is available (should be true here)
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        Write-Error "ImportExcel module is required but not installed. Please run: Install-Module ImportExcel -Scope CurrentUser"
        return
    }

        # Flatten a reasonable "ops-friendly" row set (non-destructive; original objects can be JSON exported)
        $rows = foreach ($c in $items) {
            $start = $null
            $end   = $null
            $id    = $null

            if ($c.PSObject.Properties.Name -contains 'conversationId') { $id = $c.conversationId }
            elseif ($c.PSObject.Properties.Name -contains 'id') { $id = $c.id }

            if ($c.PSObject.Properties.Name -contains 'conversationStart') { $start = $c.conversationStart }
            if ($c.PSObject.Properties.Name -contains 'conversationEnd')   { $end   = $c.conversationEnd }

            $participants = $null
            if ($c.PSObject.Properties.Name -contains 'participants') { $participants = $c.participants }

            $pCount = 0
            try { if ($participants) { $pCount = @($participants).Count } } catch { $pCount = 0 }

            [pscustomobject]@{
                ConversationId      = $id
                ConversationStart   = $start
                ConversationEnd     = $end
                DivisionId          = ($c.divisionId  | ForEach-Object { $_ })  # safe passthru
                OriginatingDirection= ($c.originatingDirection | ForEach-Object { $_ })
                MediaStatsCount     = (try { @($c.mediaStats).Count } catch { 0 })
                ParticipantCount    = $pCount
            }
        }

        $formatLower = $Format.ToLower()

        switch ($Format) {
            'Json' {
                $json = $items | ConvertTo-Json -Depth 80
                if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
                    throw "Refusing to overwrite existing file: $($OutputPath). Use -Force."
                }
                $json | Set-Content -LiteralPath $OutputPath -Encoding utf8
                return $OutputPath
            }

            'Csv' {
                if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
                    throw "Refusing to overwrite existing file: $($OutputPath). Use -Force."
                }
                $rows | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding utf8
                return $OutputPath
            }

            'Xlsx' {
                $hasImportExcel = $false
                try { $hasImportExcel = [bool](Get-Module -ListAvailable -Name ImportExcel) } catch { $hasImportExcel = $false }

                if ($hasImportExcel) {
                    if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
                        throw "Refusing to overwrite existing file: $($OutputPath). Use -Force."
                    }

                    Import-Module ImportExcel -ErrorAction Stop

                    $rows | Export-Excel -Path $OutputPath `
                        -WorksheetName 'Conversations' `
                        -FreezeTopRow `
                        -AutoSize

                    return $OutputPath
                }

                # Fallback: write CSV next to the requested xlsx path
                $csvPath = [System.IO.Path]::ChangeExtension($OutputPath, 'csv')
                if ((Test-Path -LiteralPath $csvPath) -and -not $Force) {
                    throw "ImportExcel not found; refusing to overwrite existing fallback file: $($csvPath). Use -Force."
                }

                $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding utf8
                return $csvPath
            }
        }
    }
}
