# Dale's Home Assistant Add-ons

Home Assistant add-on/app repository for Dale's projects.

Add this repository in Home Assistant:

```text
https://github.com/you209/HA-OS-all
```

## Add-ons

- Quote Machine
- ST Security Tool
- Find My Local Pollie
- Family Database

## Important

This repository is the Home Assistant wrapper repo. Each folder contains the required Home Assistant add-on files: `config.yaml`, `Dockerfile`, `run.sh`, and `README.md`.

For private source repositories, Home Assistant will not be able to clone them unless the source repo is public or the source code is copied directly into this repository.


## Anchor ecosystem: native Home Assistant dashboards

The [Anchor Home dashboard](dashboards/README.md) is a standalone Home Assistant YAML dashboard starter with interactive household shopping, jobs and workshop to-do cards. Import it into a new Home Assistant dashboard and replace the entity IDs with your actual Local to-do lists. It does **not** create a new add-on, automatically install an integration or change live automations. It is designed for shared kitchen/workshop screens while keeping private Anchor data off shared displays.
