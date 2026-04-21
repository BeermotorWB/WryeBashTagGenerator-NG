# xEdit Pascal Scripting API Reference

Distilled from https://tes5edit.github.io/docs/13-Scripting-Functions.html (fetched 2026-04-21).

This is a local reference for navigating the xEdit scripting API while working on `WryeBashTagGenerator-NG.pas` / `WryeBashTagGenerator-NG-debug.pas`. For exhaustive semantics, defer to the upstream page linked above.

## Script entry points (xEdit calls these automatically)

- `function Initialize : integer` — called once when script starts
- `function Process(e : IInterface) : integer` — called once per selected element. In this script, `ScriptProcessElements := [etFile]` is set in Initialize so `e` is a file.
- `function ProcessRecord(e : IInterface) : integer` — called once per record when iterating via `RecordByIndex` inside `Process`.
- `function Finalize : integer` — called after all processing completes.

Return codes: non-zero from Initialize typically aborts; convention elsewhere varies (see existing code for patterns like `Result := 99` as error).

## Read-only globals

| Name | Type | Description |
|------|------|-------------|
| `DataPath` | String | Path to the game's data folder |
| `ProgramPath` | String | Path to xEdit's installation folder |
| `ScriptsPath` | String | Path to `Edit Scripts` folder |
| `FileCount` | Integer | Number of loaded files in current session |
| `wbAppName` | String | `'TES5'` / `'TES4'` / `'FNV'` / `'FO3'` |
| `wbVersionNumber` | Integer | xEdit version number |

## Global functions

- `procedure AddMessage(asMessage: string)` — push message to Information tab
- `function Assigned(aeElement: IwbElement): boolean` — check element is not Nil
- `function ObjectToElement(akObject): IInterface` — retrieve IInterface from TList/TStringList
- `function FileByIndex(aiFile: integer): IwbFile` — get loaded file by index
- `function FileByLoadOrder(aiLoadOrder: integer): IwbFile` — get file by load order
- `function FullPathToFilename(asFilename: string): string` — full path to filename
- `procedure EnableSkyrimSaveFormat()` — enable Skyrim save format (corrupts until restart)
- `procedure GetRecordDefNames(akList: TStrings)` — populate list with record definition names
- `procedure wbFilterStrings(akListIn: TStrings; akListOut: TStrings; asFilter: String)` — filter strings by substring
- `procedure wbRemoveDuplicateStrings(akList: TStringList)` — remove duplicate entries

## IwbElement

