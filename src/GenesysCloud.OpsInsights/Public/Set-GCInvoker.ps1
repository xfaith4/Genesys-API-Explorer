function Set-GCInvoker {
    <#
      .SYNOPSIS
        Overrides the internal request invoker used by Invoke-GCRequest.
      .DESCRIPTION
        Enables offline testing by swapping the real web call for fixture playback.
        Invoker signature: param([hashtable]$Request) -> object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Invoker
    )

    $script:GCInvoker = $Invoker
}
