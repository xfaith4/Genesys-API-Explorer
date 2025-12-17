PR2 Fix Patch
- Replaces manifest with ASCII-only description (restricted language friendly)
- Adds/repairs Export-GCConversationToExcel.ps1 (previous file had parse errors)
- Adds/repairs Set-GCInvoker.ps1
- Replaces module loader psm1 with safe dot-sourcing + export-by-filename

Copy these into your repo, preserving the folder structure under src\GenesysCloud.OpsInsights\.
