locals {
  name              = "${var.system_short_name}-${var.app_name}-${var.environment}"
  function_app_name = "${local.name}-func"

  # Add 'o' to prevent name conflict with Tensio's EnergiMidt tenant. Storage account names must be globally unique.
  storage_account_name = var.storage_account.app_short_name != null ? "${var.system_short_name}${var.storage_account.app_short_name}o${var.environment}st" : null

  existing_storage_account_name       = try(var.storage_account.existing_account.azurerm_storage_account.name, null)
  existing_storage_account_access_key = try(var.storage_account.existing_account.azurerm_storage_account.primary_access_key, null)
}

module "storageaccount" {
  source = "github.com/onegridoperation/terraform-azurerm-storageaccount.git?ref=v1.0.1"
  count  = var.storage_account.app_short_name != null ? 1 : 0

  environment              = var.environment
  system_name              = local.name
  override_name            = local.storage_account_name
  resource_group           = var.resource_group
  account_replication_type = "LRS"
  account_tier             = "Standard"
  account_kind             = "StorageV2"

  tags = var.tags
}

resource "azurerm_linux_function_app" "app" {
  count                         = var.service_plan.os_type == "Linux" ? 1 : 0
  name                          = local.function_app_name
  location                      = var.resource_group.location
  resource_group_name           = var.resource_group.name
  service_plan_id               = var.service_plan.id
  storage_account_name          = var.storage_account.existing_account != null ? local.existing_storage_account_name : local.storage_account_name
  storage_account_access_key    = var.storage_account.existing_account != null ? local.existing_storage_account_access_key : module.storageaccount[0].azurerm_storage_account.primary_access_key
  public_network_access_enabled = var.public_network_access_enabled

  https_only   = true
  app_settings = var.app_settings
  tags         = var.tags

  enabled = var.enabled != null ? var.enabled : true

  dynamic "identity" {
    for_each = var.identity[*]
    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }

  site_config {
    health_check_path                 = var.health_check_path
    health_check_eviction_time_in_min = var.health_check_eviction_time_in_min
    application_stack {
      dotnet_version = var.runtime.dotnet_version
      java_version   = var.runtime.java_version
      node_version   = var.runtime.node_version
    }
    dynamic "cors" {
      for_each = var.cors[*]
      content {
        allowed_origins     = cors.value.allowed_origins
        support_credentials = cors.value.support_credentials
      }
    }
    dynamic "ip_restriction" {
      for_each = var.inbound_ip_filtering[*]
      content {
        ip_address = ip_restriction.value.ip_address
        name       = ip_restriction.value.name
        priority   = ip_restriction.value.priority
        action     = "Allow"
      }
    }
    always_on                              = var.always_on
    application_insights_connection_string = var.app_insights.connection_string
    application_insights_key               = var.app_insights.instrumentation_key
    vnet_route_all_enabled                 = var.vnet_route_all_enabled
  }

  lifecycle {
    # network integration should be done with the `azurerm_app_service_virtual_network_swift_connection` resource
    # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_virtual_network_swift_connection
    ignore_changes = [virtual_network_subnet_id]
  }
}

resource "azurerm_windows_function_app" "app" {
  count                         = var.service_plan.os_type == "Windows" ? 1 : 0
  name                          = local.function_app_name
  location                      = var.resource_group.location
  resource_group_name           = var.resource_group.name
  service_plan_id               = var.service_plan.id
  storage_account_name          = var.storage_account.existing_account != null ? local.existing_storage_account_name : local.storage_account_name
  storage_account_access_key    = var.storage_account.existing_account != null ? local.existing_storage_account_access_key : module.storageaccount[0].azurerm_storage_account.primary_access_key
  public_network_access_enabled = var.public_network_access_enabled
  https_only                    = true
  app_settings                  = var.app_settings
  tags                          = var.tags

  dynamic "identity" {
    for_each = var.identity[*]
    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }
  site_config {
    application_stack {
      dotnet_version = var.runtime.dotnet_version
      java_version   = var.runtime.java_version
      node_version   = var.runtime.node_version
    }
    dynamic "cors" {
      for_each = var.cors[*]
      content {
        allowed_origins     = cors.value.allowed_origins
        support_credentials = cors.value.support_credentials
      }
    }
    dynamic "ip_restriction" {
      for_each = var.inbound_ip_filtering[*]
      content {
        ip_address = ip_restriction.value.ip_address
        name       = ip_restriction.value.name
        priority   = ip_restriction.value.priority
        action     = "Allow"
      }
    }
    always_on                              = var.always_on
    application_insights_connection_string = var.app_insights.connection_string
    application_insights_key               = var.app_insights.instrumentation_key
  }

  lifecycle {
    # network integration should be done with the `azurerm_app_service_virtual_network_swift_connection` resource
    # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_virtual_network_swift_connection
    ignore_changes = [virtual_network_subnet_id]
  }
}