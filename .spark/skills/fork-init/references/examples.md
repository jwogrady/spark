# fork-init — Examples

## All inputs provided, shell commands requested

Input:
- project_name: acme-platform
- github_owner: acme-corp
- repo_url: git@github.com:acme-corp/acme-platform.git
- default_branch: main
- output_format: guided_shell_sequence

Expected: the skill produces a copy-paste shell sequence for the full
fork-init workflow with `acme-platform` substituted throughout.

## No inputs provided

Input: (none)

Expected: the skill asks for project_name, github_owner, repo_url, and
default_branch before generating any commands.

## Push rejection error

Input:
- project_name: acme-platform
- github_owner: acme-corp
- repo_url: git@github.com:acme-corp/acme-platform.git
- default_branch: main
- output_format: troubleshooting_guide
- error_context: git push rejected because remote has commits that local does not have.

Expected: the skill produces a troubleshooting guide for the push rejection
scenario, without suggesting --force.
