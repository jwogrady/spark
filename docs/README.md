# Spark documentation

These docs follow [Diátaxis](https://diataxis.fr/) — four modes of documentation,
each serving a different need. Find what you need by what you're trying to do:

| You want to… | Go to | Mode |
|---|---|---|
| Learn Spark by doing, start to finish | [tutorials/](tutorials/) | Tutorial (learning) |
| Accomplish one specific task | [how-to/](how-to/) | How-to (task) |
| Look up exactly how something behaves | [reference/](reference/) | Reference (information) |
| Understand why Spark is built this way | [explanation/](explanation/) | Explanation (understanding) |

## The shape of Spark

Spark is a Claude Code **plugin**: one portable, opinionated toolkit you install
once and carry into every project. It organizes work around a single GitHub-native
software-development lifecycle:

```
Ideate → Plan → Generate → Solve → Ship
```

Each stage is a skill (`/spark:ideate`, `/spark:plan`, `/spark:build`,
`/spark:fix-issue`, `/spark:review`, `/spark:commit`, `/spark:ship`), backed by
enforcement hooks and a small `spark` CLI. See [explanation/sdlc-doctrine.md](explanation/sdlc-doctrine.md)
for why this is the spine.
