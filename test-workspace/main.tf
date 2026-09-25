# Minimal, credential-free configuration for exercising the OPA policy set.
#
# Uses only the built-in terraform_data resource (Terraform >= 1.4), so it runs
# on any TFE instance, including air-gapped ones, with no provider downloads.
# Each variable below flips one policy from pass to fail. See README.md.

terraform {
  required_version = ">= 1.4.0"

  cloud {
    hostname     = "tfe-release-2-1-x.ptfe-dev.aws.ptfedev.com" # <- your TFE hostname
    organization = "nathanp-test"          # <- your organization

    workspaces {
      name = "opa-policy-test"
    }
  }
}

variable "resource_count" {
  description = "Number of terraform_data resources. Creating more than 10 NEW ones in one run trips max-new-resources; lowering it trips protect-deletes."
  type        = number
  default     = 3
}

variable "owner" {
  description = "Written into each resource's input.owner. Set to \"\" to trip require-owner."
  type        = string
  default     = "platform-team"
}

variable "revision" {
  description = "Changing this after the first apply forces every resource to be replaced, which trips protect-deletes."
  type        = string
  default     = "1"
}

resource "terraform_data" "example" {
  count = var.resource_count

  input = {
    owner = var.owner
    index = count.index
  }

  triggers_replace = [var.revision]
}

output "resources" {
  value = terraform_data.example[*].output
}
