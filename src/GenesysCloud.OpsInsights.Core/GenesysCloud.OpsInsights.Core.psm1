$moduleRoot = $PSScriptRoot
$publicDir  = Join-Path $moduleRoot 'Public'

$publicScripts = Get-ChildItem -Path $publicDir -Filter '*.ps1' -File | Sort-Object Name
foreach ($script in $publicScripts) { . $script.FullName }

$publicFunctions = $publicScripts | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }
Export-ModuleMember -Function $publicFunctions
