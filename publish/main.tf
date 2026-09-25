# Optional: publish ../policy-set to Terraform Enterprise without a VCS
# connection. The tfe_slug data source packages the directory and
# tfe_policy_set uploads it as a new policy set version on every change.
#
#   export TFE_TOKEN=<token with Manage Policies permission>
#   terraform init
#   terraform apply -var 'tfe_hostname=tfe.example.com' -var 'organization=my-org'
#
# The target workspace(s) must already exist (running `terraform init` in
# ../test-workspace creates opa-policy-test automatically).

terraform {
  required_version = ">= 1.4.0"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = ">= 0.60.0"
    }
  }
}

variable "tfe_hostname" {
  description = "TFE hostname, e.g. tfe.example.com"
  type        = string
}

variable "organization" {
  description = "TFE organization name"
  type        = string
}

variable "workspace_names" {
  description = "Workspaces to attach the policy set to"
  type        = list(string)
  default     = ["opa-policy-test"]
}

variable "opa_version" {
  description = "OPA runtime version to pin (pick one from the policy set's Runtime version list in the UI). null uses the TFE default."
  type        = string
  default     = null
}

provider "tfe" {
  hostname = var.tfe_hostname
}

data "tfe_slug" "opa_test" {
  source_path = "${path.module}/../policy-set"
}

resource "tfe_policy_set" "opa_test" {
  name                = "opa-functional-test"
  description         = "Test policy set for validating OPA policy enforcement in TFE."
  organization        = var.organization
  kind                = "opa"
  overridable         = true
  policy_tool_version = var.opa_version
  slug                = data.tfe_slug.opa_test
}

data "tfe_workspace_ids" "targets" {
  names        = var.workspace_names
  organization = var.organization
}

resource "tfe_workspace_policy_set" "targets" {
  for_each = data.tfe_workspace_ids.targets.ids

  policy_set_id = tfe_policy_set.opa_test.id
  workspace_id  = each.value
}

output "policy_set_id" {
  value = tfe_policy_set.opa_test.id
}
