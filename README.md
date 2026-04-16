# Project Documentation

## 1. Project Architecture and Folder Structure

The project follows a Service-Oriented Architecture (SOA) to maintain a strict separation between logic, data, and presentation.

| Directory | Responsibility | Components |
| :--- | :--- | :--- |
| **`core/`** | Central orchestration and global messaging. | Event Bus, Service Locator, Main entry point. |
| **`services/`** | Backend logic and heavy-duty data processing. | Save systems, Day/Night cycles, Profile management. |
| **`data/`** | Data definitions and structural blueprints. | `.gd` Component scripts and `.tres` Resources. |
| **`entities/`** | Concrete game objects and world actors. | Player, NPCs, and interactable world objects. `.tscn` and `.gd` |
| **`ui/`** | Interface, HUDs, and user feedback layers. | Menus, Themes, Fonts, and HUD scenes. |

* **`data/component/`**: Contains script-only logic defining object properties.
* **`data/definition/`**: Contains `.tres` files for static data configuration.

The main idea is to have all the heavy logic in the `services/`, pure data in `data/` and `entities/` notify events and receive changes.

---
## 1. Branching Strategy

| Branch | Purpose | Stability |
| :--- | :--- | :--- |
| `main` | Production-ready code; contains only tested milestones. | Stable |
| `develop` | Integration branch; target for all feature completions. | Testing |
| `feature/*` | Individual tasks and new functionality. | Volatile |
| `fix/*` | Critical bug fixes and hotfixes. | Volatile |

---

## 2. Version Control Workflow

### 2.1 Daily Routine
1.  **Synchronize**: Ensure the local environment is current.
    ```bash
    git checkout develop
    git pull origin develop
    ```
2.  **Branching**: Create a dedicated branch for each task.
    ```bash
    git checkout -b feature/task-name
    ```
3.  **Commits**: Use atomic commits with descriptive messages.
    ```bash
    git add .
    git commit -m "Add: Core jump logic to Player.gd"
    ```

### 2.2 Submission and Review
* **Push**: Upload the branch to the remote repository.
* **Pull Request**: Open a PR from the feature branch to `develop`.
* **Peer Review**: Notify the team for code audit.
* **Integration**: Merge only after approval and resolve local branch deletion.



