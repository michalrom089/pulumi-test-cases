variable "repository" {
  type        = string
  description = "Name of the GitHub repository that holds the cases."
  default     = "pulumi-test-cases"
}

variable "git_url" {
  type        = string
  description = "HTTPS URL of the repository. The stacks read it through the raw Git vendor, so the account needs no VCS integration."
  default     = "https://github.com/michalrom089/pulumi-test-cases.git"
}

variable "git_namespace" {
  type        = string
  description = "Namespace the raw Git vendor shows next to the repository name. Cosmetic only."
  default     = "michalrom089"
}

variable "branch" {
  type        = string
  description = "Branch the stacks track."
  default     = "main"
}

variable "parent_space_id" {
  type        = string
  description = "Space that holds the case space."
  default     = "root"
}

variable "space_name" {
  type        = string
  description = "Name of the space that holds the case stacks. Change it for a second copy of the set in the same account."
  default     = "pulumi-test-cases"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for the stack names."
  default     = "pulumi"
}

variable "runner_image" {
  type        = string
  description = "Runner image with the Pulumi CLI. The account default image has no Pulumi."
  default     = "public.ecr.aws/spacelift/runner-pulumi-javascript:latest"
}

variable "drift_schedule" {
  type        = list(string)
  description = "Cron schedule of the drift detection runs."
  default     = ["*/5 * * * *"]
}

variable "autodeploy" {
  type        = bool
  description = "Apply tracked runs without a confirmation."
  default     = true
}

variable "trigger_runs" {
  type        = bool
  description = "Start one run per stack after the stack is created. The run fires once, at create."
  default     = true
}

variable "worker_pool_id" {
  type        = string
  description = "Private worker pool the case stacks run on. Drift detection never runs on the public worker pool, so set it to test drift detection."
  default     = null
}
