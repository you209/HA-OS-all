# GitHub Project Launcher

Private Home Assistant add-on wrapper for `you209/Launcher`.

This add-on lets Home Assistant run your private Launcher repo without making that repo public.

## How it works

1. Home Assistant installs this public wrapper add-on from `HA-OS-all`.
2. You enter a fine-grained GitHub token for the private Launcher repo.
3. You enter one fine-grained GitHub token per private app repo under `app_repositories`.
4. At runtime, the add-on clones or updates `you209/Launcher` into `/data/launcher`.
5. Launcher clones each private app repo into `/addons/<slug>/source`.
6. Launcher writes the Home Assistant add-on wrapper files around each repo: `config.yaml`, `Dockerfile`, `run.sh`, and `README.md`.
7. Home Assistant sees them as **Local add-ons**.

## GitHub tokens

Use fine-grained GitHub tokens with **Contents: Read-only**.

Recommended setup:

- `launcher_token`: access only to `you209/Launcher`
- `Quote-Machine` token: access only to `you209/Quote-Machine`
- `ST` token: access only to `you209/ST`
- `Find-My-Local-Pollie` token: access only to `you209/Find-My-Local-Pollie`
- `Family-Database` token: optional if the repo is public, otherwise access only to `you209/Family-Database`

Do not paste your normal GitHub password.

## Options

```yaml
github_username: you209
launcher_repo: you209/Launcher
launcher_branch: main
launcher_token: YOUR_LAUNCHER_REPO_TOKEN_HERE
app_repositories:
  - name: Quote-Machine
    repo: you209/Quote-Machine
    branch: main
    token: YOUR_QUOTE_MACHINE_TOKEN_HERE
  - name: ST
    repo: you209/ST
    branch: main
    token: YOUR_ST_TOKEN_HERE
  - name: Find-My-Local-Pollie
    repo: you209/Find-My-Local-Pollie
    branch: main
    token: YOUR_POLLIE_TOKEN_HERE
  - name: Family-Database
    repo: you209/Family-Database
    branch: main
    token: ""
admin_username: admin
admin_password: change-this-now
auto_pull: true
sync_interval_minutes: 15
```

## Notes

The private app repos can stay as normal development repos. They do **not** need to contain Home Assistant add-on files themselves. Launcher creates the local add-on wrapper around them inside `/addons`.
