variable location {
  type = string

  validation {
    condition     = contains(["uksouth", "ukwest"], lower(var.location))
    error_message = "Unsupported Azure Region specified. Supported regions include: uksouth, ukwest."
  }
}

variable environment {
  type = string

  validation {
    condition     = contains(["dev", "test", "prod"], lower(var.environment))
    error_message = "Unsupported environment specified. Supported environments include: devtest, uat, prod."
  }
}

variable product_name {
  type        = string
  description = "The product name to use"

  validation {
    condition     = contains(["cdsfnhs", "futurenhs"], lower(var.product_name))
    error_message = "Unsupported product_name specified. Supported product_name include: cdsfnhs, futurenhs."
  }
}

variable sqlserver_admin_email {
  type = string
  #sensitive = true

  #validation {
  #  condition     = length(regexall("/^w+[+.w-]*@([w-]+.)*w+[w-]*.([a-z]{2,4}|d+)$/i", var.sqlserver_admin_email)) > 0
  #  error_message = "The sqlserver_admin_email variable must contain an email address."
  #}
}

variable security_center_contact_email {
  type = string
  #sensitive = true

  #validation {
  #  condition     = length(regexall("/^w+[+.w-]*@([w-]+.)*w+[w-]*.([a-z]{2,4}|d+)$/i", var.sqlserver_admin_email)) > 0
  #  error_message = "The sqlserver_admin_email variable must contain an email address."
  #}
}