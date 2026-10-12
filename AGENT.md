# AGENT.md

Instructions for an agent working in this repository.

## What this repository is

Stacks for testing Pulumi stacks in Spacelift. `README.md` lists the stacks
and what each one tests. Keep that table correct.

## Layout

| Path             | Purpose                                                         |
| ---------------- | --------------------------------------------------------------- |
| `drift-refresh/` | Pulumi YAML program with one random resource.                   |
| `spacelift/`     | Not a case. Creates the space, the stacks and their first runs. |

## Rules

1. **One directory per program.** The directory is the stack's project root.
   Two cases can share a program and differ only in their hooks and env vars.
2. **A case sets its hooks and env vars in `spacelift/main.tf`.** The program
   stays the same for every case that shares it.
3. **Every case seeds the state.** The first `after_init` hook runs
   `pulumi up`, because the `file://~` state dies with the run container.
   Without it the preview has nothing to refresh.
4. **The stacks use the raw Git vendor.** The repository must stay public.
5. **Commit no lock file and no state.** `.gitignore` covers them.

## Verifying a change

```bash
tofu fmt -recursive -check
cd spacelift && tofu init -backend=false && tofu validate && tofu plan
```

With the local dev API key in the env, `tofu plan` reads the local account and
changes nothing. Delete `.terraform/` and the lock file afterwards.

## The `spacelift/` directory

**Do not apply it without asking.** It creates real stacks in a real account.
