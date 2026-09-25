package terraform.policies.run_data_test

import data.terraform.policies.block_auto_apply
import data.terraform.policies.sensitive_variables
import future.keywords.if

# --- block_auto_apply -------------------------------------------------------

test_auto_apply_true_warns if {
	count(block_auto_apply.deny) == 1 with input as {"run": {"workspace": {"name": "ws", "auto_apply": true}}}
}

test_auto_apply_false_passes if {
	count(block_auto_apply.deny) == 0 with input as {"run": {"workspace": {"name": "ws", "auto_apply": false}}}
}

test_auto_apply_missing_passes if {
	count(block_auto_apply.deny) == 0 with input as {"run": {"workspace": {"name": "ws"}}}
}

# --- sensitive_variables ----------------------------------------------------

test_secret_like_non_sensitive_warns if {
	vars := {
		"db_password": {"category": "input", "sensitive": false},
		"GITHUB_TOKEN": {"category": "environment", "sensitive": false},
		"region": {"category": "input", "sensitive": false},
	}
	count(sensitive_variables.deny) == 2 with input as {"run": {"variables": vars}}
}

test_secret_like_sensitive_passes if {
	vars := {"api_key": {"category": "input", "sensitive": true}}
	count(sensitive_variables.deny) == 0 with input as {"run": {"variables": vars}}
}

test_no_variables_passes if {
	count(sensitive_variables.deny) == 0 with input as {"run": {}}
}
