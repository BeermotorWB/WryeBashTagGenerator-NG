# Wrye Bash Tags Reference

**Distilled:** 2026-04-21, from the Wrye Bash source in this repo at commit `7fa2d87ae` (branch `dev`, tip commit dated 2026-04-20). **Method:** direct static reading of the Python source — each fact cross-referenced against the specific file/symbol listed under "source of truth" below, not against the upstream readme (which is a user-facing summary and omits per-game applicability for several tags). To regenerate, re-walk the same files; they are the authoritative definitions.

The source of truth for every fact below is:

- `Mopy/bash/bosh/__init__.py` — alias/removal maps (`_tag_aliases`, `_removed_tags`)
- `Mopy/bash/game/patch_game.py` — `allTags` default + baseline patcher metadata
- `Mopy/bash/game/<game>/__init__.py` — per-game `patchers`, `actor_importer_attrs`, `cellRecAttrs`, `graphicsTypes`, `names_types`, `sounds_attrs`, `stats_attrs`, `text_types`, `object_bounds_types`, `destructible_types`, `keywords_types`, `scripts_types`, `enchantment_types`, `mgef_stats_attrs`, `ench_stats_attrs`, `import_races_attrs`, `leveled_list_types`, `spell_stats_types`, `actor_types`, `relations_attrs`, etc.
- `Mopy/bash/patcher/patchers/preservers.py` / `mergers.py` — `patcher_tags` for each patcher class
- `Mopy/bash/game/oblivion/patcher/preservers.py` — `Roads` (ImportRoadsPatcher)
- `Mopy/bash/game/falloutnv/patcher/preservers.py` — `WeaponMods` (ImportWeaponModificationsPatcher)
- `Mopy/bash/basher/gui_patchers.py` — `initPatchers` populates `bush.game.allTags` from each enabled patcher's `patcher_tags`

Tags listed in `patch_game.py` (`allTags = {'Deactivate', 'Filter', 'MustBeActiveIfImported'}`) are unconditional. All other tags are contributed dynamically by whichever patcher classes the game enables via its `patchers` set. If a game's `patchers` set doesn't include the class that contributes a tag, **the tag is not valid for that game** — it won't survive the `ret_tags &= bush.game.allTags` intersection in `bosh._process_tags` and users can't even set it on the plugin's header. This is the most common reason the readme is incomplete: it describes tags by meaning without cross-referencing each game's `patchers` set.

## Game codes

| Code | Game | Inherits from |
|---|---|---|
| OB | Oblivion (retail/GOG/Steam/WS) | PatchGame |
| OB-RE | Oblivion Remastered | OB minus `RaceChecker` |
| NE | Nehrim: At Fate's Edge | OB minus `CoblCatalogs, CoblExhaustion, MorphFactions, SEWorldTests` (none contribute tags → NE tag set = OB tag set) |
| FO3 | Fallout 3 | PatchGame |
| FNV | Fallout: New Vegas | FO3 + `ImportWeaponModifications` (adds `WeaponMods`) |
| SK | Skyrim (LE) | PatchGame |
| SSE | Skyrim Special Edition | SK (overrides `stats_attrs` for AMMO only) |
| EN | Enderal: Forgotten Stories | SK (no tag differences) |
| EN-SE | Enderal SE | SSE (no tag differences) |
| SK-VR | Skyrim VR | SSE (no tag differences) |
| FO4 | Fallout 4 | PatchGame |
| FO4-VR | Fallout 4 VR | FO4 (no tag differences) |

**Bashed Patch unsupported:** Morrowind (`allTags = set()`), Starfield (`allTags = set()`), Fallout 76 (not a PatchGame — CBash limitation; also explicitly unsupported by WryeBashTagGenerator-NG).

Throughout this doc, "SK-family" = {SK, SSE, EN, EN-SE, SK-VR}. "FO3/FNV" means both. "OB-family" = {OB, OB-RE, NE}.

### Local augmentation: Detection lines

Some entries carry a third bullet — **Detection (this script):** — summarizing how `WryeBashTagGenerator-NG.pas` actually decides to emit the tag. These are not from Wrye Bash. They're here because Wrye Bash describes what a tag *means* to the Bashed Patch, not the override-vs-master diff the generator script performs. Detection lines cover the non-obvious cases: specialty procedures (`ProcessRaceSpells`, `ProcessDelevRelevTags`, `ProcessForceTagHeuristics`), `DiffSubrecordList`-driven `.Change` tags, `Actors.Factions` gating, per-game path differences (RACE `SPLO` is `'Spells'` on OB/NE vs `'Actor Effects'` on SK+), and opt-in Force-add heuristics. For tags without a Detection bullet, the rule is the obvious one: the override differs from the master on a subrecord listed under **Records**. **If you regenerate this file from upstream, redo the Detection pass — the source of truth for each Detection line is the corresponding branch in `ProcessTag` or the specialty procedure it delegates to.**

## Special function tags

These are game-independent hints to the Bashed Patch process. No record diffing; tag generators generally should not emit these.

| Tag | Meaning | Games |
|---|---|---|
| Deactivate | Plugin should be deactivated after import. | All BP games |
| Filter | Plugin doesn't require all masters; Filter mode trims missing-master records. | All BP games |
| IIM | Item Interchange Mode. Suppresses non-inventory-data imports when combined with `Invent.*`. | OB-family only (`allTags` in `oblivion/__init__.py` adds `'IIM'`) |
| MustBeActiveIfImported | Must be active even when imported into the BP (suppresses the deactivation prompt). | All BP games |
| NoMerge | Don't merge even if mergeable. Added dynamically in `initPatchers` if the game's `mergeability_checks` contains `MergeabilityCheck.MERGE`. | All BP games that support merging |

## Removed & deprecated tags → replacements

Authoritative — mirrored directly from `_removed_tags` and `_tag_aliases` in `Mopy/bash/bosh/__init__.py` (lines 206–234). `_process_tags` drops removed tags first, then expands aliases, then intersects with `bush.game.allTags`.

**Removed (dropped, not replaced):**

| Old tag | Notes |
|---|---|
| Merge | Obsoleted by the Merge Patches rework. |
| ScriptContents | Dangerous tag that was never fully implemented. |

**Aliases (expand on read, emit canonical on write):**

| Old tag | Expands to |
|---|---|
| Actors.Perks.Add | NPC.Perks.Add |
| Actors.Perks.Change | NPC.Perks.Change |
| Actors.Perks.Remove | NPC.Perks.Remove |
| Body-F | R.Body-F |
| Body-M | R.Body-M |
| Body-Size-F | R.Body-Size-F |
| Body-Size-M | R.Body-Size-M |
| C.GridFlags | C.ForceHideLand |
| Derel | Relations.Remove |
| Eyes | R.Eyes |
| Eyes-D | R.Eyes |
| Eyes-E | R.Eyes |
| Eyes-R | R.Eyes |
| Factions | Actors.Factions |
| Hair | R.Hair |
| Invent | Invent.Add + Invent.Remove |
| InventOnly | IIM + Invent.Add + Invent.Remove |
| Npc.EyesOnly | NPC.Eyes |
| Npc.HairOnly | NPC.Hair |
| NpcFaces | NPC.Eyes + NPC.Hair + NPC.FaceGen |
| R.Relations | R.Relations.Add + R.Relations.Change + R.Relations.Remove |
| Relations | Relations.Add + Relations.Change |
| Voice-F | R.Voice-F |
| Voice-M | R.Voice-M |

## Tag definitions

Each entry lists: the patcher class that owns it, the games where it's valid (derived from each game's `patchers` set), and the records/subrecords it targets (from `rec_attrs` / `_fid_rec_attrs` / per-game type sets / per-game `actor_importer_*` / `cellRecAttrs` / `import_races_*` dicts).

---

