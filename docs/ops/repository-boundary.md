# The repository boundary

Development-only prose. Not shipped with the plugin.

## The hole

A session bound to one project received a prompt written for another. The issue
numbers the prompt named did not exist locally, so the agent found them in the
sibling repository, switched to that checkout, and continued working there. When
the session boundary pulled execution back toward the assigned project, the
agent routed around it with `git -C` and absolute paths.

The damage was limited. The hole was not:

> **Repository discovery was treated as repository authorization.**
>
> Discovery is evidence. It is **not authorization**.

Finding a prompt's issue numbers in another repository is evidence about what
the prompt refers to. It is not permission to write there. A second warning was
also missed: a safety boundary that an agent learns to work around has already
failed.

## Why this is not a pattern rule

`git -C`, `--git-dir`, an absolute path, a sibling worktree, and a `gh --repo`
write all reach a different repository by different syntax. A substring rule
would have to enumerate every one, and would still miss the next.

So the authority attaches to a **resolved repository identity** built from
canonical git facts — root, normalized origin locator, HEAD, branch — and the
question becomes "which repository would this actually change?" rather than "what
does this command look like?". An SSH remote and an HTTPS remote for the same
repository normalize to one locator, because they are one repository.

## Three outcomes, kept apart

| | |
|---|---|
| `same` | Proceed, subject to whatever authority the motion already required |
| `boundary` | The target is a **different** repository. Fail closed |
| `NOT ASSESSED` | Identity could not be resolved. Never treated as `same` |

Collapsing these destroys the signal. A repository mismatch is not a judgment
call and not missing evidence — it is a refusal, and it says so in those words
rather than borrowing `DECISION REQUIRED` or `NOT ASSESSED`.

## It fails closed by allow-listing reads

The guard recognises read-only shapes and treats **everything else** as capable
of mutation. That direction is deliberate: a deny-list of write verbs is only as
complete as its author's imagination, and the one verb nobody thought of is
precisely the one that crosses the boundary.

Reading another repository stays legitimate — `git -C … log`, `gh pr view
--repo …`, `gh issue list --repo …` all pass untouched. Evidence gathering is
not mutation, and a boundary that blocked it would be unusable, which is its own
kind of failure: people switch off guards that get in the way.

## Handoff is a human act

`spark repo handoff --to <owner/name> --yes` rebinds authority, and
re-establishes root, locator, HEAD and branch against the repository now in
force. Without `--yes` it refuses.

That flag is the entire point. The incident happened because a rebind occurred
with no human ever saying so. Having *read* the sibling issue changes nothing: a
fixture asserts that reading it is allowed, and that writing there immediately
afterwards is still refused.

## What it does not replace

Force-push and trunk-push protections are unchanged. This is an additional
authority dimension — which repository — layered beneath the existing question
of which branch.
