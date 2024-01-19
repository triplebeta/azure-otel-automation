{
    "version": "Notebook/1.0",
    "items": [
      {
        "type": 12,
        "content": {
          "version": "NotebookGroup/1.0",
          "groupType": "editable",
          "items": [
            {
              "type": 3,
              "content": {
                "version": "KqlItem/1.0",
                "query": "(AppTraces\r\n| where TimeGenerated >=ago(3d)\r\n| where AppRoleName == 'Tasker (prod)'\r\n| where Message startswith 'Tasker started batch'\r\n| project-rename start_timestamp=TimeGenerated\r\n| extend batchid = tostring(Properties['batch_id'])\r\n| extend device_id = tostring(Properties['device_id'])\r\n| project start_timestamp, device_id, batchid\r\n| join kind=leftouter \r\n    (AppTraces\r\n    | where AppRoleName == 'Tasker (prod)'\r\n    | where Message has 'Tasker completed run'\r\n    | extend batchid = tostring(Properties['batch_id'])\r\n    | extend iteration = toint(Properties['iteration'])\r\n    | project iteration, batchid) on batchid)\r\n| extend bin=bin(start_timestamp,1d)\r\n| summarize successful_runs=sum(iif(isnotnull(iteration),1,0)) by bin, device_id, valid=1\r\n| summarize successful_runs=sum(successful_runs), days=sum(valid) by device_id\r\n",
                "size": 1,
                "timeContext": {
                  "durationMs": 604800000
                },
                "queryType": 0,
                "resourceType": "microsoft.operationalinsights/workspaces",
                "crossComponentResources": [
                  "/subscriptions/${sub_id}/resourceGroups/${resource_group_name}/providers/Microsoft.OperationalInsights/workspaces/${log_analytics_name}"
                ],
                "visualization": "graph",
                "graphSettings": {
                  "type": 2,
                  "topContent": {
                    "columnMatch": "device_id"
                  },
                  "centerContent": {
                    "columnMatch": "successful_runs"
                  },
                  "nodeIdField": "device_id",
                  "graphOrientation": 3,
                  "showOrientationToggles": false,
                  "nodeSize": null,
                  "staticNodeSize": 100,
                  "colorSettings": {
                    "nodeColorField": "days",
                    "type": 3,
                    "thresholdsGrid": [
                      {
                        "operator": "<=",
                        "thresholdValue": "1",
                        "representation": "redBright"
                      },
                      {
                        "operator": "==",
                        "thresholdValue": "2",
                        "representation": "orange"
                      },
                      {
                        "operator": ">",
                        "thresholdValue": "2",
                        "representation": "green"
                      },
                      {
                        "operator": "Default",
                        "thresholdValue": null,
                        "representation": "lightBlue"
                      }
                    ]
                  },
                  "hivesMargin": 5,
                  "edgeColorSettings": null
                }
              },
              "name": "query - 2"
            },
            {
              "type": 11,
              "content": {
                "version": "LinkItem/1.0",
                "style": "bullets",
                "links": [
                  {
                    "id": "66844806-8a08-4521-8b84-545b627804ad",
                    "cellValue": "Foo",
                    "linkTarget": "GenericDetails",
                    "linkLabel": "Here is the link",
                    "preText": "Before link",
                    "postText": "And after link",
                    "style": "primary",
                    "linkIsContextBlade": true
                  }
                ]
              },
              "name": "links - 1"
            }
          ]
        },
        "name": "group - 1"
      }
    ],
    "fallbackResourceIds": [
      "azure monitor"
    ],
    "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
  }