# Warns when a workspace/run variable looks like a secret but is not marked
# sensitive. input.run.variables maps each variable name to
# {"category": "input" | "environment", "sensitive": bool}.
package terraform.policies.sensitive_variables

import future.keywords.contains
import future.keywords.if
import future.keywords.in

secret_name_pattern := `(?i)(password|passwd|secret|token|api_?key|private_?key|access_?key)`

deny contains msg if {
	some name, v in input.run.variables
	regex.match(secret_name_pattern, name)
	not v.sensitive
	msg := sprintf(
		"Variable %q (%s) looks like a secret but is not marked sensitive.",
		[name, object.get(v, "category", "unknown")],
	)
}
