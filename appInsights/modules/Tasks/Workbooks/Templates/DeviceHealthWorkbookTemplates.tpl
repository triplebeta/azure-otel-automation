{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# Device Health\r\n\r\nShows some important statistics for a specific device."
      },
      "name": "text - 2"
    },
    {
      "type": 9,
      "content": {
        "version": "KqlParameterItem/1.0",
        "crossComponentResources": [
          "/subscriptions/a6faafc0-def0-429a-bd0e-2c2550f163a3/resourceGroups/otelpoc/providers/Microsoft.Insights/components/otelpoc-ai"
        ],
        "parameters": [
          {
            "id": "16e516f9-dc10-4762-9a55-f7a913187389",
            "version": "KqlParameterItem/1.0",
            "name": "device_id",
            "label": "Device",
            "type": 2,
            "query": "Sample_DeviceList()",
            "crossComponentResources": [
              "/subscriptions/a6faafc0-def0-429a-bd0e-2c2550f163a3/resourceGroups/otelpoc/providers/Microsoft.OperationalInsights/workspaces/otelpoc-la"
            ],
            "typeSettings": {
              "additionalResourceOptions": [],
              "showDefault": false
            },
            "timeContext": {
              "durationMs": 86400000
            },
            "queryType": 0,
            "resourceType": "microsoft.operationalinsights/workspaces",
            "value": "CC33"
          },
          {
            "id": "0db7d65e-d9e4-43d8-9582-8910cbfbd599",
            "version": "KqlParameterItem/1.0",
            "name": "TimeRange",
            "label": "Period",
            "type": 4,
            "isRequired": true,
            "typeSettings": {
              "selectableValues": [
                {
                  "durationMs": 300000
                },
                {
                  "durationMs": 900000
                },
                {
                  "durationMs": 1800000
                },
                {
                  "durationMs": 3600000
                },
                {
                  "durationMs": 14400000
                },
                {
                  "durationMs": 43200000
                },
                {
                  "durationMs": 86400000
                },
                {
                  "durationMs": 259200000
                },
                {
                  "durationMs": 604800000
                },
                {
                  "durationMs": 1209600000
                },
                {
                  "durationMs": 2419200000
                }
              ],
              "allowCustom": true
            },
            "timeContext": {
              "durationMs": 86400000
            },
            "value": {
              "durationMs": 4274280000,
              "endTime": "2024-02-18T10:18:00.000Z"
            }
          }
        ],
        "style": "pills",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      },
      "name": "parameters - 1"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "Sample_BatchDuration\r\n| where device_id == \"{device_id}\"\r\n| where TimeGenerated > {TimeRange:start} and TimeGenerated <= {TimeRange:end}",
        "size": 1,
        "aggregation": 2,
        "title": "Batch duration",
        "noDataMessage": "No batches available",
        "noDataMessageStyle": 4,
        "timeContext": {
          "durationMs": 86400000
        },
        "timeBrushParameterName": "period",
        "timeBrushExportOnlyWhenBrushed": true,
        "exportFieldName": "batch_id",
        "exportParameterName": "batch_id",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "crossComponentResources": [
          "/subscriptions/a6faafc0-def0-429a-bd0e-2c2550f163a3/resourceGroups/otelpoc/providers/Microsoft.OperationalInsights/workspaces/otelpoc-la"
        ],
        "visualization": "barchart",
        "chartSettings": {
          "xAxis": "TimeGenerated",
          "showMetrics": false,
          "showLegend": true,
          "customThresholdLine": "500",
          "customThresholdLineStyle": 1
        }
      },
      "name": "BatchDuration"
    }
  ],
  "fallbackResourceIds": [
    "/subscriptions/a6faafc0-def0-429a-bd0e-2c2550f163a3/resourceGroups/otelpoc/providers/Microsoft.Insights/components/otelpoc-ai"
  ],
  "fromTemplateId": "ArmTemplates-/subscriptions/a6faafc0-def0-429a-bd0e-2c2550f163a3/resourceGroups/otelpoc/providers/Microsoft.Insights/workbooktemplates/DeviceHealthWorkbookTemplate",
  "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
}