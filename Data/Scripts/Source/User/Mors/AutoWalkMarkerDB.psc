ScriptName Mors:AutoWalkMarkerDB Extends Quest

; ==========================
; === STRUCT DEFINITIONS ===
; ==========================

Struct Grid
  float worldXStart
  float worldXEnd
  float worldYStart
  float worldYEnd
  float cellWidth
  float cellHeight
  float worldWidth
  float worldHeight
  int numCols
  int numRows
EndStruct

Struct GridCell
  float x1
  float x2
  float y1
  float y2
  FormList markers
EndStruct

Struct CustomDestinationMarkerInfo
  float playerMarkerX
  float playerMarkerY
  float playerMarkerZ
  cell playerMarkerCell
  ObjectReference nearestStaticMarker
  float nearestStaticMarkerDistance
  string nearestStaticMarkerName
  bool playerMarkerZProbed
  bool nearestStaticMarkerHasFix
  float nearestStaticMarkerFixX
  float nearestStaticMarkerFixY
  float nearestStaticMarkerFixZ
EndStruct

; ============================
; === PROPERTY DEFINITIONS ===
; ============================

Grid Property GridCommonwealth Auto Const
Grid Property GridFarHarbor Auto Const
Grid Property GridNukaWorld Auto Const
; Property: GridCellsCommonwealth, GridCellsFarHarbor, GridCellsNukaWorld
; Type: GridCell[]
; Description: Each grid cell contains a list of map markers. Indexed by their position in the world.
GridCell[] Property GridCellsCommonwealth Auto Const
GridCell[] Property GridCellsFarHarbor Auto Const
GridCell[] Property GridCellsNukaWorld Auto Const

Actor Property PlayerRef Auto Const Mandatory
FormList Property Blacklist Auto Const
FormList Property DebugList Auto Const
; Property: UserMarkerListCommonwealth, UsedUserMarkerListCommonwealth, UserMarkerListFarHarbor, UsedUserMarkerListFarHarbor, UserMarkerListNukaWorld, UsedUserMarkerListNukaWorld
; Type: FormList
; Description: Holds lists of user map markers for different worldspaces.
;           The lists can be used to store user-defined map markers that can be dynamically added or removed.
;           Used lists are for markers that are currently in use by user placing them on the map.
FormList Property UserMarkerListCommonwealth Auto Const
FormList Property UsedUserMarkerListCommonwealth Auto Const
FormList Property UserMarkerListFarHarbor Auto Const
FormList Property UsedUserMarkerListFarHarbor Auto Const
FormList Property UserMarkerListNukaWorld Auto Const
FormList Property UsedUserMarkerListNukaWorld Auto Const
; Property: ExtraMarkerListCommonwealth
; Type: FormList
; Description: Holds a list of extra marker references.
;              This list can be used to hold additional map markers which can move around the world. not like other static/fixed markers.
;              Grid search mechanism will not be used for this list.
FormList Property ExtraMarkerListCommonwealth Auto Const
FormList Property ExtraMarkerListFarHarbor Auto Const
FormList Property ExtraMarkerListNukaWorld Auto Const

Location Property CommonwealthLocation Auto Const
Location Property FarHarborLocation Auto Const
Location Property NukaWorldLocation Auto Const

WorldSpace Property WorldSpaceCommonwealth Auto Const
WorldSpace Property WorldSpaceDiamondCity Auto Const
WorldSpace Property WorldSpaceGoodNeighbor Auto Const
WorldSpace Property WorldSpaceSanctuaryHills Auto Const
WorldSpace Property WorldSpaceFarHarbor Auto Const
WorldSpace Property WorldSpaceNukaWorld Auto Const

Form Property GroundProbeForm Auto Const

ObjectReference Property PlayerMapMarkerCommonwealth Auto Const
ObjectReference Property PlayerMapMarkerFarHarbor Auto Const
ObjectReference Property PlayerMapMarkerNukaWorld Auto Const
Message Property MessageRebuildDB Auto

; Hidden properties for saving user map marker names. Each property corresponds to MCM's UI element tyed as "textinput".
; User can see their placed markers in the MCM and edit their names.
String Property markerSlot0 Auto Hidden
String Property markerSlot1 Auto Hidden
String Property markerSlot2 Auto Hidden
String Property markerSlot3 Auto Hidden
String Property markerSlot4 Auto Hidden
String Property markerSlot5 Auto Hidden
String Property markerSlot6 Auto Hidden
String Property markerSlot7 Auto Hidden
String Property markerSlot8 Auto Hidden
String Property markerSlot9 Auto Hidden
String Property markerSlot10 Auto Hidden
String Property markerSlot11 Auto Hidden
String Property markerSlot12 Auto Hidden
String Property markerSlot13 Auto Hidden
String Property markerSlot14 Auto Hidden
String Property markerSlot15 Auto Hidden
String Property markerSlot16 Auto Hidden
String Property markerSlot17 Auto Hidden
String Property markerSlot18 Auto Hidden
String Property markerSlot19 Auto Hidden
String Property markerSlot20 Auto Hidden
String Property markerSlot21 Auto Hidden
String Property markerSlot22 Auto Hidden
String Property markerSlot23 Auto Hidden
String Property markerSlot24 Auto Hidden
String Property markerSlot25 Auto Hidden
String Property markerSlot26 Auto Hidden
String Property markerSlot27 Auto Hidden
String Property markerSlot28 Auto Hidden
String Property markerSlot29 Auto Hidden

CustomEvent UpdateCustomDestination



; =======================
; === STATE VARIABLES ===
; =======================

int STATE_NOT_READY = 0
int STATE_BUILDING = 1
int STATE_READY = 2
int databaseState = 0

ObjectReference[] allStaticRefs
int staticRefsIndex = 0
int totalStaticObjects = 0
int foundMapMarkerObjects = 0
float buildProgress = 0.0
float lastNotificationTime = 0.0
bool isCalibrating = false
bool isFilterMapMarkersScheduled = false
bool isCompleteBuildingScheduled = false

WorldSpace lastPlayerWorldSpace = None
CustomDestinationMarkerInfo currentDestinationMarkerInfo = None

; ====================
; === QUEST EVENTS ===
; ====================

Event OnQuestInit()
  Debug.Trace("AutoWalk: OnQuestInit", 1)
  RegisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")
  RegisterForExternalEvent("OnMCMOpen", "OnMCMOpen")
  RegisterForExternalEvent("OnMCMClose", "OnMCMClose")
EndEvent