- `function BaseName(aeElement): string` — element name without load order index
- `procedure BeginUpdate(aeElement)` — begin batch operations on container
- `procedure BuildRef(aeElement)` — build reference information
- `function CanContainFormIDs(aeElement): boolean`
- `function CanMoveDown(aeElement): boolean` / `function CanMoveUp(aeElement): boolean`
- `function Check(aeElement): string` — run error check, return error message
- `procedure ClearElementState(aeElement; aiState: TwbElementState)`
- `function ContainingMainRecord(aeElement): IwbMainRecord`
- `function DefType(aeElement): TwbDefType`
- `function DisplayName(aeElement): string` — display name or fallback to Name
- `function ElementAssign(aeContainer: IwbContainer; aiIndex: integer; aeSource: IwbElement; abOnlySK: boolean): IwbElement`
- `function ElementType(aeElement): TwbElementType` — returns etFile, etMainRecord, etc.
- `procedure EndUpdate(aeElement)`
- `function EnumValues(aeElement): string` — named enum values as space-separated string
- `function Equals(aeElement1, aeElement2): boolean`
- `function FlagValues(aeElement): string` — set flags as space-separated string
- `function FullPath(aeElement): string`
- `function GetContainer(aeElement): IwbContainer`
- `function GetEditValue(aeElement): string` — string representation of element value
- `function GetElementState(aeElement; aiState: TwbElementState): TwbElementState`
- `function GetFile(aeElement): IwbFile`
- `function GetNativeValue(aeElement): variant`
- `function IsEditable(aeElement): boolean`
- `function IsInjected(aeElement): boolean`
- `function LinksTo(aeElement): IwbElement` — FormID resolution
- `procedure MarkModifiedRecursive(aeElement)`
- `procedure MoveDown(aeElement)` / `procedure MoveUp(aeElement)`
- `function Name(aeElement): string`
- `function Path(aeElement): string` — single path component
- `function PathName(aeElement): string` — full path with bracket-prefixed names
- `procedure Remove(aeElement)` — remove element from file
- `procedure ReportRequiredMasters(aeElement; akListOut: TStrings; abUnknown1, abUnknown2: boolean)`
- `procedure SetEditValue(aeElement; asValue: string)` — **the debug fork short-circuits this on SNAM**
- `function SetElementState(aeElement; aiState): TwbElementState`
- `procedure SetNativeValue(aeElement; avValue: variant)`
- `procedure SetToDefault(aeElement)`
- `function ShortName(aeElement): string` — signature + FormID for refs
- `function SortKey(aeElement): string` — unique sort/compare string
- `function wbCopyElementToFile(aeElement; aeFile: IwbFile; abAsNew, abDeepCopy: boolean): IwbElement`
- `function wbCopyElementToFileWithPrefix(aeElement; aeFile; abAsNew, abDeepCopy: boolean; aPrefixRemove, aPrefix, aSuffix: string): IwbElement`
- `function wbCopyElementToRecord(aeElement; aeRecord: IwbMainRecord; abAsNew, abDeepCopy: boolean): IwbElement`

## IwbContainer

- `function Add(aeContainer; asNameOrSignature: string; abSilent: boolean): IwbElement`
- `procedure AddElement(aeContainer; aeElement)`
- `function AdditionalElementCount(aeContainer): integer` — count of "fake" elements xEdit adds
- `function ContainerStates(aeContainer): byte`
- `function ElementByIndex(aeContainer; aiIndex: integer): IwbElement`
- `function ElementByName(aeContainer; asName: string): IwbElement`
- `function ElementByPath(aeContainer; asPath: string): IwbElement` — core traversal function used throughout this script
- `function ElementBySignature(aeContainer; asSignature: string): IwbElement`
- `function ElementCount(aeContainer): integer`
- `function ElementExists(aeContainer; asName: string): boolean`
- `function GetElementEditValues(aeContainer; asPath: string): string` — shortcut for ElementByPath + GetEditValue
- `function GetElementNativeValues(aeContainer; asPath: string): variant`
- `function IndexOf(aeContainer; aeChild): integer` — child's index or -1
- `procedure InsertElement(aeContainer; aiPosition: Integer; aeElement)`
- `function IsSorted(aeContainer: IwbSortableContainer): boolean`
- `function LastElement(aeContainer): IwbElement`
- `function RemoveByIndex(aeContainer; aiIndex: integer; abMarkModified: boolean): IwbElement`
- `function RemoveElement(aeContainer; avChild: variant): IwbElement`
- `procedure ReverseElements(aeContainer)`
- `procedure SetElementEditValues(aeContainer; asPath, asValue: string)`
- `procedure SetElementNativeValues(aeContainer; asPath: string; asValue: variant)`

## IwbFile — key for multifile handling

