# MMCheat 2.0.2 — Custom Party Snapshot Export

This branch preserves a custom **read-only party snapshot exporter** for the original [MMCheat](https://github.com/might-and-magic/mmcheat) v2.0.2, used with **Might and Magic Merge (MMMerge)**. The rest of MMCheat is upstream source; the original work is by Tom Chen and contributors. The original MIT license and credits remain in the repository.

The parent fork's `main` branch remains the unmodified upstream v2.0.2 source. This `custom-export` branch captures the customized Lua scripts recovered from the user's working October 2026 archive. It is an archive of that implementation—not a claim that it was tested on every MMMerge build or on later MMCheat releases.

## Custom changes

- `Scripts/Modules/MMCheat/util/inventory_export.lua` — new Lua exporter.
- `Scripts/Modules/MMCheat/ui/char_subtabs/items_tab.lua` — adds an **Export Party Snapshot** button at **Characters → Items**.
- This guide documents the custom functionality and how to restore it.

All other Lua files were compared with upstream v2.0.2 and matched after normalizing Windows/Unix line endings. There is no separate `.exe` to compile; MMCheat runs through MMExtension.

## How to install

1. Make a backup of your current MMMerge installation and save games. Close the game.
2. Install the [official MMCheat v2.0.2 package](https://github.com/might-and-magic/mmcheat/releases/tag/v2.0.2) using the upstream instructions and required MMExtension version.
3. From **this `custom-export` branch**, overlay only the two customized Lua files at the exact relative paths shown above inside your game folder. Do not replace unrelated game/mod files.
4. Launch MMMerge, press **Ctrl + Backspace** to open MMCheat, go to **Characters → Items**, and click **Export Party Snapshot**.
5. Check the generated files in `Scripts/Modules/MMCheat/`.

The repository source checkout alone does not bundle the third-party IUP and VC++ runtime binaries required by the upstream MMCheat package. Follow the upstream installation instructions for those dependencies.

## Output

One button click writes **four timestamped TSV files** into `Scripts/Modules/MMCheat/`:

```text
MMCheat_inventory_YYYYMMDD_HHMMSS.tsv
MMCheat_characters_YYYYMMDD_HHMMSS.tsv
MMCheat_skills_YYYYMMDD_HHMMSS.tsv
MMCheat_party_YYYYMMDD_HHMMSS.tsv
```

- Inventory: items and equipment, bonuses and enchants, artifact/relic notes where supported, item flags and identifiers.
- Characters: classes, level, XP, HP/SP, combat values, effective/base attributes and resistances.
- Skills: learned skills, rank, mastery, effective values and raw skill encoding.
- Party: in-game date/time, food, gold, reputation, member count and melee recovery floor.

These text files can be opened in spreadsheet software or supplied to an AI for equipment comparison and party optimization. The exporter does **not** write the old `*_latest.*` copies or human-readable snapshot TXT files described by an earlier packaging README.

## Crash and compatibility notes

The exported code uses protected reads for MMExtension arrays and methods. To avoid a crash observed with a Merge/Revamp installation, it avoids reading item `Notes` for ordinary items and only retrieves those notes for artifact/relic entries. These safeguards were part of the archived custom implementation.

The exporter is intended to **read** party data, not to modify the game or save. However, MMCheat and the mod can still crash if memory structures differ. Save before use; test with the exact game/mod version you trust, and do not assume newer upstream releases will accept this patch unchanged.

## Archival notes

The original user archive also contained local `conf.ini`, map caches and ordinary upstream source. Those were intentionally not added as custom changes. **No save games, character exports, or personal inventory snapshots are committed.**

For future work, compare or merge changes against the upstream [MMCheat repository](https://github.com/might-and-magic/mmcheat) rather than blindly overwriting a working MMMerge installation.
