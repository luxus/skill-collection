# skill-collection

Pi package for personal skill collection.

## Install in Pi

From local path:

```bash
pi install /Users/luxus/projects/skill-collection
```

From GitHub:

```bash
pi install git:github.com/luxus/skill-collection
```

Pin to tag:

```bash
pi install git:github.com/luxus/skill-collection@v0.1.0
```

## Package layout

```text
skill-collection/
├── package.json
└── skills/
    └── <skill-name>/
        └── SKILL.md
```

## Add skill

Create folder under `skills/`.
Folder name must match skill `name` in frontmatter.

Example:

```text
skills/my-skill/SKILL.md
```

Minimal `SKILL.md`:

```md
---
name: my-skill
description: What skill does and when to use it.
---

# My Skill

Instructions here.
```

## Publish to GitHub

```bash
git init
git add .
git commit -m "Initial pi package scaffold"
gh repo create luxus/skill-collection --public --source=. --remote=origin --push
```

After publish, install from GitHub with:

```bash
pi install git:github.com/luxus/skill-collection
```
