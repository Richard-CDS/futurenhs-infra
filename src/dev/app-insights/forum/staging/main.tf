# We have a separate instance of app insights for the staging slot so we can monitor release through azure monitor
# and rollback if anything goes wrong in the first N minutes.  Assuming all is ok, traffic can start to be routed to 
# staging and thereafter the slots swapped over

# Note that the release pipeline will also add some tests to the monitor and alerts that execute off the back of them

resource "azurerm_application_insights" "forum_staging" {
  name                                    = "appi-${var.product_name}-${var.environment}-${var.location}-forum-staging"
  location                                = var.location
  resource_group_name                     = var.resource_group_name
  application_type                        = "web"

  # TODO - change these settings for a production environment

  daily_data_cap_in_gb                    = 1
  daily_data_cap_notifications_disabled   = true
  retention_in_days                       = 30
  sampling_percentage                     = 100
  disable_ip_masking                      = true
}

# https://docs.microsoft.com/en-gb/azure/azure-monitor/app/monitor-web-app-availability

resource "azurerm_application_insights_web_test" "forum-staging-availability-test" {
  name                    = "appiwt-${var.product_name}-${var.environment}-${var.location}-forum-staging"
  description             = "Example - http ping test hitting the root page of the forum website's staging environment using the internal Azure domain"
  location                = var.location
  resource_group_name     = var.resource_group_name
  application_insights_id = azurerm_application_insights.forum_staging.id
  kind                    = "ping"
  frequency               = 300
  timeout                 = 60
  enabled                 = true
  geo_locations           = ["emea-ru-msa-edge", "emea-se-sto-edge"] # UK South and UK West

  lifecycle {
    ignore_changes = [
      tags
    ]
  }

  configuration = <<XML
<WebTest Name="ForumAvailabilityWebTest" Id="ABD48585-0831-40CB-9069-682EA6BB3583" Enabled="True" CssProjectStructure="" CssIteration="" Timeout="0" WorkItemIds="" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010" Description="" CredentialUserName="" CredentialPassword="" PreAuthenticate="True" Proxy="default" StopOnError="False" RecordedResultFile="" ResultsLocale="">
  <Items>
    <Request Method="GET" Guid="a5f10126-e4cd-570d-961c-cea43999a200" Version="1.1" Url="https://app-${var.product_name}-${var.environment}-${var.location}-forum-staging.azurewebsites.net" ThinkTime="0" Timeout="300" ParseDependentRequests="True" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" ExpectedResponseUrl="" ReportingName="" IgnoreHttpStatusCode="False" />
  </Items>
</WebTest>
XML
}