- `procedure AddMasterIfMissing(aeFile; asMasterFilename: string)`
- `procedure AddNewFileName(aeFile; FileName: String; ESLFlag: Boolean)` — create new plugin with filename
- `procedure AddNewFile(aeFile; ESLFlag: Boolean)` — create new empty plugin
- `procedure CleanMasters(aeFile)` — remove unnecessary masters
- `function FileFormIDtoLoadOrderFormID(aeFile; aiFormID: cardinal): cardinal`
- `procedure FileWriteToStream(aeFile; akOutStream: TStream)`
- `function GetFileName(aeFile): string`
- `function GetIsESM(aeFile): boolean`
- `function GetLoadOrder(aeFile): integer`
- `function GetNewFormID(aeFile): cardinal`
- `function GroupBySignature(aeFile; asSignature: string): IwbGroupRecord`
- `function HasGroup(aeFile; asSignature: string): boolean`
- `function HasMaster(aeFile; asMasterFilename: string): boolean`
- `function LoadOrderFormIDtoFileFormID(aeFile; aiFormID: cardinal): cardinal`
- `function MasterByIndex(aeFile; aiIndex: integer): IwbFile`
- `function MasterCount(aeFile): cardinal`
- `function RecordByEditorID(aeFile; asEditorID: string): IwbMainRecord` — MGEF/GMST lookup by EditorID
- `function RecordByFormID(aeFile; aiFormID: integer; abAllowInjected: boolean): IwbMainRecord`
- `function RecordByIndex(aeFile; aiIndex: integer): IwbMainRecord` — the main per-file record iterator
- `function RecordCount(aeFile): cardinal`
- `procedure SetIsESM(aeFile; abFlag: boolean)`
- `procedure SortMasters(aeFile)`

## IwbMainRecord

- `function BaseRecord(aeRecord): IwbMainRecord` — base form of reference
- `function BaseRecordID(aeRecord): cardinal` — load order FormID
- `procedure ChangeFormSignature(aeRecord; asNewSignature: string)`
- `function ChildGroup(aeRecord): IwbGroupRecord`
- `function CompareExchangeFormID(aeRecord; aiOldFormID, aiNewFormID: cardinal): boolean`
- `function EditorID(aeRecord): string`
- `function FixedFormID(aeRecord): cardinal` — local FormID
- `function FormID(aeRecord): cardinal`
- `function GetFormVCS1(aeRecord): cardinal` / `GetFormVCS2` — Version Control Info
- `function GetFormVersion(aeRecord): cardinal`
- `function GetGridCell(aeRecord): TwbGridCell`
- `function GetIsDeleted(aeRecord): boolean` — core check in ProcessRecord early-exit
- `function GetIsInitiallyDisabled(aeRecord): boolean`
- `function GetIsPersistent(aeRecord): boolean`
- `function GetIsVisibleWhenDistant(aeRecord): boolean`
- `function GetLoadOrderFormID(aeRecord): cardinal`
- `function GetPosition(aeRecord): TwbVector` / `function GetRotation(aeRecord): TwbVector`
- `function HasPrecombinedMesh(aeRecord): boolean` — FO4
- `function HighestOverrideOrSelf(aeRecord; aiMaxIndex: integer): IwbMainRecord` — central to this script's override diffing
- `function IsMaster(aeRecord): boolean`
- `function IsWinningOverride(aeRecord): boolean`
- `function Master(aeRecord): IwbMainRecord`
- `function MasterOrSelf(aeRecord): IwbMainRecord`
- `function OverrideByIndex(aeRecord; aiIndex: integer): IwbMainRecord`
- `function OverrideCount(aeRecord): cardinal`
- `function PrecombinedMesh(aeRecord): string`
- `function ReferencedByIndex(aeRecord; aiIndex: integer): IwbMainRecord` / `function ReferencedByCount(aeRecord): cardinal`
- `function SetEditorID(aeRecord; asEditorID: string): string`
- `procedure SetFormVersion(aeRecord; aiVersion: cardinal)`
- `function SetIsDeleted/SetIsInitiallyDisabled/SetIsPersistent/SetIsVisibleWhenDistant(aeRecord; abFlag: boolean): boolean`
- `function SetLoadOrderFormID(aeRecord; aiFormID: cardinal): cardinal`
- `procedure SetFormVCS1(aeRecord; aiValue: cardinal)` / `SetFormVCS2`
- `function Signature(aeRecord): string` — 4-char record signature
- `procedure UpdateRefs(aeRecord)`
- `function WinningOverride(aeRecord): IwbMainRecord`

