# Blocks plans that create more than max_new_resources brand-new resources.
# Replacements are not counted (see protect_deletes for those).
package terraform.policies.max_resources

import data.terraform.lib
import future.keywords.contains
import future.keywords.if
import future.keywords.in

max_new_resources := 10

new_resources := [rc.address |
	some rc in lib.managed_changes
	lib.is_create(rc)
]

deny contains msg if {
	count(new_resources) > max_new_resources
	msg := sprintf(
		"Plan creates %d new resources; at most %d are allowed per run.",
		[count(new_resources), max_new_resources],
	)
}
