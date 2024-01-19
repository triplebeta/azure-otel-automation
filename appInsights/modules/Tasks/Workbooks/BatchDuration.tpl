{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "// Duration of batches (each might consist of 1, 2 or 3 runs)\r\n// Get timestamp of start batch, join it with completed run on batchid\r\n// Also include the number of iterations needed to complete it.\r\n(AppTraces\r\n| where AppRoleName == 'Tasker (prod)'\r\n| where Message startswith 'Tasker started batch'\r\n| project-rename start_timestamp=TimeGenerated\r\n| extend batchid = tostring(Properties['batch_id'])\r\n| extend device_id = tostring(Properties['device_id'])\r\n| project start_timestamp, device_id, batchid\r\n| join kind=leftouter \r\n    (AppTraces\r\n    | where AppRoleName == 'Tasker (prod)'\r\n    | where Message startswith 'Tasker completed run'\r\n    | project-rename completed_timestamp=TimeGenerated\r\n    | extend batchid = tostring(Properties['batch_id'])\r\n    | extend iteration = toint(Properties['iteration'])\r\n    | project completed_timestamp, iteration, batchid) on batchid)\r\n| project start_timestamp, device_id, batchid, success=iff(isempty(iteration),\"FAILED\",\"SUCCESS\"), duration=completed_timestamp-start_timestamp, iteration",
        "size": 0,
        "timeContext": {
          "durationMs": 86400000
        },
        "showRefreshButton": true,
        "exportFieldName": "device_id",
        "exportParameterName": "device",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "crossComponentResources": [
          "/subscriptions/${sub_id}/resourceGroups/${resource_group_name}/providers/Microsoft.OperationalInsights/workspaces/${resource_group_name}-la"
        ],
        "gridSettings": {
          "formatters": [
            {
              "columnMatch": "batchid",
              "formatter": 1,
              "formatOptions": {
                "linkColumn": "batchid",
                "linkTarget": "WorkbookTemplate"
              }
            },
            {
              "columnMatch": "duration",
              "formatter": 8,
              "formatOptions": {
                "palette": "greenRed"
              }
            },
            {
              "columnMatch": "iteration",
              "formatter": 3,
              "formatOptions": {
                "palette": "blue"
              }
            },
            {
              "columnMatch": "Batch duration",
              "formatter": 8,
              "formatOptions": {
                "palette": "blue"
              }
            }
          ]
        }
      },
      "name": "query - 0"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "AppTraces\r\n| where Message == \"Tasker failed run\"\r\n| extend device_id = tostring(Properties[\"device_id\"])\r\n| where device_id == \"{device_id}\"\r\n| project TimeGenerated, Message, SeverityLevel, Properties",
        "size": 1,
        "noDataMessage": "No failed runs found for this batch.",
        "timeContext": {
          "durationMs": 86400000
        },
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "crossComponentResources": [
          "/subscriptions/${sub_id}/resourceGroups/${resource_group_name}/providers/Microsoft.OperationalInsights/workspaces/${resource_group_name}-la"
        ]
      },
      "name": "query - 1"
    }
  ],
  "fallbackResourceIds": [
    "azure monitor"
  ],
  "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
}