Event Actor.OnPlayerLoadGame(Actor sender)
  Debug.Trace("AutoWalk: OnPlayerLoadGame.", 1)
  SUP_F4SE.RegisterForSUPEvent("OnPlayerMapMarkerStateChange", self as Form, "Mors:AutoWalkMarkerDB", "OnPlayerMapMarkerStateChange", true, false)
  SUP_F4SE.RegisterForSUPEvent("OnCellChange", self as Form, "Mors:AutoWalkMarkerDB", "OnCellChange", true, false)
  isCalibrating = false

  if databaseState == STATE_BUILDING
    lastNotificationTime = 0.0
    if totalStaticObjects == 0
      Debug.Trace("AutoWalk: OnPlayerLoadGame: Database building started but no static objects to process. Completing...", 1)
      if !isCompleteBuildingScheduled
        isCompleteBuildingScheduled = true
        CallFunctionNoWait("CompleteBuilding", None)
      endif
      return
    endif

    if staticRefsIndex < totalStaticObjects
      Debug.Trace("AutoWalk: OnPlayerLoadGame: Still building database, resuming...", 1)
      if !isFilterMapMarkersScheduled
        isFilterMapMarkersScheduled = true
        CallFunctionNoWait("FilterMapMarkers", None)
      endif
      return
    endif
  endif
  ; update user map marker usedList and spareList from json files for current worldspace
  ; this is needed because FormList does not persist its contents across save/load
  RefreshUserMapMarkerUsedList()
  RefreshUserMapMarkersForMCM()
EndEvent

Event OnInit()
  Debug.Trace("AutoWalk: OnInit.", 1)
  SUP_F4SE.RegisterForSUPEvent("OnPlayerMapMarkerStateChange", self as Form, "Mors:AutoWalkMarkerDB", "OnPlayerMapMarkerStateChange", true, false)
EndEvent

Function OnPlayerMapMarkerStateChange(bool wasAdded, WorldSpace currentWorldSpace, float posX, float posY, float posZ)
  Debug.Trace("AutoWalk: OnPlayerMapMarkerStateChange: added=" + wasAdded + ", (" + posX + ", " + posY + "," + posZ + ")", 1)
  Debug.Trace("AutoWalk: OnPlayerMapMarkerStateChange: Clearing currentDestinationMarkerInfo...", 1)
  currentDestinationMarkerInfo = None
EndFunction

Function OnCellChange(Cell newCell)
  Debug.Trace("AutoWalk: OnCellChange: Cell=" + newCell, 1)
  ; only if we have a pending custom destination marker to update
  if currentDestinationMarkerInfo != None && currentDestinationMarkerInfo.playerMarkerZProbed == false
    GetPlayerWorldSpace()
    SendUpdateCustomDestination()
  Else
    Debug.Trace("AutoWalk: OnCellChange: No pending custom destination marker to update.", 1)
  endif
EndFunction

; ======================
; === GRID FUNCTIONS ===
; ======================

Int Function GetContainingCellIndex(Grid grid, float x, float y)
  int xIdx = Math.Floor((x - grid.worldXStart) / grid.cellWidth)
  int yIdx = Math.Floor((y - grid.worldYStart) / grid.cellHeight)
  if xIdx < 0 || yIdx < 0 || xIdx > grid.numCols - 1 || yIdx > grid.numRows - 1
    Debug.Trace("AutoWalk: GetContainingCellIndex(): grid=" + grid + " xIdx=" + xIdx + ", yIdx=" + yIdx + ", x=" + x + ", y=" + y)
    return -1
  endif
  return xIdx + yIdx * grid.numCols
EndFunction

Int[] Function GetSearchCellIndexes(Grid grid, float x, float y)
  Int[] cells = new Int[9]
  cells[0] = GetContainingCellIndex(grid, x, y)
  cells[1] = GetContainingCellIndex(grid, x, y + grid.cellHeight)
  cells[2] = GetContainingCellIndex(grid, x + grid.cellWidth, y + grid.cellHeight)
  cells[3] = GetContainingCellIndex(grid, x + grid.cellWidth, y)
  cells[4] = GetContainingCellIndex(grid, x + grid.cellWidth, y - grid.cellHeight)
  cells[5] = GetContainingCellIndex(grid, x, y - grid.cellHeight)
  cells[6] = GetContainingCellIndex(grid, x - grid.cellWidth, y - grid.cellHeight)
  cells[7] = GetContainingCellIndex(grid, x - grid.cellWidth, y)
  cells[8] = GetContainingCellIndex(grid, x - grid.cellWidth, y + grid.cellHeight)
  return cells
EndFunction

Cell Function GetCellAtPosition(float x, float y, float z)
  ObjectReference probe = PlayerRef.PlaceAtMe(GroundProbeForm)
  probe.SetPosition(x, y, z)
  Cell foundCell = probe.GetParentCell()
  Debug.Trace("AutoWalk: GetCellAtPosition: Probe Position=(" + probe.x + "," + probe.y + ", " + probe.z + "), Cell=" + foundCell + ", World=" + probe.GetWorldSpace(), 1)
  Debug.Trace("AutoWalk: GetCellAtPosition: Original Position=(" + x + "," + y + ", " + z + ")", 1)
  probe.Delete()
  return foundCell
EndFunction

; =========================
; === DATABASE BUILDING ===
; =========================

; Starts the process of building the map marker database.
Function BuildMapMarkerDatabase()
  if databaseState == STATE_BUILDING
    Debug.Trace("AutoWalk: BuildMapMarkerDatabase() called while already building. Aborting.", 1)
    return
  endif

  int response = MessageRebuildDB.Show()
  if response != 0
    return
  endif

  databaseState = STATE_BUILDING
  currentDestinationMarkerInfo = None

  UsedUserMarkerListCommonwealth.Revert()
  UsedUserMarkerListFarHarbor.Revert()
  UsedUserMarkerListNukaWorld.Revert()
  ExtraMarkerListCommonwealth.Revert()
  ExtraMarkerListFarHarbor.Revert()
  ExtraMarkerListNukaWorld.Revert()

  int i = 0
  while i < GridCellsCommonwealth.Length
    GridCellsCommonwealth[i].markers.Revert()
    i += 1
  endwhile
  i = 0
  while i < GridCellsFarHarbor.Length
    GridCellsFarHarbor[i].markers.Revert()
    i += 1
  endwhile
  i = 0
  while i < GridCellsNukaWorld.Length
    GridCellsNukaWorld[i].markers.Revert()
    i += 1
  endwhile

  CallFunctionNoWait("ScanAllStaticMarkers", None)
EndFunction

; Scans all static references to find map markers and starts filtering.
Function ScanAllStaticMarkers()
  isFilterMapMarkersScheduled = false
  isCompleteBuildingScheduled = false
  lastNotificationTime = 0.0

  Debug.Trace("AutoWalk: ScanAllStaticMarkers() called...", 1)
  Debug.Notification("AutoWalk: Starting scan of all map markers...")

  BuildBlacklist()

  string[] types = new string[1]
  types[0] = "STAT"
  allStaticRefs = GardenOfEden2.FindAllReferencesWithFormType(types, PlayerRef, -1)
  if allStaticRefs == None || allStaticRefs.Length < 1
    Debug.Trace("AutoWalk: ERROR: GardenOfEden2.FindAllReferencesWithFormType() returned zero references.", 1)
    return
  endif
  buildProgress = 0.0
  foundMapMarkerObjects = 0
  totalStaticObjects = allStaticRefs.Length

  isFilterMapMarkersScheduled = true
  CallFunctionNoWait("FilterMapMarkers", None)
EndFunction

