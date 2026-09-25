package terraform.policies.always_pass_test

import data.terraform.policies.always_pass
import future.keywords.if

test_always_empty if {
	always_pass.deny == [] with input as {}
	always_pass.deny == [] with input as {"plan": {"resource_changes": [{"x": 1}]}, "run": {"message": "[opa-fail]"}}
}