### Actors.ACBS
- **Patcher:** `ImportActorsPatcher` (multi-tag — `actor_importer_attrs` key)
- **Games:** OB, OB-RE, NE, FO3, FNV, SK, SSE, EN, EN-SE, SK-VR, FO4, FO4-VR
- **Records (OB/NE/OB-RE):** CREA (ACBS) — `crea_biped, crea_essential, weapon_and_shield, crea_respawn, crea_swims, crea_flies, crea_walks, pc_level_offset+level_offset (fused), no_low_level, crea_no_blood_spray, crea_no_blood_decal, no_head, no_right_arm, no_left_arm, crea_no_combat_in_water, crea_no_shadow, no_corpse_check`; `barter_gold, base_spell, calc_max_level, calc_min_level, fatigue`. NPC_ (ACBS) — `npc_female, npc_essential, npc_respawn, npc_auto_calc, pc_level_offset+level_offset (fused), no_low_level, no_rumors, npc_summonable, no_persuasion, can_corpse_check`; `barter_gold, base_spell, calc_max_level, calc_min_level, fatigue`.
- **Records (FO3/FNV):** CREA (ACBS) — biped/essential/weapon_and_shield/respawn/swims/flies/walks/pc_level_mult+level_offset (fused)/no_low_level/blood decals/no_head/arms/combat_in_water/shadow/no_vats_melee/allow_pc_dialogue/cant_open_doors/immobile/tilt_front_back/tilt_left_right/no_knockdowns/not_pushable/allow_pickpocket/is_ghost/no_rotating_head_track/invulnerable + barter_gold/calc_min/max/disposition_base/fatigue/karma/speed_multiplier. NPC_ (ACBS) — essential/female/is_chargen_face_preset/respawn/auto_calc/pc_level_mult+level_offset (fused)/no_low_level/blood decals/no_vats_melee/can_be_all_races/auto_calc_service (FNV only)/no_knockdowns/not_pushable/no_rotating_head_track/fatigue/barter_gold/calc_min/max/speed_multiplier/karma/disposition_base.
- **Records (SK-family):** NPC_ (ACBS) — `npc_female, npc_essential, is_chargen_face_preset, npc_respawn, npc_auto_calc, npc_unique, does_not_affect_stealth, pc_level_offset+level_offset (fused), npc_protected, npc_summonable, does_not_bleed, bleedout_override (flag), opposite_gender_anims, simple_actor, looped_script, looped_audio, npc_is_ghost, npc_invulnerable`; `magicka_offset, stamina_offset, calc_min_level, calc_max_level, speed_multiplier, disposition_base, health_offset, bleedout_override (value)`.
- **Records (FO4/FO4-VR):** NPC_ (ACBS) — `npc_female, npc_essential, is_chargen_face_preset, npc_respawn, npc_auto_calc, npc_unique, does_not_affect_stealth, npc_protected, npc_summonable, does_not_bleed, bleedout_override (flag), opposite_gender_anims, simple_actor, no_activation_or_hellos, diffuse_alpha_test, npc_is_ghost, npc_invulnerable`; `xp_value_offset, pc_level_offset+level_offset (fused), calc_min_level, calc_max_level, disposition_base, bleedout_override (value)`.

### Actors.AIData
- **Patcher:** `ImportActorsPatcher`
- **Games:** All BP games with ImportActors (same list as Actors.ACBS).
- **Records (OB/NE/OB-RE):** CREA/NPC_ (AIDT) — `ai_aggression, ai_confidence, ai_energy_level, ai_responsibility, ai_service_flags, ai_train_level, ai_train_skill`.
- **Records (FO3/FNV):** CREA/NPC_ (AIDT) — OB fields plus `ai_mood, ai_assistance, ai_aggro_radius_behavior, ai_aggro_radius`.
- **Records (SK-family):** NPC_ (AIDT) — `ai_aggression, ai_confidence, ai_energy_level, ai_morality` (`ai_responsibility`), `ai_mood, ai_assistance, ai_aggro_radius_behavior, ai_warn, ai_warn_attack, ai_attack`.
- **Records (FO4):** NPC_ (AIDT) — SK fields plus `ai_no_slow_approach`.

### Actors.AIPackages
- **Patcher:** `ImportActorsAIPackagesPatcher`
- **Games:** All BP games with ImportActors (same list as Actors.ACBS).
- **Records:** CREA (PKID, OB-family/FO3/FNV) + NPC_ (PKID) `ai_packages` list. Adds/modifies/removes.

### Actors.AIPackagesForceAdd
- **Patcher:** `ImportActorsAIPackagesPatcher` (secondary tag)
- **Games:** Same as Actors.AIPackages.
- **Records:** Same as Actors.AIPackages, but carries forward only adds (no deletes) even when later Actors.AIPackages plugins remove them.
- **Detection (this script):** `ProcessForceTagHeuristics`, gated on `g_HeuristicForceTags`. Fires only when `Actors.AIPackages` was already suggested AND the override's `Packages` array is a strict superset of the master's (adds at least one, removes none).

### Actors.Anims
- **Patcher:** `ImportActorsPatcher`
- **Games:** OB, OB-RE, NE, FO3, FNV *only* (`'Actors.Anims'` key exists in `actor_importer_attrs` only for those games; SK-family and FO4 omit it).
- **Records:** CREA/NPC_ (KFFZ) `animations` list.

### Actors.CombatStyle
- **Patcher:** `ImportActorsPatcher` (FID attr)
- **Games:** All BP games with ImportActors.
- **Records:** CREA (OB-family/FO3/FNV) + NPC_ (ZNAM) `combat_style`.

### Actors.DeathItem
- **Patcher:** `ImportActorsPatcher` (FID attr)
- **Games:** All BP games with ImportActors.
- **Records:** CREA (OB-family/FO3/FNV) + NPC_ (INAM) `death_item`.

### Actors.Factions
- **Patcher:** `ImportActorsFactionsPatcher`
- **Games:** All BP games with ImportActorsFactions (OB, OB-RE, NE, FO3, FNV, SK-family, FO4, FO4-VR).
- **Records:** NPC_ + CREA (SNAM) `factions` list (faction FormID + rank). CREA applies on OB-family/FO3/FNV only.
- **Detection (this script):** `CompareAssignment` + `CompareKeys` on the whole `Factions` subrecord. Fires when the list is assigned on one side only, or when sorted key contents (faction FID + rank together) differ — so rank-only changes trigger the tag.

### Actors.RecordFlags
- **Patcher:** `ImportActorsPatcher`
- **Games:** All BP games with ImportActors.
- **Records:** CREA (OB-family/FO3/FNV) + NPC_ record flags (`flags1`).

### Actors.Skeleton
- **Patcher:** `ImportActorsPatcher`
- **Games:** OB, OB-RE, NE, FO3, FNV only (same rationale as Actors.Anims).
- **Records:** CREA/NPC_ `model` (MODL + MODB + MODT — all three carried together via `setattr_deep`).

### Actors.Spells
- **Patcher:** `ImportActorsSpellsPatcher`
- **Games:** All BP games with ImportActorsSpells (OB-family, FO3, FNV, SK-family, FO4, FO4-VR).
- **Records:** CREA (OB-family/FO3/FNV) + NPC_ `spells` list. On SK-family, the patcher also reads LVSP (because `Esp.sort_lvsp_after_spel` is True) to sort LVSP after SPEL in the final list.

### Actors.SpellsForceAdd
- **Patcher:** `ImportActorsSpellsPatcher` (secondary tag)
- **Games:** Same as Actors.Spells.
- **Records:** Same as Actors.Spells but carries forward only adds (no deletes) even when later Actors.Spells plugins remove them.
- **Detection (this script):** `ProcessForceTagHeuristics`, gated on `g_HeuristicForceTags`. Fires only when `Actors.Spells` was already suggested AND the override's SPLO list is a strict superset of the master's. Array path is `'Spells'` on OB-family, `'Actor Effects'` on SK-family/FO3/FNV/FO4.

### Actors.Stats
- **Patcher:** `ImportActorsPatcher`
- **Games:** All BP games with ImportActors.
- **Records (OB-family):** CREA (DATA) — `agility, attackDamage, combat_skill, endurance, health, intelligence, luck, magic, personality, soul, stealth, speed, strength, willpower`. NPC_ (DATA) — `attributes, health, skills`.
- **Records (FO3/FNV):** CREA (DATA) — SPECIAL, `combat_skill, damage, health, magic_skill, stealth_skill`. NPC_ (DATA) — `attributes, health, skillValues, skillOffsets` (DNAM).
- **Records (SK-family):** NPC_ (DNAM) — `health, magicka, stamina` + 18 skill-value / skill-offset pairs (alchemy, alteration, block, conjuration, destruction, enchanting, heavyArmor, illusion, lightArmor, lockpicking, marksman, oneHanded, pickpocket, restoration, smithing, sneak, speechcraft, twoHanded — each with SV/SO suffixes).
- **Records (FO4/FO4-VR):** NPC_ (PRPS) `properties` — SPECIAL + action points + health, etc. all bundled in PRPS.