; Builds the blacklist of map markers to ignore.
Function BuildBlacklist()
  Blacklist.Revert()
  if Game.IsPluginInstalled("CartographersMapMarkers Commonwealth.esp")
    int formid = 0x28008FBF
    int index = 0
    while index < 50
      Form f = Game.GetFormFromFile(formid + index, "CartographersMapMarkers Commonwealth.esp") as Form
      if f
        Debug.Trace("AutoWalk: Adding formid [" + GardenOfEden.IntToHex(f.GetFormId(), true) + "] to blacklist...", 1)
        Blacklist.AddForm(f)
      endif
      index += 1
    endwhile
  endif

  if Game.IsPluginInstalled("CartographersMapMarkers FarHarbor.esp")
    int formid = 0x52019DB1
    int index = 0
    while index < 20
      Form f = Game.GetFormFromFile(formid + index, "CartographersMapMarkers FarHarbor.esp") as Form
      if f
        Debug.Trace("AutoWalk: Adding formid [" + GardenOfEden.IntToHex(f.GetFormId(), true) + "] to blacklist...", 1)
        Blacklist.AddForm(f)
      endif
      index += 1
    endwhile
  endif

  if Game.IsPluginInstalled("CartographersMapMarkers NukaWorld.esp")
    int formid = 0x5300218D
    int index = 0
    while index < 20
      Form f = Game.GetFormFromFile(formid + index, "CartographersMapMarkers NukaWorld.esp") as Form
      if f
        Debug.Trace("AutoWalk: Adding formid [" + GardenOfEden.IntToHex(f.GetFormId(), true) + "] to blacklist...", 1)
        Blacklist.AddForm(f)
      endif
      index += 1
    endwhile
  endif

  if Game.IsPluginInstalled("BusMod.esl")
    int busCommonwealth = 0x164 ; .esl formid limit is 0xfff
    int busFarHarbor = 0x16C
    int busNukaWorld = 0x167
    int[] formids = new int[3]
    formids[0] = busCommonwealth
    formids[1] = busFarHarbor
    formids[2] = busNukaWorld
    int idx = 0
    while idx < formids.Length
      Form f = Game.GetFormFromFile(formids[idx], "BusMod.esl") as Form
      if f
        Debug.Trace("AutoWalk: Adding formid [" + GardenOfEden.IntToHex(f.GetFormId(), true) + "] to blacklist...", 1)
        Blacklist.AddForm(f)
      endif
      idx += 1
    endwhile
    ExtraMarkerListCommonwealth.AddForm(Game.GetFormFromFile(busCommonwealth, "BusMod.esl") as Form)
    ExtraMarkerListFarHarbor.AddForm(Game.GetFormFromFile(busFarHarbor, "BusMod.esl") as Form)
    ExtraMarkerListNukaWorld.AddForm(Game.GetFormFromFile(busNukaWorld, "BusMod.esl") as Form)
  endif
EndFunction

; Filters static references to find map markers and adds them to the appropriate grid cell or debug list.
Function FilterMapMarkers()
  isFilterMapMarkersScheduled = false
  int limit = 200 ; Limit to prevent long processing time
  while staticRefsIndex < totalStaticObjects && limit > 0
    ObjectReference ref = allStaticRefs[staticRefsIndex]
    if SUP_F4SE.IsMapMarker(ref)
      WorldSpace ws = ref.GetWorldSpace()
      string name = SUP_F4SE.MapMarkerGetName(ref)
      Debug.Trace("AutoWalk: Marker[" + GardenOfEden.IntToHex(ref.GetFormId(), true) + "](" + name + ", " + WorldSpaceToString(ws) + ", (" + ref.x + ", " + ref.y + ", " + ref.z + "))", 1)
      if Blacklist.Find(ref) < 0
        int cellIndex = -1
        GridCell[] cells = None
        if ws == WorldSpaceCommonwealth
          cellIndex = GetContainingCellIndex(GridCommonwealth, ref.x, ref.y)
          cells = GridCellsCommonwealth
        elseif ws == WorldSpaceFarHarbor
          cellIndex = GetContainingCellIndex(GridFarHarbor, ref.x, ref.y)
          cells = GridCellsFarHarbor
        elseif ws == WorldSpaceNukaWorld
          cellIndex = GetContainingCellIndex(GridNukaWorld, ref.x, ref.y)
          cells = GridCellsNukaWorld
        endif
        if cellIndex > -1
          cells[cellIndex].markers.AddForm(ref)
          Debug.Trace("AutoWalk: Added to cell [" + cellIndex + "] [" + WorldSpaceToString(ws) + "]", 1)
        else
          Debug.Trace("AutoWalk: ERROR: No cell found for [" + GardenOfEden.IntToHex(ref.GetFormId(), true) + "]", 1)
          if ws == WorldSpaceCommonwealth || ws == WorldSpaceFarHarbor
            DebugList.AddForm(ref)
          endif
        endif
        foundMapMarkerObjects += 1
      else
        Debug.Trace("AutoWalk: Not adding blacklisted formid [" + GardenOfEden.IntToHex(ref.GetFormId(), true) + "]", 1)
      endif
    endif
    buildProgress = (staticRefsIndex / totalStaticObjects as float) * 100
    staticRefsIndex += 1
    limit -= 1
  endwhile

  if (Utility.GetCurrentRealTime() - lastNotificationTime > 10.0)
    lastNotificationTime = Utility.GetCurrentRealTime()
    ShowDBBuildingProgress()
  endif

  if staticRefsIndex < totalStaticObjects
    if !isFilterMapMarkersScheduled
      isFilterMapMarkersScheduled = true
      Utility.Wait(0.1)
      CallFunctionNoWait("FilterMapMarkers", None)
    endif
  else
    if !isCompleteBuildingScheduled
      isCompleteBuildingScheduled = true
      CallFunctionNoWait("CompleteBuilding", None)
    endif
  endif
EndFunction

; Finalizes the database build process and reports results.
Function CompleteBuilding()
  isCompleteBuildingScheduled = false
  Debug.Trace("AutoWalk: CompleteBuilding() called...", 1)
  allStaticRefs = None
  staticRefsIndex = 0
  foundMapMarkerObjects = 0
  totalStaticObjects = 0
  lastNotificationTime = 0.0

  int i = 0
  int countCW = 0
  while i < GridCellsCommonwealth.Length
    countCW += GridCellsCommonwealth[i].markers.GetSize()
    i += 1
  endwhile
  Debug.Trace("AutoWalk: Commonwealth: " + countCW + " markers scanned.", 1)
  i = 0
  int countFH = 0
  while i < GridCellsFarHarbor.Length
    countFH += GridCellsFarHarbor[i].markers.GetSize()
    i += 1
  endwhile
  Debug.Trace("AutoWalk: FarHarbor: " + countFH + " markers scanned.", 1)
  i = 0
  int countNW = 0
  while i < GridCellsNukaWorld.Length
    countNW += GridCellsNukaWorld[i].markers.GetSize()
    i += 1
  endwhile
  Debug.Trace("AutoWalk: NukaWorld: " + countNW + " markers scanned.", 1)
  Debug.Trace("AutoWalk: Total: " + (countCW + countFH + countNW) + " markers scanned.", 1)
  Debug.MessageBox("AutoWalk: Building Marker DB complete.")
  Debug.Trace("AutoWalk: Building Marker DB complete.", 1)

  i = 0
  if DebugList.GetSize() > 0
    Debug.Trace("AutoWalk: Total " + DebugList.GetSize() + " missed markers: ")
  endif
  while i < DebugList.GetSize()
    ObjectReference ref = DebugList.GetAt(i) as ObjectReference
    WorldSpace ws = ref.GetWorldSpace()
    string name = SUP_F4SE.MapMarkerGetName(ref)
    Debug.Trace("AutoWalk: Missed Marker[" + GardenOfEden.IntToHex(ref.GetFormId(), true) + "](" + name + ", " + WorldSpaceToString(ws) + ", (" + ref.x + ", " + ref.y + ", " + ref.z + "))", 1)
    i += 1
  endwhile
  DebugList.Revert()

  databaseState = STATE_READY
