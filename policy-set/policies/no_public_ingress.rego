# Blocks AWS security group rules that allow ingress from anywhere.
# Extends the public_ingress example from the TFE OPA docs to cover inline
# rules, aws_security_group_rule, aws_vpc_security_group_ingress_rule, and IPv6.
# Passes trivially when the plan has no AWS security group resources.
package terraform.policies.no_public_ingress

import data.terraform.lib
import future.keywords.contains
import future.keywords.if
import future.keywords.in

open_cidrs := {"0.0.0.0/0", "::/0"}

# Inline ingress blocks on aws_security_group.
deny contains msg if {
	some rc in lib.managed_changes
	rc.type == "aws_security_group"
	some rule in rc.change.after.ingress
	some cidr in cidrs(rule)
	cidr in open_cidrs
	msg := sprintf("%s allows ingress from %s.", [rc.address, cidr])
}

# Standalone aws_security_group_rule of type "ingress".
deny contains msg if {
	some rc in lib.managed_changes
	rc.type == "aws_security_group_rule"
	rc.change.after.type == "ingress"
	some cidr in cidrs(rc.change.after)
	cidr in open_cidrs
	msg := sprintf("%s allows ingress from %s.", [rc.address, cidr])
}

# Newer aws_vpc_security_group_ingress_rule resource.
deny contains msg if {
	some rc in lib.managed_changes
	rc.type == "aws_vpc_security_group_ingress_rule"
	some attr in ["cidr_ipv4", "cidr_ipv6"]
	cidr := rc.change.after[attr]
	cidr in open_cidrs
	msg := sprintf("%s allows ingress from %s.", [rc.address, cidr])
}

# Union of IPv4 and IPv6 CIDRs on a rule; tolerates null/missing lists.
cidrs(rule) := {c | some c in rule.cidr_blocks} | {c | some c in rule.ipv6_cidr_blocks}
