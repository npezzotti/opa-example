# OPA Policy Set Test Kit for Terraform Enterprise

A small, self-contained OPA policy set designed to exercise every part of TFE's OPA
policy enforcement: loading and compiling a multi-file set, reading both `input.plan`
and `input.run`, advisory vs. mandatory enforcement, overrides, and destroy runs.
Every policy can be flipped from pass to fail on demand, and the companion Terraform
config needs no cloud credentials.

```
policy-set/                  <- the policy set TFE loads (set "Policies path" to this)
├── policies.hcl             <- policy names, queries, enforcement levels
├── lib/terraform_lib.rego   <- shared helpers (tests cross-file query resolution)
└── policies/*.rego          <- one file per policy
tests/*_test.rego            <- `opa test` unit tests (32 tests)
mocks/{pass,fail,destroy}.json  <- sample TFE policy inputs
scripts/eval-policy-set.sh   <- evaluates policies.hcl locally like TFE does
test-workspace/main.tf       <- credential-free config to trigger each policy
└── publish/main.tf              <- optional: upload the set with the tfe provider
```

## Policies

| Policy | Level | Reads | Fails when |
|---|---|---|---|
| `always-pass` | advisory | nothing | never (wiring check) |
| `canary-advisory` | advisory | `run.message`, `run.workspace.tags` | run message contains `[opa-warn]` or workspace tagged `opa-warn` |
| `canary-mandatory` | mandatory | `run.message`, `run.workspace.tags` | run message contains `[opa-fail]` or workspace tagged `opa-fail` |
| `block-auto-apply` | advisory | `run.workspace.auto_apply` | workspace Apply Method is auto-apply |
| `sensitive-variables` | advisory | `run.variables` | a variable named like `*password*`, `*token*`, `*secret*`, `*api_key*` is not sensitive |
| `max-new-resources` | mandatory | `plan.resource_changes` | more than 10 new resources in one run |
| `require-owner` | mandatory | `plan.resource_changes` | a `terraform_data` resource has an empty/missing `input.owner` |
| `no-public-ingress` | mandatory | `plan.resource_changes` | an AWS SG rule allows `0.0.0.0/0` or `::/0` (passes if no AWS resources) |
| `protect-deletes` | mandatory | `plan` + `run.is_destroy` | a delete or replace happens outside a destroy run |

The Rego uses `import future.keywords.*` rather than `import rego.v1`, so it compiles on
every runtime from OPA 0.46 through 1.x. It was verified with `opa check --strict` and
`opa test` on 0.46.1, 0.61.0, 0.70.0, and 1.4.2.

## Deploy to TFE

First create the workspace: set `hostname` and `organization` in
`test-workspace/main.tf`, then run `terraform login <hostname>` and `terraform init`
in that directory. The cloud block creates `opa-policy-test` for you.

**Option A: VCS.** Push this repo, then in TFE go to Settings → Policies →
Connect a new policy set. Choose OPA as the framework, set Policies path to
`policy-set`, scope it to the `opa-policy-test` workspace, pin a Runtime version, and
enable Overrides so you can test the override flow.

**Option B: tfe provider (no VCS).**

```sh
cd publish
export TFE_TOKEN=...          # needs Manage Policies permission
terraform init
terraform apply -var tfe_hostname=tfe.example.com -var organization=my-org
```

Re-running `apply` after editing any `.rego` file uploads a new policy set version.

## Test scenarios

Run these from `test-workspace/`. Start with the baseline so later scenarios have
existing state to change.

| # | Scenario | How | Expected |
|---|---|---|---|
| 1 | Baseline | `terraform apply` | all 9 pass; apply proceeds |
| 2 | Advisory failure | UI: Start new run with reason `check [opa-warn]` | `canary-advisory` warns; run is not blocked |
| 3 | Mandatory failure + override | UI: Start new run with reason `check [opa-fail]` | `canary-mandatory` fails; run stops until someone with Manage Policy Overrides overrides it |
| 4 | Run data: workspace setting | Settings → General → Apply Method: Auto apply, then run | `block-auto-apply` warns |
| 5 | Run data: variables | Add env var `DEMO_API_TOKEN` (not sensitive), then run | `sensitive-variables` warns; mark it sensitive and it passes |
| 6 | Plan data: count | `terraform apply -var resource_count=15` | `max-new-resources` fails (12 new) |
| 7 | Plan data: attribute | `terraform apply -var owner=""` | `require-owner` fails (in-place update) |
| 8 | Plan + run: replace | `terraform apply -var revision=2` | `protect-deletes` fails (3 replacements) |
| 9 | Plan + run: delete | `terraform apply -var resource_count=1` | `protect-deletes` fails (2 deletions) |
| 10 | Destroy run allowed | `terraform destroy` | all pass; `protect-deletes` exempts destroy runs |

A few notes on these. CLI-driven runs always get a fixed run message, so for scenarios
2 and 3 either use the UI's reason field, a VCS commit message, or the `message`
attribute in the Runs API; alternatively add a workspace tag named `opa-warn` or
`opa-fail`. If `-var` isn't accepted for your CLI/TFE combination, set the same values
as workspace Terraform variables instead. Scenario 3 is the key one for validating that
the Overrides setting on the policy set behaves as you expect.

## Local testing

```sh
# Unit tests (use the OPA version your policy set is pinned to)
opa test policy-set tests -v

# Evaluate every policy in policies.hcl, TFE-style; exit 1 on mandatory failure
scripts/eval-policy-set.sh mocks/pass.json
scripts/eval-policy-set.sh mocks/fail.json      # trips all 8 non-trivial policies
scripts/eval-policy-set.sh mocks/destroy.json
OPA=/path/to/opa-0.61 scripts/eval-policy-set.sh mocks/fail.json
```

To test against a real plan, download the JSON plan from a run (the
Retrieve JSON Execution Plan endpoint) and wrap it with run data:

```sh
curl -sL -H "Authorization: Bearer $TFE_TOKEN" \
  https://tfe.example.com/api/v2/runs/run-XXXX/plan/json-output > plan.json

jq '{plan: ., run: {message: "local test", is_destroy: false,
     workspace: {name: "opa-policy-test", auto_apply: false, tags: []},
     variables: {}}}' plan.json > input.json

scripts/eval-policy-set.sh input.json
```

## Adapting

Thresholds live at the top of each policy (`max_new_resources`, `open_cidrs`,
`secret_name_pattern`). To add a policy, write a package under `policy-set/policies/`
that produces a set of messages, then add a `policy` block to `policies.hcl` whose
query points at that rule. An empty result passes; anything else fails at the block's
`enforcement_level` (default `advisory`).
# opa-example
