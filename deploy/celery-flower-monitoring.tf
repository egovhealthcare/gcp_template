# Celery worker/task dashboard built from the metrics Flower exports on
# /metrics (scraped by the PodMonitoring in the care_be chart). Panels follow
# mher/flower/examples/celery-monitoring-grafana-dashboard.json, rewritten for
# Cloud Monitoring: no Grafana template variables, fixed 5m rate windows.
locals {
  flower_selector = "cluster=\"${data.terraform_remote_state.infra.outputs.cluster_name}\",namespace=\"${local.namespace_name}\""

  flower_online_workers_query   = "count(flower_worker_online{${local.flower_selector}} == 1) or vector(0)"
  flower_offline_workers_query  = "count(flower_worker_online{${local.flower_selector}} == 0) or vector(0)"
  flower_processed_tasks_query  = "sum by (worker) (increase(flower_events_total{${local.flower_selector},type=~\"task-(succeeded|failed)\"}[5m]))"
  flower_failed_tasks_query     = "sum by (task) (increase(flower_events_total{${local.flower_selector},type=\"task-failed\"}[5m]))"
  flower_active_tasks_query     = "flower_worker_number_of_currently_executing_tasks{${local.flower_selector}}"
  flower_prefetched_tasks_query = "sum by (worker) (flower_worker_prefetched_tasks{${local.flower_selector}})"
  flower_task_runtime_avg_query = "sum by (task) (rate(flower_task_runtime_seconds_sum{${local.flower_selector}}[5m])) / clamp_min(sum by (task) (rate(flower_task_runtime_seconds_count{${local.flower_selector}}[5m])), 0.000000001)"
  flower_task_runtime_p95_query = "histogram_quantile(0.95, sum by (le, task) (rate(flower_task_runtime_seconds_bucket{${local.flower_selector}}[5m])))"
}

resource "google_monitoring_dashboard" "celery_flower" {
  count   = var.enable_celery_flower ? 1 : 0
  project = var.project_id

  dashboard_json = jsonencode({
    displayName = "CARE Celery (Flower) - ${var.environment}"
    mosaicLayout = {
      columns = 48
      tiles = [
        {
          width  = 24
          height = 8
          widget = {
            title = "Online workers"
            scorecard = {
              timeSeriesQuery = { prometheusQuery = local.flower_online_workers_query }
            }
          }
        },
        {
          xPos   = 24
          width  = 24
          height = 8
          widget = {
            title = "Offline workers"
            scorecard = {
              timeSeriesQuery = { prometheusQuery = local.flower_offline_workers_query }
              thresholds      = [{ value = 1, color = "RED", direction = "ABOVE" }]
            }
          }
        },
        {
          yPos   = 8
          width  = 24
          height = 16
          widget = {
            title = "Active tasks per worker"
            xyChart = {
              dataSets = [{
                plotType        = "LINE"
                targetAxis      = "Y1"
                legendTemplate  = "$${metric.labels.worker}"
                timeSeriesQuery = { prometheusQuery = local.flower_active_tasks_query }
              }]
              yAxis = { label = "tasks", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 24
          yPos   = 8
          width  = 24
          height = 16
          widget = {
            title = "Processed tasks per worker (5m)"
            xyChart = {
              dataSets = [{
                plotType        = "LINE"
                targetAxis      = "Y1"
                legendTemplate  = "$${metric.labels.worker}"
                timeSeriesQuery = { prometheusQuery = local.flower_processed_tasks_query }
              }]
              yAxis = { label = "tasks", scale = "LINEAR" }
            }
          }
        },
        {
          yPos   = 24
          width  = 24
          height = 16
          widget = {
            title = "Failed tasks by task name (5m)"
            xyChart = {
              dataSets = [{
                plotType        = "LINE"
                targetAxis      = "Y1"
                legendTemplate  = "$${metric.labels.task}"
                timeSeriesQuery = { prometheusQuery = local.flower_failed_tasks_query }
              }]
              yAxis = { label = "tasks", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 24
          yPos   = 24
          width  = 24
          height = 16
          widget = {
            title = "Prefetched tasks per worker"
            xyChart = {
              dataSets = [{
                plotType        = "LINE"
                targetAxis      = "Y1"
                legendTemplate  = "$${metric.labels.worker}"
                timeSeriesQuery = { prometheusQuery = local.flower_prefetched_tasks_query }
              }]
              yAxis = { label = "tasks", scale = "LINEAR" }
            }
          }
        },
        {
          yPos   = 40
          width  = 24
          height = 16
          widget = {
            title = "Average task runtime (5m)"
            xyChart = {
              dataSets = [{
                plotType        = "LINE"
                targetAxis      = "Y1"
                legendTemplate  = "$${metric.labels.task}"
                timeSeriesQuery = { prometheusQuery = local.flower_task_runtime_avg_query }
              }]
              yAxis = { label = "seconds", scale = "LINEAR" }
            }
          }
        },
        {
          xPos   = 24
          yPos   = 40
          width  = 24
          height = 16
          widget = {
            title = "P95 task runtime (5m)"
            xyChart = {
              dataSets = [{
                plotType        = "LINE"
                targetAxis      = "Y1"
                legendTemplate  = "$${metric.labels.task}"
                timeSeriesQuery = { prometheusQuery = local.flower_task_runtime_p95_query }
              }]
              yAxis = { label = "seconds", scale = "LINEAR" }
            }
          }
        },
      ]
    }
  })
}
