# Legacy Launcher Home Assistant add-on — security and migration

**Recommended architecture:** Run the main Launcher service separately on Proxmox, behind a private HTTPS reverse proxy or VPN. Let Home Assistant run automations and native household dashboards independently. Do not install a second Launcher instance on Home Assistant unless you knowingly want that legacy deployment.

## Improved start-up safety in this branch

- Admin password defaults to blank and refuses to start until configured with at least 16 characters. Existing short/placeholder passwords also fail. Configure a new password before upgrading an installed add-on.
- `auto_pull` defaults to **false**. A previously installed Launcher checkout is reused on startup without a destructive Git reset. The first install still clones the selected Launcher branch.
- `repair_addon_wrappers` defaults to **false**, so the background 60-second `/addons` rewrite loop is off. It can be deliberately enabled for legacy workflows, but it may overwrite local wrapper customisations.
- Python-runner credentials and .env files are created with `umask 077`. Existing token files should still be audited and rotated if previously exposed.
- New app discovery is disabled by default in the generated Launcher configuration. Updates, PR merges and Proxmox service changes remain separate manual operations.

These changes have automated shell/YAML checks; **they have not been installed or verified on your Home Assistant host**.

## Known unresolved privilege / design issues

The legacy add-on still declares `hassio_api: true`, `hassio_role: manager` and a writable `/addons` mount. These are broad privileges. This PR does **not** safely remove them, because its original purpose includes generating/updating additional add-on wrappers. Removing those permissions without redesigning that feature could break the legacy installer.

It also uses a server-side GitHub token and may install dependencies on startup. Review its dependency and build execution permissions before running arbitrary repositories on a privileged Home Assistant system.

A default-passcode guard alone is **not** complete security. Even with `auto_pull=false`, a first install still clones code from GitHub, and code or dependencies can change if not pinned.

## Migration plan

1. Back up your Home Assistant configuration and any `/data/launcher`, `/data/launcher.db`, installed app data and project state before changing anything.
2. Deploy a single audited Launcher instance in an isolated Proxmox VM/container with limited filesystem access, persistent volumes and private HTTPS.
3. Migrate its database and app registry, then verify authentication, Project Brain and Home Assistant read-only endpoints.
4. Reconnect Anchor to the Proxmox Launcher endpoint. Keep Home Assistant's automation and dashboard features independent.
5. Once data and API traffic are verified, disable the legacy Launcher add-on. Remove its supervisor manager permissions and writable addons access as part of a separate decommissioning PR. Do not operate competing authoritative Launchers.

No secret values belong in GitHub issues, Pull Request descriptions or logs.
