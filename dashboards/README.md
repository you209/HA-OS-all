# Anchor Home: native Home Assistant dashboard starter

This folder is a **dashboard template, not a new Home Assistant add-on**. Home Assistant stays responsible for household devices, local to-do lists and shared displays. Anchor remains the offline-first personal app; Launcher will provide a separate read-only API adapter when it is securely configured.

## Install

1. In Home Assistant, make or confirm your **Shopping list** integration. Find its entity ID in **Developer tools → States** (commonly `todo.shopping_list`).
2. Go to **Settings → Devices & services → Helpers** and create two **Local to-do** lists, named `Household jobs` and `Workshop parts`. Verify their generated entity IDs; substitute them in the YAML if different.
3. In **Settings → Dashboards**, create a new dashboard named **Anchor Home**. Open it, choose **Edit dashboard → ⋮ → Raw configuration editor**. Paste the contents of [anchor-home.yaml](anchor-home.yaml), editing the to-do IDs.
4. View the Household and Workshop tabs. Lists are interactive on the dashboard immediately because the cards are Home Assistant's built-in `todo-list` cards, **not** a custom cloud integration.

Do not paste this into `configuration.yaml` or into an add-on's `config.yaml`. Native dashboard config only.

## Extend with your real entities

After verifying your actual entity IDs, add these standard cards beneath the household to-do cards:

```yaml
# Remove the comments and replace the sample IDs:
# - type: calendar
#   title: Shared calendar
#   initial_view: listWeek
#   entities:
#     - calendar.household
#
# - type: tile
#   entity: sensor.solar_power
#   name: Current solar production
#
# - type: tile
#   entity: light.kitchen
#   name: Kitchen lighting
```

No solar, calendar, light or temperature entities are fabricated by the template. Nothing in this repo changes your existing Home Assistant instance until you import the dashboard.

## Roles and privacy

- **Home Assistant owns** shopping, household chores, home automation, device states, energy and local wall dashboards.
- **Anchor owns** personal tasks, project checkpoints, BOM and the user's private notes.
- **Launcher** should only fetch an explicitly allowlisted subset of Home Assistant to-do lists and benign sensors using a server-side Home Assistant token; it must not expose that credential to a phone or publish your internal home status.
- **Family Planner and Family Database** remain separate. No family/legal records, private photos, people, alarm codes, camera streams or lock controls are allowed in unattended display lists or the first adapter.
- Future two-way task updates require per-item ownership, stable IDs, acknowledgements and conflict handling. The initial bridge is **read-only**, not full synchronisation.

References: [Home Assistant to-do list card](https://www.home-assistant.io/dashboards/todo-list/), [todo.get_items](https://www.home-assistant.io/actions/todo.get_items/), [Dashboard cards](https://www.home-assistant.io/dashboards/cards/).
