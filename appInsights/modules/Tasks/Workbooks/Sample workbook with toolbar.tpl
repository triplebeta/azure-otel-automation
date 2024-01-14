{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 9,
      "content": {
        "version": "KqlParameterItem/1.0",
        "crossComponentResources": [
          "value::all"
        ],
        "parameters": [
          {
            "id": "eddb3313-641d-4429-b467-4793d6ed3575",
            "version": "KqlParameterItem/1.0",
            "name": "Subscription",
            "type": 6,
            "isRequired": true,
            "multiSelect": true,
            "quote": "'",
            "delimiter": ",",
            "query": "where type =~ \"microsoft.web/sites\"\r\n| summarize count() by subscriptionId\r\n| order by subscriptionId asc\r\n| project subscriptionId, label=subscriptionId, selected=row_number()==1",
            "crossComponentResources": [
              "value::all"
            ],
            "typeSettings": {
              "additionalResourceOptions": [],
              "showDefault": false
            },
            "timeContext": {
              "durationMs": 86400000
            },
            "queryType": 1,
            "resourceType": "microsoft.resourcegraph/resources"
          },
          {
            "id": "8beaeea6-9550-4574-a51e-bb0c16e68e84",
            "version": "KqlParameterItem/1.0",
            "name": "site",
            "type": 5,
            "description": "global parameter set by selection in the grid",
            "isRequired": true,
            "isGlobal": true,
            "query": "where type =~ \"microsoft.web/sites\"\r\n| project id",
            "crossComponentResources": [
              "{Subscription}"
            ],
            "isHiddenWhenLocked": true,
            "typeSettings": {
              "additionalResourceOptions": [],
              "showDefault": false
            },
            "timeContext": {
              "durationMs": 86400000
            },
            "queryType": 1,
            "resourceType": "microsoft.resourcegraph/resources",
            "value": null
          },
          {
            "id": "0311fb5a-33ca-48bd-a8f3-d3f57037a741",
            "version": "KqlParameterItem/1.0",
            "name": "properties",
            "type": 1,
            "isRequired": true,
            "isGlobal": true,
            "isHiddenWhenLocked": true
          }
        ],
        "style": "above",
        "queryType": 1,
        "resourceType": "microsoft.resourcegraph/resources"
      },
      "name": "parameters - 0"
    },
    {
      "type": 11,
      "content": {
        "version": "LinkItem/1.0",
        "style": "toolbar",
        "links": [
          {
            "id": "7ea6a29e-fc83-40cb-a7c8-e57f157b1811",
            "cellValue": "{site}",
            "linkTarget": "ArmAction",
            "linkLabel": "Start",
            "postText": "Start website {site:name}",
            "style": "primary",
            "icon": "Start",
            "linkIsContextBlade": true,
            "armActionContext": {
              "pathSource": "static",
              "path": "{site}/start",
              "headers": [],
              "params": [
                {
                  "key": "api-version",
                  "value": "2019-08-01"
                }
              ],
              "isLongOperation": false,
              "httpMethod": "POST",
              "titleSource": "static",
              "title": "Start {site:name}",
              "descriptionSource": "static",
              "description": "Attempt to start:\n\n{site:grid}",
              "resultMessage": "Start {site:name} completed",
              "runLabelSource": "static",
              "runLabel": "Start"
            }
          },
          {
            "id": "676a0860-6ec8-4c4f-a3b8-a98af422ae47",
            "cellValue": "{site}",
            "linkTarget": "ArmAction",
            "linkLabel": "Stop",
            "postText": "Stop website {site:name}",
            "style": "primary",
            "icon": "Stop",
            "linkIsContextBlade": true,
            "armActionContext": {
              "pathSource": "static",
              "path": "{site}/stop",
              "headers": [],
              "params": [
                {
                  "key": "api-version",
                  "value": "2019-08-01"
                }
              ],
              "isLongOperation": false,
              "httpMethod": "POST",
              "titleSource": "static",
              "title": "Stop {site:name}",
              "descriptionSource": "static",
              "description": "# Attempt to Stop:\n\n{site:grid}",
              "resultMessage": "Stop {site:name} completed",
              "runLabelSource": "static",
              "runLabel": "Stop"
            }
          },
          {
            "id": "5e48925f-f84f-4a2d-8e69-6a4deb8a3007",
            "cellValue": "{properties}",
            "linkTarget": "CellDetails",
            "linkLabel": "Properties",
            "postText": "View the properties for Start website {site:name}",
            "style": "secondary",
            "icon": "Properties",
            "linkIsContextBlade": true
          }
        ]
      },
      "name": "site toolbar"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "where type =~ \"microsoft.web/sites\"\r\n| extend properties=tostring(properties)\r\n| project-away name, type",
        "size": 0,
        "showAnalytics": true,
        "title": "Web Apps in Subscription {Subscription:name}",
        "showRefreshButton": true,
        "exportedParameters": [
          {
            "fieldName": "id",
            "parameterName": "site"
          },
          {
            "fieldName": "",
            "parameterName": "properties",
            "parameterType": 1
          }
        ],
        "showExportToExcel": true,
        "queryType": 1,
        "resourceType": "microsoft.resourcegraph/resources",
        "crossComponentResources": [
          "{Subscription}"
        ],
        "gridSettings": {
          "formatters": [
            {
              "columnMatch": "properties",
              "formatter": 5
            }
          ],
          "filter": true,
          "sortBy": [
            {
              "itemKey": "subscriptionId",
              "sortOrder": 1
            }
          ]
        },
        "sortBy": [
          {
            "itemKey": "subscriptionId",
            "sortOrder": 1
          }
        ]
      },
      "name": "query - 1"
    },
    {
      "type": 1,
      "content": {
        "json": "## How this workbook works\r\n1. The parameters step declares a `site` resource parameter that is hidden in reading mode, but uses the same query as the grid.  this parameter is marked `global`, and has no default selection.   The parameters also declares a `properties` hidden text parameter. These parameters are [declared global](https://github.com/microsoft/Application-Insights-Workbooks/blob/master/Documentation/Parameters/Parameters.md#global-parameters) so they can be set by the grid below, but the toolbar can appear *above* the grid.\r\n\r\n2. The workbook has a links step, that renders as a toolbar.  This toolbar has items to start a website, stop a website, and show the Azure Resourcve Graph properties for that website.  The toolbar buttons all reference the `site` parameter, which by default has no selection, so the toolbar buttons are disabled.  The start and stop buttons use the [ARM Action](https://github.com/microsoft/Application-Insights-Workbooks/blob/master/Documentation/Links/LinkActions.md#arm-action-settings) feature to run an action against the selected resource.\r\n\r\n3. The workbook has an Azure Resource Graph (ARG) query step, which queries for web sites in the selected subscriptions, and displays them in a grid. When a row is selected, the selected resource is exported to the `site` global parameter, causing start and stop buttons to become enabled.  The ARG properties are also exported to the `properties` parameter, causing the poperties button to become enabled.",
        "style": "info"
      },
      "conditionalVisibility": {
        "parameterName": "debug",
        "comparison": "isEqualTo",
        "value": "true"
      },
      "name": "text - 3"
    }
  ],
  "fallbackResourceIds": [
    "azure monitor"
  ],
  "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
}