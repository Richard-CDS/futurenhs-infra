data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                                   = "kv-${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}"     # max of 23 characters
  location                               = var.location
  resource_group_name                    = var.resource_group_name
  tenant_id                              = data.azurerm_client_config.current.tenant_id
  enabled_for_deployment                 = true
  enabled_for_disk_encryption            = false
  enabled_for_template_deployment        = false
  soft_delete_retention_days             = 90
  purge_protection_enabled               = true

  sku_name = "standard"

  # network_acls {} #TODO  



  # There is a dependency between the key vault access policies and the managed identity of the services that use it to host their secrets.  
  # Unfortunately, this means we have to create access policies when the vault is created (which means we need the identities of the consuming services) otherwise we run into 
  # problems where the deployment pipeline cannot manage the secrets using these terraform scripts.  
  # We cannot combine assigning an access policy for the pipeline at the point of creation and use of the azurerm_key_vault_access_policy resource because this creates conflicts that 
  # results in the terraform planning stage being unable to identify a policy will be dropped.  Instead, we end up dropping it and then adding it the next time 
  # the deployment pipeline runs, but in the meantime leaving services hanging because they no longer have permission to read the key vault.  
  # Best compromise I can come up with is for the depending services to be created before the key vault which means any key vault references they need must be hard coded
  # rather than given to them by the modules that manage those secrets (whom in turn depend on key vault to have been created).  Must be a better way but can't yet see what that is!

  # We can add up to 16 access policies.  Going to be a difficult problem to solve if we need to exceed this figure (multiple key vaults?).

  # 1. The service principal (pipeline/user logged into azure) running the terrafrom scripts needs access to manage secrets once the vault is created

  access_policy {
    tenant_id                            = data.azurerm_client_config.current.tenant_id
    object_id                            = data.azurerm_client_config.current.object_id

    certificate_permissions = [
      "Backup", "Create", "Delete", "DeleteIssuers", "Get", "GetIssuers", "Import", "List", "ListIssuers", "ManageContacts", "ManageIssuers", "Purge", "Recover", "Restore", "SetIssuers", "Update"
    ]

    key_permissions = [
      "Backup", "Create", "Decrypt", "Delete", "Encrypt", "Get", "Import", "List", "Purge", "Recover", "Restore", "Sign", "UnwrapKey", "Update", "Verify", "WrapKey"
    ]

    secret_permissions = [
      "Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"
    ]

    storage_permissions = [
      "Backup", "Delete", "DeleteSAS", "Get", "GetSAS", "List", "ListSAS", "Purge", "Recover", "RegenerateKey", "Restore", "Set", "SetSAS", "Update"
    ]
  }

  # 2. The app-service hosting the core/forum code uses a kv reference to lookup database connection string

  access_policy {
    tenant_id                            = data.azurerm_client_config.current.tenant_id
    object_id                            = var.principal_id_forum_app_svc

    secret_permissions = [
      "Get"
    ]
  }

  # 3. The app configuration service which may expose secrets to clients using key vault references

  access_policy {
    tenant_id                            = data.azurerm_client_config.current.tenant_id
    object_id                            = var.principal_id_app_configuration_svc

    certificate_permissions = [
      "Get", "List"
    ]

    key_permissions = [
      "Get", "List"
    ]

    secret_permissions = [
      "Get", "List"
    ]
  }

  # 4. The application gateway on the default subnet of the virtual network through which all public incoming traffic is routed.  It needs access to the 
  #    key vault to pull out the certificate it uses to manage HTTPS connnections

  access_policy {
    tenant_id                            = data.azurerm_client_config.current.tenant_id
    object_id                            = var.principal_id_app_gateway_svc 

    certificate_permissions = [
      "Get"
    ]

    secret_permissions = [
      "Get"				 # TODO - Remove secret perms once I've figured out how to hook up directly to certificate using key vault references
    ]
  }
}

# Create a temporary self-signed certificate that the application gateway can use for HTTPS management.  This will eventually be replaced by a certificate we 
# generate for a specific wildcard domain using something like LetsEncrypt, and oush direct to the key vault as it is renewed.  This lifecycle will be managed
# outside of this terraform script

resource "azurerm_key_vault_certificate" "app_forum_https" {
  name                                   = "futurenhs-website"
  key_vault_id                           = azurerm_key_vault.main.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"] # Server authentication

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject_alternative_names {
        dns_names = ["app-${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-forum.azurewebsites.net"]
      }

      subject            = "CN=app-${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-forum.azurewebsites.net"
      validity_in_months = 3
    }
  }
}