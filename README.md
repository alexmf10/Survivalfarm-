# 🚀 Team Workflow & Contribution Guide

Welcome to the team! To keep our Godot project stable and avoid merge conflicts, we follow this **Feature Branch Workflow**. Please read this before making your first commit.

---

## 🌲 Branching Strategy

| Branch | Purpose | Stability |
| --- | --- | --- |
| `main` | **Production.** Only contains playable, tested milestones. | 🟢 Stable |
| `develop` | **Integration.** Where all finished features meet. | 🟡 Testing |
| `feature/*` | **Work-in-progress.** Individual tasks (e.g., `feature/player-jump`). | 🔴 Volatile |
| `fix/*` | **Bug fixes** Correcciones individuales (e.g., fix/login-error). | 🔴 Volatile |
---

## 🔄 The Standard Loop (Daily Routine)

### 1. Start of Session

Always start by syncing your local machine with the latest team changes.

```bash
git checkout develop
git pull origin develop

```

### 2. Creating a Feature

Never work directly on `develop` or `main`. Create a new branch for your specific task:

```bash
git checkout -b feature/your-task-name

```

### 3. Committing Work

Commit in small "atomic" chunks. Use descriptive messages.

```bash
git add .
git commit -m "Add: Jump logic to Player.gd"

```

### 4. Submitting for Review

Once your feature is finished and tested in Godot:

1. Push to GitHub: `git push origin feature/your-task-name`
2. Open a **Pull Request (PR)** on GitHub from your branch to `develop`.
3. Notify the team in Discord/Slack for a code review.
4. Once approved, merge to `develop` and delete your local branch.

---

## 🛠 Godot-Specific Rules

Godot files (`.tscn`) are text-based but can be messy to merge. Follow these "Golden Rules":

| Rule | Description |
| --- | --- |
| **No Shared Scenes** | Avoid two people editing the same `.tscn` file at the same time. |
| **Scene Composition** | Break big scenes into smaller, nested scenes. It reduces conflict risks. |
| **External Scripts** | Keep scripts as separate `.gd` files rather than "built-in" to the node. |
| **The `.godot/` Folder** | **Never** commit the `.godot/` folder. It should be in our `.gitignore`. |
| **UIDs** | If you see `.uid` changes in files you didn't touch, don't worry—it's Godot's internal tracking. |

---

## ⚠️ Handling Merge Conflicts

If Git tells you there is a conflict:

1. **Don't Panic.**
2. Open the conflicting file in a text editor (like VS Code).
3. Look for the markers:
```text
<<<<<<< HEAD
Current Code
=======
Incoming Code from Teammate
>>>>>>> develop

```


4. Delete the version you don't want, remove the markers, save, and `git commit`.
5. **If it's a `.tscn` file:** If you aren't sure, ask the person who worked on it last before saving.
