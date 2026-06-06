# GitHub Project Launcher

Private Home Assistant add-on wrapper for `you209/Launcher`.

This add-on lets Home Assistant run your private Launcher repo without making that repo public.

## How it works

1. Home Assistant installs this public wrapper add-on from `HA-OS-all`.
2. You enter a GitHub token in the add-on options.
3. At runtime, the add-on clones or updates `you209/Launcher` into `/data/launcher`.
4. The Launcher runs on port `8000` and uses `/addons` as its apps directory.

## GitHub token

Use a fine-grained GitHub token with read-only access to the private repos you want to sync.

Do not paste your normal GitHub password.

## Options

```yaml
github_username: you209
launcher_repo: you209/Launcher
launcher_branch: main
github_token: YOUR_TOKEN_HERE
admin_username: admin
admin_password: change-this-now
auto_pull: true
sync_interval_minutes: 15
```

## Notes

The current `you209/Launcher` repo is Windows-first. This wrapper runs it under Linux in Home Assistant by installing its Python requirements and starting FastAPI with Uvicorn.

If the Launcher syncs project repos into `/addons`, those repos still need valid Home Assistant add-on files (`config.yaml`, `Dockerfile`, and `run.sh`) before Supervisor can build them as local add-ons.
