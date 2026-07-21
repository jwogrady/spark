# What Spark is

> *Authoritative — Spark's product identity. Everything else in these docs serves
> this. Owner: `jwogrady`.*

**Spark turns your Claude and GitHub subscriptions into a software delivery
system.** It is a force multiplier for the solo developer: one operator, many
projects, all run to the same standard — not more AI activity, more finished
software.

The mechanism behind that promise: **Spark is the layer between your intent and
Claude's tools.**

You bring the judgment a tool can't: definitions, priorities, decisions,
preferences, opinions. Claude brings the capability: a growing set of great tools
and the best practices for using them. Spark sits between the two — it turns your
intent into disciplined work by *arranging* Claude's tools, filling the gaps they
leave, and holding you to your own standards. It does not reinvent what Claude
already does; it knows **how and when** to reach for what already exists.

## The four parties

- **You** — the directing force. You supply intent and taste, and you take the shot.
- **Claude** — the tools and the know-how for using them. Spark leans on Claude for
  the *how*, and never tries to know the host's tools better than the host.
- **Spark** — the layer that binds them. It owns only three things: the **sequence**
  (the lifecycle), the **gaps** Claude doesn't cover, and **your standards**.
- **GitHub** — the durable record. Where the work is reviewed, delivered, and
  remembered: issues, branches, pull requests, and releases outlive any one
  session.

Native tools have no opinion. You do. **Spark is where your opinions live and get
applied** — which is why nothing Claude ships can replace it.

## The experience: a caddy

Spark behaves like a caddy, not a control panel. It rides along while you play:
it reads the situation, recommends the right club, challenges a questionable
choice — and you swing. Three rules:

- **It plays alongside; you take the shot.** Spark advises and arranges; it never
  decides for you.
- **It riffs and challenges.** Not a form to fill, not a yes-man — it holds
  opinions grounded in the work in front of you.
- **It only recommends clubs in the bag.** Every recommendation is a real,
  available tool. Reach for one that isn't there and it says so — it never fakes a
  club.

## The three bags

A caddy juggles clubs from three distinct bags:

1. **The provider's bag** — Claude's native tools. Leased from the vendor; grows
   on its own. Spark leverages these and never duplicates them.
2. **The standard bag** — your custom clubs, the same on every project: your
   preferences, the lifecycle, your standard tooling. **This bag is Spark** —
   loaded once, carried everywhere.
3. **The project's bag** — the clubs specific to one project. Local to that repo.

Spark's own bag holds only what Claude doesn't. A club that duplicates a native
one is dead weight — the caddy would reach for Claude's anyway.

## Who it's for

One operator running many projects to a consistent standard — today, a single
developer directing an increasingly agent-run, human-supervised workflow. Spark is
that operator's means of production: the way their standards survive being handed
to an agent, so they never have to be re-explained or personally re-checked on
each new project. It is **not** a team-coordination platform; that is not a goal
today.

## What Spark owns, and what it defers

- **Owns:** the lifecycle sequence (`Ideate → Plan → Codify → Validate → Ship`),
  the gap-fillers Claude doesn't provide, and your enforced standards.
- **Defers:** to Claude for how to use the tools — Spark references the host's own
  guidance rather than hard-coding opinions that would drift as the host evolves.
- **Never:** reinvents a native tool. When a native club fits the shot, the caddy
  hands you the native one.

## In scope / out of scope

**In scope:** carrying your standards and lifecycle into every project; arranging
Claude's tools into a disciplined flow; filling the gaps (project inception,
scoped work, mechanical enforcement); keeping the record honest.

**Out of scope:** reimplementing Claude's tools; team coordination or shared
state; being a runtime or hosting environment; the specific environment a project
runs in — that is the project's own concern, not Spark's.

## Shipped vs. building toward

Honest today: Spark ships the lifecycle skills, the mechanical guardrails (the two
doors), a canonical engineering standard the projects conform to, the **brief on
entry** (orient / locate / load — `spark brief`, plus `resume` for picking work
back up), and the **load-once** mechanism (`spark setup`, the one-command
carry-in that arms a repo with the git hooks, permission baseline, and resolved
standard). The standard bag is no longer a seed; it loads.

Capabilities that are real but not the shipping loop ride as **companion
plugins** in the same marketplace — whole-project auditing (`spark-audit`),
service connectivity and secrets (`spark-connect`), and public docs authorship
(`spark-docs`). The core stays the loop; the companions carry the rest.

Building toward, not yet shipped: generated projects growing from a
standardized repository into a full per-client environment — infra, runtime,
telemetry. That is the north star — named here so it is never mistaken for what
exists.

## The name

A spark ignites. Spark is the ignition — the disciplined start and the standing
method that turn a directive into built work. The Claude Code plugin is how Spark
is *delivered* today; the identity above is what it *is*, and it would survive
another delivery vehicle.

## See also

- [sdlc-doctrine.md](sdlc-doctrine.md) — the lifecycle spine this identity runs on
- [philosophy.md](philosophy.md) — the values beneath the identity
- [additive.md](additive.md) — the additive stance, in detail
