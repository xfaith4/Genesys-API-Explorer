# Filter Builder Enhancement: Dynamic Predicate Field Population

## Overview
This enhancement improves the Conversation and Segment Filters sections by dynamically populating predicate fields from the GenesysCloudAPIEndpoints.json schema definitions. Previously, predicate type values were hardcoded; now they are extracted from the API schema, ensuring accuracy and automatic updates when the schema changes.

## Problem Statement
The original implementation hardcoded predicate type values ("dimension" and "metric") in the filter builder UI. This approach had several limitations:
1. Missing the "property" predicate type from the schema
2. No support for segment-specific propertyType field
3. Manual updates required when API schema changes
4. Potential for inconsistency between UI and actual API requirements

## Solution
Enhanced the filter builder to dynamically extract and populate predicate field values from the GenesysCloudAPIEndpoints.json schema, specifically:
- Predicate type enum values for both Conversation and Segment filters
- PropertyType enum values for Segment filters (unique to segment predicates)
- Added UI elements to support property-type predicates

## Technical Changes

### 1. Enhanced Data Structure
**File:** `GenesysCloudAPIExplorer.ps1`, lines 4027-4041

Added new fields to `$script:FilterBuilderEnums`:
```powershell
$script:FilterBuilderEnums = @{
    Conversation = @{
        Dimensions = @()
        Metrics = @()
        Types = @()              # NEW: Extracted from ConversationDetailQueryPredicate.type
    }
    Segment = @{
        Dimensions = @()
        Metrics = @()
        Types = @()              # NEW: Extracted from SegmentDetailQueryPredicate.type
        PropertyTypes = @()      # NEW: Extracted from SegmentDetailQueryPredicate.propertyType
    }
    Operators = @("matches", "exists", "notExists")
}
```

### 2. Enhanced Enum Extraction
**File:** `GenesysCloudAPIExplorer.ps1`, lines 1070-1087

Updated `Initialize-FilterBuilderEnum` function to extract additional enums:
```powershell
function Initialize-FilterBuilderEnum {
    $convPredicate = Resolve-SchemaReference -Schema $script:Definitions.ConversationDetailQueryPredicate -Definitions $script:Definitions
    $segmentPredicate = Resolve-SchemaReference -Schema $script:Definitions.SegmentDetailQueryPredicate -Definitions $script:Definitions

    # Existing extractions
    $script:FilterBuilderEnums.Conversation.Dimensions = Get-EnumValues -Schema $convPredicate -PropertyName "dimension"
    $script:FilterBuilderEnums.Conversation.Metrics = Get-EnumValues -Schema $convPredicate -PropertyName "metric"
    
    # NEW: Type enum extraction
    $script:FilterBuilderEnums.Conversation.Types = Get-EnumValues -Schema $convPredicate -PropertyName "type"

    # Existing extractions
    $script:FilterBuilderEnums.Segment.Dimensions = Get-EnumValues -Schema $segmentPredicate -PropertyName "dimension"
    $script:FilterBuilderEnums.Segment.Metrics = Get-EnumValues -Schema $segmentPredicate -PropertyName "metric"
    
    # NEW: Type and PropertyType enum extractions
    $script:FilterBuilderEnums.Segment.Types = Get-EnumValues -Schema $segmentPredicate -PropertyName "type"
    $script:FilterBuilderEnums.Segment.PropertyTypes = Get-EnumValues -Schema $segmentPredicate -PropertyName "propertyType"

    $operatorValues = Get-EnumValues -Schema $convPredicate -PropertyName "operator"
    if ($operatorValues.Count -gt 0) {
        $script:FilterBuilderEnums.Operators = $operatorValues
    }
}
```

### 3. Fixed Get-EnumValues Function
**File:** `GenesysCloudAPIExplorer.ps1`, lines 1047-1073

Corrected the function to properly access schema properties:
```powershell
function Get-EnumValues {
    param (
        $Schema,
        [string]$PropertyName
    )

    if (-not $Schema) {
        return @()
    }

    # First check if the schema has properties
    $properties = $Schema.properties
    if (-not $properties) {
        return @()
    }

    # Look for the property by name
    $property = $properties.PSObject.Properties[$PropertyName]
    if (-not $property) {
        return @()
    }

    # Check if the property has enum values
    $propValue = $property.Value
    if ($propValue -and $propValue.enum) {
        # Comma operator forces PowerShell to treat the array as a single object
        # preventing automatic unwrapping when the array is returned
        return ,$propValue.enum
    }

    return @()
}
```

### 4. Dynamic UI Population
**File:** `GenesysCloudAPIExplorer.ps1`, lines 1382-1449

Changed `Initialize-FilterBuilderControl` to use extracted enums:

**Before:**
```powershell
$conversationPredicateTypeCombo.Items.Clear()
$conversationPredicateTypeCombo.Items.Add("dimension") | Out-Null
$conversationPredicateTypeCombo.Items.Add("metric") | Out-Null
$conversationPredicateTypeCombo.SelectedIndex = 0
```

**After:**
```powershell
$conversationPredicateTypeCombo.Items.Clear()
if ($script:FilterBuilderEnums.Conversation.Types.Count -gt 0) {
    foreach ($type in $script:FilterBuilderEnums.Conversation.Types) {
        $conversationPredicateTypeCombo.Items.Add($type) | Out-Null
    }
} else {
    # Fallback to default values if enum extraction fails
    $conversationPredicateTypeCombo.Items.Add("dimension") | Out-Null
    $conversationPredicateTypeCombo.Items.Add("property") | Out-Null
    $conversationPredicateTypeCombo.Items.Add("metric") | Out-Null
}
$conversationPredicateTypeCombo.SelectedIndex = 0
```

