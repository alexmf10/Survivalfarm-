# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

FarmSurvivalGame — a 2D farm/survival game built with **Godot 4.4** and **GDScript**. No external build tools; use the Godot editor or a compiled export binary to run the project.

- Main scene: `res://core/main.tscn` (bootstrap)
- First player-facing scene: `res://ui/menus/main_menu.tscn`
- Project config: `project.godot`

## Running & Testing

Open the project in Godot 4.4 and press **F5** to run from the main scene, or **F6** to run the currently open scene.

There is no automated test suite; test scenes live in `/test/` and are run manually in the editor.

## Architecture

### Service Locator + Event Bus

All inter-system communication goes through two autoloads:

- **`EventBus`** (`core/event_bus.gd`) — global signal hub. All cross-system signals are declared and emitted here. Never wire direct node references between unrelated systems.
- **`ServiceLocator`** (`core/service_locator.gd`) — accessed via `EventBus.services`. Register services with `register_service(&"name", instance)` and retrieve with `get_service(&"name")`. Quick accessors: `.profile`, `.save`, `.day_cycle`, `.player`, `.crop`, `.farm`.

### Bootstrap (`core/main.gd`)

Runs at startup via `main.tscn`. Registers all services, loads crop definitions (`wheat.tres`, `beet.tres`), then changes scene to the main menu. Services that need `_process` (DayCycleService, FarmService) are Nodes added as children; the rest are RefCounted.

### Services (`/services/`)

| Service | Responsibility |
|---|---|
| `DayCycleService` | Day/night phases, time ticks, current day |
| `CropService` | Crop state machine (tilled → planted → watered → grown → harvested) |
| `FarmService` | Visual rendering of farm tiles and crop entities (TileMap + CropEntity spawning) |
| `SaveService` | 5 save slots in `user://saves/slot_N.json` |
| `ProfileService` | Per-slot achievements in `user://achievements_slot_N.json` |
| `PlayerService` | Player spawn/despawn lifecycle |
| `GameWorldService` | World coordination |

### Components (`/components/`)

Player actors use thin component facades. The three components communicate via **local signals** (not EventBus):

- **`MovementComponent`** — WASD input → `CharacterBody2D` velocity; emits `moved`, `stopped`, `facing_changed`
- **`AnimationComponent`** — listens to MovementComponent signals; plays idle/walk/action animations
- **`ToolComponent`** — tools 1–5 (None, Till, Water, PlantWheat, PlantBeet); E to use; validates tile distance ≤24 px in facing direction; emits global signals on use (`player_tilled`, `player_watered`, `player_planted`, `player_harvest_attempted`)

### Player (`/actors/player/`)

`player.gd` is a thin facade — it delegates entirely to the three components above and emits `player_spawned`, `player_despawned`, `player_position_changed` (throttled: max 0.5 s or 4 px moved).

### UI (`/ui/`)

- `/ui/menus/` — MainMenu, SlotsScreen, ProfileScreen, OptionsScreen, ControlManual
- `/ui/hud/` — DayCycleHUD, ToolHUD

### Entities & Data

- `/entities/` — game world objects (crops, houses, interactables)
- `/data/component/` — CropComponent, ToolsComponent resource definitions
- `/data/definition/` — resource instances (`wheat.tres`, `beet.tres`)

## Conventions

- **All scripts are external `.gd` files** — never use built-in scene scripts.
- Signals use `snake_case`; classes use `PascalCase`; methods/variables use `snake_case`.
- Emit signals on EventBus for cross-system events; use local component signals only within a single actor.
- New crop types: create a `.tres` using `CropComponent`, register it in `core/main.gd`.
- New services: extend `RefCounted` (or `Node` if `_process` is needed), register in bootstrap, add a quick accessor to ServiceLocator if frequently used.

## Git Workflow

Branch structure: `main` → `develop` → `feature/*` / `fix/*`. PRs target `develop`; `develop` merges to `main` for releases.
