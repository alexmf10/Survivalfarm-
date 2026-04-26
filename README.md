# Project Documentation

## 1. Project Architecture and Folder Structure

The project follows a Service-Oriented Architecture (SOA) to maintain a strict separation between logic, data, and presentation.

| Directory | Responsibility | Components |
| :--- | :--- | :--- |
| **`core/`** | Central orchestration and global messaging. | Event Bus, Service Locator, Main entry point. |
| **`services/`** | Backend logic and heavy-duty data processing. | Save systems, Day/Night cycles, Profile management. |
| **`assets/`** | Media storage and engine-side visual configurations. | Textures, Audio, and Resource setups. |
| **`data/`** | Gameplay blueprints and numerical balance data. | Custom Resource scripts and stat definitions. |
| **`entities/`** | Concrete game objects and world actors. | Player, NPCs, and interactable world objects. |
| **`script/`** | Abstract behavioral templates and reusable logic. | State Machine and Utility helpers. |
| **`ui/`** | Interface, HUDs, and user feedback layers. | Menus, Themes, Fonts, and HUD scenes. |

### 1.1 Asset and Data Breakdown

To maintain a clean distinction between "Source" files and "Gameplay" data, the following sub-structures are enforced:

* **`assets/textures/`**: Raw visual media (`.png`, `.svg`) and sprite sheets.
* **`assets/audio/`**: Sound effects and music tracks (`.wav`, `.ogg`).
* **`assets/resources/`**: Godot-native visual configurations like `TileSets`, `Materials`, and `Environments` (`.tres`).
* **`data/component/`**: Script-only logic (`.gd`) defining the structure of custom resources.
* **`data/definition/`**: Instance-specific data (`.tres`) such as item stats, NPC health values, or loot tables.

The main idea is to have all heavy logic in `services/`, raw media in `assets/`, and pure numerical/logic data in `data/`, while `entities/` act as the bridge by notifying events and reflecting changes.

---

## 2. Branching Strategy

| Branch | Purpose | Stability |
| :--- | :--- | :--- |
| `main` | Production-ready code; contains only tested milestones. | Stable |
| `develop` | Integration branch; target for all feature completions. | Testing |
| `feature/*` | Individual tasks and new functionality. | Volatile |
| `fix/*` | Critical bug fixes and hotfixes. | Volatile |

---

## 3. Version Control Workflow

### 3.1 Daily Routine
1. **Synchronize**: Ensure the local environment is current.
   ```bash
   git checkout develop
   git pull origin develop
   ```
2. **Branching**: Create a dedicated branch for each task.
   ```bash
   git checkout -b feature/task-name
   ```
3. **Commits**: Use atomic commits with descriptive messages.
   ```bash
   git add .
   git commit -m "Add: Core jump logic to Player.gd"
   ```

### 3.2 Submission and Review
* **Push**: Upload the branch to the remote repository.
* **Pull Request**: Open a PR from the feature branch to `develop`.
* **Peer Review**: Notify the team for code audit.
* **Integration**: Merge only after approval and resolve local branch deletion.