EndFunction

; Shows progress notifications during database building.
Function ShowDBBuildingProgress()
  if databaseState != STATE_READY
    if staticRefsIndex < totalStaticObjects
      Debug.Trace("AutoWalk: Progress=(" + foundMapMarkerObjects + "/" + staticRefsIndex + "/" + totalStaticObjects + ")", 1)
      Debug.Notification("AutoWalk: Building Marker DB " + buildProgress as Int + "%...")
    else
      Debug.Trace("AutoWalk: Progress=(" + foundMapMarkerObjects + "/" + staticRefsIndex + "/" + totalStaticObjects + ") - done", 1)
      Debug.Notification("AutoWalk: Map Marker Database built successfully.")
    endif
  endif
EndFunction

; =====================================
; === CUSTOM DESTINATION MANAGEMENT ===
; =====================================

; Returns the custom destination marker ObjectReference, calibrating if needed.
ObjectReference Function GetCustomDestinationMarkerAsync()
  if databaseState != STATE_READY
    Debug.Trace("AutoWalk: ERROR: Cannot start calibration; database is not ready.", 1)
    return None
  endif

  SUP_F4SE:SUPReferenceInfo markerInfo = SUP_F4SE.GetPlayerMapMarkerInfo()
  if !markerInfo || !markerInfo.exists
    Debug.Notification("AutoWalk: Please set a Custom Destination Marker in the Pip-Boy and try again.")
    Debug.Trace("AutoWalk: Please set a Custom Destination Marker in the Pip-Boy and try again.", 1)
    return None
  endif

  WorldSpace ws = GetPlayerWorldSpace()
  ObjectReference staticMarker = None
  if ws == WorldSpaceCommonwealth
    staticMarker = PlayerMapMarkerCommonwealth
	; TODO: DiamondCity, GoodNeighbor, SanctuaryHillsWorld
  elseif ws == WorldSpaceFarHarbor
    staticMarker = PlayerMapMarkerFarHarbor
  elseif ws == WorldSpaceNukaWorld
    staticMarker = PlayerMapMarkerNukaWorld
  endif

  if staticMarker == None
    Debug.Trace("AutoWalk: Unsupported worldspace: " + WorldSpaceToString(ws), 1)
    Debug.Notification("AutoWalk: Unable to start traveling here. You can move to outdoor and try again.")
    return None
  endif

  if isCalibrating
    Debug.Trace("AutoWalk: WARNING: Calibration already in progress.", 1)
    if currentDestinationMarkerInfo
      staticMarker.SetPosition(currentDestinationMarkerInfo.playerMarkerX, currentDestinationMarkerInfo.playerMarkerY, currentDestinationMarkerInfo.playerMarkerZ)
      return staticMarker
    else
      return None
    endif
  endif

  isCalibrating = true
  CustomDestinationMarkerInfo dstInfo = currentDestinationMarkerInfo
  if !dstInfo
    Debug.Trace("AutoWalk: markerInfo = (" + markerInfo.x as Int + ", " + markerInfo.y as Int + ", " + markerInfo.z as Int + ")", 1)
    dstInfo = new CustomDestinationMarkerInfo
    dstInfo.playerMarkerX = markerInfo.X
    dstInfo.playerMarkerY = markerInfo.Y
    dstInfo.playerMarkerZ = PlayerRef.Z
    dstInfo.playerMarkerZProbed = false
    dstInfo.nearestStaticMarkerName = ""
    dstInfo.nearestStaticMarker = None
    dstInfo.nearestStaticMarkerDistance = 0.0
  endif

  CallFunctionNoWait("CalibrateCustomDestinationMarker", None)
  staticMarker.SetPosition(dstInfo.playerMarkerX, dstInfo.playerMarkerY, dstInfo.playerMarkerZ)
  return staticMarker
EndFunction

