# ---------------------------------------------------------------------------
# OPA policy set for exercising Terraform Enterprise policy enforcement.
#
# Each block maps a policy name to an OPA query. TFE evaluates the query
# against {"plan": ..., "run": ...}. An empty array = pass; any element = fail.
#
# Enforcement levels:
#   advisory  -> failure is shown as a warning, run continues
#   mandatory -> failure stops the run (overridable if the set allows overrides)
# ---------------------------------------------------------------------------

# --- Wiring / sanity ---------------------------------------------------------

policy "always-pass" {
  query             = "data.terraform.policies.always_pass.deny"
  enforcement_level = "advisory"
  description       = "Always passes. Proves the set loads, compiles, and evaluates."
}

# --- On-demand canaries (no config changes needed to trigger) ---------------

policy "canary-advisory" {
  query             = "data.terraform.policies.canary.warn"
  enforcement_level = "advisory"
  description       = "Fails (warning only) when the run message contains [opa-warn] or the workspace is tagged opa-warn."
}

policy "canary-mandatory" {
  query             = "data.terraform.policies.canary.fail"
  enforcement_level = "mandatory"
  description       = "Fails and blocks the run when the run message contains [opa-fail] or the workspace is tagged opa-fail."
}

# --- Run data (input.run) ----------------------------------------------------

policy "block-auto-apply" {
  query             = "data.terraform.policies.block_auto_apply.deny"
  enforcement_level = "advisory"
  description       = "Warns when the workspace Apply Method is set to auto-apply."
}

policy "sensitive-variables" {
  query             = "data.terraform.policies.sensitive_variables.deny"
  enforcement_level = "advisory"
  description       = "Warns when a variable whose name looks like a secret is not marked sensitive."
}

# --- Plan data (input.plan) --------------------------------------------------

policy "max-new-resources" {
  query             = "data.terraform.policies.max_resources.deny"
  enforcement_level = "mandatory"
  description       = "Blocks runs that create more than 10 new resources."
}

policy "require-owner" {
  query             = "data.terraform.policies.require_owner.deny"
  enforcement_level = "mandatory"
  description       = "Blocks terraform_data resources whose input has no non-empty owner."
}

policy "no-public-ingress" {
  query             = "data.terraform.policies.no_public_ingress.deny"
  enforcement_level = "mandatory"
  description       = "Blocks AWS security group rules that allow ingress from 0.0.0.0/0 or ::/0."
}

# --- Plan + run data combined -----------------------------------------------

policy "protect-deletes" {
  query             = "data.terraform.policies.protect_deletes.deny"
  enforcement_level = "mandatory"
  description       = "Blocks deletes and replacements unless the run is an explicit destroy run."
}