## IwbGroupRecord

- `function ChildrenOf(aeGroup): IwbMainRecord`
- `function FindChildGroup(aeGroup; aiType: integer; aeMainRecord: IwbMainRecord): IwbGroupRecord`
- `function GroupLabel(aeGroup): cardinal`
- `function GroupType(aeGroup): integer`
- `function MainRecordByEditorID(aeGroup; asEditorID: string): IwbMainRecord`

## IwbResource

- `procedure ResourceContainerList(akContainers: TwbFastStringList)` — fill with BSA/BA2 filenames
- `procedure ResourceCopy(asContainerName, asFilename, asPathOut: string)`
- `function ResourceCount(asFilename: string; akContainers: TStrings): cardinal`
- `function ResourceExists(asFilename: string): boolean`
- `procedure ResourceList(asContainerName: string; akContainers: TStrings)`
- `function ResourceOpenData(asContainerName, asFilename: string): TBytesStream`

## Misc utilities

- `procedure LocalizationGetStringsFromFile(asFilename: string; akListOut: TStrings)`
- `function wbAlphaBlend(...)` — wrapper for Windows.AlphaBlend
- `function wbBlockFromSubBlock(akSubBlock: TwbGridCell): TwbGridCell`
- `function wbCRC32Data(akData: TBytes): cardinal` / `wbCRC32File(asFilename: string)` / `wbCRC32Resource(asContainerName, asFileName)`
- `procedure wbFindREFRsByBase(aeREFR: IwbMainRecord; asSignatures: string; aiFlags: integer; akOutList: TList)`
- `procedure wbFlipBitmap(akBitmap: TBitmap; aiAxes: integer)`
- `procedure wbGetSiblingRecords(aeRecord: IwbElement; asSignatures: string; abIncludeOverrides: boolean; akOutList: TList)`
- `function wbGridCellToGroupLabel(akGridCell: TwbGridCell): cardinal` / `wbPositionToGridCell` / `wbSubBlockFromGridCell`
- `function wbIsInGridCell(akPosition: TwbVector; akGridCell: TwbGridCell): boolean`
- `function wbMD5Data(akData)` / `wbMD5File(asFilename)`
- `function wbNormalizeResourceName(asResourceName: string; akResourceType: TGameResourceType): string`
- `function wbSHA1Data(akData)` / `wbSHA1File(asFilename)`
- `function wbStringListInString(akList: TStringList; asSubstring: string): integer`

## NIF / DDS

- `function NifBlockList(akData: TBytes; akListOut: TStrings): boolean`
- `function NifTextureList(akData: TBytes; akListOut: TStrings): boolean`
- `function NifTextureListResource(akData: variant; akListOut: TStrings): boolean`
- `function NifTextureListUVRange(akData: TBytes; afUVRange: Single; akListOut: TStrings): boolean`
- `function wbDDSStreamToBitmap(akStream: TStream; akBitmapOut: TBitmap): boolean`
- `function wbDDSDataToBitmap(akData: TBytes; akBitmapOut: TBitmap): boolean`
- `function wbDDSResourceToBitmap(akUnknown; akBitmapOut: TBitmap): boolean`

## Functions especially relevant to multifile handling

- `FileCount`, `FileByIndex`, `FileByLoadOrder` — enumerate selected/loaded files
- `GetFileName`, `GetLoadOrder`, `GetIsESM`, `HasMaster`, `MasterCount`, `MasterByIndex` — per-file properties
- `RecordByIndex`, `RecordCount`, `GroupBySignature` — iterate records within one file
- `GetFile` on any element → owning `IwbFile` (maps record back to plugin)
- Setting `ScriptProcessElements := [etFile]` in Initialize causes `Process(e)` to fire once per selected file; this is the entry pattern the multifile implementation relies on.