; Calibrates the custom destination marker by finding the nearest static marker.
Function CalibrateCustomDestinationMarker()
  if currentDestinationMarkerInfo && currentDestinationMarkerInfo.nearestStaticMarker
    if !SendUpdateCustomDestination()
      SendUpdateCustomDestination(true)
    endif
    isCalibrating = false
    return
  endif

  Grid grid = None
  GridCell[] cells = None
  FormList extraList = None

  SUP_F4SE:SUPReferenceInfo markerInfo = SUP_F4SE.GetPlayerMapMarkerInfo()
  if !markerInfo || !markerInfo.exists
    Debug.Trace("AutoWalk: ERROR: Custom Marker disappeared; cannot process.", 1)
    isCalibrating = false
    return
  endif

  WorldSpace targetWS = GetPlayerWorldSpace()
  ; TODO: DiamondCity, GoodNeighbor, SanctuaryHillsWorld
  if targetWS == WorldSpaceCommonwealth
    grid = GridCommonwealth
    cells = GridCellsCommonwealth
    extraList = ExtraMarkerListCommonwealth
  elseif targetWS == WorldSpaceFarHarbor
    grid = GridFarHarbor
    cells = GridCellsFarHarbor
    extraList = ExtraMarkerListFarHarbor
  elseif targetWS == WorldSpaceNukaWorld
    grid = GridNukaWorld
    cells = GridCellsNukaWorld
    extraList = ExtraMarkerListNukaWorld
  endif

  if grid == None
    Debug.Notification("AutoWalk: Please move to the Commonwealth, Far Harbor, or Nuka World worldspace and try again.")
    Debug.Trace("AutoWalk: WorldSpace " + WorldSpaceToString(targetWS) + " is not supported yet.", 1)
    isCalibrating = false
    return
  endif

  float startTime = Utility.GetCurrentRealTime()
  int i = 0
  int nearestCellIndex = -1
  ObjectReference nearestMarker = None
  float nearestMarkerDistance = 0.0

  int notified = 0
  if grid != None
    Int[] searchIndexes = GetSearchCellIndexes(grid, markerInfo.x, markerInfo.y)
    Debug.Trace("AutoWalk: Search indexes for custom marker (" + markerInfo.x + ", " + markerInfo.y + ") in worldspace " + targetWS + ": " + searchIndexes, 1)
    while i < searchIndexes.Length
      int cellIdx = searchIndexes[i]
      if cellIdx >= 0
        int j = 0
        while j < cells[cellIdx].markers.GetSize()
          ObjectReference marker = cells[cellIdx].markers.GetAt(j) as ObjectReference
          float dist = SUP_F4SE.GetDistanceBetweenPoints(marker.X, markerInfo.x, marker.Y, markerInfo.y, 0, 0)
          ; TODO: Prioritize user markers
          if marker == None
            if notified < 3
              notified += 1
              Debug.Trace("AutoWalk: ERROR: Marker at index " + j + " in cell " + cellIdx + " is None. This may indicate that a mod providing this marker was uninstalled.", 1)
              Debug.Notification("AutoWalk: WARNING: A map marker is missing. This may be due to a mod being uninstalled. Please rebuild the marker database if you encounter issues.")
            endif
          else
            if nearestMarker == None
              nearestMarker = marker
              nearestCellIndex = cellIdx
              nearestMarkerDistance = dist
            elseif dist < nearestMarkerDistance
              nearestMarker = marker
              nearestMarkerDistance = dist
              nearestCellIndex = cellIdx
            endif
          endif          
          j += 1
        endwhile
      endif
      i += 1
    endwhile
  endif

  if extraList != None && extraList.GetSize() > 0
    i = 0
    while i < extraList.GetSize()
      ObjectReference marker = extraList.GetAt(i) as ObjectReference
      if marker && marker.GetWorldSpace() == targetWS
        float dist = SUP_F4SE.GetDistanceBetweenPoints(marker.X, markerInfo.x, marker.Y, markerInfo.y, 0, 0)
        if nearestMarker == None || dist < nearestMarkerDistance
          nearestMarker = marker
          nearestMarkerDistance = dist
          nearestCellIndex = -1 ; Extra markers are not in grid cells
        endif
      endif
      i += 1
    endwhile
  endif

  Debug.Trace("AutoWalk: Search took " + (Utility.GetCurrentRealTime() - startTime) + " seconds.", 1)
  if nearestMarker
    Debug.Trace("AutoWalk: Found nearest marker [" + GardenOfEden.IntToHex(nearestMarker.GetFormId(), true) + "][" + GardenOfEden2.GetFormTypeAsString(nearestMarker as Form) + "] dist=" + nearestMarkerDistance + " found index=" + nearestCellIndex, 1)

    CustomDestinationMarkerInfo dstInfo = new CustomDestinationMarkerInfo
    dstInfo.playerMarkerX = markerInfo.X
    dstInfo.playerMarkerY = markerInfo.Y
    dstInfo.playerMarkerZ = nearestMarker.Z
    dstInfo.playerMarkerCell = GetCellAtPosition(markerInfo.x, markerInfo.y, nearestMarker.z)

    float[] fix = GetMarkerFix(nearestMarker)
    if fix && fix.Length > 2
      dstInfo.nearestStaticMarkerFixX = fix[0]
      dstInfo.nearestStaticMarkerFixY = fix[1]
      dstInfo.nearestStaticMarkerFixZ = fix[2]
      dstInfo.nearestStaticMarkerHasFix = true
      dstInfo.playerMarkerZProbed = true
      Debug.Trace("AutoWalk: nearestStaticMarkerHasFix=" + dstInfo.nearestStaticMarkerHasFix, 1)
    endif

    String name
    UserMapMarker umk = LoadUserMapMarkerInfo(nearestMarker)
    ; if it's a user map marker, use its custom name
    if umk
      name = umk.name
    endif
    if !name
      name = SUP_F4SE.MapMarkerGetName(nearestMarker)
    endif

    dstInfo.nearestStaticMarkerName = name
    dstInfo.nearestStaticMarker = nearestMarker
    dstInfo.nearestStaticMarkerDistance = nearestMarkerDistance
    currentDestinationMarkerInfo = dstInfo
    SendUpdateCustomDestination(true)
  else
    Debug.Trace("AutoWalk: ERROR: No grid cell or extra marker found for (" + markerInfo.x + ", " + markerInfo.y + ")", 1)
  endif

  isCalibrating = false
EndFunction

; Sends the custom event to update the custom destination marker.
bool Function SendUpdateCustomDestination(bool fallbackDraft = false)
  if currentDestinationMarkerInfo
    if currentDestinationMarkerInfo.playerMarkerCell == PlayerRef.GetParentCell()
      if currentDestinationMarkerInfo.playerMarkerZProbed == false
        Debug.Trace("AutoWalk: Determining ground height for custom destination marker...", 1)
        float groundZ = GetGroundZ(currentDestinationMarkerInfo.playerMarkerX, currentDestinationMarkerInfo.playerMarkerY, currentDestinationMarkerInfo.playerMarkerZ)
        currentDestinationMarkerInfo.playerMarkerZ = groundZ
        currentDestinationMarkerInfo.playerMarkerZProbed = true
      endif
      Var[] args = new Var[1]
      args[0] = currentDestinationMarkerInfo
      SendCustomEvent("UpdateCustomDestination", args)
      return true
    elseif fallbackDraft
      Var[] args = new Var[1]
      args[0] = currentDestinationMarkerInfo
      SendCustomEvent("UpdateCustomDestination", args)
      return true
    endif
    ; Not in the same cell; will try again later.
  endif
  return false
EndFunction

; Loads marker fix data from JSON, if available.
float[] Function GetMarkerFix(ObjectReference marker)
  string formIdStr = MyFormIdHexStr(marker.GetFormId())
  ;string pluginFile = GardenOfEden2.LookupPluginNameByForm(marker)
  string pluginFile = GardenOfEden2.GetLastOverridePluginFile(marker)
  string fileName = "Data/Mors Auto Walk/MarkerFix_" + pluginFile + ".json"
  Debug.Trace("AutoWalk: GetMarkerFix: Searching for marker fix for [" + formIdStr + "](" + marker + "), plugin=" + pluginFile, 1)

  SUP_F4SE:JSONValue[] fix = SUP_F4SE.JSONGetValueArray(fileName, formIdStr + "_position", 0)
  Debug.Trace("AutoWalk: GetMarkerFix: " + fix, 1)
  if fix && fix.Length > 2
    float[] ret = new Float[3]
    ret[0] = fix[0].JSONfValue
    ret[1] = fix[1].JSONfValue
    ret[2] = fix[2].JSONfValue
    return ret
  endif

  ; To save a fix, you could use:
  ; SUP_F4SE.JSONClearKey(fileName, formIdStr, 0)
  ; SUP_F4SE.JSONAppendValueFloat(fileName, formIdStr, marker.X , 0)
  ; SUP_F4SE.JSONAppendValueFloat(fileName, formIdStr, marker.Y , 0)
  ; SUP_F4SE.JSONAppendValueFloat(fileName, formIdStr, marker.Z , 0)
  return None
EndFunction

; ==================================
; === USER MAP MARKER MANAGEMENT ===
; ==================================

struct UserMapMarker
  String name
  float X
  float Y
  float Z
EndStruct

bool gDisplayUserMarkers = false

