# On-demand failures for testing enforcement behaviour without editing code.
#
# Trigger by either:
#   * putting the keyword in brackets in the run message, e.g. "test [opa-fail]"
#     (the "Reason for starting run" field in the UI, a VCS commit message,
#     or the "message" attribute when creating a run through the API), or
#   * adding a workspace tag with the same name (opa-warn / opa-fail).
package terraform.policies.canary

import data.terraform.lib
import future.keywords.contains
import future.keywords.if

# Advisory canary -> query: data.terraform.policies.canary.warn
warn contains msg if {
	lib.triggered("opa-warn")
	msg := sprintf(
		"Canary (advisory) triggered on workspace %q. This is a deliberate test warning; the run is not blocked.",
		[lib.workspace_name],
	)
}

# Mandatory canary -> query: data.terraform.policies.canary.fail
fail contains msg if {
	lib.triggered("opa-fail")
	msg := sprintf(
		"Canary (mandatory) triggered on workspace %q. This is a deliberate test failure; override it or remove the trigger.",
		[lib.workspace_name],
	)
}
