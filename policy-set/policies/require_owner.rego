# Blocks terraform_data resources that do not declare a non-empty owner in
# their input. terraform_data is built into Terraform (>= 1.4), so this policy
# can be exercised without any provider credentials.
package terraform.policies.require_owner

import data.terraform.lib
import future.keywords.contains
import future.keywords.if
import future.keywords.in

deny contains msg if {
	some rc in lib.managed_changes
	rc.type == "terraform_data"
	rc.change.after != null
	not has_owner(rc.change.after)
	msg := sprintf("%s is missing a non-empty input.owner value.", [rc.address])
}

has_owner(after) if {
	owner := after.input.owner
	is_string(owner)
	trim_space(owner) != ""
}