; Returns the spare and used user marker lists for the given worldspace.
FormList[] Function GetUserMapMarkerLists(WorldSpace ws)
  FormList[] ret = new FormList[2]
  FormList spareList = None
  FormList usedList = None
  ; TODO: DiamondCity, GoodNeighbor, SanctuaryHillsWorld
  if ws == WorldSpaceCommonwealth
    spareList = UserMarkerListCommonwealth
    usedList = UsedUserMarkerListCommonwealth
  elseif ws == WorldSpaceFarHarbor
    spareList = UserMarkerListFarHarbor
    usedList = UsedUserMarkerListFarHarbor
  elseif ws == WorldSpaceNukaWorld
    spareList = UserMarkerListNukaWorld
    usedList = UsedUserMarkerListNukaWorld
  endif
  ret[0] = spareList
  ret[1] = usedList
  return ret
EndFunction

; Returns an unused user map marker ObjectReference for the given worldspace.
ObjectReference Function GetUnusedUserMapMarker(WorldSpace ws)
  FormList[] lists = GetUserMapMarkerLists(ws)
  FormList spareList = lists[0]
  FormList usedList = lists[1]

  if spareList == None
    String noti = "AutoWalk: No spare user map markers for " + WorldSpaceToString(ws) + "."
    Debug.Notification(noti)
    Debug.Trace(noti, 1)
    return None
  endif

  int i = 0
  while i < spareList.GetSize()
    Form f = spareList.GetAt(i)
    if usedList.Find(f) < 0
      return f as ObjectReference
    endif
    i += 1
  endwhile

  String noti = "AutoWalk: No more spare user map markers for " + WorldSpaceToString(ws) + "."
  Debug.Notification(noti)
  Debug.Trace(noti, 1)
  return None
EndFunction

; Marks a user map marker as used in the used list for the given worldspace.
Function SetUserMapMarkerUsed(WorldSpace ws, ObjectReference marker)
  FormList[] lists = GetUserMapMarkerLists(ws)
  FormList usedList = lists[1]
  if usedList
    usedList.AddForm(marker)
  endif
EndFunction

; Sets the value for a user map marker slot in the MCM.
Function SetMcmUserMapMarkerSlot(int idx, string value)
  if idx == 0
    markerSlot0 = value
  elseif idx == 1
    markerSlot1 = value
  elseif idx == 2
    markerSlot2 = value
  elseif idx == 3
    markerSlot3 = value
  elseif idx == 4
    markerSlot4 = value
  elseif idx == 5
    markerSlot5 = value
  elseif idx == 6
    markerSlot6 = value
  elseif idx == 7
    markerSlot7 = value
  elseif idx == 8
    markerSlot8 = value
  elseif idx == 9
    markerSlot9 = value
  elseif idx == 10
    markerSlot10 = value
  elseif idx == 11
    markerSlot11 = value
  elseif idx == 12
    markerSlot12 = value
  elseif idx == 13
    markerSlot13 = value
  elseif idx == 14
    markerSlot14 = value
  elseif idx == 15
    markerSlot15 = value
  elseif idx == 16
    markerSlot16 = value
  elseif idx == 17
    markerSlot17 = value
  elseif idx == 18
    markerSlot18 = value
  elseif idx == 19
    markerSlot19 = value
  elseif idx == 20
    markerSlot20 = value
  elseif idx == 21
    markerSlot21 = value
  elseif idx == 22
    markerSlot22 = value
  elseif idx == 23
    markerSlot23 = value
  elseif idx == 24
    markerSlot24 = value
  elseif idx == 25
    markerSlot25 = value
  elseif idx == 26
    markerSlot26 = value
  elseif idx == 27
    markerSlot27 = value
  elseif idx == 28
    markerSlot28 = value
  elseif idx == 29
    markerSlot29 = value
  endif
EndFunction

; Gets the value for a user map marker slot in the MCM.
String Function GetMcmUserMapMarkerSlot(int idx)
  if idx == 0
    return markerSlot0
  elseif idx == 1
    return markerSlot1
  elseif idx == 2
    return markerSlot2
  elseif idx == 3
    return markerSlot3
  elseif idx == 4
    return markerSlot4
  elseif idx == 5
    return markerSlot5
  elseif idx == 6
    return markerSlot6
  elseif idx == 7
    return markerSlot7
  elseif idx == 8
    return markerSlot8
  elseif idx == 9
    return markerSlot9
  elseif idx == 10
    return markerSlot10
  elseif idx == 11
    return markerSlot11
  elseif idx == 12
    return markerSlot12
  elseif idx == 13
    return markerSlot13
  elseif idx == 14
    return markerSlot14
  elseif idx == 15
    return markerSlot15
  elseif idx == 16
    return markerSlot16
  elseif idx == 17
    return markerSlot17
  elseif idx == 18
    return markerSlot18
  elseif idx == 19
    return markerSlot19
  elseif idx == 20
    return markerSlot20
  elseif idx == 21
    return markerSlot21
  elseif idx == 22
    return markerSlot22
  elseif idx == 23
    return markerSlot23
  elseif idx == 24
    return markerSlot24
  elseif idx == 25
    return markerSlot25
  elseif idx == 26
    return markerSlot26
  elseif idx == 27
    return markerSlot27
  elseif idx == 28
    return markerSlot28
  elseif idx == 29
    return markerSlot29
  endif
  return ""
EndFunction

; Returns the number of user map marker slots in the MCM.
int Function GetMcmUserMapMarkerSlotCount()
  return 30
EndFunction


; Saves the name for a user map marker to a JSON file.
Function SaveUserMapMarkerInfo(ObjectReference marker, String name)
  string formIdStr = MyFormIdHexStr(marker.GetFormId())
  string worldSpaceStr = WorldSpaceToString(marker.GetWorldSpace())
  string fileName = "Data/Mors Auto Walk/UserMarker_" + worldSpaceStr + ".json"
  int rc = SUP_F4SE.JSONSetValueString(fileName, formIdStr + "_name", name, 0)
  ; SUP_F4SE.JSONAppendValueFloat does not work
  rc = SUP_F4SE.JSONSetValueFloat(fileName, formIdStr + "_x", marker.x, 0) 
  rc = SUP_F4SE.JSONSetValueFloat(fileName, formIdStr + "_y", marker.y, 0)
  rc = SUP_F4SE.JSONSetValueFloat(fileName, formIdStr + "_z", marker.z, 0)
EndFunction

; Loads the name for a user map marker from a JSON file.
UserMapMarker Function LoadUserMapMarkerInfo(ObjectReference marker)
  string formIdStr = MyFormIdHexStr(marker.GetFormId())
  string worldSpaceStr = WorldSpaceToString(marker.GetWorldSpace())
  string fileName = "Data/Mors Auto Walk/UserMarker_" + worldSpaceStr + ".json"
  string keyStr = formIdStr + "_name"
  SUP_F4SE:JSONValue jsval = SUP_F4SE.JSONGetValue(fileName, keyStr, 0)
  if !jsval || jsval.JSONsValue == ""
    return None
  endif
  keyStr = formIdStr + "_position"
  SUP_F4SE:JSONValue jsX = SUP_F4SE.JSONGetValue(fileName, formIdStr + "_x", 0)
  SUP_F4SE:JSONValue jsY = SUP_F4SE.JSONGetValue(fileName, formIdStr + "_y", 0)
  SUP_F4SE:JSONValue jsZ = SUP_F4SE.JSONGetValue(fileName, formIdStr + "_z", 0)
  if !jsX || !jsY || !jsZ || (jsX.JSONfValue == 0.0 && jsY.JSONfValue == 0.0 && jsZ.JSONfValue == 0.0)
    return None
  endif
  UserMapMarker ret = new UserMapMarker
  ret.name = jsval.JSONsValue
  ret.X = jsX.JSONfValue
  ret.Y = jsY.JSONfValue
  ret.Z = jsZ.JSONfValue
  return ret
