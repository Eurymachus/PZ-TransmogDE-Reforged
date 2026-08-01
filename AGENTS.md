# Project Notes for Codex Agents

This workspace is the source for Better Dressed for Project Zomboid.

## Workspace

- Mod workspace: `E:\LocalProfiles\Eurymachus\GameData\Zomboid\Workshop\Better Dressed`
- Primary editable mod content lives under `Contents/`.
- Mod versions currently live under `Contents/mods/Better Dressed/`.
- Treat this workspace as the normal place to make changes.

## Reference Paths

Use these local paths when tracing Lua behavior, mod dependencies, or Project Zomboid internals:

- Steam workshop mods: `C:\Games\Steam\steamapps\workshop\content\108600`
- Local workshop mods / style references: `C:\Users\refle\Zomboid\Workshop`
- Project Zomboid install: `C:\Games\Steam\steamapps\common\ProjectZomboid`
- Project Zomboid 42.18 Lua and scripts reference: `C:\Games\Steam\steamapps\common\PZJava\ProjectZomboid-LUA_and_Scripts-42_18`
- Versioned decompiled Java root: `C:\Games\Steam\steamapps\common\ProjectZomboid\tgsrr_decompiled`
- Legacy decompiled Java reference: `C:\Games\Steam\steamapps\common\PZJava`

## Working Rules

- Prefer `rg` for searches across Lua, Java references, `mod.info`, media scripts, recipes, translations, and workshop dependencies.
- When investigating behavior, search in this order unless the task suggests otherwise:
  1. Better Dressed workspace.
  2. Relevant version folders under `Contents/mods/Better Dressed/`.
  3. Local workshop mods under `C:\Users\refle\Zomboid\Workshop` when code style or established Eurymachus patterns matter.
  4. Steam workshop mods when checking compatibility or comparable mod behavior.
  5. Project Zomboid game files.
  6. The versioned 42.18 Lua and scripts reference in `PZJava\ProjectZomboid-LUA_and_Scripts-42_18` when comparing against Build 42.18.
  7. The matching authoritative versioned Java decompile under `ProjectZomboid\tgsrr_decompiled`.
  8. Legacy decompiled Java references in `PZJava` when legacy comparison is useful.
- Do not edit files outside this mod workspace unless the user explicitly asks for that.
- Use external workshop, local workshop, Project Zomboid, Lua reference, and Java paths as read-only references by default.
- Preserve existing mod structure and Project Zomboid conventions.
- Keep edits focused and avoid unrelated refactors.