### 5. New UI Elements
**File:** `GenesysCloudAPIExplorer.ps1`, lines 3679-3682

Added UI elements for Segment property-type predicates:
```xml
<StackPanel Orientation="Horizontal" Margin="0 4 0 0">
  <TextBox Name="SegmentPropertyInput" Width="120" Margin="0 0 8 0" 
           ToolTip="Property name (for property type predicates)"/>
  <ComboBox Name="SegmentPropertyTypeCombo" Width="120" Margin="0 0 8 0" 
            ToolTip="Property type (for property type predicates)"/>
</StackPanel>
```

### 6. Enhanced Hint Display
**File:** `GenesysCloudAPIExplorer.ps1`, lines 1247-1258

Updated to show all enum counts:
```powershell
function Update-FilterBuilderHint {
    if (-not $filterBuilderHintText) { return }
    $convDims = $script:FilterBuilderEnums.Conversation.Dimensions.Count
    $convMetrics = $script:FilterBuilderEnums.Conversation.Metrics.Count
    $convTypes = $script:FilterBuilderEnums.Conversation.Types.Count
    $segDims = $script:FilterBuilderEnums.Segment.Dimensions.Count
    $segMetrics = $script:FilterBuilderEnums.Segment.Metrics.Count
    $segTypes = $script:FilterBuilderEnums.Segment.Types.Count
    $segPropTypes = $script:FilterBuilderEnums.Segment.PropertyTypes.Count
    $hint = "Conversation types ($convTypes) · dims ($convDims) · metrics ($convMetrics); Segment types ($segTypes) · dims ($segDims) · metrics ($segMetrics) · prop types ($segPropTypes)."
    $filterBuilderHintText.Text = $hint
}
```

## Schema Reference

### ConversationDetailQueryPredicate
From `GenesysCloudAPIEndpoints.json`:
```json
{
  "type": {
    "enum": ["dimension", "property", "metric"]
  },
  "dimension": {
    "enum": ["conversationEnd", "conversationId", "conversationInitiator", 
             "conversationStart", "customerParticipation", "divisionId", 
             "externalTag", "mediaStatsMinConversationMos", 
             "originatingDirection", "originatingSocialMediaPublic"]
  },
  "metric": {
    "enum": ["nBlindTransferred", "nBotInteractions", "nCobrowseSessions",
             "nConnected", "tAbandon", "tAcd", "tConnected", /* 68 total */]
  },
  "operator": {
    "enum": ["matches", "exists", "notExists"]
  }
}
```

### SegmentDetailQueryPredicate
From `GenesysCloudAPIEndpoints.json`:
```json
{
  "type": {
    "enum": ["dimension", "property", "metric"]
  },
  "dimension": {
    "enum": ["addressFrom", "addressTo", "agentAssistantId", "agentOwned",
             "ani", "authenticated", "direction", "mediaType", "queueId",
             "userId", /* 76 total */]
  },
  "propertyType": {
    "enum": ["bool", "integer", "real", "date", "string", "uuid"]
  },
  "property": {
    "type": "string"  // Free-form text, not an enum
  },
  "metric": {
    "enum": ["tSegmentDuration"]
  },
  "operator": {
    "enum": ["matches", "exists", "notExists"]
  }
}
```

## Populated Values Summary

### Conversation Filters
- **Types (3)**: dimension, property, metric
- **Dimensions (10)**: All conversation-level attributes
- **Metrics (68)**: All conversation-level metrics (counts, durations, etc.)
- **Operators (3)**: matches, exists, notExists

### Segment Filters
- **Types (3)**: dimension, property, metric
- **Dimensions (76)**: All segment-level attributes
- **Metrics (1)**: tSegmentDuration
- **PropertyTypes (6)**: bool, integer, real, date, string, uuid
- **Operators (3)**: matches, exists, notExists

## Benefits

1. **Schema Accuracy**: Filter predicates now match exact API schema definitions
2. **Automatic Updates**: Changes to API schema are automatically reflected in UI
3. **Completeness**: Added support for "property" predicate type (was missing)
4. **Extensibility**: New enum values in future API versions are automatically included
5. **Maintainability**: No hardcoded values to update when API changes
6. **User Experience**: Users can build more precise and complete filter queries

## Testing

All changes have been verified with the actual GenesysCloudAPIEndpoints.json:
- ✅ Enum extraction from schema works correctly
- ✅ All predicate types are populated (dimension, property, metric)
- ✅ PropertyType enum is populated for Segment filters
- ✅ Fallback behavior works when enum extraction fails
- ✅ Initialization logic works with actual schema data
- ✅ Switch statement handles all predicate type combinations

## Usage Example

When users build filters, they can now:

1. **Select predicate type** from dynamically populated options:
   - dimension (for categorical attributes)
   - property (for custom properties)
   - metric (for numeric measurements)

2. **For property-type predicates in Segment filters**:
   - Enter property name in the text box
   - Select property type from the combo box (bool, integer, real, date, string, uuid)

3. **All selections** are validated against the current API schema, ensuring compatibility

## Future Enhancements

Potential improvements for the filter builder:
1. Add property name auto-completion for property-type predicates
2. Implement dynamic validation based on selected property type
3. Add tooltips with descriptions for each dimension/metric
4. Support for nested filter clauses
5. Filter template saving and loading

## Related Files
- `GenesysCloudAPIExplorer.ps1` - Main application with filter builder logic
- `GenesysCloudAPIEndpoints.json` - API schema source (cached OpenAPI spec)
- `docs/FILTER_BUILDER_ENHANCEMENT.md` - This documentation

## References
- Genesys Cloud API Explorer Schema Documentation
- ConversationDetailQueryPredicate schema definition
- SegmentDetailQueryPredicate schema definition