EndFunction

Function AddUserMapMarker(string markerName)
  WorldSpace ws
  ws = Game.GetPlayer().GetWorldSpace()
 ; Check player is not in an in-door cell
  if ws == None || (ws != WorldSpaceCommonwealth && ws != WorldSpaceFarHarbor && ws != WorldSpaceNukaWorld)
    Debug.Notification("AutoWalk: Cannot add user map marker while indoors.")
    return
  endif

  ws = GetPlayerWorldSpace()
  GridCell cell_ = GetContainingGridCell(PlayerRef.x, PlayerRef.y, ws)
  ObjectReference spareMarker = GetUnusedUserMapMarker(ws)

  if spareMarker
    SetUserMapMarkerUsed(ws, spareMarker)
    spareMarker.SetPosition(PlayerRef.x, PlayerRef.y, PlayerRef.z)
    SUP_F4SE.MapMarkerSetName(spareMarker, markerName)
    SaveUserMapMarkerInfo(spareMarker, markerName)
    cell_.markers.AddForm(spareMarker)
    if gDisplayUserMarkers
      spareMarker.Enable()
    else
      spareMarker.Disable()
    endif
    Debug.Notification("AutoWalk: New user map marker added: " + SUP_F4SE.MapMarkerGetName(spareMarker))
  else
    Debug.Notification("AutoWalk: Unable to add new user map marker; no spare markers available.")
  endif
EndFunction

; Deletes the name for a user map marker from the JSON file.
Function RemoveUserMapMarker(ObjectReference marker)
  string formIdStr = MyFormIdHexStr(marker.GetFormId())
  string worldSpaceStr = WorldSpaceToString(marker.GetWorldSpace())
  string fileName = "Data/Mors Auto Walk/UserMarker_" + worldSpaceStr + ".json"
  string keyStr = formIdStr + "_name"
  SUP_F4SE.JSONSetValueString(fileName, formIdStr + "_name", "", 0)
  SUP_F4SE.JSONSetValueFloat(fileName, formIdStr + "_x", 0.0, 0)
  SUP_F4SE.JSONSetValueFloat(fileName, formIdStr + "_y", 0.0, 0)
  SUP_F4SE.JSONSetValueFloat(fileName, formIdStr + "_z", 0.0, 0)
  ; Note: SUP_F4SE.JSONEraseKey(fileName, keyStr, 0) causes crash-to-desktop (CtoD)
EndFunction

GridCell Function GetContainingGridCell(float x, float y, WorldSpace ws)
  GridCell[] cells = None
  int index = -1
  if ws == WorldSpaceCommonwealth
    cells = GridCellsCommonwealth
    index = GetContainingCellIndex(GridCommonwealth, x, y)
  elseif ws == WorldSpaceFarHarbor
    cells = GridCellsFarHarbor
    index = GetContainingCellIndex(GridFarHarbor, x, y)
  elseif ws == WorldSpaceNukaWorld
    cells = GridCellsNukaWorld
    index = GetContainingCellIndex(GridNukaWorld, x, y)
  endif
  if index >= 0 && index < cells.Length
    return cells[index]
  endif
  return None
EndFunction

Function RefreshUserMapMarkerUsedList()
  Debug.Trace("AutoWalk: RefreshUserMapMarkerUsedList() called...", 1)
  FormList[] lists = GetUserMapMarkerLists(GetPlayerWorldSpace())
  FormList spareList = lists[0]
  FormList usedList = lists[1]
  ; Clear the used list and rebuild it from the database
  usedList.revert()
  int i = 0
  while i < spareList.GetSize()
    ObjectReference marker = spareList.GetAt(i) as ObjectReference
    UserMapMarker umk = LoadUserMapMarkerInfo(marker)
    if umk
      marker.SetPosition(umk.X, umk.Y, umk.Z)
      SUP_F4SE.MapMarkerSetName(marker, umk.name)
      usedList.AddForm(marker)
      ; check cell and add to database if needed
      GridCell cell_ = GetContainingGridCell(marker.x, marker.y, GetPlayerWorldSpace())
      if cell_ && !cell_.markers.HasForm(marker)
        cell_.markers.AddForm(marker)
        Debug.Trace("AutoWalk: RefreshUserMapMarkerUsedList(): added marker " + GardenOfEden.IntToHex(marker.GetFormId()) + " to database", 1)
      endif
      if gDisplayUserMarkers
        marker.Enable()
      endif
      Debug.Trace("AutoWalk: RefreshUserMapMarkerUsedList(): added marker " + GardenOfEden.IntToHex(marker.GetFormId()) + " with name " + umk.name + " to used list", 1)
    else
      ; remove from cell database if present
      GridCell cell_ = GetContainingGridCell(marker.x, marker.y, GetPlayerWorldSpace())
      if cell_ && cell_.markers.HasForm(marker)
        cell_.markers.RemoveAddedForm(marker)
        Debug.Trace("AutoWalk: RefreshUserMapMarkerUsedList(): removed marker " + GardenOfEden.IntToHex(marker.GetFormId()) + " from database", 1)
      endif
      marker.Disable()
    endif
    i += 1
  endwhile
EndFunction

; Refreshes the user map marker list in the MCM.
Function RefreshUserMapMarkersForMCM()
  Debug.Trace("AutoWalk: RefreshUserMapMarkersForMCM() called...", 1)
  int idx = 0
  while idx < GetMcmUserMapMarkerSlotCount()
    SetMcmUserMapMarkerSlot(idx, "")
    idx += 1
  endwhile

  FormList[] lists = GetUserMapMarkerLists(GetPlayerWorldSpace())
  FormList usedList = lists[1]
  if usedList
    Debug.Trace("AutoWalk: RefreshUserMapMarkersForMCM(): world=" + GetPlayerWorldSpace() + " usedList=" + usedList + ", size=" + usedList.GetSize(), 1)
    idx = 0
    while idx < Math.Min(usedList.GetSize(), GetMcmUserMapMarkerSlotCount())
      ObjectReference marker = usedList.GetAt(idx) as ObjectReference
      string name = ""
      UserMapMarker umk = LoadUserMapMarkerInfo(marker)
      if umk
        name = umk.name
      endif
      if !name || name == ""
        name = SUP_F4SE.MapMarkerGetName(marker)
      endif
      Debug.Trace("AutoWalk: RefreshUserMapMarkersForMCM(): markerName=" + name, 1)
      SetMcmUserMapMarkerSlot(idx, name)
      idx += 1
    endwhile
  else
    Debug.Trace("AutoWalk: RefreshUserMapMarkersForMCM(): no usedList for world=" + GetPlayerWorldSpace(), 1)
    ;Debug.Notification("AutoWalk: User map markers not supported for this worldspace."); no use because it shows up after MCM is closed
  endif

  MCM.RefreshMenu()
