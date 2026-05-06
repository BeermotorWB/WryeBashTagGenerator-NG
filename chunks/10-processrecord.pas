{ chunk: ProcessRecord -- per-record dispatch, game-grouped blocks calling ProcessTag for each applicable tag }

Function ProcessRecord(e: IwbMainRecord): integer;

Var 
  o               : IwbMainRecord;
  sSignature      : string;
  sGfxNamesSigs   : string;
  ConflictState   : TConflictThis;
  iFormID         : integer;
Begin
{#IF DEBUG}
  g_DebugCurrentRecord := e;
{#ENDIF}
  ConflictState := ConflictAllForMainRecord(e);

{#IF DEBUG}
  DbgLogUnfiltered(DBG_PER_TAG, '');
  DbgLogUnfiltered(DBG_PER_TAG, Format('--- RECORD %s  [conflict=%s] ---',
    [DbgRecordTag, DbgConflictName(ConflictState)]));
{#ENDIF}

  If (ConflictState = caUnknown)
     Or (ConflictState = caOnlyOne)
     Or (ConflictState = caNoConflict) Then
{#IF SINGLE,MULTI}
    Exit;
{#ELSEIF DEBUG}
    Begin
      DbgLogUnfiltered(DBG_PER_TAG, Format('  ProcessRecord: SKIP entire record (conflict=%s; no override conflict to analyze)',
        [DbgConflictName(ConflictState)]));
      g_DebugCurrentRecord := Nil;
      Exit;
    End;
{#ENDIF}

{#IF DEBUG}
  Try
{#ENDIF}

  // exit if the record should not be processed
  If SameText(g_FileName, 'Dawnguard.esm') Then
    Begin
      iFormID := GetLoadOrderFormID(e) And $00FFFFFF;
      If (iFormID = $00016BCF)
         Or (iFormID = $0001EE6D)
         Or (iFormID = $0001FA4C)
         Or (iFormID = $00039F67)
         Or (iFormID = $0006C3B6) Then
        Exit;
    End;

  // get master record if record is an override
  o := Master(e);

{#IF MULTI}
  If Not Assigned(o) Then
    Exit;

  // Multi mode: ignore non-stock masters to keep each plugin’s results anchored
  // to the base game. Walk up the master chain until we hit a stock master.
  While Assigned(o) And (Not IsStockMasterFile(GetFileName(GetFile(o)))) Do
    o := Master(o);
{#ENDIF}

  If Not Assigned(o) Then
    Exit;

  // if record overrides several masters, then get the last one
  o := HighestOverrideOrSelf(o, OverrideCount(o));

  If Equals(e, o) Then
    Exit;

  // stop processing deleted records to avoid errors
  If GetIsDeleted(e)
     Or GetIsDeleted(o) Then
    Exit;

  sSignature := Signature(e);

  logInfo(Name(e));

  // -------------------------------------------------------------------------------
  // GROUP: Supported tags exclusive to FNV
  // -------------------------------------------------------------------------------
  If wbIsFalloutNV Then
    If sSignature = 'WEAP' Then
      ProcessTag('WeaponMods', e, o);

  // -------------------------------------------------------------------------------
  // GROUP: Supported tags exclusive to TES4
  // -------------------------------------------------------------------------------
  If wbIsOblivion Then
    Begin
      If ContainsStr('CREA NPC_', sSignature) Then
        Begin
          ProcessTag('Actors.Spells', e, o);

          If sSignature = 'CREA' Then
            ProcessTag('Creatures.Blood', e, o);
        End

      Else If sSignature = 'RACE' Then
             Begin
               ProcessRaceSpells(e, o);
               ProcessTag('R.Attributes-F', e, o);
               ProcessTag('R.Attributes-M', e, o);
             End

      Else If sSignature = 'ROAD' Then
             ProcessTag('Roads', e, o)

      Else If sSignature = 'SPEL' Then
             ProcessTag('SpellStats', e, o);

      // Scripts on Oblivion: SCRI subrecord in the signatures below. Oblivion
      // lacks the template flag system, so this is a plain signature check
      // (no 'Use Script' gate like FO3/FNV/Skyrim). Independent If — per-tag
      // dedup is handled inside ProcessTag.
      If ContainsStr('ACTI ALCH APPA ARMO BOOK CLOT CONT CREA DOOR FLOR FURN INGR KEYM LIGH LVLC MISC NPC_ QUST SGST SLGM WEAP', sSignature) Then
        ProcessTag('Scripts', e, o);
    End;

  // -------------------------------------------------------------------------------
  // GROUP: Supported tags exclusive to TES5, SSE
  // -------------------------------------------------------------------------------
  If wbIsSkyrim Then
    Begin
      // NOTE: Each signature branch below is an INDEPENDENT If (not Else If).
      // The Keywords signature list contains 'NPC_', so an If/Else If chain
      // would short-circuit on Keywords and silently skip the dedicated NPC_
      // branch (NPC.Perks.*, Actors.Factions, NPC.AIPackageOverrides,
      // Actors.Spells, NPC.AttackRace, NPC.CrimeFaction, NPC.DefaultOutfit).
      // Per-tag dedup is handled by ProcessTag, so independent Ifs are safe.
      If sSignature = 'CELL' Then
        Begin
          ProcessTag('C.Location', e, o);
          ProcessTag('C.LockList', e, o);
          ProcessTag('C.Regions', e, o);
          ProcessTag('C.SkyLighting', e, o);
        End;

      If ContainsStr('ACTI ALCH AMMO ARMO BOOK FLOR FURN INGR KEYM LCTN MGEF MISC NPC_ RACE SCRL SLGM SPEL TACT WEAP', sSignature) Then
        ProcessTag('Keywords', e, o);

      If sSignature = 'FACT' Then
        Begin
          ProcessTag('Relations.Add', e, o);
          ProcessTag('Relations.Change', e, o);
          ProcessTag('Relations.Remove', e, o);
        End;

      If sSignature = 'NPC_' Then
        Begin
          ProcessTag('NPC.Perks.Add', e, o);
          ProcessTag('NPC.Perks.Change', e, o);
          ProcessTag('NPC.Perks.Remove', e, o);

          TryTagGatedByFlag('Actors.Factions',        'Use Factions',     e, o);
          TryTagGatedByFlag('NPC.AIPackageOverrides', 'Use AI Packages',  e, o);
          // Skyrim/SSE Actors.Spells — skip if the NPC inherits its spell list
          // from a template (modifying SPLO directly would be ignored by the engine).
          TryTagGatedByFlag('Actors.Spells',          'Use Spell List',   e, o);

          ProcessTag('NPC.AttackRace', e, o);
          ProcessTag('NPC.CrimeFaction', e, o);
          ProcessTag('NPC.DefaultOutfit', e, o);
        End;

      If sSignature = 'OTFT' Then
        Begin
          ProcessTag('Outfits.Add', e, o);
          ProcessTag('Outfits.Remove', e, o);
        End;

      // R.AddSpells / R.ChangeSpells (Skyrim/SSE/Enderal). ProcessRaceSpells
      // emits the Add/Change split (Adds-only -> R.AddSpells, Removes present
      // -> R.ChangeSpells) using the per-game SPLO array path.
      If sSignature = 'RACE' Then
        ProcessRaceSpells(e, o);

      // COBJ (Constructible Object) inventory on Skyrim+. Uses the same
      // 'Items' / CNTO shape as CONT, so the standard Invent.* handlers apply.
      If sSignature = 'COBJ' Then
        Begin
          ProcessTag('Invent.Add', e, o);
          ProcessTag('Invent.Change', e, o);
          ProcessTag('Invent.Remove', e, o);
        End;

      // Import Destructible (skyrim __init__ destructible_types; no FO3 FNV gating).
      If ContainsStr('ACTI ALCH AMMO APPA ARMO BOOK CONT DOOR FLOR FURN KEYM LIGH MISC MSTT NPC_ PROJ SCRL SLGM TACT WEAP', sSignature) Then
        ProcessTag('Destructible', e, o);
    End;

  // -------------------------------------------------------------------------------
  // GROUP: Supported tags exclusive to FO3, FNV
  // -------------------------------------------------------------------------------
  If wbIsFallout3 Or wbIsFalloutNV Then
    Begin
      If sSignature = 'FLST' Then
        ProcessTag('Deflst', e, o);

      // Creatures.Blood applies to CREA on both Oblivion (NAM0/NAM1) and
      // FO3/FNV (CNAM). The Oblivion dispatch lives in the Oblivion block
      // above; this is the FO3/FNV counterpart.
      If sSignature = 'CREA' Then
        ProcessTag('Creatures.Blood', e, o);

      If ContainsStr('ACTI ALCH AMMO BOOK CONT DOOR FURN IMOD KEYM MISC MSTT PROJ TACT TERM WEAP', sSignature) Then
        ProcessTag('Destructible', e, o)

        // special handling for CREA and NPC_ record types
      Else If ContainsStr('CREA NPC_', sSignature) Then
             TryTagGatedByFlag('Destructible', 'Use Model/Animation', e, o)

             // added in Wrye Bash 307 Beta 6
      Else If sSignature = 'FACT' Then
             Begin
               ProcessTag('Relations.Add', e, o);
               ProcessTag('Relations.Change', e, o);
               ProcessTag('Relations.Remove', e, o);
             End;
    End;

  // -------------------------------------------------------------------------------
  // GROUP: Supported tags exclusive to FO3, FNV, TES4
  // -------------------------------------------------------------------------------
  If wbIsFallout3 Or wbIsFalloutNV Or wbIsOblivion Then
    Begin
      If ContainsStr('CREA NPC_', sSignature) Then
        Begin
          If sSignature = 'CREA' Then
            ProcessTag('Creatures.Type', e, o);

          g_Tag := 'Actors.Factions';
          If wbIsOblivion Or Not CompareFlags(e, o, 'ACBS\Template Flags', 'Use Factions', False, False) Then
            ProcessTag('Actors.Factions', e, o);

          If sSignature = 'NPC_' Then
            Begin
              ProcessTag('NPC.Eyes', e, o);
              ProcessTag('NPC.FaceGen', e, o);
              ProcessTag('NPC.Hair', e, o);

              // Oblivion-only here: NPC.Class / NPC.Race for FO3/FNV/Skyrim are
              // emitted further down with template-flag gating. Oblivion has no
              // template flag system, so emit unconditionally.
              If wbIsOblivion Then
                Begin
                  ProcessTag('NPC.Class', e, o);
                  ProcessTag('NPC.Race',  e, o);
                End;
            End;
        End

      Else If sSignature = 'RACE' Then
             Begin
               ProcessTag('R.Body-F', e, o);
               ProcessTag('R.Body-M', e, o);
               ProcessTag('R.Body-Size-F', e, o);
               ProcessTag('R.Body-Size-M', e, o);
               ProcessTag('R.Eyes', e, o);
               ProcessTag('R.Hair', e, o);
               ProcessTag('R.Relations.Add', e, o);
               ProcessTag('R.Relations.Change', e, o);
               ProcessTag('R.Relations.Remove', e, o);
               // R.Ears/Head/Mouth/Teeth are Oblivion/FO3/FNV-only per Wrye
               // Bash; emitted here rather than in the FO3/FNV/Skyrim block.
               ProcessTag('R.Ears', e, o);
               ProcessTag('R.Head', e, o);
               ProcessTag('R.Mouth', e, o);
               ProcessTag('R.Teeth', e, o);
             End;
    End;

  // Skyrim/SSE/Enderal: RACE body/eyes/hair/relations (WB import_races_attrs);
  // no R.Ears/Head/Mouth/Teeth here (FO3/FNV/Oblivion-only in WB).
  If wbIsSkyrim And (sSignature = 'RACE') Then
    Begin
      ProcessTag('R.Body-F', e, o);
      ProcessTag('R.Body-M', e, o);
      ProcessTag('R.Body-Size-F', e, o);
      ProcessTag('R.Body-Size-M', e, o);
      ProcessTag('R.Eyes', e, o);
      ProcessTag('R.Hair', e, o);
      ProcessTag('R.Relations.Add', e, o);
      ProcessTag('R.Relations.Change', e, o);
      ProcessTag('R.Relations.Remove', e, o);
    End;

  // -------------------------------------------------------------------------------
  // GROUP: Supported tags exclusive to FO3, FNV, TES5, SSE
  // -------------------------------------------------------------------------------
  If wbIsFallout3 Or wbIsFalloutNV Or wbIsSkyrim Then
    Begin
      If ContainsStr('CREA NPC_', sSignature) Then
        Begin
          TryTagGatedByFlag('Actors.ACBS',      'Use Stats',        e, o);
          TryTagGatedByFlag('Actors.AIData',    'Use AI Data',      e, o);
          TryTagGatedByFlag('Actors.AIPackages','Use AI Packages',  e, o);

          If sSignature = 'CREA' Then
            TryTagGatedByFlag('Actors.Anims',   'Use Model/Animation', e, o);

          If Not CompareFlags(e, o, 'ACBS\Template Flags', 'Use Traits', False, False) Then
            Begin
              ProcessTag('Actors.CombatStyle', e, o);
              ProcessTag('Actors.DeathItem', e, o);
            End;

          TryTagGatedByFlag('Actors.Skeleton',  'Use Model/Animation', e, o);
          TryTagGatedByFlag('Actors.Stats',     'Use Stats',           e, o);

          If wbIsFallout3 Or wbIsFalloutNV Or (sSignature = 'NPC_') Then
            ProcessTag('Actors.Voice', e, o);

          If sSignature = 'NPC_' Then
            Begin
              TryTagGatedByFlag('NPC.Class', 'Use Traits', e, o);
              TryTagGatedByFlag('NPC.Race',  'Use Traits', e, o);
            End;

          TryTagGatedByFlag('Scripts', 'Use Script', e, o);

          // FO3/FNV Actors.Spells (CREA + NPC_). Skyrim/SSE NPC_ Actors.Spells is
          // handled by the dedicated wbIsSkyrim NPC_ block above. The FNV/FO3
          // template flag is named 'Use Actor Effect List' (not 'Use Spell List').
          If wbIsFallout3 Or wbIsFalloutNV Then
            TryTagGatedByFlag('Actors.Spells', 'Use Actor Effect List', e, o);
        End;

      If sSignature = 'CELL' Then
        Begin
          ProcessTag('C.Acoustic', e, o);
          ProcessTag('C.Encounter', e, o);
          ProcessTag('C.ForceHideLand', e, o);
          ProcessTag('C.ImageSpace', e, o);
        End;

      If ContainsStr('ACTI ALCH ARMO CONT DOOR FLOR FURN INGR KEYM LIGH LVLC MISC QUST WEAP', sSignature) Then
        ProcessTag('Scripts', e, o);
    End;

  // -------------------------------------------------------------------------------
  // GROUP: RACE tags supported on every game except FO4.
  // R.Description / R.Skills / R.Voice-F / R.Voice-M apply to Oblivion,
  // FO3/FNV, and Skyrim per Wrye Bash.
  // -------------------------------------------------------------------------------
  If Not wbIsFallout4 And (sSignature = 'RACE') Then
    Begin
      ProcessTag('R.Description', e, o);
      ProcessTag('R.Skills', e, o);
      If wbIsSkyrim Then
        ProcessTag('R.Stats', e, o);
      ProcessTag('R.Voice-F', e, o);
      ProcessTag('R.Voice-M', e, o);
    End;

  // -------------------------------------------------------------------------------
  // GROUP: Supported tags exclusive to FO3, FNV, TES4, TES5, SSE
  // -------------------------------------------------------------------------------
  If wbIsFallout3 Or wbIsFalloutNV Or wbIsOblivion Or wbIsSkyrim Then
    Begin
      If sSignature = 'CELL' Then
        Begin
          ProcessTag('C.Climate', e, o);
          ProcessTag('C.Light', e, o);
          ProcessTag('C.MiscFlags', e, o);
          ProcessTag('C.Music', e, o);
          ProcessTag('C.Name', e, o);
          ProcessTag('C.Owner', e, o);
          ProcessTag('C.RecordFlags', e, o);
          // C.Regions: FO3 FNV Oblivion cellRecAttrs; Skyrim emits above (wbIsSkyrim block).
          If Not wbIsSkyrim Then
            ProcessTag('C.Regions', e, o);
          ProcessTag('C.Water', e, o);
        End;

      // Delev, Relev — leveled list types per game (bush.game.leveled_list_types)
      If wbIsOblivion And ContainsStr('LVLC LVLI LVSP', sSignature) Then
        ProcessDelevRelevTags(e, o);
      If (wbIsFallout3 Or wbIsFalloutNV) And ContainsStr('LVLC LVLI LVLN', sSignature) Then
        ProcessDelevRelevTags(e, o);
      If wbIsSkyrim And ContainsStr('LVLI LVLN LVSP', sSignature) Then
        ProcessDelevRelevTags(e, o);

      sGfxNamesSigs := 'ACTI ALCH AMMO APPA ARMO BOOK BSGN CLAS CLOT DOOR FLOR FURN INGR KEYM LIGH MGEF MISC SGST SLGM WEAP';
      If wbIsSkyrim Then
        sGfxNamesSigs := 'ACTI ALCH AMMO APPA ARMO AVIF BOOK CLAS CLFM CONT DOOR ENCH EXPL EYES FACT FLOR FURN HAZD HDPT INGR KEYM LCTN LIGH MESG MGEF MISC MSTT NPC_ PERK PROJ QUST RACE SCRL SHOU SLGM SNCT SPEL TACT TREE WATR WEAP WOOP';

      If ContainsStr(sGfxNamesSigs, sSignature) Then
        Begin
          ProcessTag('Graphics', e, o);
          ProcessTag('Names', e, o);
          ProcessTag('Stats', e, o);

          If ContainsStr('ACTI DOOR LIGH MGEF', sSignature) Then
            Begin
              ProcessTag('Sound', e, o);

              If sSignature = 'MGEF' Then
                ProcessTag('EffectStats', e, o);
            End;
        End;

      If ContainsStr('CREA EFSH GRAS LSCR LTEX REGN STAT TREE', sSignature) Then
        ProcessTag('Graphics', e, o);

      // OB-only Graphics dispatch for record types not covered by sGfxNamesSigs.
      // Per Wrye Bash OB Graphics: CONT (MODL), EYES (ICON), HAIR (ICON+MODL),
      // QUST (ICON), SKIL (ICON). Handler buckets in the Graphics ProcessTag
      // branch are extended to match.
      If wbIsOblivion And ContainsStr('CONT EYES HAIR QUST SKIL', sSignature) Then
        ProcessTag('Graphics', e, o);

      // FO3/FNV-only Stats dispatch for ARMA.
      // evaluates ARMA DNAM; only the dispatch was missing.
      If (wbIsFallout3 Or wbIsFalloutNV) And (sSignature = 'ARMA') Then
        ProcessTag('Stats', e, o);

      If sSignature = 'CONT' Then
        Begin
          ProcessTag('Invent.Add', e, o);
          ProcessTag('Invent.Change', e, o);
          ProcessTag('Invent.Remove', e, o);
          ProcessTag('Names', e, o);
          ProcessTag('Sound', e, o);
        End;

      If ContainsStr('DIAL ENCH EYES FACT HAIR QUST RACE SPEL WRLD', sSignature) Then
        Begin
          ProcessTag('Names', e, o);

          If sSignature = 'ENCH' Then
            ProcessTag('EnchantmentStats', e, o);

          If sSignature = 'SPEL' Then
            ProcessTag('SpellStats', e, o);
        End;

      // FO3/FNV-only Names dispatch for record types not covered by
      // sGfxNamesSigs (which is OB-shaped on these games). Names handler is a
      // uniform EvaluateByPath(FULL); extension is dispatch-only.
      If (wbIsFallout3 Or wbIsFalloutNV) And ContainsStr('AVIF COBJ MESG NOTE PERK TACT TERM', sSignature) Then
        ProcessTag('Names', e, o);

      If sSignature = 'FACT' Then
        Begin
          ProcessTag('Relations.Add', e, o);
          ProcessTag('Relations.Change', e, o);
          ProcessTag('Relations.Remove', e, o);
        End;

      If (sSignature = 'WTHR') Then
        ProcessTag('Sound', e, o);

      // special handling for CREA and NPC_
      If ContainsStr('CREA NPC_', sSignature) Then
        Begin
          If wbIsOblivion Or wbIsFallout3 Or wbIsFalloutNV Or (sSignature = 'NPC_') Then
            ProcessTag('Actors.RecordFlags', e, o);

          If wbIsOblivion Then
            Begin
              ProcessTag('Invent.Add', e, o);
              ProcessTag('Invent.Change', e, o);
              ProcessTag('Invent.Remove', e, o);
              ProcessTag('Names', e, o);

              If sSignature = 'CREA' Then
                ProcessTag('Sound', e, o);
            End;

          If Not wbIsOblivion Then
            Begin
              TryTagGatedByFlag('Invent.Add',    'Use Inventory', e, o);
              TryTagGatedByFlag('Invent.Change', 'Use Inventory', e, o);
              TryTagGatedByFlag('Invent.Remove', 'Use Inventory', e, o);
              TryTagGatedByFlag('Names',         'Use Base Data', e, o);

              If sSignature = 'CREA' Then
                TryTagGatedByFlag('Sound', 'Use Model/Animation', e, o);
            End;
        End;
    End;

  // -------------------------------------------------------------------------------
  // GROUP: Fallout 4 (Wrye Bash patcher coverage)
  // -------------------------------------------------------------------------------
  If wbIsFallout4 Then
    Begin
      If sSignature = 'NPC_' Then
        Begin
          // FO4 template flag names are bare words (no 'Use ' prefix) compared
          // to the FO3/FNV/Skyrim set.
          TryTagGatedByFlag('Actors.ACBS',           'Stats',       e, o);
          TryTagGatedByFlag('Actors.AIData',         'AI Data',     e, o);
          TryTagGatedByFlag('Actors.AIPackages',     'AI Packages', e, o);

          If Not CompareFlags(e, o, 'ACBS\Template Flags', 'Traits', False, False) Then
            Begin
              ProcessTag('Actors.CombatStyle', e, o);
              ProcessTag('Actors.DeathItem', e, o);
            End;

          TryTagGatedByFlag('Actors.Stats',          'Stats',       e, o);

          ProcessTag('Actors.Voice', e, o);
          ProcessTag('Actors.RecordFlags', e, o);

          TryTagGatedByFlag('NPC.Class',             'Traits',      e, o);
          TryTagGatedByFlag('NPC.Race',              'Traits',      e, o);

          ProcessTag('NPC.Perks.Add', e, o);
          ProcessTag('NPC.Perks.Change', e, o);
          ProcessTag('NPC.Perks.Remove', e, o);

          TryTagGatedByFlag('Actors.Factions',       'Factions',    e, o);
          TryTagGatedByFlag('NPC.AIPackageOverrides','AI Packages', e, o);

          ProcessTag('NPC.AttackRace', e, o);
          ProcessTag('NPC.CrimeFaction', e, o);
          ProcessTag('NPC.DefaultOutfit', e, o);

          TryTagGatedByFlag('Invent.Add',    'Inventory', e, o);
          TryTagGatedByFlag('Invent.Change', 'Inventory', e, o);
          TryTagGatedByFlag('Invent.Remove', 'Inventory', e, o);
          TryTagGatedByFlag('Names',         'Base Data', e, o);

          ProcessTag('Actors.Spells', e, o);
        End;

      If ContainsStr('ACTI ALCH AMMO ARMO ARTO BOOK CONT DOOR FLOR FURN IDLM INGR KEYM LCTN LIGH MGEF MISC MSTT NPC_ SPEL', sSignature) Then
        ProcessTag('Keywords', e, o);

      If ContainsStr('AACT ACTI ALCH AMMO ARMO AVIF BOOK CLAS CLFM CMPO CONT DOOR ENCH EXPL FACT FLOR FLST FURN HAZD HDPT INGR KEYM KYWD LIGH MESG MGEF MISC MSTT NOTE NPC_ OMOD PERK PROJ SCOL SNCT SPEL STAT', sSignature) Then
        ProcessTag('Names', e, o);

      If ContainsStr('ACTI ALCH AMMO ARMO BOOK CONT DOOR FLOR FURN INGR KEYM LIGH MISC MSTT NPC_ PROJ', sSignature) Then
        ProcessTag('Destructible', e, o);

      If sSignature = 'CONT' Then
        Begin
          ProcessTag('Invent.Add', e, o);
          ProcessTag('Invent.Change', e, o);
          ProcessTag('Invent.Remove', e, o);
        End;

      If sSignature = 'FURN' Then
        Begin
          ProcessTag('Invent.Add', e, o);
          ProcessTag('Invent.Change', e, o);
          ProcessTag('Invent.Remove', e, o);
        End;

      // WB inventory_types: CONT, FURN, NPC_. COBJ shares list/inventory import patterns for recipes.
      If sSignature = 'COBJ' Then
        Begin
          ProcessTag('Invent.Add', e, o);
          ProcessTag('Invent.Change', e, o);
          ProcessTag('Invent.Remove', e, o);
        End;

      If sSignature = 'FACT' Then
        Begin
          ProcessTag('Relations.Add', e, o);
          ProcessTag('Relations.Change', e, o);
          ProcessTag('Relations.Remove', e, o);
        End;

      If sSignature = 'OTFT' Then
        Begin
          ProcessTag('Outfits.Add', e, o);
          ProcessTag('Outfits.Remove', e, o);
        End;

      // Deflst applies to FO3/FNV only per Wrye Bash; FO4 has no equivalent.

      If sSignature = 'MGEF' Then
        ProcessTag('EffectStats', e, o);

      If sSignature = 'ENCH' Then
        ProcessTag('EnchantmentStats', e, o);

      If ContainsStr('ARMO EXPL', sSignature) Then
        Begin
          ProcessTag('Enchantments', e, o);
          ProcessTag('Names', e, o);
        End;

      If ContainsStr('LVLI LVLN LVSP', sSignature) Then
        ProcessDelevRelevTags(e, o);
    End;

  // ObjectBounds — per-game signature whitelist.
  g_Tag := 'ObjectBounds';

  If wbIsFallout3 And ContainsStr('ACTI ADDN ALCH AMMO ARMA ARMO ASPC BOOK COBJ CONT CREA DOOR EXPL FURN GRAS IDLM INGR KEYM LIGH LVLC LVLI LVLN MISC MSTT NOTE NPC_ PROJ PWAT SCOL SOUN STAT TACT TERM TREE TXST WEAP', sSignature) Then
    ProcessTag(g_Tag, e, o);

  If wbIsFalloutNV And ContainsStr('ACTI ADDN ALCH AMMO ARMA ARMO ASPC BOOK CCRD CHIP CMNY COBJ CONT CREA DOOR EXPL FURN GRAS IDLM IMOD INGR KEYM LIGH LVLC LVLI LVLN MISC MSTT NOTE NPC_ PROJ PWAT SCOL SOUN STAT TACT TERM TREE TXST WEAP', sSignature) Then
    ProcessTag(g_Tag, e, o);

  If wbIsSkyrim And ContainsStr('ACTI ADDN ALCH AMMO APPA ARMO ARTO ASPC BOOK CONT DOOR DUAL ENCH EXPL FLOR FURN GRAS HAZD IDLM INGR KEYM LIGH LVLI LVLN LVSP MISC MSTT NPC_ PROJ SCRL SLGM SOUN SPEL STAT TACT TREE TXST WEAP', sSignature) Then
    ProcessTag(g_Tag, e, o);

  If wbIsFallout4 And ContainsStr('ACTI ADDN ALCH AMMO ARMO ARTO ASPC BNDS BOOK CMPO CONT DOOR ENCH EXPL FLOR FURN GRAS HAZD IDLM INGR KEYM LIGH LVLI LVLN LVSP MISC MSTT NOTE NPC_ PKIN PROJ SCOL SOUN SPEL STAT', sSignature) Then
    ProcessTag(g_Tag, e, o);

  // Text — per-game signature whitelist. Not applicable to FO4.
  If Not wbIsFallout4 Then
    Begin
    g_Tag := 'Text';

      If wbIsOblivion And ContainsStr('BOOK BSGN CLAS LSCR MGEF SKIL', sSignature) Then
        ProcessTag(g_Tag, e, o);

      If wbIsFallout3 And ContainsStr('AVIF BOOK CLAS LSCR MESG MGEF NOTE PERK TERM', sSignature) Then
        ProcessTag(g_Tag, e, o);

      If wbIsFalloutNV And ContainsStr('AVIF BOOK CHAL CLAS IMOD LSCR MESG MGEF NOTE PERK TERM', sSignature) Then
        ProcessTag(g_Tag, e, o);

      If wbIsSkyrim And ContainsStr('ALCH AMMO APPA ARMO AVIF BOOK CLAS LSCR MESG MGEF SCRL SHOU SPEL WEAP', sSignature) Then
        ProcessTag(g_Tag, e, o);
    End;

  // Heuristic Force* tags (opt-in; runs after all other detection so it can read TagExists state).
  ProcessForceTagHeuristics(e, o);
{#IF DEBUG}

  Finally
    g_DebugCurrentRecord := Nil;
  End;
{#ENDIF}
End;
