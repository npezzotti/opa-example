# Blocks deletes and replacements during normal runs. Explicit destroy runs
# (input.run.is_destroy == true) are allowed so the test workspace can still
# be cleaned up. Combines plan data with run data in a single policy.
package terraform.policies.protect_deletes

import data.terraform.lib
import future.keywords.contains
import future.keywords.if
import future.keywords.in

deny contains msg if {
	not lib.is_destroy_run
	some rc in lib.managed_changes
	lib.is_delete(rc)
	msg := sprintf(
		"%s would be %s. Deletions are only allowed in destroy runs.",
		[rc.address, verb(rc)],
	)
}

verb(rc) := "replaced" if lib.is_replace(rc)

else := "deleted"