EndFunction

; Called when the MCM menu is opened.
Function OnMCMOpen()
  RefreshUserMapMarkersForMCM()
EndFunction

Function OnMCMClose()

EndFunction

; Updates the user map marker list in the MCM and database.
Function UpdateUserMapMarkerList(int idx, string markerName)
  FormList[] lists = GetUserMapMarkerLists(GetPlayerWorldSpace())
  FormList usedList = lists[1]
  if !usedList
    Debug.Trace("AutoWalk: UpdateUserMapMarkerList(): ERROR: cannot find used list. Unsupported worldspace?", 1)
    return
  endif

  if usedList.GetSize() == 0 || idx > usedList.GetSize() - 1
    Debug.Trace("AutoWalk: UpdateUserMapMarkerList(): index out of range: idx=" + idx + ", list size=" + usedList.GetSize(), 1)
    if markerName != ""
      Debug.Trace("AutoWalk: UpdateUserMapMarkerList(): adding new user map marker with name " + markerName, 1)
      AddUserMapMarker(markerName)
    endif
    RefreshUserMapMarkersForMCM()
    return
  endif

  ObjectReference marker = usedList.GetAt(idx) as ObjectReference
  if markerName == ""
    WorldSpace ws = Game.GetPlayer().GetWorldSpace()
    GridCell cell_ = GetContainingGridCell(marker.x, marker.y, ws)
    if cell_ && cell_.markers.HasForm(marker)
      cell_.markers.RemoveAddedForm(marker)
      Debug.Trace("AutoWalk: UpdateUserMapMarkerList(): user marker " + GardenOfEden.IntToHex(marker.GetFormId()) + " removed from database", 1)
      Debug.Notification("AutoWalk: User map marker \"" + SUP_F4SE.MapMarkerGetName(marker) + "\" [" + GardenOfEden.IntToHex(marker.GetFormId()) + "] removed.")
    else
      Debug.Trace("AutoWalk: UpdateUserMapMarkerList(): ERROR: user marker " + GardenOfEden.IntToHex(marker.GetFormId()) + " not found in database", 1)
    endif
    usedList.RemoveAddedForm(marker)
    marker.Disable()
    RemoveUserMapMarker(marker)
    RefreshUserMapMarkersForMCM()
  else
    SetMcmUserMapMarkerSlot(idx, markerName)
    SaveUserMapMarkerInfo(marker, markerName) ; Save separately because SUP_F4SE.MapMarkerSetName is not reliable
    SUP_F4SE.MapMarkerSetName(marker, markerName)
    Debug.Trace("AutoWalk: UpdateUserMapMarkerList(): user marker " + GardenOfEden.IntToHex(marker.GetFormId()) + " name changed to " + SUP_F4SE.MapMarkerGetName(marker), 1)
  endif
EndFunction

function UserMarkerShowHide(bool show)
  Debug.Trace("AutoWalk: UserMarkerShowHide: show=" + show, 1)
  gDisplayUserMarkers = show
  FormList[] lists = GetUserMapMarkerLists(GetPlayerWorldSpace())
  FormList usedList = lists[1]
  if usedList
    int i = 0
    while i < usedList.GetSize()
      ObjectReference marker = usedList.GetAt(i) as ObjectReference
      if show
        marker.Enable()
      else
        marker.Disable()
      endif
      i += 1
    endwhile
  endif
EndFunction
; ======================
; === UTIL FUNCTIONS ===
; ======================

; Returns the ground Z coordinate at the specified (x, y, z) position by placing a probe object and reading its final Z after settling.
Float Function GetGroundZ(float x, float y, float z)
  ; The ground probe must have a mesh, weight, and dimensions for the drop effect and must be in the same cell as the player.
  Debug.Trace("AutoWalk: GetGroundZ: ground probe = " + GroundProbeForm, 1)
  ObjectReference probeObject = PlayerRef.PlaceAtMe(GroundProbeForm)
  probeObject.SetPosition(x, y, z + 500)
  Utility.Wait(4)
  Debug.Trace("AutoWalk: GetGroundZ: Probe Object Position = (" + probeObject.x + ", " + probeObject.y + ", " + probeObject.z + ")", 1)
  Debug.Trace("AutoWalk: GetGroundZ: Original Position = (" + x + ", " + y + ", " + z + ")", 1)
  probeObject.Delete()
  return probeObject.z
EndFunction

; Sets the player map marker at the specified worldspace and position.
Function SetPlayerMapMarker(WorldSpace targetWorldSpace, float posX, float posY, float posZ)
  SUP_F4SE.RegisterForSUPEvent("OnPlayerMapMarkerStateChange", self as Form, "Mors:AutoWalkMarkerDB", "OnPlayerMapMarkerStateChange", false, false)
  SUP_F4SE.SetPlayerMapMarker(targetWorldSpace, posX, posY, posZ)
  SUP_F4SE.RegisterForSUPEvent("OnPlayerMapMarkerStateChange", self as Form, "Mors:AutoWalkMarkerDB", "OnPlayerMapMarkerStateChange", true, false)
EndFunction

; Returns the last 6 hex digits of a form ID as a string.
String Function MyFormIdHexStr(int formID)
  String formIDString = GardenOfEden.IntToHex(formID)
  int len = StringUtil.GetLength(formIDString)
  int start = len - 6
  if start >= 0
    return StringUtil.Substring(formIDString, start, 6)
  else
    return formIDString
  endif
EndFunction

; Returns the current state of the marker database.
int Function GetDBState()
  return databaseState
EndFunction

; Gets and caches the player's current worldspace.
WorldSpace Function GetPlayerWorldSpace()
  ; TODO: Should Diamond City and Goodneighbor be treated as Commonwealth?
  WorldSpace ws = Game.GetPlayer().GetWorldSpace()
  if ws != None
    lastPlayerWorldSpace = ws
  else
    Debug.Trace("AutoWalk: GetPlayerWorldSpace: Player worldspace is None. Location = " + Game.GetPlayer().GetCurrentLocation(), 1)
  endif
  return lastPlayerWorldSpace
EndFunction

; Converts a WorldSpace object to a readable string name.
String Function WorldSpaceToString(WorldSpace ws)
  if ws == None
    return "None"
  endif
  if ws == WorldSpaceCommonwealth
    return "Commonwealth"
  elseif ws == WorldSpaceDiamondCity
    return "DiamondCity"
  elseif ws == WorldSpaceGoodNeighbor
    return "GoodNeighbor"
  elseif ws == WorldSpaceSanctuaryHills
    return "SanctuaryHills"
  elseif ws == WorldSpaceFarHarbor
    return "FarHarbor"
  elseif ws == WorldSpaceNukaWorld
    return "NukaWorld"
  else
    return ws as String
  endif
EndFunction