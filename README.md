# pulumi-test-cases

Stacks for testing Pulumi stacks in Spacelift.

Nothing here costs money. The only resource is a `random:RandomString`, and
the Pulumi state lives in the run container through the `file://~` backend.

## Stacks

| Stack                         | What it tests                                                                                                                                                                 |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pulumi-drift-refresh-set`    | No env var. One `after_init` hook sets `SPACELIFT_PULUMI_CLI_ARGS_preview` to `--refresh=true` in a drift detection run and to `--refresh=false` in every other run. The drift preview refreshes, the tracked preview does not. |
| `pulumi-drift-refresh-append` | Same, but the hook appends `--refresh=true` to the variable. The drift preview gets three `--refresh` flags and fails with `unable to determine value for --refresh`.          |

How the cases work:

- The worker runs `pulumi preview --refresh ... $SPACELIFT_PULUMI_CLI_ARGS_preview`.
  Pulumi takes the last of two `--refresh` flags. Three `--refresh` flags fail.
- The worker loads the hooks environment last, so a variable a hook exports
  wins over the stack's environment variable in the planning phase.
- `TF_VAR_spacelift_run_trigger` is `spacelift/drift_detection` in a drift
  detection run.
- A first `after_init` hook runs `pulumi up`, so the preview has a resource to
  refresh. A refreshing preview logs `~ pulumi:pulumi:Stack: (refresh)`.

The bootstrap stack starts one run per stack at create, so each stack has a
finished tracked run before drift detection starts. Drift detection runs every
five minutes and never reconciles.

## Getting started

This creates one bootstrap stack. The bootstrap stack creates the space and
the stacks. The commands need spacectl v1.20.0 or later and a spacectl
profile.

**1. Create the bootstrap stack.** It reads this repository over the raw Git
vendor, so the account needs no VCS integration.

```bash
spacectl api --variables '{
  "input": {
    "name": "pulumi-bootstrap",
    "description": "Creates the Pulumi test cases space and stacks.",
    "provider": "GIT",
    "repository": "pulumi-test-cases",
    "repositoryURL": "https://github.com/michalrom089/pulumi-test-cases.git",
    "namespace": "michalrom089",
    "branch": "main",
    "projectRoot": "spacelift",
    "space": "root",
    "autodeploy": true,
    "administrative": false,
    "labels": ["pulumi", "bootstrap"],
    "vendorConfig": {
      "opentofu": { "version": "1.10.6", "workflowTool": "OPENTOFU" }
    }
  },
  "manageState": true
}' 'mutation CreateBootstrap($input: StackInput!, $manageState: Boolean!) {
  stackCreate(input: $input, manageState: $manageState) { id name }
}'
```

Set `TF_VAR_worker_pool_id` on the bootstrap stack to a private worker pool.
Drift detection never runs on the public worker pool.

For a second copy of the set in the same account, set `TF_VAR_name_prefix`
and `TF_VAR_space_name` on the bootstrap stack.

**2. Give the stack permission to create the space and the stacks.** Attach the
`space-admin` system role in `root`. You need admin access to `root`.

```bash
ROLE_ID=$(spacectl api '{ roles { id slug } }' --raw \
  | jq -r '.data.roles[] | select(.slug == "space-admin") | .id')

spacectl api --variables "{
  \"input\": {
    \"stackID\": \"pulumi-bootstrap\",
    \"roleID\": \"$ROLE_ID\",
    \"spaceID\": \"root\"
  }
}" 'mutation AttachRole($input: StackRoleBindingInput!) {
  stackRoleBindingCreate(input: $input) { id }
}'
```

**3. Run it.**

```bash
spacectl stack deploy --id pulumi-bootstrap
```

## Changing a case

The stacks read this repository over raw Git, so a push does not move a
stack's tracked commit. After you push a change, sync each stack you changed,
then run it:

```bash
spacectl api 'mutation { stackSyncCommit(id: "<stack>") { id } }'
spacectl stack deploy --id <stack>
```
