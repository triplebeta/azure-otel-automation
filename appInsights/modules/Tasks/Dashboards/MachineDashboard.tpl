{
  "lenses": {
    "0": {
      "order": 0,
      "parts": {
        "0": {
          "position": {
            "x": 0,
            "y": 0,
            "colSpan": 9,
            "rowSpan": 4
          },
          "metadata": {
            "inputs": [
              {
                "name": "sharedTimeRange",
                "isOptional": true
              },
              {
                "name": "options",
                "value": {
                  "chart": {
                    "metrics": [
                      {
                        "resourceMetadata": {
                          "id": "/subscriptions/${sub_id}/resourceGroups/otelpoc/providers/Microsoft.Insights/components/${resource_group_name}-ai"
                        },
                        "name": "customMetrics/eventscreated",
                        "aggregationType": 1,
                        "namespace": "microsoft.insights/components/kusto",
                        "metricVisualization": {
                          "displayName": "eventscreated"
                        }
                      }
                    ],
                    "title": "Sum eventscreated for ${resource_group_name}-ai by machinenr",
                    "titleKind": 1,
                    "visualization": {
                      "chartType": 1,
                      "legendVisualization": {
                        "isVisible": true,
                        "position": 2,
                        "hideSubtitle": false
                      },
                      "axisVisualization": {
                        "x": {
                          "isVisible": true,
                          "axisType": 2
                        },
                        "y": {
                          "isVisible": true,
                          "axisType": 1
                        }
                      }
                    },
                    "grouping": {
                      "dimension": "customDimensions/machinenr",
                      "sort": 2,
                      "top": 10
                    },
                    "timespan": {
                      "absolute": {
                        "startTime": "2023-08-06T20:23:19.533Z",
                        "endTime": "2023-08-06T20:37:30.765Z"
                      },
                      "showUTCTime": false,
                      "grain": 1
                    }
                  }
                },
                "isOptional": true
              }
            ],
            "type": "Extension/HubsExtension/PartType/MonitorChartPart",
            "settings": {
              "content": {
                "options": {
                  "chart": {
                    "metrics": [
                      {
                        "resourceMetadata": {
                          "id": "/subscriptions/${sub_id}/resourceGroups/${resource_group_name}/providers/Microsoft.Insights/components/${resource_group_name}-ai"
                        },
                        "name": "customMetrics/eventscreated",
                        "aggregationType": 1,
                        "namespace": "microsoft.insights/components/kusto",
                        "metricVisualization": {
                          "displayName": "eventscreated"
                        }
                      }
                    ],
                    "title": "Events created per machine",
                    "titleKind": 2,
                    "visualization": {
                      "chartType": 1,
                      "legendVisualization": {
                        "isVisible": true,
                        "position": 2,
                        "hideSubtitle": false
                      },
                      "axisVisualization": {
                        "x": {
                          "isVisible": true,
                          "axisType": 2
                        },
                        "y": {
                          "isVisible": true,
                          "axisType": 1
                        }
                      },
                      "disablePinning": true
                    },
                    "grouping": {
                      "dimension": "customDimensions/machinenr",
                      "sort": 2,
                      "top": 10
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  },
  "metadata": {
    "model": {
      "timeRange": {
        "value": {
          "relative": {
            "duration": 1,
            "timeUnit": 3
          }
        },
        "type": "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
      },
      "filterLocale": {
        "value": "en-us"
      },
      "filters": {
        "value": {
          "MsPortalFx_TimeRange": {
            "model": {
              "format": "utc",
              "granularity": "auto",
              "relative": "30m"
            },
            "displayCache": {
              "name": "UTC Time",
              "value": "Past 30 minutes"
            },
            "filteredPartIds": [
              "StartboardPart-MonitorChartPart-2047913e-2e8c-4775-8a78-91b514b9c7d5"
            ]
          }
        }
      }
    }
  }
}