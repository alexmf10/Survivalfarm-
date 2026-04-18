# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Godot 4.4 farming survival game built with a **Service‑Oriented Architecture (SOA)**. The codebase separates logic, data, and presentation using a global Event Bus and a Service Locator. The project uses the Forward Plus renderer (configurable in `project.godot`).

## Key Directories

| Directory | Responsibility |
|-----------|----------------|
| `core/` | Central orchestration, Event Bus, Service Locator, main entry point |
| `services/` | Backend logic and heavy‑duty data processing (crops, day/night cycle, saving, input, profile, farm) |
| `data/` | Gameplay blueprints and numerical balance data (component scripts, resource definitions) |
| `entities/` | Concrete game objects (Player, NPCs, interactables, crops) |
| `script/` | Abstract behavioral templates (state machine, utility helpers) |
| `ui/` | Interface, HUDs, menus, themes |
| `assets/` | Textures, audio, Godot‑native visual configurations (TileSets, Materials) |

## Core Architectural Patterns

### Event Bus (`core/event_bus.gd`)
- Autoloaded global signal hub.
- Services emit signals (e.g., `player_tilled`, `crop_planted`).
- UI and visual scenes listen without knowing the emitter.
- Also hosts the `ServiceLocator` instance.

### Service Locator (`core/service_locator.gd`)
- Central registry for all services.
- Access via `EventBus.services.get_service(&"name")` or shortcuts (`EventBus.services.crop`, `EventBus.services.day_cycle`, etc.).
- Services are registered in `EventBus._ready()`.

### Services (`services/*.gd`)
- Extend `RefCounted` (or `Node` if they need to be in the scene tree).
- Hold internal state and react to events.
- **Example:** `CropService` tracks tilled tiles, planted crops, and growth stages; listens to `player_tilled`, `player_planted`, etc.

### Visual Integration (FarmService)
- `FarmService` (a `Node` service) automatically discovers the visual `TileMapLayer` that belongs to the group `"farm_tilled_dirt"`.
- It injects the discovered layer into `CropService` via `set_tilled_layer()`, bridging the logical tile grid with the visual representation.
- This pattern allows the game world to be built in the editor without hard‑coded node paths.

### Entities & State Machine
- Player behavior is implemented as a **finite‑state machine** (states in `entities/player/*_state.gd`).
- Each state extends `NodeState` (`script/state_machine/node_state.gd`).
- States emit global events via `EventBus` on exit (e.g., `tilling_state.gd` emits `player_tilled`).

### Data Components (`data/component/*.gd`)
- Define the structure of custom resources (e.g., `CropComponent` enum and fields).
- Concrete instances (`.tres` files) live in `data/definition/` and store actual game balance numbers.

## Running the Game

### In the Godot Editor
1. Open the project in Godot 4.4 (or later compatible version).
2. The main scene is `res://core/main.tscn`.
3. Press **F5** (or click the “Play” button) to run the game.

### From the Command Line
```bash
godot --path .  # starts the project in headless mode (requires Godot executable)
```

## Common Development Tasks

### Adding a New Service
1. Create a script in `services/` that extends `RefCounted` (or `Node` if needed).
2. Add any necessary signals to `EventBus.gd`.
3. Register the service in `EventBus._ready()`.
4. Connect its signals (or call `connect_signals()` if the service provides one).

### Adding a New Crop Type
1. Add the crop type to the `CropComponent.CropType` enum in `data/component/crop_component.gd`.
2. Define its `max_stages` in `CropService.CROP_MAX_STAGES`.
3. Create a `.tres` resource in `data/definition/` with the desired stats.
4. Update any UI that displays crop types.

### Adding a New Player Action / State
1. Create a new state script in `entities/player/` (e.g., `new_action_state.gd`).
2. Implement `_on_enter()`, `_on_exit()`, and optionally `_on_process()`.
3. In `_on_exit()`, emit the corresponding signal via `EventBus` (e.g., `EventBus.player_new_action.emit(...)`).
4. Add the state to the player’s state‑machine scene (currently not in version control; may need to be set up in the editor).

### Adding a New UI Screen
1. Create the scene in `ui/`.
2. Listen to `EventBus.screen_change_requested` if the screen should be opened by other parts of the game.
3. Emit `EventBus.screen_change_requested` to request a screen change.

## Branching Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Production‑ready code (tested milestones) |
| `develop` | Integration branch; target for feature completions |
| `feature/*` | Individual tasks and new functionality |
| `fix/*` | Critical bug fixes and hotfixes |

**Workflow:** Create a feature branch from `develop`, commit with atomic changes, push, open a PR to `develop`, and merge after review.

## Notes

- **CLAUDE.md is git‑ignored** (see `.gitignore`). It is intended as a local development aid.
- The project uses **GDScript**; all scripts are `.gd`.
- The `assets/` folder contains imported textures and audio; do not commit the `.import` files (they are generated by Godot).
- The `.godot/` folder is also git‑ignored.
- For more detailed documentation (folder breakdown, branching strategy, daily workflow), see `README.md`.
