# Shared helpers imported by every policy in this set.
#
# Keeping these in a separate file/package also verifies that TFE compiles
# every .rego file in the set and resolves queries across files.
package terraform.lib

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# ---------------------------------------------------------------------------
# Plan helpers (input.plan)
# ---------------------------------------------------------------------------

# Every resource change in the plan; empty array when there are none.
resource_changes := [rc | some rc in input.plan.resource_changes]

# Only managed resources (excludes data sources).
managed_changes := [rc |
	some rc in resource_changes
	rc.mode == "managed"
]

# A brand-new resource (not a replacement).
is_create(rc) if rc.change.actions == ["create"]

# Any change that removes the existing object: delete or replace.
is_delete(rc) if "delete" in rc.change.actions

# Replacement = delete + create, in either order.
is_replace(rc) if {
	"delete" in rc.change.actions
	"create" in rc.change.actions
}

# ---------------------------------------------------------------------------
# Run helpers (input.run)
# ---------------------------------------------------------------------------

default run_message := ""

run_message := input.run.message if is_string(input.run.message)

default workspace_name := "unknown"

workspace_name := input.run.workspace.name if is_string(input.run.workspace.name)

workspace_tags := {t | some t in input.run.workspace.tags}

is_destroy_run if input.run.is_destroy == true

# A canary keyword is "triggered" when the run message contains "[keyword]"
# or the workspace carries a tag named "keyword".
triggered(keyword) if contains(run_message, sprintf("[%s]", [keyword]))

triggered(keyword) if keyword in workspace_tags
