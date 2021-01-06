terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # Root module should specify the maximum provider version
      # The ~> operator is a convenient shorthand for allowing only patch releases within a specific minor release.
      version = "~> 2.26"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "resource_group" {
  name = "${var.project}-${var.environment}-resource-group"
  location = var.location
}

resource "azurerm_storage_account" "storage_account" {
  name = "${var.project}${var.environment}storage"
  resource_group_name = azurerm_resource_group.resource_group.name
  location = var.location
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "app_service_plan" {
  name                = "${var.project}-${var.environment}-app-service-plan"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = var.location
  kind                = "elastic"
  reserved            = true
  sku {
    tier = "ElasticPremium"
    size = "EP1"
  }
}

resource "azurerm_function_app" "function_app" {
  name                       = "${var.project}-${var.environment}-function-app"
  resource_group_name        = azurerm_resource_group.resource_group.name
  location                   = var.location
  app_service_plan_id        = azurerm_app_service_plan.app_service_plan.id
  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE"       = "",
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE"   = true,
    "FUNCTIONS_WORKER_RUNTIME"              = "node",
  }
  os_type = "linux"
  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key
  version                    = "~3"
  
  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}

resource "azurerm_api_management" "api_management" {
  name                = "${var.project}-${var.environment}-api-management"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = var.location
  publisher_name      = "MaxIvanov"
  publisher_email     = "hello@maxivanov.io"
  sku_name            = "Developer_1" # Support for Consumption_0 arrives in hashicorp/azurerm v2.42.0
}

resource "azurerm_api_management_api" "api_management_api_public" {
  name                  = "${var.project}-${var.environment}-api-management-api-public"
  api_management_name   = azurerm_api_management.api_management.name
  resource_group_name   = azurerm_resource_group.resource_group.name
  revision              = "1"
  display_name          = "Public"
  path                  = ""
  protocols             = ["https"]
  service_url           = "https://${azurerm_function_app.function_app.default_hostname}/api"
  subscription_required = false
}

resource "azurerm_api_management_api_operation" "api_management_api_operation_public_hello_world" {
  operation_id        = "public-hello-world"
  api_name            = azurerm_api_management_api.api_management_api_public.name
  api_management_name = azurerm_api_management.api_management.name
  resource_group_name = azurerm_resource_group.resource_group.name
  display_name        = "Hello World API endpoint"
  method              = "GET"
  url_template        = "/hello-world"
}