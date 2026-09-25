# Sanity-check policy. Always returns an empty array, so it always passes.
# If this shows up as "Passed" in the run's policy results, TFE fetched the
# set, compiled every .rego file, and evaluated a query successfully.
package terraform.policies.always_pass

deny := []
