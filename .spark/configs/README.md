# configs

Project-type presets. Each config is the basis for a Spark branch that a
downstream project can fork to get the right defaults for its stack.

## How configs and branches work together

A Spark branch locks in the defaults for a given project type:

```
spark/master        ← engine, skills, base config
spark/python-uv     ← Python + uv + Black + Ruff preset
spark/typescript    ← TypeScript + ESLint + Prettier preset
spark/monorepo      ← monorepo layout and tooling preset
```

A downstream project forks the branch that matches its stack, then adds its
own origin remote. It gets the engine and all skills from Spark, plus the
project-type defaults from the branch. Project-specific config stays downstream.

When Spark's engine improves, downstream projects pull from `upstream/master`.
When a preset improves, they pull from the relevant `upstream/spark/<type>`
branch.

## Adding a config

Create a directory here named after the project type:

```
configs/
└── python-uv/
    ├── CLAUDE.md          # preset CLAUDE.md for this stack
    ├── AGENTS.md          # preset AGENTS.md for this stack
    ├── .vscode/           # VS Code settings for this stack
    ├── pyproject.toml     # base project config
    └── README.md          # describes this preset
```

Keep presets minimal. They should set the defaults a project needs on day one,
not anticipate every future requirement.

## Current presets

None yet. Presets are added when a second downstream project uses the same stack
and the defaults are worth standardizing.
