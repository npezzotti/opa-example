package terraform.policies.canary_test

import data.terraform.policies.canary
import future.keywords.if

test_no_trigger_passes if {
	count(canary.warn) == 0 with input as {"run": {"message": "routine run", "workspace": {"tags": []}}}
	count(canary.fail) == 0 with input as {"run": {"message": "routine run", "workspace": {"tags": []}}}
}

test_warn_via_message if {
	count(canary.warn) == 1 with input as {"run": {"message": "try it [opa-warn]"}}
	count(canary.fail) == 0 with input as {"run": {"message": "try it [opa-warn]"}}
}

test_fail_via_message if {
	count(canary.fail) == 1 with input as {"run": {"message": "try it [opa-fail]"}}
}

test_fail_via_workspace_tag if {
	count(canary.fail) == 1 with input as {"run": {"message": "", "workspace": {"tags": ["opa-fail"]}}}
}

test_keyword_without_brackets_does_not_trigger if {
	count(canary.fail) == 0 with input as {"run": {"message": "mentions opa-fail in passing"}}
}

test_null_message_is_safe if {
	count(canary.fail) == 0 with input as {"run": {"message": null, "workspace": {"tags": null}}}
}
