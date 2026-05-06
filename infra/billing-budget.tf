data "google_project" "current" {
  project_id = var.project_id
}

locals {
  enable_billing_budget        = lookup(local.cfg, "enable_billing_budget", false)
  billing_budget_currency_code = upper(lookup(local.cfg, "billing_budget_currency_code", "INR"))
  billing_budget_monthly_units = tostring(max(1, ceil(tonumber(lookup(local.cfg, "billing_budget_monthly_amount", 90000)))))
  billing_budget_alert_emails  = toset(lookup(local.cfg, "billing_budget_alert_emails", []))
}

resource "google_monitoring_notification_channel" "billing_alert_email" {
  for_each = local.enable_billing_budget ? local.billing_budget_alert_emails : toset([])

  display_name = "Billing Budget Alert - ${each.value}"
  type         = "email"

  labels = {
    email_address = each.value
  }
}

resource "google_billing_budget" "project_budget" {
  count           = local.enable_billing_budget ? 1 : 0
  billing_account = data.google_project.current.billing_account
  display_name    = "${local.cfg["org"]}-${local.cfg["app"]}-${local.cfg["environment"]}-monthly-budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = local.billing_budget_currency_code
      units         = local.billing_budget_monthly_units
    }
  }

  threshold_rules {
    threshold_percent = 0.5
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.8
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.5
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 2.0
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.2
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [
      for channel in google_monitoring_notification_channel.billing_alert_email : channel.name
    ]
  }
}
