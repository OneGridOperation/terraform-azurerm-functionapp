locals {
  tags = {
    "MaintainerName"  = "Tore Eide Andersen"
    "MaintainerEmail" = "tore.eide.andersen@tensio.no"
    "CreatedBy"       = "Terraform"
  }
}

module "resource_group" {
  source = "github.com/onegridoperation/terraform-azurerm-resourcegroup.git?ref=v1.0.0"

  location          = "norwayeast"
  environment       = "test"
  tags              = local.tags
  app_name          = "functionapp"
  system_short_name = "tc"
}

module "service_plan" {
  source = "github.com/onegridoperation/terraform-azurerm-serviceplan.git?ref=v1.0.0"

  resource_group    = module.resource_group
  environment       = "test"
  os_type           = "Linux"
  sku_name          = "P1v3"
  tags              = local.tags
  app_name          = "functionapp"
  system_short_name = "tf"
}

module "functionapp" {
  source = "../"

  resource_group    = module.resource_group
  service_plan      = module.service_plan
  environment       = "test"
  system_short_name = "tf"
  app_name          = "functionapp"
  storage_account = {
    app_short_name = "functionapp"
  }
  runtime = {
    java_version = "17"
  }
  inbound_ip_filtering = [
    {
      ip_address = "0.0.0.0/0"
      priority   = 1000
      name       = "allow_all"
      }, {
      ip_address = "1.2.3.4/32"
      priority   = 1100
      name       = "allow_only"
    }
  ]
  tags = local.tags
}