### Actors.Voice
- **Patcher:** `ImportActorsPatcher` (FID attr)
- **Games:** FO3, FNV, SK-family, FO4, FO4-VR. **Not** OB/OB-RE/NE (`Actors.Voice` key absent from Oblivion's `actor_importer_fid_attrs`).
- **Records:** CREA (FO3/FNV) + NPC_ (VTCK) `voice`.

### C.Acoustic
- **Patcher:** `ImportCellsPatcher` (cellRecAttrs key)
- **Games:** FO3, FNV, SK-family. **Not** OB-family (no `'C.Acoustic'` in Oblivion `cellRecAttrs`), not FO4 (no `cellRecAttrs` at all).
- **Records:** CELL (XCAS) `acousticSpace`.

### C.Climate
- **Patcher:** `ImportCellsPatcher`
- **Games:** OB-family, FO3, FNV, SK-family. Not FO4.
- **Records:** CELL (XCCM) `climate` + DATA-flag `behaveLikeExterior` (OB-family/FO3/FNV) / `showSky` (SK-family). Skip-interior: no.

### C.Encounter
- **Patcher:** `ImportCellsPatcher`
- **Games:** FO3, FNV, SK-family. Not OB-family, not FO4.
- **Records:** CELL (XEZN) `encounterZone`.

### C.ForceHideLand
- **Patcher:** `ImportCellsPatcher`
- **Games:** FO3, FNV, SK-family. Not OB-family, not FO4. (OB-family's XCLC `forceHideLand` flag is covered by `C.MiscFlags`.)
- **Records:** CELL (XCLC) `cell_land_flags`.

### C.ImageSpace
- **Patcher:** `ImportCellsPatcher`
- **Games:** FO3, FNV, SK-family. Not OB-family, not FO4.
- **Records:** CELL (XCIM) `imageSpace`.

### C.Light
- **Patcher:** `ImportCellsPatcher`
- **Games:** OB-family, FO3, FNV, SK-family. Not FO4.
- **Records (OB-family):** CELL (XCLL) — Ambient/Directional/Fog RGB + unused bytes, fogNear/Far, directionalXY/Z, directionalFade, fogClip.
- **Records (FO3/FNV):** OB fields + `fogPower, lightTemplate (LTMP), lightInheritFlags (LNAM)`.
- **Records (SK-family):** OB fields + `fogPower`, Ambient Colors Directional (redXplus etc.) / Specular (redSpec etc.) / Scale (fresnelPower), `fogColorFarRed/Green/Blue, fogMax, lightFadeBegin, lightFadeEnd, inherits, lightTemplate (LTMP)`.

### C.Location
- **Patcher:** `ImportCellsPatcher`
- **Games:** SK-family only. Not OB-family/FO3/FNV/FO4.
- **Records:** CELL (XLCN) `location`.

### C.LockList
- **Patcher:** `ImportCellsPatcher`
- **Games:** SK-family only.
- **Records:** CELL (XILL) `lockList`.

### C.MiscFlags
- **Patcher:** `ImportCellsPatcher`
- **Games:** OB-family, FO3, FNV, SK-family. Not FO4.
- **Records:** CELL (DATA) flags. OB-family: `isInterior, invertFastTravel, forceHideLand, handChanged`. FO3/FNV: `isInterior, invertFastTravel, noLODWater, handChanged`. SK-family: `isInterior, cantFastTravel, noLODWater, handChanged`.

### C.Music
- **Patcher:** `ImportCellsPatcher`
- **Games:** OB-family, FO3, FNV, SK-family. Not FO4.
- **Records:** OB-family XCMT; FO3/FNV/SK-family XCMO.

### C.Name
- **Patcher:** `ImportCellsPatcher`
- **Games:** OB-family, FO3, FNV, SK-family. Not FO4.
- **Records:** CELL (FULL) `full`.

### C.Owner
- **Patcher:** `ImportCellsPatcher`
- **Games:** OB-family, FO3, FNV, SK-family. Not FO4.
- **Records:** CELL (XOWN/XRNK/XGLB on OB-family) `ownership` + DATA-flag `publicPlace`.

### C.RecordFlags
- **Patcher:** `ImportCellsPatcher`
- **Games:** OB-family, FO3, FNV, SK-family. Not FO4.
- **Records:** CELL `flags1` (record-header flags).

### C.Regions
- **Patcher:** `ImportCellsPatcher`
- **Games:** OB-family, FO3, FNV, SK-family. Not FO4.
- **Records:** CELL (XCLR) `regions`.

### C.SkyLighting
- **Patcher:** `ImportCellsPatcher`
- **Games:** SK-family only.
- **Records:** CELL DATA-flag `useSkyLighting` (on `skyFlags`).

### C.Water
- **Patcher:** `ImportCellsPatcher`
- **Games:** OB-family, FO3, FNV, SK-family. Not FO4.
- **Records:** CELL (XCWT) `water`, (XCLW) `waterHeight` (but skipped in interiors for SK-family — see `cell_skip_interior_attrs`), DATA-flag `hasWater`, (XNAM) `waterNoiseTexture` (FO3/FNV/SK-family — not OB-family), (XWEM) `waterEnvironmentMap` (SK-family only).

### Creatures.Blood
- **Patcher:** `ImportActorsPatcher`
- **Games:** OB, OB-RE, NE, FO3, FNV. (The key exists in `actor_importer_attrs` for CREA on those games; SK-family and FO4 have no CREA.)
- **Records:** CREA — OB-family: `blood_decal_path, blood_spray_path` (NAM0/NAM1). FO3/FNV: `impact_dataset` (CNAM — a FID).

### Creatures.Type
- **Patcher:** `ImportActorsPatcher`
- **Games:** OB, OB-RE, NE, FO3, FNV.
- **Records:** CREA (DATA) `creature_type`. Enum values: OB-family `Creature|Daedra|Undead|Humanoid|Horse|Giant`; FO3/FNV `Animal|Mutated Animal|Mutated Insect|Abomination|Super Mutant|Feral Ghoul|Robot|Giant`.

### Deflst
- **Patcher:** `FormIDListsPatcher` (`_de_tag = 'Deflst'`, no `_re_tag`)
- **Games:** FO3, FNV only. (Only FO3/FNV `patchers` sets include `'FormIDLists'`.)
- **Records:** FLST (LNAM) FormID removals.

### Delev
- **Patcher:** `LeveledListsPatcher` (`_de_tag = 'Delev'`)
- **Games:** OB-family, FO3, FNV, SK-family, FO4, FO4-VR.
- **Records:** Removal of LVLO entries in — OB-family: LVLC/LVLI/LVSP; FO3/FNV: LVLC/LVLI/LVLN; SK-family: LVLI/LVLN/LVSP; FO4: LVLI/LVLN/LVSP (per each game's `leveled_list_types`).
- **Detection (this script):** `ProcessDelevRelevTags`. For each override LVLO entry, looks up the master entry by `LVLO\Reference`; counts matches. Fires if fewer override entries match than the master has total — i.e., master entries are missing from the override.

### Destructible
- **Patcher:** `ImportDestructiblePatcher`
- **Games:** FO3, FNV, SK-family, FO4, FO4-VR. **Not** OB-family (Oblivion has no destructibles).
- **Records:** FO3 (DEST, DSTD, DMDL, DMDT, DSTF) — ACTI/ALCH/AMMO/ARMO/BOOK/CONT/CREA/DOOR/FURN/KEYM/LIGH/MISC/MSTT/NPC_/PROJ/TACT/TERM/WEAP. FNV adds CHIP/IMOD. SK adds APPA/FLOR/SCRL/SLGM; record variant adds (DMDS). FO4: (DEST, DAMC, DSTA, DSTD, DMDL, DMDT, DMDC, DMDS, DSTF) in ACTI/ALCH/AMMO/ARMO/BOOK/CONT/DOOR/FLOR/FURN/INGR/KEYM/LIGH/MISC/MSTT/NPC_/PROJ.

### EffectStats
- **Patcher:** `ImportEffectStatsPatcher`
- **Games:** All BP games. (All define `mgef_stats_attrs`.)
- **Records:** MGEF. OB-family: `flags, base_cost, school, resist_value, projectileSpeed, cef_enchantment, cef_barter` + FID `associated_item`. FO3/FNV: OB fields + `effect_archetype, actorValue`. SK-family: `flags, base_cost, magic_skill, resist_value, taper_weight, minimum_skill_level, spellmaking_area, spellmaking_casting_time, taper_curve, taper_duration, second_av_weight, effect_archetype, actorValue, casting_type, delivery, second_av, skill_usage_multiplier, script_effect_ai_score, script_effect_ai_delay_time` + FIDs `associated_item, equip_ability, perk_to_apply`. FO4: SK fields minus `magic_skill, actorValue, resist_value, second_av` (those move to FID attrs) + FIDs `associated_item, resist_value, actorValue, second_av, equip_ability, perk_to_apply`.

### Enchantments
- **Patcher:** `ImportEnchantmentsPatcher`
- **Games:** All BP games with `enchantment_types` defined (all of them).
- **Records (OB-family):** AMMO/ARMO/BOOK/CLOT/WEAP (ENAM).
- **Records (FO3/FNV):** ARMO/CREA/EXPL/NPC_/WEAP (EITM; CREA/NPC_ uses EITM as "Unarmed Attack Effect").
- **Records (SK-family):** ARMO/EXPL/WEAP (EITM).
- **Records (FO4/FO4-VR):** ARMO/EXPL (EITM).

### EnchantmentStats
- **Patcher:** `ImportEnchantmentStatsPatcher`
- **Games:** All BP games.
- **Records (OB-family):** ENCH (ENIT) — `item_type, charge_amount, enchantment_cost, enit_flags`.
- **Records (FO3/FNV):** ENCH (ENIT) — same four.
- **Records (SK-family):** ENCH (ENIT) — `enchantment_cost, enit_flags, enchantment_cast_type, enchantment_amount, enchantment_target_type, enchantment_type, enchantment_charge_time` + FIDs `base_enchantment, worn_restrictions`.
- **Records (FO4):** Same as SK-family.

### Graphics
- **Patcher:** `ImportGraphicsPatcher`
- **Games:** OB-family, FO3, FNV, SK-family. **Not** FO4 (not in `patchers` set; FO4 has no `graphicsTypes` populated).
- **Records (OB):** ACTI (MODL); ALCH/AMMO/APPA (ICON, MODL); ARMO/CLOT (male+female body/world/icon + biped flags); BOOK/BSGN/CLAS/CONT/DOOR/EYES/FLOR/FURN/GRAS/HAIR/INGR/KEYM/LIGH/LSCR/LTEX/MGEF/MISC/QUST/REGN/SGST/SKIL/SLGM/STAT/TREE/WEAP with their respective ICON/MODL + LIGH gets extra light data; EFSH (ICON + ICO2 + ~80 effect-shader fields); CREA (bodyParts, model_list_textures); FID `MGEF.light/effectShader/enchantEffect`.
- **Records (FO3):** Per the `graphicsTypes` dict for FO3 — ACTI/ALCH/AMMO/ARMA/ARMO/AVIF/BOOK/BPTD/CLAS/COBJ/CONT/CREA/DOOR/EFSH/EXPL/EYES/FURN/GRAS/HAIR/HDPT/INGR/IPCT/KEYM/LIGH/LSCR/MGEF/MICN/MISC/MSTT/NOTE/PERK/PROJ/PWAT/STAT/TACT/TERM/TREE/TXST/WEAP with the readme's listed subrecords; FID types CREA (body_part_data), EFSH (addon_models), EXPL (image_space_modifier/expl_light/expl_impact_dataset/placed_impact_object), IPCT (ipct_texture_set), IPDS (impact materials), MGEF (light/effectShader/enchantEffect), PROJ (proj_light/muzzle_flash/proj_explosion), WEAP (scopeEffect/impact_dataset/firstPersonModel).
- **Records (FNV):** FO3 + CCRD/CHAL/CHIP/CMNY/CSNO/IMOD/REPU (NV-only casino/items) + WEAP extended with `modelWithMods/firstPersonModelWithMods`.
- **Records (SK):** ACTI/ALCH/AMMO/APPA/ARMA/ARMO/AVIF/BOOK/CLAS/CONT/DOOR/EFSH/EXPL/FLOR/FURN/GRAS/HDPT/INGR/IPCT/KEYM/LIGH/LSCR/MGEF/MISC/PERK/PROJ/SLGM/STAT/TREE/TXST/WEAP/WTHR with SK-specific subrecords (ARMA uses MOD2/MOD3/MOD4/MOD5; TXST uses TX00–TX07; WTHR uses DALC ambient colors). FID types: BOOK/EFSH/EXPL/IPCT/MGEF/PROJ/SCRL/SPEL/WEAP.
- **Not valid on FO4.**

### Invent.Add
- **Patcher:** `ImportInventoryPatcher`
- **Games:** OB-family, FO3, FNV, SK-family, FO4, FO4-VR.
- **Records:** Items in CONT, CREA (OB-family/FO3/FNV), NPC_, COBJ (SK-family), FURN (FO4). FormID change = Invent.Add + Invent.Remove.

### Invent.Change
- **Patcher:** `ImportInventoryPatcher` (change tag)
- **Games:** Same as Invent.Add.
- **Records:** Items in the same records; Change carries forward per-entry count/extra-data changes for items that exist in both master and override.
- **Detection (this script):** `DiffSubrecordList` on `Items`, key=`CNTO\Item`, data paths=`CNTO\Count` (OB-family) or `CNTO\Count|COED` (all other games). Fires only for items present in BOTH master and override whose count (or extra data, on non-OB-family) differs.

### Invent.Remove
- **Patcher:** `ImportInventoryPatcher` (remove tag)
- **Games:** Same as Invent.Add.
- **Records:** Items in the same records; removes items that existed in master.

### Keywords
- **Patcher:** `ImportKeywordsPatcher`
- **Games:** SK-family, FO4, FO4-VR. **Not** OB-family/FO3/FNV (no KWDA subrecord).
- **Records (SK):** KWDA/KSIZ in ACTI/ALCH/AMMO/ARMO/BOOK/FLOR/FURN/INGR/KEYM/LCTN/MGEF/MISC/NPC_/RACE/SCRL/SLGM/SPEL/TACT/WEAP.
- **Records (FO4):** KWDA/KSIZ in ACTI/ALCH/AMMO/ARMO/ARTO/BOOK/CONT/DOOR/FLOR/FURN/IDLM/INGR/KEYM/LCTN/LIGH/MGEF/MISC/MSTT/NPC_/SPEL.

### Names
- **Patcher:** `ImportNamesPatcher`
- **Games:** All BP games.
- **Records (OB-family):** FULL in ACTI/ALCH/AMMO/APPA/ARMO/BOOK/BSGN/CLAS/CLOT/CONT/CREA/DOOR/ENCH/EYES/FACT/FLOR/HAIR/INGR/KEYM/LIGH/MGEF/MISC/NPC_/QUST/RACE/SGST/SLGM/SPEL/WEAP.
- **Records (FO3):** FULL in ACTI/ALCH/AMMO/ARMO/AVIF/BOOK/CLAS/COBJ/CONT/CREA/DOOR/ENCH/EYES/FACT/HAIR/INGR/KEYM/LIGH/MESG/MGEF/MISC/NOTE/NPC_/PERK/QUST/RACE/SPEL/TACT/TERM/WEAP.
- **Records (FNV):** FO3 + CCRD/CHAL/CHIP/CMNY/CSNO/IMOD/RCCT/RCPE/REPU.
- **Records (SK):** FULL in ACTI/ALCH/AMMO/APPA/ARMO/AVIF/BOOK/CLAS/CLFM/CONT/DOOR/ENCH/EXPL/EYES/FACT/FLOR/FURN/HAZD/HDPT/INGR/KEYM/LCTN/LIGH/MESG/MGEF/MISC/MSTT/NPC_/PERK/PROJ/QUST/RACE/SCRL/SHOU/SLGM/SNCT/SPEL/TACT/TREE/WATR/WEAP/WOOP.
- **Records (FO4):** FULL in AACT/ACTI/ALCH/AMMO/ARMO/AVIF/BOOK/CLAS/CLFM/CMPO/CONT/DOOR/ENCH/EXPL/FACT/FLOR/FLST/FURN/HAZD/HDPT/INGR/KEYM/KYWD/LIGH/MESG/MGEF/MISC/MSTT/NOTE/NPC_/OMOD/PERK/PROJ/SCOL/SNCT/SPEL/STAT.

### NPC.AIPackageOverrides
- **Patcher:** `ImportActorsPatcher` (FID attrs, SK-family / FO4 only)
- **Games:** SK-family, FO4, FO4-VR. **Not** OB-family/FO3/FNV (key absent from those `actor_importer_fid_attrs`).
- **Records:** NPC_ `override_package_list_spectator` (SPOR), `override_package_list_observe_dead_body` (OCOR), `override_package_list_guard_warn` (GWOR), `override_package_list_combat` (ECOR).

### NPC.AttackRace
- **Patcher:** `ImportActorsPatcher` (FID)
- **Games:** SK-family, FO4, FO4-VR.
- **Records:** NPC_ (ATKR) `attack_race`.

### NPC.Class
- **Patcher:** `ImportActorsPatcher` (FID)
- **Games:** All BP games with ImportActors.
- **Records:** NPC_ (CNAM) `npc_class`. On OB-family/FO3/FNV, `NPC.Class` is also a (no-op) key for CREA.

### NPC.CrimeFaction
- **Patcher:** `ImportActorsPatcher` (FID)
- **Games:** SK-family, FO4, FO4-VR.
- **Records:** NPC_ (CRIF) `crime_faction`.

### NPC.DefaultOutfit
- **Patcher:** `ImportActorsPatcher` (FID)
- **Games:** SK-family, FO4, FO4-VR.
- **Records:** NPC_ (DOFT) `default_outfit`.

### NPC.Eyes
- **Patcher:** `ImportActorsFacesPatcher`
- **Games:** OB, OB-RE, NE, FO3, FNV. **Not** SK-family/FO4 (no ImportActorsFaces).
- **Records:** NPC_ (ENAM) `eye` (FID).

### NPC.FaceGen
- **Patcher:** `ImportActorsFacesPatcher`
- **Games:** OB, OB-RE, NE, FO3, FNV.
- **Records:** NPC_ `fggs_p` (FGGS), `fgga_p` (FGGA), `fgts_p` (FGTS).

### NPC.Hair
- **Patcher:** `ImportActorsFacesPatcher`
- **Games:** OB, OB-RE, NE, FO3, FNV.
- **Records:** NPC_ (HNAM) `hair` (FID), (LNAM) `hairLength`, (HCLR) `hairRed/hairBlue/hairGreen`.

### NPC.Perks.Add
- **Patcher:** `ImportActorsPerksPatcher` (add tag)
- **Games:** SK-family, FO4, FO4-VR. **Not** OB-family/FO3/FNV.
- **Records:** NPC_ `npc_perks` list (PRKR additions).

### NPC.Perks.Change
- **Patcher:** `ImportActorsPerksPatcher` (change tag)
- **Games:** SK-family, FO4, FO4-VR.
- **Records:** NPC_ `npc_perks` (PRKR rank changes).
- **Detection (this script):** `DiffSubrecordList` on `Perks`, key=`Perk`, data=`Rank`. Fires only for perks present in BOTH master and override with differing rank.

### NPC.Perks.Remove
- **Patcher:** `ImportActorsPerksPatcher` (remove tag)
- **Games:** SK-family, FO4, FO4-VR.
- **Records:** NPC_ `npc_perks` (PRKR removals).

### NPC.Race
- **Patcher:** `ImportActorsPatcher` (FID)
- **Games:** All BP games with ImportActors.
- **Records:** NPC_ (RNAM) `race`. On OB-family/FO3/FNV, `NPC.Race` is also a (no-op) key for CREA.

### NpcFacesForceFullImport
- **Patcher:** `ImportActorsFacesPatcher` (`_force_full_import_tag`)
- **Games:** OB, OB-RE, NE, FO3, FNV.
- **Records:** NPC_ `fggs_p, fgga_p, fgts_p, hairLength, hairRed, hairBlue, hairGreen` (rec attrs) + `eye, hair` (FID attrs). Force-imports all face data without filtering by master, overriding NPC.Eyes/NPC.Hair/NPC.FaceGen.
- **Detection (this script):** `ProcessForceTagHeuristics`, gated on `g_HeuristicForceTags`, NPC_ only. Fires only when ALL THREE of ENAM (eyes), HNAM (hair), and FaceGen Data differ from master simultaneously — any one matching the master suppresses the tag.

### ObjectBounds
- **Patcher:** `ImportObjectBoundsPatcher`
- **Games:** FO3, FNV, SK-family, FO4, FO4-VR. **Not** OB-family (no OBND subrecord — the patcher is not in Oblivion's `patchers` set).
- **Records (FO3):** OBND in ACTI/ADDN/ALCH/AMMO/ARMA/ARMO/ASPC/BOOK/COBJ/CONT/CREA/DOOR/EXPL/FURN/GRAS/IDLM/INGR/KEYM/LIGH/LVLC/LVLI/LVLN/MISC/MSTT/NOTE/NPC_/PROJ/PWAT/SCOL/SOUN/STAT/TACT/TERM/TREE/TXST/WEAP.
- **Records (FNV):** FO3 + CCRD/CHIP/CMNY/IMOD.
- **Records (SK):** OBND in ACTI/ADDN/ALCH/AMMO/APPA/ARMO/ARTO/ASPC/BOOK/CONT/DOOR/DUAL/ENCH/EXPL/FLOR/FURN/GRAS/HAZD/IDLM/INGR/KEYM/LIGH/LVLI/LVLN/LVSP/MISC/MSTT/NPC_/PROJ/SCRL/SLGM/SOUN/SPEL/STAT/TACT/TREE/TXST/WEAP.
- **Records (FO4):** OBND in ACTI/ADDN/ALCH/AMMO/ARMO/ARTO/ASPC/BNDS/BOOK/CMPO/CONT/DOOR/ENCH/EXPL/FLOR/FURN/GRAS/HAZD/IDLM/INGR/KEYM/LIGH/LVLI/LVLN/LVSP/MISC/MSTT/NOTE/NPC_/PKIN/PROJ/SCOL/SOUN/SPEL/STAT.

### Outfits.Add
- **Patcher:** `ImportOutfitsPatcher` (add tag)
- **Games:** SK-family, FO4, FO4-VR. **Not** OB-family/FO3/FNV (no OTFT record).
- **Records:** OTFT `items` list (additions).

### Outfits.Remove
- **Patcher:** `ImportOutfitsPatcher` (remove tag)
- **Games:** SK-family, FO4, FO4-VR.
- **Records:** OTFT `items` list (removals).

### R.AddSpells
- **Patcher:** `ImportRacesSpellsPatcher` (secondary tag)
- **Games:** OB-family, SK-family. **Not** FO3/FNV (ImportRacesSpells absent), **not** FO4.
- **Records:** RACE (SPLO) `spells` additions. **Mutually exclusive with R.ChangeSpells** — Wrye Bash raises `BPConfigError` if a plugin has both.
- **Detection (this script):** `ProcessRaceSpells`. Fires when the override RACE SPLO list adds at least one SPEL vs master AND removes none. SPLO array path is `'Spells'` on OB-family, `'Actor Effects'` on SK-family.

### R.Attributes-F / R.Attributes-M
- **Patcher:** `ImportRacesPatcher`
- **Games:** OB, OB-RE, NE only. **Not** FO3/FNV (keys removed from FO3 `import_races_attrs`), not SK-family (no such keys), not FO4.
- **Records:** RACE (ATTR) female/male `Strength, Intelligence, Willpower, Agility, Speed, Endurance, Personality, Luck`.

### R.Body-F / R.Body-M
- **Patcher:** `ImportRacesPatcher`
- **Games:** OB-family, FO3, FNV. **Not** SK-family, **not** FO4.
- **Records (OB-family):** RACE female/male `TailModel, UpperBodyPath, LowerBodyPath, HandPath, FootPath, TailPath`.
- **Records (FO3/FNV):** RACE female/male `UpperBody, LeftHand, RightHand, UpperBodyTexture`.

### R.Body-Size-F / R.Body-Size-M
- **Patcher:** `ImportRacesPatcher`
- **Games:** OB-family, FO3, FNV, SK-family. **Not** FO4.
- **Records:** RACE (DATA) female/male `Height, Weight`.

### R.ChangeSpells
- **Patcher:** `ImportRacesSpellsPatcher` (primary tag)
- **Games:** OB-family, SK-family. Not FO3/FNV/FO4.
- **Records:** RACE (SPLO) `spells` — adds/removes. **Mutually exclusive with R.AddSpells.**
- **Detection (this script):** `ProcessRaceSpells`. Fires whenever the override removes at least one SPEL from the master's RACE SPLO list (regardless of whether it also adds). Takes precedence over R.AddSpells.

### R.Description
- **Patcher:** `ImportRacesPatcher`
- **Games:** OB-family, FO3, FNV, SK-family. Not FO4.
- **Records:** RACE (DESC) `description`.

### R.Ears
- **Patcher:** `ImportRacesPatcher`
- **Games:** OB-family, FO3, FNV. Not SK-family/FO4.
- **Records:** RACE Face Data Part: Ear (Male/Female) — MODL, MODB, ICON.

### R.Eyes
- **Patcher:** `ImportRacesPatcher`
- **Games:** OB-family, FO3, FNV. Not SK-family/FO4.
- **Records (OB-family):** RACE `eyes` (ENAM, list of FID), `leftEye, rightEye` (Face Data Parts — MODL/MODB/ICON).
- **Records (FO3/FNV):** RACE `eyes` (ENAM), Face Data Parts `femaleLeftEye, femaleRightEye, maleLeftEye, maleRightEye` (MODL/MODB/ICON each).

### R.Hair
- **Patcher:** `ImportRacesPatcher`
- **Games:** OB-family, FO3, FNV. Not SK-family/FO4.
- **Records:** RACE `hairs` (HNAM) list of FID.

### R.Head
- **Patcher:** `ImportRacesPatcher`
- **Games:** OB-family, FO3, FNV. Not SK-family/FO4.
- **Records (OB-family):** RACE `head` (Face Data Part — MODL/MODB/ICON).
- **Records (FO3/FNV):** RACE `femaleHead, maleHead` (Face Data Parts).

### R.Mouth
- **Patcher:** `ImportRacesPatcher`
- **Games:** OB-family, FO3, FNV. Not SK-family/FO4.
- **Records (OB-family):** RACE `mouth, tongue` (Face Data Parts).
- **Records (FO3/FNV):** RACE `maleMouth, femaleMouth, maleTongue, femaleTongue`.

### R.Relations.Add / R.Relations.Change / R.Relations.Remove
- **Patcher:** `ImportRacesRelationsPatcher` (3-way add/change/remove)
- **Games:** OB-family, FO3, FNV. **Not** SK-family, **not** FO4 (ImportRacesRelations absent from those `patchers` sets).
- **Records:** RACE `relations` list keyed by `faction` (XNAM). Change data paths: `Modifier` (OB-family), `Modifier|Group Combat Reaction` (FO3/FNV — `relations_attrs` adds `group_combat_reaction`).
- **Detection for .Change (this script):** `DiffSubrecordList` on `Relations`, key=`Faction`, data=`Modifier` (OB-family) or `Modifier|Group Combat Reaction` (FO3/FNV). Same algorithm as Relations.Change but on RACE rather than FACT.

### R.Skills
- **Patcher:** `ImportRacesPatcher`
- **Games:** OB-family, FO3, FNV, SK-family. Not FO4.
- **Records:** RACE (DATA) `skills` (race skill bonuses).

### R.Stats
- **Patcher:** `ImportRacesPatcher`
- **Games:** SK-family only. Not OB-family/FO3/FNV/FO4.
- **Records:** RACE (DATA) `starting_health, starting_magicka, starting_stamina, base_carry_weight, health_regen, magicka_regen, stamina_regen, unarmed_damage, unarmed_reach`.

### R.Teeth
- **Patcher:** `ImportRacesPatcher`
- **Games:** OB-family, FO3, FNV. Not SK-family/FO4.
- **Records (OB-family):** RACE `teethLower, teethUpper` (Face Data Parts).
- **Records (FO3/FNV):** RACE `femaleTeethLower, femaleTeethUpper, maleTeethLower, maleTeethUpper`.

### R.Voice-F / R.Voice-M
- **Patcher:** `ImportRacesPatcher` (FID)
- **Games:** OB-family, FO3, FNV, SK-family. **Not** FO4.
- **Records:** RACE `femaleVoice / maleVoice` (VNAM on OB-family, VTCK on others).

### Relations.Add / Relations.Change / Relations.Remove
- **Patcher:** `ImportRelationsPatcher` (3-way add/change/remove)
- **Games:** All BP games (OB-family, FO3, FNV, SK-family, FO4, FO4-VR).
- **Records:** FACT `relations` list keyed by `faction` (XNAM). Change data paths: `Modifier` (OB-family), `Modifier|Group Combat Reaction` (FO3/FNV/SK-family/FO4).
- **Detection for Relations.Change (this script):** `DiffSubrecordList` on `Relations`, key=`Faction`, data=`Modifier` (OB-family) or `Modifier|Group Combat Reaction` (all other games). Fires only for relations present in BOTH master and override with differing data.

### Relev
- **Patcher:** `LeveledListsPatcher` (`_re_tag = 'Relev'`)
- **Games:** OB-family, FO3, FNV, SK-family, FO4, FO4-VR.
- **Records:** LVLO entry in LVLC (OB-family/FO3/FNV) / LVLI (all) / LVLN (FO3/FNV/SK-family/FO4) / LVSP (OB-family/SK-family/FO4). See Delev for the per-game leveled_list_types.
- **Detection (this script):** `ProcessDelevRelevTags`. For each shared entry (matched by `LVLO\Reference`), fires if `LVLO\Level` or `LVLO\Count` differs, or — on non-OB-family — if the COED extra-data subrecord's edit values differ.

### Roads
- **Patcher:** `ImportRoadsPatcher` (game-specific — `oblivion/patcher/preservers.py`)
- **Games:** OB, OB-RE, NE only. (The class is registered only in Oblivion's `_dynamic_import_modules`.)
- **Records:** WRLD's child ROAD record (`points_p, connections_p`).

### Scripts
- **Patcher:** `ImportScriptsPatcher`
- **Games:** OB, OB-RE, NE, FO3, FNV. **Not** SK-family (Papyrus, not Obscript), **not** FO4. (ImportScripts not in SK-family/FO4 `patchers` sets.)
- **Records (OB-family):** SCRI in ACTI/ALCH/APPA/ARMO/BOOK/CLOT/CONT/CREA/DOOR/FLOR/FURN/INGR/KEYM/LIGH/LVLC/MISC/NPC_/QUST/SGST/SLGM/WEAP.
- **Records (FO3):** SCRI in ACTI/ALCH/ARMO/BOOK/COBJ/CONT/CREA/DOOR/FURN/INGR/KEYM/LIGH/MISC/NPC_/QUST/TACT/TERM/WEAP.
- **Records (FNV):** FO3 + AMMO/CCRD/CHAL/IMOD.

### Sound
- **Patcher:** `ImportSoundsPatcher`
- **Games:** OB-family, FO3, FNV, SK-family. **Not** FO4.
- **Records (OB-family):** ACTI (SNAM); CONT (SNAM/QNAM); CREA (foot_weight, actor_sounds, inherits_sounds_from); DOOR (SNAM/ANAM/BNAM); LIGH (SNAM); MGEF (casting/bolt/hit/area sounds); SOUN (SNDX + distance/freq/attenuation); WATR (SNAM); WTHR (sounds).
- **Records (FO3):** Many more types — ACTI/ADDN/ALCH/ARMO/ASPC/COBJ/CONT/CREA/DOOR/EXPL/IPCT/KEYM/LIGH/MGEF/MISC/NOTE/PROJ/SOUN/TACT/TERM/WATR/WEAP/WTHR (see `sounds_attrs`/`sounds_fid_attrs` in `fallout3/__init__.py`).
- **Records (FNV):** FO3 + STAT (passthroughSound + random_looping); ASPC extended (dawn/afternoon/dusk/night/walla); CONT/KEYM/MISC add `sound_random_looping`; WEAP adds `sound_gun_shoot_3d, sound_gun_shoot_dist, sound_mod1_shoot_3d/2d/dist`.
- **Records (SK):** Different set — EXPL, IPCT, MGEF (mgef_sounds, casting level), PROJ, SNCT (static volume), SNDR (full descriptor), SOPM (output model), SOUN, ACTI, ADDN, ALCH, AMMO, APPA, ARMA (footstep), ARMO, ASPC (sound, use_sound_from_region, environment_type), BOOK, CONT, DOOR, EFSH (ambient sound), EXPL, FLOR, HAZD, INGR, IPCT, KEYM, LIGH, MISC, MSTT, PROJ, SCRL, SLGM, TACT, TREE (harvest), WATR, WEAP, WTHR.

### SpellStats
- **Patcher:** `ImportSpellStatsPatcher`
- **Games:** OB-family, FO3, FNV, SK-family. **Not** FO4 (ImportSpellStats not in FO4 `patchers` set).
- **Records (OB-family/FO3/FNV):** SPEL (SPIT) `eid, spell_cost, spell_level, spell_type, spell_flags`.
- **Records (SK-family):** SPEL + SCRL (SPIT) `eid, spell_cost, spell_type, spell_charge_time, spell_cast_type, spell_target_type, spell_cast_duration, spell_range, spell_flags` + FID `casting_perk`.

### Stats
- **Patcher:** `ImportStatsPatcher`
- **Games:** OB-family, FO3, FNV, SK-family. **Not** FO4.
- **Records (OB):** ALCH (weight, value), AMMO (weight, value, damage, speed, enchantment_charge), APPA (weight, value, quality), ARMO (weight, value, health, strength), BOOK (weight, value, enchantment_charge), CLOT (weight, value, enchantment_charge), EYES (flags), HAIR (flags), INGR (weight, value), KEYM (weight, value), LIGH (weight, value, duration), MISC (weight, value), SGST (weight, value, uses), SLGM (weight, value), WEAP (weight, value, health, damage, speed, reach, enchantment_charge).
- **Records (FO3):** ALCH/AMMO/ARMA/ARMO/BOOK/EYES/HAIR/HDPT/INGR/KEYM/LIGH/MISC/WEAP — see `fallout3.stats_csv_attrs` for full field list (WEAP has ~30 fields including clipsize, animationMultiplier, spread, fireRate, rumble, crit, etc.).
- **Records (FNV):** FO3 extended — AMMO adds `projPerShot`, ARMA/ARMO add `dt`, WEAP adds `strengthReq, regenRate, killImpulse, impulseDist, skillReq, vatsSkill, vatsDamMult, vatsAp`.
- **Records (SK):** ALCH (weight, value), AMMO (value, damage + weight on SSE only), APPA (weight, value), ARMO (weight, value, armorRating), BOOK (weight, value), EYES (flags), HDPT (flags), INGR (weight, value), KEYM (weight, value), LIGH (weight, value, duration), MISC (weight, value), SLGM (weight, value), WEAP (weight, value, damage, speed, reach, enchantment_charge, stagger, criticalDamage, criticalMultiplier + FID criticalEffect).

### Text
- **Patcher:** `ImportTextPatcher`
- **Games:** OB-family, FO3, FNV, SK-family. **Not** FO4.
- **Records (OB-family):** DESC in BOOK/BSGN/CLAS/LSCR/MGEF/SKIL + BOOK book_text. (RACE description is covered by R.Description.)
- **Records (FO3):** AMMO (short_name), AVIF (description, short_name), BOOK (book_text), CLAS (description), LSCR (description), MESG (description), MGEF (description), NOTE (note_contents), PERK (description), TERM (description).
- **Records (FNV):** FO3 + ACTI (activation_prompt), AMMO (short_name, abbreviation — extends FO3's AMMO), CHAL (description), IMOD (description).
- **Records (SK):** ACTI (activate_text_override), ALCH/AMMO (description, short_name), APPA/ARMO (description), ASTP (male/female parent/child titles), AVIF (description, abbreviation), BOOK (description, book_text), CLAS/COLL (description), FLOR (activate_text_override), LSCR/MESG (description), MGEF (magic_item_description), NPC_ (short_name), PERK/QUST/SCRL/SHOU/SPEL/WEAP (description), WOOP (translation).

### WeaponMods
- **Patcher:** `ImportWeaponModificationsPatcher` (game-specific — `falloutnv/patcher/preservers.py`)
- **Games:** FNV only. (Wrye Bash even adds it explicitly: `FalloutNVGameInfo.allTags = AFallout3GameInfo.allTags | {'WeaponMods'}`.)
- **Records:** WEAP — `modelWithMods (MWD1–7), firstPersonModelWithMods (WNM1–7), weaponMods (WMI1/WMI2/WMI3), effectMod1/2/3, valueAMod1/2/3, valueBMod1/2/3, reloadAnimationMod, vats_mod_required (VATS), dnamFlags2.scopeFromMod (DNAM Flags 2)` + FIDs `sound_mod1_shoot_3d, sound_mod1_shoot_dist, sound_mod1_shoot_2d (WMS1/WMS2)`. Shares subrecords with Graphics and Sound for backwards compatibility; upstream recommends WeaponMods over those.

---

## Appendix A — Tag sets by game

Exact enumeration of the union of `PatchGame.allTags` plus every `patcher_tags` contributed by each game's `patchers` set. `NoMerge` is added dynamically by `initPatchers` if the game supports merging; not listed below.

### OB, OB-RE, NE

`Deactivate, Filter, IIM, MustBeActiveIfImported` +
`Actors.ACBS, Actors.AIData, Actors.AIPackages, Actors.AIPackagesForceAdd, Actors.Anims, Actors.CombatStyle, Actors.DeathItem, Actors.Factions, Actors.RecordFlags, Actors.Skeleton, Actors.Spells, Actors.SpellsForceAdd, Actors.Stats, C.Climate, C.Light, C.MiscFlags, C.Music, C.Name, C.Owner, C.RecordFlags, C.Regions, C.Water, Creatures.Blood, Creatures.Type, Delev, EffectStats, Enchantments, EnchantmentStats, Graphics, Invent.Add, Invent.Change, Invent.Remove, Names, NPC.Class, NPC.Eyes, NPC.FaceGen, NPC.Hair, NPC.Race, NpcFacesForceFullImport, R.AddSpells, R.Attributes-F, R.Attributes-M, R.Body-F, R.Body-M, R.Body-Size-F, R.Body-Size-M, R.ChangeSpells, R.Description, R.Ears, R.Eyes, R.Hair, R.Head, R.Mouth, R.Relations.Add, R.Relations.Change, R.Relations.Remove, R.Skills, R.Teeth, R.Voice-F, R.Voice-M, Relations.Add, Relations.Change, Relations.Remove, Relev, Roads, Scripts, Sound, SpellStats, Stats, Text`

OB-RE omits `RaceChecker`; has no effect on tags.

### FO3

`Deactivate, Filter, MustBeActiveIfImported` +
`Actors.ACBS, Actors.AIData, Actors.AIPackages, Actors.AIPackagesForceAdd, Actors.Anims, Actors.CombatStyle, Actors.DeathItem, Actors.Factions, Actors.RecordFlags, Actors.Skeleton, Actors.Spells, Actors.SpellsForceAdd, Actors.Stats, Actors.Voice, C.Acoustic, C.Climate, C.Encounter, C.ForceHideLand, C.ImageSpace, C.Light, C.MiscFlags, C.Music, C.Name, C.Owner, C.RecordFlags, C.Regions, C.Water, Creatures.Blood, Creatures.Type, Deflst, Delev, Destructible, EffectStats, Enchantments, EnchantmentStats, Graphics, Invent.Add, Invent.Change, Invent.Remove, Names, NPC.Class, NPC.Eyes, NPC.FaceGen, NPC.Hair, NPC.Race, NpcFacesForceFullImport, ObjectBounds, R.Body-F, R.Body-M, R.Body-Size-F, R.Body-Size-M, R.Description, R.Ears, R.Eyes, R.Hair, R.Head, R.Mouth, R.Relations.Add, R.Relations.Change, R.Relations.Remove, R.Skills, R.Teeth, R.Voice-F, R.Voice-M, Relations.Add, Relations.Change, Relations.Remove, Relev, Scripts, Sound, SpellStats, Stats, Text`

### FNV

FO3 set + `WeaponMods`.

### SK, EN

`Deactivate, Filter, MustBeActiveIfImported` +
`Actors.ACBS, Actors.AIData, Actors.AIPackages, Actors.AIPackagesForceAdd, Actors.CombatStyle, Actors.DeathItem, Actors.Factions, Actors.RecordFlags, Actors.Spells, Actors.SpellsForceAdd, Actors.Stats, Actors.Voice, C.Acoustic, C.Climate, C.Encounter, C.ForceHideLand, C.ImageSpace, C.Light, C.Location, C.LockList, C.MiscFlags, C.Music, C.Name, C.Owner, C.RecordFlags, C.Regions, C.SkyLighting, C.Water, Delev, Destructible, EffectStats, Enchantments, EnchantmentStats, Graphics, Invent.Add, Invent.Change, Invent.Remove, Keywords, Names, NPC.AIPackageOverrides, NPC.AttackRace, NPC.Class, NPC.CrimeFaction, NPC.DefaultOutfit, NPC.Perks.Add, NPC.Perks.Change, NPC.Perks.Remove, NPC.Race, ObjectBounds, Outfits.Add, Outfits.Remove, R.AddSpells, R.Body-Size-F, R.Body-Size-M, R.ChangeSpells, R.Description, R.Skills, R.Stats, R.Voice-F, R.Voice-M, Relations.Add, Relations.Change, Relations.Remove, Relev, Sound, SpellStats, Stats, Text`

### SSE, EN-SE, SK-VR

Same as SK plus SSE's additional `stats_attrs` coverage for AMMO (affects `Stats` tag record scope, not the tag list).

### FO4, FO4-VR

`Deactivate, Filter, MustBeActiveIfImported` +
`Actors.ACBS, Actors.AIData, Actors.AIPackages, Actors.AIPackagesForceAdd, Actors.CombatStyle, Actors.DeathItem, Actors.Factions, Actors.RecordFlags, Actors.Spells, Actors.SpellsForceAdd, Actors.Stats, Actors.Voice, Delev, Destructible, EffectStats, Enchantments, EnchantmentStats, Invent.Add, Invent.Change, Invent.Remove, Keywords, Names, NPC.AIPackageOverrides, NPC.AttackRace, NPC.Class, NPC.CrimeFaction, NPC.DefaultOutfit, NPC.Perks.Add, NPC.Perks.Change, NPC.Perks.Remove, NPC.Race, ObjectBounds, Outfits.Add, Outfits.Remove, Relations.Add, Relations.Change, Relations.Remove, Relev`

No `C.*`, `R.*`, `Graphics`, `Scripts`, `Sound`, `SpellStats`, `Stats`, `Text`, `NPC.Eyes/Hair/FaceGen`, `NpcFacesForceFullImport`, `Creatures.*`, `Actors.Anims`, `Actors.Skeleton`, `Roads`, `Deflst`, `WeaponMods` on FO4.

### MW, SF, FO76

No Bashed Patch, no patcher-contributed tags. MW and SF explicitly set `allTags = set()`; FO76 is excluded entirely (not a PatchGame subclass).

## Appendix B — Tag → patcher → `patcher_tags` cross-index

Source: `patcher/patchers/{preservers,mergers}.py` and `game/{oblivion,falloutnv}/patcher/preservers.py`.

| Patcher class | Tags it contributes |
|---|---|
| `ImportActorsPatcher` | Per-game keys in `actor_importer_attrs`/`actor_importer_fid_attrs` (Actors.ACBS, Actors.AIData, Actors.Anims, Actors.CombatStyle, Actors.DeathItem, Actors.RecordFlags, Actors.Skeleton, Actors.Stats, Actors.Voice, Creatures.Blood, Creatures.Type, NPC.AIPackageOverrides, NPC.AttackRace, NPC.Class, NPC.CrimeFaction, NPC.DefaultOutfit, NPC.Race) |
| `ImportActorsAIPackagesPatcher` | Actors.AIPackages, Actors.AIPackagesForceAdd |
| `ImportActorsFacesPatcher` | NPC.Eyes, NPC.FaceGen, NPC.Hair, NpcFacesForceFullImport |
| `ImportActorsFactionsPatcher` | Actors.Factions |
| `ImportActorsPerksPatcher` | NPC.Perks.Add, NPC.Perks.Change, NPC.Perks.Remove |
| `ImportActorsSpellsPatcher` | Actors.Spells, Actors.SpellsForceAdd |
| `ImportCellsPatcher` | Per-game keys in `cellRecAttrs` (C.Acoustic, C.Climate, C.Encounter, C.ForceHideLand, C.ImageSpace, C.Light, C.Location, C.LockList, C.MiscFlags, C.Music, C.Name, C.Owner, C.RecordFlags, C.Regions, C.SkyLighting, C.Water) |
| `ImportDestructiblePatcher` | Destructible |
| `ImportEffectStatsPatcher` | EffectStats |
| `ImportEnchantmentsPatcher` | Enchantments |
| `ImportEnchantmentStatsPatcher` | EnchantmentStats |
| `ImportGraphicsPatcher` | Graphics |
| `ImportInventoryPatcher` | Invent.Add, Invent.Change, Invent.Remove |
| `ImportKeywordsPatcher` | Keywords |
| `ImportNamesPatcher` | Names |
| `ImportObjectBoundsPatcher` | ObjectBounds |
| `ImportOutfitsPatcher` | Outfits.Add, Outfits.Remove |
| `ImportRacesPatcher` | Per-game keys in `import_races_attrs`/`import_races_fid_attrs` (R.Attributes-F/M, R.Body-F/M, R.Body-Size-F/M, R.Description, R.Ears, R.Eyes, R.Hair, R.Head, R.Mouth, R.Skills, R.Stats, R.Teeth, R.Voice-F/M) |
| `ImportRacesRelationsPatcher` | R.Relations.Add, R.Relations.Change, R.Relations.Remove |
| `ImportRacesSpellsPatcher` | R.AddSpells, R.ChangeSpells |
| `ImportRelationsPatcher` | Relations.Add, Relations.Change, Relations.Remove |
| `ImportScriptsPatcher` | Scripts |
| `ImportSoundsPatcher` | Sound |
| `ImportSpellStatsPatcher` | SpellStats |
| `ImportStatsPatcher` | Stats |
| `ImportTextPatcher` | Text |
| `LeveledListsPatcher` | Delev, Relev |
| `FormIDListsPatcher` | Deflst |
| `ImportRoadsPatcher` (OB-only) | Roads |
| `ImportWeaponModificationsPatcher` (FNV-only) | WeaponMods |

Checkers and tweakers (`AliasPluginNames`, `ContentsChecker`, `NpcChecker`, `RaceChecker`, `TimescaleChecker`, `TweakActors`, `TweakAssorted`, `TweakClothes`, `TweakNames`, `TweakRaces`, `TweakSettings`, `ReplaceFormIDs`, `CoblCatalogs`, `CoblExhaustion`, `MorphFactions`, `SEWorldTests`) have no `patcher_tags` — they contribute nothing to `allTags`. The `MergePatches` meta-patcher adds `NoMerge` if the game supports merging.
