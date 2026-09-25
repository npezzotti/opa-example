package terraform.policies.plan_data_test

import data.terraform.policies.max_resources
import data.terraform.policies.no_public_ingress
import data.terraform.policies.protect_deletes
import data.terraform.policies.require_owner
import future.keywords.if
import future.keywords.in

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

tf_data(i, actions, owner) := {
	"address": sprintf("terraform_data.example[%d]", [i]),
	"mode": "managed",
	"type": "terraform_data",
	"change": {"actions": actions, "after": {"input": {"owner": owner}}},
}

tf_data_deleted(i) := {
	"address": sprintf("terraform_data.example[%d]", [i]),
	"mode": "managed",
	"type": "terraform_data",
	"change": {"actions": ["delete"], "after": null},
}

creates(n) := [tf_data(i, ["create"], "team") | some i in numbers.range(1, n)]

plan_input(rcs) := {"plan": {"resource_changes": rcs}, "run": {"is_destroy": false}}

# ---------------------------------------------------------------------------
# max_resources
# ---------------------------------------------------------------------------

test_ten_creates_passes if {
	count(max_resources.deny) == 0 with input as plan_input(creates(10))
}

test_eleven_creates_fails if {
	count(max_resources.deny) == 1 with input as plan_input(creates(11))
}

test_replacements_not_counted_as_new if {
	rcs := [tf_data(i, ["delete", "create"], "team") | some i in numbers.range(1, 15)]
	count(max_resources.deny) == 0 with input as plan_input(rcs)
}

test_data_sources_ignored if {
	rcs := [{"address": sprintf("data.x.y[%d]", [i]), "mode": "data", "change": {"actions": ["create"]}} |
		some i in numbers.range(1, 20)
	]
	count(max_resources.deny) == 0 with input as plan_input(rcs)
}

# ---------------------------------------------------------------------------
# require_owner
# ---------------------------------------------------------------------------

test_owner_present_passes if {
	count(require_owner.deny) == 0 with input as plan_input([tf_data(1, ["create"], "team")])
}

test_owner_empty_fails if {
	count(require_owner.deny) == 1 with input as plan_input([tf_data(1, ["create"], "  ")])
}

test_owner_missing_fails if {
	rc := {"address": "terraform_data.x", "mode": "managed", "type": "terraform_data", "change": {"actions": ["update"], "after": {"input": {}}}}
	count(require_owner.deny) == 1 with input as plan_input([rc])
}

test_owner_not_checked_on_delete if {
	count(require_owner.deny) == 0 with input as plan_input([tf_data_deleted(1)])
}

# ---------------------------------------------------------------------------
# protect_deletes
# ---------------------------------------------------------------------------

test_delete_in_normal_run_fails if {
	count(protect_deletes.deny) == 1 with input as plan_input([tf_data_deleted(1)])
}

test_replace_in_normal_run_fails if {
	msgs := protect_deletes.deny with input as plan_input([tf_data(1, ["create", "delete"], "team")])
	msgs == {"terraform_data.example[1] would be replaced. Deletions are only allowed in destroy runs."}
}

test_delete_in_destroy_run_passes if {
	inp := {"plan": {"resource_changes": [tf_data_deleted(1)]}, "run": {"is_destroy": true}}
	count(protect_deletes.deny) == 0 with input as inp
}

test_updates_pass if {
	count(protect_deletes.deny) == 0 with input as plan_input([tf_data(1, ["update"], "team")])
}

# ---------------------------------------------------------------------------
# no_public_ingress
# ---------------------------------------------------------------------------

sg(ingress) := {
	"address": "aws_security_group.web",
	"mode": "managed",
	"type": "aws_security_group",
	"change": {"actions": ["create"], "after": {"ingress": ingress}},
}

test_inline_ipv4_open_fails if {
	rcs := [sg([{"cidr_blocks": ["0.0.0.0/0"], "ipv6_cidr_blocks": null}])]
	count(no_public_ingress.deny) == 1 with input as plan_input(rcs)
}

test_inline_ipv6_open_fails if {
	rcs := [sg([{"cidr_blocks": [], "ipv6_cidr_blocks": ["::/0"]}])]
	count(no_public_ingress.deny) == 1 with input as plan_input(rcs)
}

test_inline_private_passes if {
	rcs := [sg([{"cidr_blocks": ["10.0.0.0/8"]}])]
	count(no_public_ingress.deny) == 0 with input as plan_input(rcs)
}

test_sg_rule_ingress_open_fails if {
	rc := {"address": "aws_security_group_rule.r", "mode": "managed", "type": "aws_security_group_rule", "change": {"actions": ["create"], "after": {"type": "ingress", "cidr_blocks": ["0.0.0.0/0"]}}}
	count(no_public_ingress.deny) == 1 with input as plan_input([rc])
}

test_sg_rule_egress_open_passes if {
	rc := {"address": "aws_security_group_rule.r", "mode": "managed", "type": "aws_security_group_rule", "change": {"actions": ["create"], "after": {"type": "egress", "cidr_blocks": ["0.0.0.0/0"]}}}
	count(no_public_ingress.deny) == 0 with input as plan_input([rc])
}

test_vpc_ingress_rule_open_fails if {
	rc := {"address": "aws_vpc_security_group_ingress_rule.r", "mode": "managed", "type": "aws_vpc_security_group_ingress_rule", "change": {"actions": ["create"], "after": {"cidr_ipv4": "0.0.0.0/0", "cidr_ipv6": null}}}
	count(no_public_ingress.deny) == 1 with input as plan_input([rc])
}

test_deleted_open_sg_passes if {
	rc := {"address": "aws_security_group.web", "mode": "managed", "type": "aws_security_group", "change": {"actions": ["delete"], "after": null}}
	count(no_public_ingress.deny) == 0 with input as plan_input([rc])
}
