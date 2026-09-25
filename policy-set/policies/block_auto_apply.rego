# Warns when the workspace is configured to auto-apply successful plans.
# Adapted from the block_auto_apply_runs example in the TFE OPA docs.
package terraform.policies.block_auto_apply

import data.terraform.lib
import future.keywords.contains
import future.keywords.if

deny contains msg if {
	input.run.workspace.auto_apply == true
	msg := sprintf(
		"Workspace %q has auto-apply enabled. Change the Apply Method to 'Manual apply'.",
		[lib.workspace_name],
	)
}
