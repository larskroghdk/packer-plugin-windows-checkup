packer {
  required_plugins {
    windows-checkup = {
      source  = "github.com/larskroghdk/windows-checkup"
      version = ">= 0.1.0"
    }
  }
}

variable "winrm_host" { type = string }
variable "winrm_username" { type = string }
variable "winrm_password" {
  type      = string
  sensitive = true
}

source "null" "windows" {
  communicator   = "winrm"
  winrm_host     = var.winrm_host
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
}

build {
  sources = ["source.null.windows"]
  provisioner "windows-checkup" {
    report_path                   = "reports/windows-checkup.json"
    report_format                 = "json"
    fail_on_noncompliance         = false
    fail_on_error                 = false
    minimum_compliance_percentage = 0
    severity_threshold            = "Low"
  }
}
