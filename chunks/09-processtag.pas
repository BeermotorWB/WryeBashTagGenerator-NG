{ chunk: ProcessTag -- the ~1,080-line Else-If switch dispatching per-tag detection logic }

Procedure ProcessTag(ATag: String; e: IInterface; m: IInterface);

Var 
  x          : IInterface;
  y          : IInterface;
  a          : IInterface;
  b          : IInterface;
  j          : IInterface;
  k          : IInterface;
  sSignature : string;
Begin
  g_Tag := ATag;
  g_DebugCurrentTag := ATag;
  DbgSuggestSnapshot;

  DbgLog(DBG_PER_TAG, Format('CONSIDER tag=%s on %s', [ATag, DbgRecordTag]));
  Inc(g_DebugIndent);

  Try
  If TagExists(g_Tag) Then
    Exit;

  sSignature := Signature(e);

  // Bookmark: Actors.ACBS
  If (g_Tag = 'Actors.ACBS') Then
    Begin
      x := ElementBySignature(e, 'ACBS');
      y := ElementBySignature(m, 'ACBS');

      If wbIsFallout4 And (sSignature = 'NPC_') Then
        Begin
          a := ElementByName(x, 'Flags');
          b := ElementByName(y, 'Flags');

          If Not CompareFlags(x, y, 'Template Flags', 'Stats', False, False) And CompareKeys(a, b) Then
            Exit;

          EvaluateByPath(x, y, 'XP Value Offset');
          EvaluateByPath(x, y, 'Level');
          EvaluateByPath(x, y, 'Calc min level');
          EvaluateByPath(x, y, 'Calc max level');
          EvaluateByPath(x, y, 'Disposition Base');
          EvaluateByPath(x, y, 'Bleedout Override');
          EvaluateByPath(x, y, 'Template Flags');
        End
      Else If wbIsSkyrim And (sSignature = 'NPC_') Then
        Begin
          a := ElementByName(x, 'Flags');
          b := ElementByName(y, 'Flags');

          If Not CompareFlags(x, y, 'Template Flags', 'Use Stats', False, False) And CompareKeys(a, b) Then
            Exit;

          EvaluateByPath(x, y, 'Magicka Offset');
          EvaluateByPath(x, y, 'Stamina Offset');
          EvaluateByPath(x, y, 'Level');
          EvaluateByPath(x, y, 'Calc min level');
          EvaluateByPath(x, y, 'Calc max level');
          EvaluateByPath(x, y, 'Speed Multiplier');
          EvaluateByPath(x, y, 'Disposition Base (unused)');
          EvaluateByPath(x, y, 'Health Offset');
          EvaluateByPath(x, y, 'Bleedout Override');
          EvaluateByPath(x, y, 'Template Flags');
        End
      Else
        Begin
          a := ElementByName(x, 'Flags');
          b := ElementByName(y, 'Flags');

          If wbIsOblivion And CompareKeys(a, b) Then
            Exit;

          If Not wbIsOblivion And Not CompareFlags(x, y, 'Template Flags', 'Use Base Data', False, False) And CompareKeys(a, b) Then
            Exit;

          EvaluateByPath(x, y, 'Fatigue');
          EvaluateByPath(x, y, 'Level');
          EvaluateByPath(x, y, 'Calc min');
          EvaluateByPath(x, y, 'Calc max');
          EvaluateByPath(x, y, 'Speed Multiplier');
          EvaluateByPath(e, m, 'DATA\Base Health');

          If wbIsOblivion Or Not CompareFlags(x, y, 'Template Flags', 'Use AI Data', False, False) Then
            EvaluateByPath(x, y, 'Barter gold');
        End;
    End

    // Bookmark: Actors.AIData
  Else If (g_Tag = 'Actors.AIData') Then
         Begin
           x := ElementBySignature(e, 'AIDT');
           y := ElementBySignature(m, 'AIDT');

           If wbIsFallout4 Then
             Begin
               EvaluateByPath(x, y, 'Aggression');
               EvaluateByPath(x, y, 'Confidence');
               EvaluateByPath(x, y, 'Energy Level');
               EvaluateByPath(x, y, 'Morality');
               EvaluateByPath(x, y, 'Mood');
               EvaluateByPath(x, y, 'Assistance');
               j := ElementByPath(x, 'Aggro');
               k := ElementByPath(y, 'Aggro');
               If Assigned(j) And Assigned(k) Then
                 Evaluate(j, k);
               EvaluateByPath(x, y, 'No Slow Approach');
             End
           Else If wbIsSkyrim And ContainsStr('CREA NPC_', sSignature) Then
             Begin
               EvaluateByPath(x, y, 'Aggression');
               EvaluateByPath(x, y, 'Confidence');
               EvaluateByPath(x, y, 'Energy Level');
               EvaluateByPath(x, y, 'Morality');
               EvaluateByPath(x, y, 'Mood');
               EvaluateByPath(x, y, 'Assistance');
               EvaluateByPath(x, y, 'Aggro\Aggro Radius Behavior');
               EvaluateByPath(x, y, 'Aggro\Warn');
               EvaluateByPath(x, y, 'Aggro\Warn/Attack');
               EvaluateByPath(x, y, 'Aggro\Attack');
             End
           Else
             Begin
               EvaluateByPath(x, y, 'Aggression');
               EvaluateByPath(x, y, 'Confidence');
               EvaluateByPath(x, y, 'Energy level');
               EvaluateByPath(x, y, 'Responsibility');
               EvaluateByPath(x, y, 'Teaches');
               EvaluateByPath(x, y, 'Maximum training level');

               // Added in FO3/FNV; not present on Oblivion AIDT. EvaluateByPath
               // is safe on Oblivion (missing path is a silent no-op).
               If wbIsFallout3 Or wbIsFalloutNV Then
                 Begin
                   EvaluateByPath(x, y, 'Mood');
                   EvaluateByPath(x, y, 'Assistance');
                   EvaluateByPath(x, y, 'Aggro Radius Behavior');
                   EvaluateByPath(x, y, 'Aggro Radius');
                 End;

               If CompareNativeValues(x, y, 'Buys/Sells and Services') Then
                 Exit;
             End;
         End

         // Bookmark: Actors.AIPackages
  Else If (g_Tag = 'Actors.AIPackages') Then
         EvaluateByPath(e, m, 'Packages')

         // Bookmark: Actors.Anims
  Else If (g_Tag = 'Actors.Anims') Then
         EvaluateByPath(e, m, 'KFFZ')

         // Bookmark: Actors.CombatStyle
  Else If (g_Tag = 'Actors.CombatStyle') Then
         EvaluateByPath(e, m, 'ZNAM')

         // Bookmark: Actors.DeathItem
  Else If (g_Tag = 'Actors.DeathItem') Then
         EvaluateByPath(e, m, 'INAM')

         // Bookmark: NPC.Perks.Add (TES5/SSE/FO4)
         // Set-diff on Perks[*]\Perk (FormID). Element-count-only would miss
         // substitutions (swap one perk for another at same total count).
  Else If (g_Tag = 'NPC.Perks.Add') Then
         EvaluateListAdd(e, m, 'Perks', 'Perk')

         // Bookmark: NPC.Perks.Change
         // Match entries on Perk; only fire if a shared perk's Rank differs.
         // Adds/removes go to NPC.Perks.Add / NPC.Perks.Remove.
  Else If (g_Tag = 'NPC.Perks.Change') Then
         DiffSubrecordList(e, m, 'NPC.Perks.Change', 'Perks', 'Perk', 'Rank')

         // Bookmark: NPC.Perks.Remove
  Else If (g_Tag = 'NPC.Perks.Remove') Then
         EvaluateListRemove(e, m, 'Perks', 'Perk')

         // Bookmark: Actors.RecordFlags (!FO4)
  Else If (g_Tag = 'Actors.RecordFlags') Then
         EvaluateByPath(e, m, 'Record Header\Record Flags')

         // Bookmark: Actors.Skeleton
  Else If (g_Tag = 'Actors.Skeleton') Then
         Begin
           // assign Model elements
           x := ElementByName(e, 'Model');
           y := ElementByName(m, 'Model');

           // exit if the Model property does not exist in the control record
           If Not Assigned(x) Then
             Exit;

           // evaluate properties
           EvaluateByPath(x, y, 'MODL');
           EvaluateByPath(x, y, 'MODB');
           EvaluateByPath(x, y, 'MODT');
         End

         // Bookmark: Actors.Spells
  Else If (g_Tag = 'Actors.Spells') Then
         EvaluateByPath(e, m, ActorSpellArrayPath)

         // Bookmark: Actors.Stats
  Else If (g_Tag = 'Actors.Stats') Then
         Begin
           If wbIsFallout4 And (sSignature = 'NPC_') Then
             EvaluateByPath(e, m, 'PRPS')
           Else
             Begin
               x := ElementBySignature(e, 'DATA');
               y := ElementBySignature(m, 'DATA');

               If sSignature = 'CREA' Then
                 Begin
                   EvaluateByPath(x, y, 'Health');
                   EvaluateByPath(x, y, 'Combat Skill');
                   EvaluateByPath(x, y, 'Magic Skill');
                   EvaluateByPath(x, y, 'Stealth Skill');
                   EvaluateByPath(x, y, 'Attributes');
                 End
               Else If sSignature = 'NPC_' Then
                      If wbIsSkyrim Then
                        Begin
                          j := ElementBySignature(e, 'DNAM');
                          k := ElementBySignature(m, 'DNAM');
                          If Assigned(j) And Assigned(k) Then
                            Evaluate(j, k);
                        End
                      Else
                        Begin
                          EvaluateByPath(x, y, 'Base Health');
                          EvaluateByPath(x, y, 'Attributes');
                          EvaluateByPath(e, m, 'DNAM\Skill Values');
                          EvaluateByPath(e, m, 'DNAM\Skill Offsets');
                        End;
             End;
         End

         // Bookmark: Actors.Voice (FO3, FNV, TES5, SSE)
  Else If (g_Tag = 'Actors.Voice') Then
         EvaluateByPath(e, m, 'VTCK')

         // Bookmark: C.Acoustic
  Else If (g_Tag = 'C.Acoustic') Then
         EvaluateByPath(e, m, 'XCAS')

         // Bookmark: C.Climate
         // Per-game gating flag differs: Oblivion/FO3/FNV use 'Behave Like
         // Exterior', Skyrim/Enderal/SSE use 'Show Sky'. Fire the tag if the
         // flag value differs between master and override, otherwise diff XCCM.
  Else If (g_Tag = 'C.Climate') Then
         Begin
           If wbIsSkyrim Then
             Begin
               If CompareFlags(e, m, 'DATA', 'Show Sky', True, True) Then
                 Exit;
             End
           Else
             Begin
               If CompareFlags(e, m, 'DATA', 'Behave Like Exterior', True, True) Then
                 Exit;
             End;

           // evaluate additional property
           EvaluateByPath(e, m, 'XCCM');
         End

         // Bookmark: C.Encounter
  Else If (g_Tag = 'C.Encounter') Then
         EvaluateByPath(e, m, 'XEZN')

         // Bookmark: C.ForceHideLand (!TES4, !FO4)
  Else If (g_Tag = 'C.ForceHideLand') Then
         EvaluateByPath(e, m, 'XCLC\Land Flags')

         // Bookmark: C.ImageSpace
  Else If (g_Tag = 'C.ImageSpace') Then
         EvaluateByPath(e, m, 'XCIM')

         // Bookmark: C.Light
  Else If (g_Tag = 'C.Light') Then
         EvaluateByPath(e, m, 'XCLL')

         // Bookmark: C.Location
  Else If (g_Tag = 'C.Location') Then
         EvaluateByPath(e, m, 'XLCN')

         // Bookmark: C.LockList
  Else If (g_Tag = 'C.LockList') Then
         EvaluateByPath(e, m, 'XILL')

         // Bookmark: C.MiscFlags (!FO4)
  Else If (g_Tag = 'C.MiscFlags') Then
         Begin
           If CompareFlags(e, m, 'DATA', 'Is Interior Cell', True, True) Then
             Exit;

           If CompareFlags(e, m, 'DATA', 'Can Travel From Here', True, True) Then
             Exit;

           If Not wbIsOblivion And Not wbIsFallout4 Then
             If CompareFlags(e, m, 'DATA', 'No LOD Water', True, True) Then
               Exit;

           If wbIsOblivion Then
             If CompareFlags(e, m, 'DATA', 'Force hide land (exterior cell) / Oblivion interior (interior cell)', True, True) Then
               Exit;

           If CompareFlags(e, m, 'DATA', 'Hand Changed', True, True) Then
             Exit;
         End

         // Bookmark: C.Music
         // Oblivion's music subrecord is XCMT; every other supported game uses XCMO.
  Else If (g_Tag = 'C.Music') Then
         If wbIsOblivion Then
           EvaluateByPath(e, m, 'XCMT')
         Else
           EvaluateByPath(e, m, 'XCMO')

         // Bookmark: FULL (C.Name, Names)
  Else If (g_Tag = 'C.Name') Or (g_Tag = 'Names') Then
         EvaluateByPath(e, m, 'FULL')

         // Bookmark: C.Owner
         //
         // Wrye Bash's C.Owner patcher imports XOWN (Owner), XRNK (Faction
         // rank), XGLB (Oblivion-only Global), and the DATA "Public Place"
         // flag (Oblivion / FO3 / FNV). Historically this was a single
         // EvaluateByPath(e, m, 'Ownership'), which (a) depends on xEdit's
         // RStruct path resolving cleanly, (b) collapses all children into
         // one recursive edit-value string that then hits CompareKeys'
         // IsEmptyKey gate, and (c) omits the Public Place flag entirely.
         //
         // Replaced with direct subrecord-signature checks plus the flag,
         // mirroring the Wrye Bash field set and staying robust against
         // struct-path / summary-flag quirks across xEdit versions.
  Else If (g_Tag = 'C.Owner') Then
         Begin
           EvaluateBySignature(e, m, 'XOWN');
           EvaluateBySignature(e, m, 'XRNK');

           If wbIsOblivion Then
             EvaluateBySignature(e, m, 'XGLB');

           If wbIsOblivion Or wbIsFallout3 Or wbIsFalloutNV Then
             If CompareFlags(e, m, 'DATA', 'Public Place', True, True) Then
               Exit;
         End

         // Bookmark: C.RecordFlags
  Else If (g_Tag = 'C.RecordFlags') Then
         EvaluateByPath(e, m, 'Record Header\Record Flags')

         // Bookmark: C.Regions
  Else If (g_Tag = 'C.Regions') Then
         EvaluateByPath(e, m, 'XCLR')

         // Bookmark: C.SkyLighting
         // add tag if the Behave Like Exterior flag is set in one record but not the other
  Else If (g_Tag = 'C.SkyLighting') And CompareFlags(e, m, 'DATA', 'Use Sky Lighting', True, True) Then
         Exit

         // Bookmark: C.Water
  Else If (g_Tag = 'C.Water') Then
        Begin
          // add tag if Has Water flag is set in one record but not the other
          If CompareFlags(e, m, 'DATA', 'Has Water', True, True) Then
            Exit;

          // exit if Is Interior Cell is set in either record
          If CompareFlags(e, m, 'DATA', 'Is Interior Cell', False, False) Then
            Exit;

          EvaluateByPath(e, m, 'XCLW');
          EvaluateByPath(e, m, 'XCWT');

          // Water Noise Texture (XNAM) is FO3/FNV/Skyrim; Oblivion has no equivalent.
           If Not wbIsOblivion Then
             EvaluateByPath(e, m, 'XNAM');

           // Water Environment Map (XWEM) is Skyrim/Enderal/SSE only.
           If wbIsSkyrim Then
             EvaluateByPath(e, m, 'XWEM');
         End

         // Bookmark: Creatures.Blood
         // Oblivion stores blood art in two subrecords (NAM0 Blood Spray,
         // NAM1 Blood Decal). FO3/FNV collapse this to a single CNAM
         // Impact Dataset reference.
  Else If (g_Tag = 'Creatures.Blood') Then
         If wbIsOblivion Then
           Begin
             EvaluateByPath(e, m, 'NAM0');
             EvaluateByPath(e, m, 'NAM1');
           End
         Else
           EvaluateByPath(e, m, 'CNAM')

         // Bookmark: Creatures.Type
  Else If (g_Tag = 'Creatures.Type') Then
         EvaluateByPath(e, m, 'DATA\Type')

         // Bookmark: Deflst
         // FLST FormIDs is a flat FormID array; identity key is entry's own edit value.
  Else If (g_Tag = 'Deflst') Then
         EvaluateListRemove(e, m, 'FormIDs', '')

         // Bookmark: Destructible
  Else If (g_Tag = 'Destructible') Then
         Begin
           // assign Destructable elements
           x := ElementByName(e, 'Destructible');
           y := ElementByName(m, 'Destructible');

           If CompareAssignment(x, y) Then
             Exit;

           a := ElementBySignature(x, 'DEST');
           b := ElementBySignature(y, 'DEST');

           // evaluate Destructable properties
           EvaluateByPath(a, b, 'Health');
           EvaluateByPath(a, b, 'Count');
           EvaluateByPath(x, y, 'Stages');

           // assign Destructable flags
           If Not wbIsSkyrim Then
             Begin
               j := ElementByName(a, 'Flags');
               k := ElementByName(b, 'Flags');

               If Assigned(j) Or Assigned(k) Then
                 Begin
                   // add tag if Destructable flags exist in one record
                   If CompareAssignment(j, k) Then
                     Exit;

                   // evaluate Destructable flags
                   If CompareKeys(j, k) Then
                     Exit;
                 End;
             End;
         End

         // Bookmark: EffectStats
  Else If (g_Tag = 'EffectStats') Then
         Begin
           If wbIsOblivion Or wbIsFallout3 Or wbIsFalloutNV Then
             Begin
               EvaluateByPath(e, m, 'DATA\Flags');

               If Not wbIsFallout3 And Not wbIsFalloutNV Then
                 EvaluateByPath(e, m, 'DATA\Base cost');

               If Not wbIsOblivion Then
                 EvaluateByPath(e, m, 'DATA\Associated Item');

               If Not wbIsFallout3 And Not wbIsFalloutNV Then
                 EvaluateByPath(e, m, 'DATA\Magic School');

               EvaluateByPath(e, m, 'DATA\Resist Value');
               EvaluateByPath(e, m, 'DATA\Projectile Speed');

               If Not wbIsFallout3 And Not wbIsFalloutNV Then
                 Begin
                   EvaluateByPath(e, m, 'DATA\Constant Effect enchantment factor');
                   EvaluateByPath(e, m, 'DATA\Constant Effect barter factor');
                 End;

               If wbIsOblivion And CompareFlags(e, m, 'DATA\Flags', 'Use actor value', False, False) Then
                 EvaluateByPath(e, m, 'DATA\Assoc. Actor Value')
               Else If wbIsFallout3 Or wbIsFalloutNV Then
                      Begin
                        EvaluateByPath(e, m, 'DATA\Archtype');
                        EvaluateByPath(e, m, 'DATA\Actor Value');
                      End;
             End
           Else If wbIsSkyrim Or wbIsFallout4 Then
                  Begin
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Flags');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Base Cost');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Associated Item');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Magic Skill');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Resist Value');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Taper Weight');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Minimum Skill Level');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Spellmaking');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Taper Curve');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Taper Duration');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Second AV Weight');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Archtype');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Actor Value');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Casting Type');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Delivery');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Second Actor Value');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Skill Usage Multiplier');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Equip Ability');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Perk to Apply');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Script Effect AI');
                  End;
         End

         // Bookmark: EnchantmentStats
  Else If (g_Tag = 'EnchantmentStats') Then
         Begin
           If wbIsOblivion Or wbIsFallout3 Or wbIsFalloutNV Then
             Begin
               EvaluateByPath(e, m, 'ENIT\Type');
               EvaluateByPath(e, m, 'ENIT\Charge Amount');
               EvaluateByPath(e, m, 'ENIT\Enchant Cost');
               EvaluateByPath(e, m, 'ENIT\Flags');
             End
           Else If wbIsSkyrim Or wbIsFallout4 Then
                  EvaluateByPath(e, m, 'ENIT');
         End

         // Bookmark: Actors.Factions
  Else If (g_Tag = 'Actors.Factions') Then
         Begin
           x := ElementByName(e, 'Factions');
           y := ElementByName(m, 'Factions');

           If CompareAssignment(x, y) Then
             Exit;

           If Not Assigned(x) Then
             Exit;

           If CompareKeys(x, y) Then
             Exit;
         End

         // Bookmark: Enchantments (FO4 ARMO/EXPL, etc.)
  Else If (g_Tag = 'Enchantments') Then
         EvaluateByPath(e, m, 'Enchantment')

         // Bookmark: Graphics
  Else If (g_Tag = 'Graphics') Then
         Begin
           // evaluate Icon and Model properties
           If ContainsStr('ALCH AMMO APPA BOOK HAIR INGR KEYM LIGH MGEF MISC SGST SLGM TREE WEAP', sSignature) Then
             Begin
               EvaluateByPath(e, m, 'Icon');
               EvaluateByPath(e, m, 'Model');
             End

             // evaluate Icon properties
           Else If ContainsStr('BSGN CLAS EYES LSCR LTEX QUST REGN SKIL', sSignature) Then
                  EvaluateByPath(e, m, 'Icon')

                  // evaluate Model properties
           Else If ContainsStr('ACTI CONT DOOR FLOR FURN GRAS STAT', sSignature) Then
                  EvaluateByPath(e, m, 'Model')

                  // evaluate ARMO properties
           Else If sSignature = 'ARMO' Then
                  Begin
                    If wbIsFallout4 Then
                      Begin
                        EvaluateByPath(e, m, 'Male\World Model');
                        EvaluateByPath(e, m, 'Female\World Model');
                        EvaluateByPath(e, m, 'Male\Icon Image');
                        EvaluateByPath(e, m, 'Female\Icon Image');
                        x := ElementByPath(e, 'BOD2\First Person Flags');
                        If Not Assigned(x) Then
                          Exit;

                        y := ElementByPath(m, 'BOD2\First Person Flags');

                        If CompareKeys(x, y) Then
                          Exit;
                      End
                    Else
                      Begin
                        // Shared (TES4 / FO3 / FNV / TES5)
                        EvaluateByPath(e, m, 'Male world model');
                        EvaluateByPath(e, m, 'Female world model');

                        // ARMO - Oblivion
                        If wbIsOblivion Then
                      Begin
                        // evaluate Icon properties
                        EvaluateByPath(e, m, 'Icon');
                        EvaluateByPath(e, m, 'Icon 2 (female)');

                        // assign First Person Flags elements
                        x := ElementByPath(e, 'BODT\First Person Flags');
                        If Not Assigned(x) Then
                          Exit;

                        y := ElementByPath(m, 'BODT\First Person Flags');

                        // evaluate First Person Flags
                        If CompareKeys(x, y) Then
                          Exit;

                        // assign General Flags elements
                        x := ElementByPath(e, 'BODT\General Flags');
                        If Not Assigned(x) Then
                          Exit;

                        y := ElementByPath(m, 'BODT\General Flags');

                        // evaluate General Flags
                        If CompareKeys(x, y) Then
                          Exit;
                      End

                      // ARMO - FO3, FNV
                    Else If wbIsFallout3 Or wbIsFalloutNV Then
                           Begin
                             // evaluate Icon properties
                             EvaluateByPath(e, m, 'ICON');
                             EvaluateByPath(e, m, 'ICO2');

                             // assign First Person Flags elements
                             x := ElementByPath(e, 'BMDT\Biped Flags');
                             If Not Assigned(x) Then
                               Exit;

                             y := ElementByPath(m, 'BMDT\Biped Flags');

                             // evaluate First Person Flags
                             If CompareKeys(x, y) Then
                               Exit;

                             // assign General Flags elements
                             x := ElementByPath(e, 'BMDT\General Flags');
                             If Not Assigned(x) Then
                               Exit;

                             y := ElementByPath(m, 'BMDT\General Flags');

                             // evaluate General Flags
                             If CompareKeys(x, y) Then
                               Exit;
                           End

                           // ARMO - TES5
                    Else If wbIsSkyrim Then
                           Begin
                             // evaluate Icon properties
                             EvaluateByPath(e, m, 'Icon');
                             EvaluateByPath(e, m, 'Icon 2 (female)');

                             // evaluate Biped Model properties
                             EvaluateByPath(e, m, 'Male world model');
                             EvaluateByPath(e, m, 'Female world model');

                             // assign First Person Flags elements
                             x  := ElementByPath(e, 'BOD2\First Person Flags');
                             If Not Assigned(x) Then
                               Exit;

                             y := ElementByPath(m, 'BOD2\First Person Flags');

                             // evaluate First Person Flags
                             If CompareKeys(x, y) Then
                               Exit;

                             // assign General Flags elements
                             x := ElementByPath(e, 'BOD2\General Flags');
                             If Not Assigned(x) Then
                               Exit;

                             y := ElementByPath(m, 'BOD2\General Flags');

                             // evaluate General Flags
                             If CompareKeys(x, y) Then
                               Exit;
                           End;
                      End;
                  End

                  // evaluate CREA properties
           Else If sSignature = 'CREA' Then
                  Begin
                    EvaluateByPath(e, m, 'NIFZ');
                    EvaluateByPath(e, m, 'NIFT');
                  End

                  // evaluate EFSH properties
           Else If sSignature = 'EFSH' Then
                  Begin
                    // evaluate Record Flags
                    x := ElementByPath(e, 'Record Header\Record Flags');
                    y := ElementByPath(m, 'Record Header\Record Flags');

                    If CompareKeys(x, y) Then
                      Exit;

                    // evaluate Icon properties
                    EvaluateByPath(e, m, 'ICON');
                    EvaluateByPath(e, m, 'ICO2');

                    // evaluate other properties
                    EvaluateByPath(e, m, 'NAM7');

                    If wbIsSkyrim Then
                      Begin
                        EvaluateByPath(e, m, 'NAM8');
                        EvaluateByPath(e, m, 'NAM9');
                      End;

                    EvaluateByPath(e, m, 'DATA');
                  End

                  // evaluate MGEF properties (TES5 + FO4: shader / art fields)
           Else If (wbIsSkyrim Or wbIsFallout4) And (sSignature = 'MGEF') Then
                  Begin
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Casting Light');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Hit Shader');
                    EvaluateByPath(e, m, 'Magic Effect Data\DATA\Enchant Shader');
                  End

                  // evaluate Material property
           Else If sSignature = 'STAT' Then
                  EvaluateByPath(e, m, 'DNAM\Material');
         End

         // Bookmark: Invent.Add
         // CNTO Items[*]\CNTO\Item holds the item FormID (separate from Count).
  Else If (g_Tag = 'Invent.Add') Then
         EvaluateListAdd(e, m, 'Items', 'CNTO\Item')

         // Bookmark: Invent.Change
         // Match entries on CNTO\Item; only fire if a shared item's count or extra data
         // (COED — owner/condition/health, FO3+ only) differs. Pure adds/removes are
         // handled by Invent.Add/Invent.Remove and must not pollute Invent.Change.
  Else If (g_Tag = 'Invent.Change') Then
         If wbIsOblivion Then
           DiffSubrecordList(e, m, 'Invent.Change', 'Items', 'CNTO\Item', 'CNTO\Count')
         Else
           DiffSubrecordList(e, m, 'Invent.Change', 'Items', 'CNTO\Item', 'CNTO\Count|COED')

         // Bookmark: Invent.Remove
  Else If (g_Tag = 'Invent.Remove') Then
         EvaluateListRemove(e, m, 'Items', 'CNTO\Item')

         // Bookmark: Keywords
  Else If (g_Tag = 'Keywords') Then
         Begin
           x := ElementBySignature(e, 'KWDA');
           y := ElementBySignature(m, 'KWDA');

           If CompareAssignment(x, y) Then
             Exit;

           If CompareElementCount(x, y) Then
             Exit;

           x := ElementBySignature(e, 'KSIZ');
           y := ElementBySignature(m, 'KSIZ');

           If CompareAssignment(x, y) Then
             Exit;

           If CompareEditValue(x, y) Then
             Exit;
         End

         // Bookmark: NPC.AIPackageOverrides
  Else If (g_Tag = 'NPC.AIPackageOverrides') Then
         Begin
           If wbIsSkyrim Then
             Begin
               EvaluateByPath(e, m, 'SPOR');
               EvaluateByPath(e, m, 'OCOR');
               EvaluateByPath(e, m, 'GWOR');
               EvaluateByPath(e, m, 'ECOR');
             End;
         End

         // Bookmark: NPC.AttackRace
  Else If (g_Tag = 'NPC.AttackRace') Then
         EvaluateByPath(e, m, 'ATKR')

         // Bookmark: NPC.Class
  Else If (g_Tag = 'NPC.Class') Then
         EvaluateByPath(e, m, 'CNAM')

         // Bookmark: NPC.CrimeFaction
  Else If (g_Tag = 'NPC.CrimeFaction') Then
         EvaluateByPath(e, m, 'CRIF')

         // Bookmark: NPC.DefaultOutfit
  Else If (g_Tag = 'NPC.DefaultOutfit') Then
         EvaluateByPath(e, m, 'DOFT')

         // Bookmark: NPC.Eyes
  Else If (g_Tag = 'NPC.Eyes') Then
         EvaluateByPath(e, m, 'ENAM')

         // Bookmark: NPC.FaceGen
  Else If (g_Tag = 'NPC.FaceGen') Then
         EvaluateByPath(e, m, 'FaceGen Data')

         // Bookmark: NPC.Hair
  Else If (g_Tag = 'NPC.Hair') Then
         EvaluateByPath(e, m, 'HNAM')

         // Bookmark: NPC.Race
  Else If (g_Tag = 'NPC.Race') Then
         EvaluateByPath(e, m, 'RNAM')

         // Bookmark: ObjectBounds
  Else If (g_Tag = 'ObjectBounds') Then
         EvaluateByPath(e, m, 'OBND')

         // Bookmark: Outfits.Add
         // OTFT records expose a single child array element 'Items' (signature INAM).
         // Pass the 'INAM' signature rather than the 'Items' name: OTFT's items
         // array is wbArrayS(INAM, 'Items', ...) at the top level of the record,
         // and ElementByPath(rec, 'Items') can return nil on wbArrayS-with-signature
         // arrays on some xEdit builds. ResolveListArray falls back to
         // ElementBySignature, which is stable. Identity key is the FormID itself.
         // Element-count-only would miss e.g. MQ101StormcloakPrisonerOutfit swapping
         // a static ARMO for an LVLI at the same count.
  Else If (g_Tag = 'Outfits.Add') Then
         EvaluateListAdd(e, m, 'INAM', '')

         // Bookmark: Outfits.Remove
  Else If (g_Tag = 'Outfits.Remove') Then
         EvaluateListRemove(e, m, 'INAM', '')

         // Bookmark: R.AddSpells / R.ChangeSpells handled by ProcessRaceSpells (list-diff split)

         // Bookmark: R.Attributes-F
  Else If (g_Tag = 'R.Attributes-F') Then
         EvaluateByPath(e, m, 'ATTR\Female')

         // Bookmark: R.Attributes-M
  Else If (g_Tag = 'R.Attributes-M') Then
         EvaluateByPath(e, m, 'ATTR\Male')

         // Bookmark: R.Body-F
  Else If (g_Tag = 'R.Body-F') Then
         EvaluateByPath(e, m, 'Body Data\Female Body Data\Parts')

         // Bookmark: R.Body-M
  Else If (g_Tag = 'R.Body-M') Then
         EvaluateByPath(e, m, 'Body Data\Male Body Data\Parts')

         // Bookmark: R.Body-Size-F
  Else If (g_Tag = 'R.Body-Size-F') Then
         Begin
           EvaluateByPath(e, m, 'DATA\Female Height');
           EvaluateByPath(e, m, 'DATA\Female Weight');
         End

         // Bookmark: R.Body-Size-M
  Else If (g_Tag = 'R.Body-Size-M') Then
         Begin
           EvaluateByPath(e, m, 'DATA\Male Height');
           EvaluateByPath(e, m, 'DATA\Male Weight');
         End

         // Bookmark: R.ChangeSpells
         // Normally reached via ProcessRaceSpells (which handles the Add/Change split itself);
         // this handler is defensive in case ProcessTag('R.ChangeSpells', ...) is called directly.
  Else If (g_Tag = 'R.ChangeSpells') Then
         EvaluateByPath(e, m, ActorSpellArrayPath)

         // Bookmark: R.Description
  Else If (g_Tag = 'R.Description') Then
         EvaluateByPath(e, m, 'DESC')

         // Bookmark: R.Ears
  Else If (g_Tag = 'R.Ears') Then
         Begin
           EvaluateByPath(e, m, 'Head Data\Male Head Data\Parts\[1]');
           EvaluateByPath(e, m, 'Head Data\Female Head Data\Parts\[1]');
         End

         // Bookmark: R.Eyes
  Else If (g_Tag = 'R.Eyes') Then
         EvaluateByPath(e, m, 'ENAM')

         // Bookmark: R.Hair
  Else If (g_Tag = 'R.Hair') Then
         EvaluateByPath(e, m, 'HNAM')

         // Bookmark: R.Head
  Else If (g_Tag = 'R.Head') Then
         Begin
           EvaluateByPath(e, m, 'Head Data\Male Head Data\Parts\[0]');
           EvaluateByPath(e, m, 'Head Data\Female Head Data\Parts\[0]');
           EvaluateByPath(e, m, 'FaceGen Data');
         End

         // Bookmark: R.Mouth
  Else If (g_Tag = 'R.Mouth') Then
         Begin
           EvaluateByPath(e, m, 'Head Data\Male Head Data\Parts\[2]');
           EvaluateByPath(e, m, 'Head Data\Female Head Data\Parts\[2]');
         End

         // Bookmark: R.Relations.Add
         // RACE Relations[*]\Faction holds the faction FormID (separate from modifier).
  Else If (g_Tag = 'R.Relations.Add') Then
         EvaluateListAdd(e, m, 'Relations', 'Faction')

         // Bookmark: R.Relations.Change
         // Match entries on Faction; only fire if a shared faction's Modifier
         // (Oblivion) or Modifier + Group Combat Reaction (non-Oblivion) differs.
         // Adds/removes go to R.Relations.Add / R.Relations.Remove.
         // Skyrim/SSE dispatches R.Relations.* from ProcessRecord; FO4 has no
         // RACE relations import here. Non-Oblivion branch handles all.
  Else If (g_Tag = 'R.Relations.Change') Then
         If wbIsOblivion Then
           DiffSubrecordList(e, m, 'R.Relations.Change', 'Relations', 'Faction', 'Modifier')
         Else
           DiffSubrecordList(e, m, 'R.Relations.Change', 'Relations', 'Faction', 'Modifier|Group Combat Reaction')

         // Bookmark: R.Relations.Remove
  Else If (g_Tag = 'R.Relations.Remove') Then
         EvaluateListRemove(e, m, 'Relations', 'Faction')

         // Bookmark: R.Skills
  Else If (g_Tag = 'R.Skills') Then
         EvaluateByPath(e, m, 'DATA\Skill Boosts')

         // Bookmark: R.Stats (TES5/SSE/Enderal — WB import_races_attrs DATA)
  Else If (g_Tag = 'R.Stats') Then
         If wbIsSkyrim And (sSignature = 'RACE') Then
           Begin
             EvaluateByPath(e, m, 'DATA\Starting Health');
             EvaluateByPath(e, m, 'DATA\Starting Magicka');
             EvaluateByPath(e, m, 'DATA\Starting Stamina');
             EvaluateByPath(e, m, 'DATA\Base Carry Weight');
             EvaluateByPath(e, m, 'DATA\Health Regen');
             EvaluateByPath(e, m, 'DATA\Magicka Regen');
             EvaluateByPath(e, m, 'DATA\Stamina Regen');
             EvaluateByPath(e, m, 'DATA\Unarmed Damage');
             EvaluateByPath(e, m, 'DATA\Unarmed Reach');
           End

         // Bookmark: R.Teeth
  Else If (g_Tag = 'R.Teeth') Then
         Begin
           EvaluateByPath(e, m, 'Head Data\Male Head Data\Parts\[3]');
           EvaluateByPath(e, m, 'Head Data\Female Head Data\Parts\[3]');

           // FO3
           If wbIsFallout3 Then
             Begin
               EvaluateByPath(e, m, 'Head Data\Male Head Data\Parts\[4]');
               EvaluateByPath(e, m, 'Head Data\Female Head Data\Parts\[4]');
             End;
         End

         // Bookmark: R.Voice-F
  Else If (g_Tag = 'R.Voice-F') Then
         EvaluateByPath(e, m, 'VTCK\Voice #1 (Female)')

         // Bookmark: R.Voice-M
  Else If (g_Tag = 'R.Voice-M') Then
         EvaluateByPath(e, m, 'VTCK\Voice #0 (Male)')

         // Bookmark: Relations.Add
         // FACT Relations[*]\Faction holds the target faction FormID.
  Else If (g_Tag = 'Relations.Add') Then
         EvaluateListAdd(e, m, 'Relations', 'Faction')

         // Bookmark: Relations.Change
         // Match entries on Faction; only fire if a shared faction's Modifier
         // (Oblivion) or Modifier + Group Combat Reaction (every other game)
         // differs. Adds/removes go to Relations.Add / Relations.Remove.
  Else If (g_Tag = 'Relations.Change') Then
         If wbIsOblivion Then
           DiffSubrecordList(e, m, 'Relations.Change', 'Relations', 'Faction', 'Modifier')
         Else
           DiffSubrecordList(e, m, 'Relations.Change', 'Relations', 'Faction', 'Modifier|Group Combat Reaction')

         // Bookmark: Relations.Remove
  Else If (g_Tag = 'Relations.Remove') Then
         EvaluateListRemove(e, m, 'Relations', 'Faction')

         // Bookmark: Roads
  Else If (g_Tag = 'Roads') Then
         EvaluateByPath(e, m, 'PGRP')

         // Bookmark: Scripts
  Else If (g_Tag = 'Scripts') Then
         EvaluateByPath(e, m, 'SCRI')

         // Bookmark: Sound
  Else If (g_Tag = 'Sound') Then
         Begin
           // Activators, Containers, Doors, and Lights
           If ContainsStr('ACTI CONT DOOR LIGH', sSignature) Then
             Begin
               EvaluateByPath(e, m, 'SNAM');

               // Activators
               If sSignature = 'ACTI' Then
                 EvaluateByPath(e, m, 'VNAM')

                 // Containers
               Else If sSignature = 'CONT' Then
                      Begin
                        EvaluateByPath(e, m, 'QNAM');
                        If Not wbIsSkyrim And Not wbIsFallout3 Then
                          EvaluateByPath(e, m, 'RNAM');
                        // FO3, TESV, and SSE don't have this element
                      End

                      // Doors
               Else If sSignature = 'DOOR' Then
                      Begin
                        EvaluateByPath(e, m, 'ANAM');
                        EvaluateByPath(e, m, 'BNAM');
                      End;
             End

             // Creatures
           Else If sSignature = 'CREA' Then
                  Begin
                    EvaluateByPath(e, m, 'WNAM');
                    EvaluateByPath(e, m, 'CSCR');
                    EvaluateByPath(e, m, 'Sound Types');
                  End

                  // Magic Effects
           Else If sSignature = 'MGEF' Then
                  Begin
                    // TES5, SSE
                    If wbIsSkyrim Then
                      EvaluateByPath(e, m, 'SNDD')

                      // FO3, FNV, TES4
                    Else
                      Begin
                        EvaluateByPath(e, m, 'DATA\Effect sound');
                        EvaluateByPath(e, m, 'DATA\Bolt sound');
                        EvaluateByPath(e, m, 'DATA\Hit sound');
                        EvaluateByPath(e, m, 'DATA\Area sound');
                      End;
                  End

                  // Weather
           Else If sSignature = 'WTHR' Then
                  EvaluateByPath(e, m, 'Sounds');
         End

         // Bookmark: SpellStats
  Else If (g_Tag = 'SpellStats') Then
         EvaluateByPath(e, m, 'SPIT')

         // Bookmark: Stats
  Else If (g_Tag = 'Stats') Then
         Begin
           If ContainsStr('ALCH AMMO APPA ARMO BOOK CLOT INGR KEYM LIGH MISC SGST SLGM WEAP', sSignature) Then
             Begin
               EvaluateByPath(e, m, 'EDID');
               EvaluateByPath(e, m, 'DATA');

               If ContainsStr('ARMO WEAP', sSignature) Then
                 EvaluateByPath(e, m, 'DNAM')

               Else If sSignature = 'WEAP' Then
                      EvaluateByPath(e, m, 'CRDT');
             End

           Else If sSignature = 'ARMA' Then
                  EvaluateByPath(e, m, 'DNAM');
         End

         // Bookmark: Text
  Else If (g_Tag = 'Text') Then
         Begin
           If ContainsStr('ALCH AMMO APPA ARMO AVIF BOOK BSGN CHAL CLAS IMOD LSCR MESG MGEF PERK SCRL SHOU SKIL SPEL TERM WEAP', sSignature) Then
             EvaluateByPath(e, m, 'DESC')

           Else If Not wbIsOblivion Then
                  Begin
                    If sSignature = 'BOOK' Then
                      EvaluateByPath(e, m, 'CNAM')

                    Else If sSignature = 'MGEF' Then
                           EvaluateByPath(e, m, 'DNAM')

                    Else If sSignature = 'NOTE' Then
                           EvaluateByPath(e, m, 'TNAM');
                  End;
         End

         // Bookmark: WeaponMods
  Else If (g_Tag = 'WeaponMods') Then
         EvaluateByPath(e, m, 'Weapon Mods');

  Finally
    Dec(g_DebugIndent);
    If DbgWasSuggested Then
      DbgLog(DBG_PER_TAG, Format('VERDICT tag=%s on %s -> SUGGESTED', [ATag, DbgRecordTag]))
    Else
      DbgLog(DBG_PER_TAG, Format('VERDICT tag=%s on %s -> NOT SUGGESTED', [ATag, DbgRecordTag]));
    g_DebugCurrentTag := '';
  End;
End;
