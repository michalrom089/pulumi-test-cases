# One stack per case. The key is the stack name suffix.
#
# project_root  is the directory with the Pulumi program.
# after_init    are the hooks the stack runs after the Pulumi login and stack
#               select. Every case seeds the file-backed state with a
#               `pulumi up` first, so the preview has a resource to refresh.
#               The state dies with the run container.
# environment   are the env vars of the stack.
locals {
  # The worker hardcodes `--refresh` in `pulumi preview` and appends
  # SPACELIFT_PULUMI_CLI_ARGS_preview after it. Pulumi takes the last of two
  # `--refresh` flags. Three `--refresh` flags fail with
  # `unable to determine value for --refresh`.
  seed_state = "pulumi up --yes --skip-preview --non-interactive"

  refresh_off = {
    SPACELIFT_PULUMI_CLI_ARGS_preview = "--refresh=false"
    PULUMI_CONFIG_PASSPHRASE          = "test"
  }

  drift_condition = "[ \"$TF_VAR_spacelift_run_trigger\" = \"spacelift/drift_detection\" ]"

  stack_entries = {
    "drift-refresh-set" = {
      project_root = "drift-refresh"
      description  = "No env var. One hook sets SPACELIFT_PULUMI_CLI_ARGS_preview to --refresh=true in a drift detection run and to --refresh=false in every other run. The drift preview refreshes, the tracked preview does not."
      after_init = [
        local.seed_state,
        "if ${local.drift_condition}; then export SPACELIFT_PULUMI_CLI_ARGS_preview=\"--refresh=true\"; else export SPACELIFT_PULUMI_CLI_ARGS_preview=\"--refresh=false\"; fi",
      ]
      environment = { PULUMI_CONFIG_PASSPHRASE = "test" }
    }
    "drift-refresh-append" = {
      project_root = "drift-refresh"
      description  = "Refresh is off through SPACELIFT_PULUMI_CLI_ARGS_preview. A drift detection run appends --refresh=true to the variable, so the drift preview gets three --refresh flags and fails."
      after_init = [
        local.seed_state,
        "if ${local.drift_condition}; then export SPACELIFT_PULUMI_CLI_ARGS_preview=\"$${SPACELIFT_PULUMI_CLI_ARGS_preview:-} --refresh=true\"; fi",
      ]
      environment = local.refresh_off
    }
  }

  stack_defaults = {
    after_init  = null
    environment = {}
  }

  stacks = {
    for key, entry in local.stack_entries : key => merge(local.stack_defaults, entry)
  }

  # One entry per stack env var. The key is unique.
  environment_variables = merge([
    for key, stack in local.stacks : {
      for name, value in stack.environment : "${key}/${name}" => {
        stack = key
        name  = name
        value = value
      }
    }
  ]...)
}

# One space that holds every case stack.
resource "spacelift_space" "test_cases" {
  name             = var.space_name
  parent_space_id  = var.parent_space_id
  description      = "Stacks for testing Pulumi stacks."
  inherit_entities = true

  labels = ["pulumi", "test-cases"]
}

resource "spacelift_stack" "test_case" {
  for_each = local.stacks

  name        = "${var.name_prefix}-${each.key}"
  description = each.value.description

  repository   = var.repository
  branch       = var.branch
  project_root = each.value.project_root

  # The raw Git vendor reads a public repository over HTTPS. No VCS integration.
  raw_git {
    namespace = var.git_namespace
    url       = var.git_url
  }

  # The file backend keeps the state in the run container. No cloud backend.
  pulumi {
    login_url  = "file://~"
    stack_name = each.key
  }

  runner_image = var.runner_image
  after_init   = each.value.after_init

  space_id       = spacelift_space.test_cases.id
  worker_pool_id = var.worker_pool_id
  autodeploy     = var.autodeploy

  labels = ["pulumi", "test-cases", each.value.project_root]
}

resource "spacelift_environment_variable" "test_case" {
  for_each = local.environment_variables

  stack_id   = spacelift_stack.test_case[each.value.stack].id
  name       = each.value.name
  value      = each.value.value
  write_only = false
}

# Drift detection runs on every stack. They never reconcile.
resource "spacelift_drift_detection" "test_case" {
  for_each = local.stacks

  stack_id  = spacelift_stack.test_case[each.key].id
  schedule  = var.drift_schedule
  reconcile = false
}

# One run per stack, so the stack has a finished tracked run before drift
# detection starts. The run fires once, at create.
resource "spacelift_run" "initial" {
  for_each = var.trigger_runs ? toset(keys(local.stacks)) : toset([])

  stack_id = spacelift_stack.test_case[each.key].id

  depends_on = [spacelift_environment_variable.test_case]
}
