ScriptName Mors:AutoWalk Extends Quest conditional

CustomEvent autowalk_SceneStopped

;-- Structs -----------------------------------------
Struct locData
  ObjectReference marker
  Form miscItem
  ObjectReference dstMarker
EndStruct


;-- Variables ---------------------------------------
Int TimerMenuKeyDown = 10
int TimerCheckArrival = 20
Bool bStopNotification = True
Form chosenItem
String dstName = ""
Int iMenu = 0
Int iWorldSpace = -1
bool bWalking = False ; MorsAW_Scene.IsPlaying() is not reliable
ObjectReference CurrentCustomDstMarker = None
bool bPlayerInCombat = false
bool bRegisteredCombatStateEvent = false
float arrivalCheckInterval = 3.0
;-- Properties --------------------------------------
Group Aliases
  ReferenceAlias Property dstMarker Auto Const mandatory
  { the DstMarker alias on this quest - used as the travel package destination }
  ReferenceAlias Property Traveler Auto Const mandatory
  { the Traveler alias on this quest - used to add the protective spells and perks to traveling player }
  ReferenceAlias Property Captive Auto Const mandatory
  { the Captive alias on this quest - used to add Captive faction to traveling player }
EndGroup

Group References
  Idle Property IdleStop Auto Const mandatory
  Actor Property PlayerRef Auto Const mandatory
  ObjectReference Property MorsAW_ContainerREF Auto Const mandatory
  { container in MorsAW_StorageCell reserved for "menu items" for the "Settlements" destination category }
  Scene Property MorsAW_Scene Auto Const mandatory
  { the AutoWalk scene on this quest }
EndGroup

Group MenuData
  FormList Property MorsAW_ListCategories Auto Const mandatory
  { formlist with misc items serving as menu items for category selection }
  FormList Property MorsAW_ListSettlements Auto Const mandatory
  { formlist with misc items serving as menu items for "Settlements" category }
  FormList Property MorsAW_ListOtherAM Auto Const mandatory
  { formlist with misc items serving as menu items for "Other A-M" category }
  FormList Property MorsAW_ListOtherNZ Auto Const mandatory
  { formlist with misc items serving as menu items for "Other N-Z" category }
  Form Property MorsAW_MnuSettlements Auto Const mandatory
  { misc item used as the "Settlements" category selection item. }
  Form Property MorsAW_MnuOtherAM Auto Const mandatory
  { misc item used as the "Other" category selection item. }
  Form Property MorsAW_MnuOtherNZ Auto Const mandatory
  { misc item used as the "Other" category selection item. }
  Form Property MorsAW_MenuCustomDestination Auto Const
EndGroup

Group MenuData_FarHarbor
  Location Property DLC03FarHarborWorldLocation Auto Const
  { top parent location for all Far Harbor }
  FormList Property MorsAW_ListCategories_FarHarbor Auto Const mandatory
  { formlist with misc items serving as menu items for category selection }
  FormList Property MorsAW_ListOtherAM_FarHarbor Auto Const mandatory
  { formlist with misc items serving as menu items for "Far Harbor A-M" category }
  FormList Property MorsAW_ListOtherNZ_FarHarbor Auto Const mandatory
  { formlist with misc items serving as menu items for "Far Harbor N-Z" category }
  Form Property MorsAW_MnuOtherAM_FarHarbor Auto Const mandatory
  { misc item used as the "Other" category selection item. }
  Form Property MorsAW_MnuOtherNZ_FarHarbor Auto Const mandatory
  { misc item used as the "Other" category selection item. }
EndGroup

Group MenuData_NukaWorld
  Location Property DLC04NukaWorldLocation Auto Const
  { top parent location for all Nuka World }
  FormList Property MorsAW_ListCategories_NukaWorld Auto Const mandatory
  { formlist with misc items serving as menu items for category selection }
  FormList Property MorsAW_ListOtherAM_NukaWorld Auto Const mandatory
  { formlist with misc items serving as menu items for "Nuka World A-M" category }
  FormList Property MorsAW_ListOtherNZ_NukaWorld Auto Const mandatory
  { formlist with misc items serving as menu items for "Nuka World N-Z" category }
  Form Property MorsAW_MnuOtherAM_NukaWorld Auto Const mandatory
  { misc item used as the "Other" category selection item. }
  Form Property MorsAW_MnuOtherNZ_NukaWorld Auto Const mandatory
  { misc item used as the "Other" category selection item. }
EndGroup

Group Destinations
  mors:autowalk:locdata[] Property Settlements Auto Const
  mors:autowalk:locdata[] Property OtherAM Auto Const
  mors:autowalk:locdata[] Property OtherNZ Auto Const
  mors:autowalk:locdata[] Property OtherAM_FarHarbor Auto Const
  mors:autowalk:locdata[] Property OtherNZ_FarHarbor Auto Const
  mors:autowalk:locdata[] Property OtherAM_NukaWorld Auto Const
  mors:autowalk:locdata[] Property OtherNZ_NukaWorld Auto Const
EndGroup

Bool Property bCombatWarning = True Auto hidden
Bool Property bRadResistant = True Auto conditional hidden
Bool Property bTrapSafety = True Auto conditional hidden
Bool Property bCaptive = False Auto hidden
Bool Property bInvincible = True Auto hidden
Float Property HotkeyHoldTime = 0.400000006 Auto hidden
Bool Property bOnlyDiscovered = True Auto hidden
Bool Property bStopMessageBox = False Auto hidden
Int Property WalkSpeed = 0 Auto conditional hidden
Int Property DrawWeapon = 0 Auto conditional hidden
Int Property Sneak = 0 Auto conditional hidden

Mors:AutoWalkMarkerDB Property MarkerDBScript Auto const 
;-- Functions ---------------------------------------

Event OnBeginState(String _oldState)
  ; Empty function
EndEvent

Event OnEndState(String _newState)
  ; Empty function
EndEvent

Function ShowMenu()
  If Utility.IsInMenuMode()
    Self.RegisterForMenuOpenCloseEvent("PipboyMenu")
    Debug.Notification("Close the Pipboy please.")
    Return 
  EndIf
  Self.RegisterForMenuOpenCloseEvent("ContainerMenu")
  Location _location = PlayerRef.GetCurrentLocation()
  If DLC04NukaWorldLocation != None && _location == DLC04NukaWorldLocation || DLC04NukaWorldLocation.IsChild(_location)
    If iMenu == 1
      iMenu = 0
    EndIf
    iWorldSpace = 2
  ElseIf DLC03FarHarborWorldLocation != None && _location == DLC03FarHarborWorldLocation || DLC03FarHarborWorldLocation.IsChild(_location)
    If iMenu == 1
      iMenu = 0
    EndIf
    iWorldSpace = 1
  Else
    iWorldSpace = 0
  EndIf
  Self.FilterMenuItems(iMenu)
  MorsAW_ContainerREF.Activate(PlayerRef as ObjectReference, False)
EndFunction

Function FilterMenuItems(Int _iMenu)
  Self.UnregisterForRemoteEvent(MorsAW_ContainerREF, "OnItemRemoved")
  Self.RemoveAllInventoryEventFilters()
  MorsAW_ContainerREF.RemoveAllItems(None, False)
  chosenItem = None
  Debug.Trace("AutoWalk: FilterMenuItems: iMenu=" + _iMenu, 1)
  iMenu = _iMenu
  Self.RegisterForRemoteEvent(MorsAW_ContainerREF, "OnItemRemoved")
  If _iMenu == 1
    Self.AddInventoryEventFilter(MorsAW_ListSettlements as Form)
    Int _i = 0
    While _i < Settlements.Length
      If !bOnlyDiscovered || Settlements[_i].marker == None || Settlements[_i].marker.IsMapMarkerVisible()
        MorsAW_ContainerREF.AddItem(Settlements[_i].miscItem, 1, False)
      EndIf
      _i += 1
    EndWhile
  ElseIf _iMenu == 2
    mors:autowalk:locdata[] _data = None
    If iWorldSpace == 0
      Self.AddInventoryEventFilter(MorsAW_ListOtherAM as Form)
      _data = OtherAM
    ElseIf iWorldSpace == 1
      Self.AddInventoryEventFilter(MorsAW_ListOtherAM_FarHarbor as Form)
      _data = OtherAM_FarHarbor
    ElseIf iWorldSpace == 2
      Self.AddInventoryEventFilter(MorsAW_ListOtherAM_NukaWorld as Form)
      _data = OtherAM_NukaWorld
    EndIf
    Int _i = 0
    Int _limit = _data.Length
    While _i < _limit
      If !bOnlyDiscovered || Settlements[_i].marker == None || _data[_i].marker.IsMapMarkerVisible()
        MorsAW_ContainerREF.AddItem(_data[_i].miscItem, 1, False)
      EndIf
      _i += 1
    EndWhile
  ElseIf _iMenu == 3
    mors:autowalk:locdata[] _data = None
    If iWorldSpace == 0
      Self.AddInventoryEventFilter(MorsAW_ListOtherNZ as Form)
      _data = OtherNZ
    ElseIf iWorldSpace == 1
      Self.AddInventoryEventFilter(MorsAW_ListOtherNZ_FarHarbor as Form)
      _data = OtherNZ_FarHarbor
    ElseIf iWorldSpace == 2
      Self.AddInventoryEventFilter(MorsAW_ListOtherNZ_NukaWorld as Form)
      _data = OtherNZ_NukaWorld
    EndIf
    Int _i = 0
    Int _limit = _data.Length
    While _i < _limit
      If !bOnlyDiscovered || Settlements[_i].marker == None || _data[_i].marker.IsMapMarkerVisible()
        MorsAW_ContainerREF.AddItem(_data[_i].miscItem, 1, False)
      EndIf
      _i += 1
    EndWhile
  ElseIf iWorldSpace == 0
    Self.AddInventoryEventFilter(MorsAW_ListCategories as Form)
    MorsAW_ContainerREF.AddItem(MorsAW_MnuSettlements, 1, False)
    MorsAW_ContainerREF.AddItem(MorsAW_MnuOtherAM, 1, False)
    MorsAW_ContainerREF.AddItem(MorsAW_MnuOtherNZ, 1, False)
    MorsAW_ContainerREF.AddItem(MorsAW_MenuCustomDestination, 1, False)
  ElseIf iWorldSpace == 1
    Self.AddInventoryEventFilter(MorsAW_ListCategories_FarHarbor as Form)
    MorsAW_ContainerREF.AddItem(MorsAW_MnuOtherAM_FarHarbor, 1, False)
    MorsAW_ContainerREF.AddItem(MorsAW_MnuOtherNZ_FarHarbor, 1, False)
    MorsAW_ContainerREF.AddItem(MorsAW_MenuCustomDestination, 1, False)
  ElseIf iWorldSpace == 2
    Self.AddInventoryEventFilter(MorsAW_ListCategories_NukaWorld as Form)
    MorsAW_ContainerREF.AddItem(MorsAW_MnuOtherAM_NukaWorld, 1, False)
    MorsAW_ContainerREF.AddItem(MorsAW_MnuOtherNZ_NukaWorld, 1, False)
    MorsAW_ContainerREF.AddItem(MorsAW_MenuCustomDestination, 1, False)
  EndIf
EndFunction

Event objectReference.OnItemRemoved(ObjectReference _sender, Form _itemForm, Int _count, ObjectReference _itemRef, ObjectReference _dstContainerRef)
  Debug.Trace("AutoWalk: OnItemRemoved(): _itemForm=" + _itemForm + ", iMenu=" + iMenu)
  If _sender == MorsAW_ContainerREF
    If _dstContainerRef == PlayerRef as ObjectReference
      PlayerRef.RemoveItem(_itemForm, _count, True, None)
      MorsAW_ContainerREF.AddItem(_itemForm, _count, False)
      Debug.Trace("AutoWalk: OnItemRemoved(): _itemForm=" + _itemForm + ", iMenu=" + iMenu)
      If iMenu == 0
        If _itemForm == MorsAW_MnuSettlements
          Self.FilterMenuItems(1)
        ElseIf _itemForm == MorsAW_MnuOtherAM || _itemForm == MorsAW_MnuOtherAM_FarHarbor || _itemForm == MorsAW_MnuOtherAM_NukaWorld
          Self.FilterMenuItems(2)
        ElseIf _itemForm == MorsAW_MnuOtherNZ || _itemForm == MorsAW_MnuOtherNZ_FarHarbor || _itemForm == MorsAW_MnuOtherNZ_NukaWorld
          Self.FilterMenuItems(3)
        ElseIf _itemForm == MorsAW_MenuCustomDestination
          chosenItem = _itemForm
        EndIf
      ElseIf _itemForm == MorsAW_MnuSettlements || _itemForm == MorsAW_MnuOtherAM || _itemForm == MorsAW_MnuOtherNZ
        Self.FilterMenuItems(0)
      ElseIf _itemForm == MorsAW_MnuOtherAM_FarHarbor || _itemForm == MorsAW_MnuOtherAM_NukaWorld
        Self.FilterMenuItems(0)
      ElseIf _itemForm == MorsAW_MnuOtherNZ_FarHarbor || _itemForm == MorsAW_MnuOtherNZ_NukaWorld
        Self.FilterMenuItems(0)
      Else
        chosenItem = _itemForm
      EndIf
    EndIf
  EndIf
EndEvent

Event OnMenuOpenCloseEvent(String _menu, Bool _opening)
  If _menu == "PipboyMenu" && !_opening
    Self.UnregisterForMenuOpenCloseEvent("PipboyMenu")
    Utility.Wait(0.200000003)
    Debug.Trace("AutoWalk: OnMenuOpenCloseEvent -> ShowMenu", 1)
    Self.ShowMenu()
  ElseIf _menu == "ContainerMenu" && !_opening
    Self.UnregisterForMenuOpenCloseEvent("ContainerMenu")
    Self.UnregisterForMenuOpenCloseEvent("PipboyMenu")
    if !chosenItem
      Debug.Notification("AutoWalk: No destination selected!")
    endif
    Self.ProcessChoice()
  EndIf
EndEvent

Function ProcessChoice()
  Self.UnregisterForRemoteEvent(MorsAW_ContainerREF, "OnItemRemoved") 
  If chosenItem
    mors:autowalk:locdata[] _items = None
    If iMenu == 0
      if chosenItem == MorsAW_MenuCustomDestination
        CurrentCustomDstMarker = GetCustomDstMarker()
        Debug.Trace("AutoWalk: ProcessChoice: marker=" + CurrentCustomDstMarker, 1)
        if CurrentCustomDstMarker
          dstName = "Custom Destination"
          StartWalkingToCustomMarker(CurrentCustomDstMarker)
        endif
      endif
      Return 
    ElseIf iMenu == 1
      _items = Settlements
    ElseIf iMenu == 2
      If iWorldSpace == 1
        _items = OtherAM_FarHarbor
      ElseIf iWorldSpace == 2
        _items = OtherAM_NukaWorld
      Else
        _items = OtherAM
      EndIf
    ElseIf iMenu == 3
      If iWorldSpace == 1
        _items = OtherNZ_FarHarbor
      ElseIf iWorldSpace == 2
        _items = OtherNZ_NukaWorld
      Else
        _items = OtherNZ
      EndIf
    EndIf
    Int _i = _items.Length
    While _i > 0
      _i -= 1
      If _items[_i].miscItem == chosenItem
        dstName = chosenItem.GetName()
        If _items[_i].dstMarker
          DstMarker.ForceRefTo(_items[_i].dstMarker)
        Else
          DstMarker.ForceRefTo(_items[_i].marker)
        EndIf
        Self.StartWalking()
        Return 
      EndIf
    EndWhile
  EndIf
EndFunction

function StartWalkingToCustomMarker(ObjectReference staticMarker)
  Debug.Trace("AutoWalk: StartWalkingToCustomMarker(): IsInCombat=" + PlayerRef.IsInCombat() + ", CombatState=" + PlayerRef.GetCombatState())
  DstMarker.ForceRefTo(staticMarker)
  Self.StartWalking() 
EndFunction

Event OnControlUp(String _ctl, Float _time)
  If _ctl == "MorsAutoWalkHotkey1"
    if bRegisteredCombatStateEvent == False
      Self.RegisterForRemoteEvent(PlayerRef, "OnCombatStateChanged")
      Debug.Trace("AutoWalk: OnControlUp: registering combat state event", 1)
      bRegisteredCombatStateEvent = True
    EndIf
    If _time < HotkeyHoldTime
      Self.CancelTimer(TimerMenuKeyDown)
      If bWalking || MorsAW_Scene.IsPlaying() 
        bStopNotification = False
        Self.GoToState("STOPPING")
      Elseif !chosenItem
        ShowMenu()
      else
          if chosenItem == MorsAW_MenuCustomDestination
            CurrentCustomDstMarker = GetCustomDstMarker()
            Debug.Trace("AutoWalk: OnControlUp: marker=" + CurrentCustomDstMarker, 1)
            if CurrentCustomDstMarker
              dstName = "Custom Destination"
              StartWalkingToCustomMarker(CurrentCustomDstMarker)
            endif
          else
            Self.StartWalking()
          endif
        endif
      EndIf
  EndIf
EndEvent

Event OnControlDown(String _ctl)
  If _ctl == "MorsAutoWalkHotkey1"
    If !DstMarker.GetReference()
      Debug.Trace("AutoWalk: OnControlDown -> ShowMenu", 1)
      Self.ShowMenu()
    Else
      Self.StartTimer(HotkeyHoldTime, TimerMenuKeyDown)
    EndIf
  Else
    If Self.GetState() == "STOPPING" || Self.GetState() == "STOPPED"
      Return 
    ElseIf _ctl == "Forward"
      If Sneak == 1
        If WalkSpeed != 2
          WalkSpeed = 2
        Else
          Return 
        EndIf
      ElseIf WalkSpeed < 3
        WalkSpeed += 1
      Else
        Return 
      EndIf
    ElseIf _ctl == "Back"
      If Sneak == 1
        If WalkSpeed != 0
          WalkSpeed = 0
        Else
          Return 
        EndIf
      ElseIf WalkSpeed > 0
        WalkSpeed -= 1
      Else
        Return 
      EndIf
    ElseIf _ctl == "Sneak"
      If Sneak == 0
        Sneak = 1
        If WalkSpeed > 1
          WalkSpeed = 2
        Else
          WalkSpeed = 0
        EndIf
      Else
        Sneak = 0
      EndIf
    Else
      Return 
    EndIf
    Self.GoToState("RESTARTING")
  EndIf
EndEvent

Function StartWalking()
  If DstMarker.GetReference()
    bStopNotification = True
    Self.RegisterForCustomEvent(Self, "autowalk_SceneStopped")
    Self.RegisterForRemoteEvent(MorsAW_Scene, "OnBegin")
    Self.RegisterForRemoteEvent(MorsAW_Scene, "OnEnd")
    Debug.Trace("AutoWalk: StartWalking(): bWalking="+bWalking+", IsPlaying=" + MorsAW_Scene.IsPlaying(), 1)
    If MorsAW_Scene.IsPlaying()
      Self.GoToState("RESTARTING")
    Else
      Self.GoToState("STARTING")
    EndIf
  EndIf
EndFunction

Function ReservePlayer()
  Traveler.ForceRefTo(PlayerRef as ObjectReference)
  If bCaptive
    Captive.ForceRefTo(PlayerRef as ObjectReference)
  EndIf
  If bInvincible
    PlayerRef.SetGhost(True)
  EndIf
  Self.RegisterForControl("Forward")
  Self.RegisterForControl("Back")
  Self.RegisterForControl("Sneak")
  If Sneak == 1 && !PlayerRef.IsSneaking()
    PlayerRef.StartSneaking()
  ElseIf Sneak == 0 && PlayerRef.IsSneaking()
    PlayerRef.StartSneaking()
  EndIf

  Game.SetPlayerAIDriven(True)
  PlayerRef.EvaluatePackage(False)
EndFunction

Function ReleasePlayer()
  Traveler.Clear()
  Captive.Clear()
  PlayerRef.SetGhost(False)
  Self.UnregisterForControl("Forward")
  Self.UnregisterForControl("Back")
  Self.UnregisterForControl("Sneak")
  Game.SetPlayerAIDriven(False)
  PlayerRef.EvaluatePackage(False)
  PlayerRef.PlayIdle(IdleStop)
EndFunction

function CheckCombatStateAndStop(bool hint)
  Debug.Trace("AutoWalk: CheckCombatStateAndStop(): bCombatWarning=" + bCombatWarning + ", bWalking=" + bWalking + ", state=" + GetState(), 1)
  If bCombatWarning && bWalking && GetState() != "STOPPING"
    float threat = GardenOfEden2.GetCurrentCombatThreatLevel(PlayerRef)
    Debug.Trace("AutoWalk: CheckCombatStateAndStop(): hint=" + hint +", bPlayerInCombat=" + bPlayerInCombat +", combatState=" + PlayerRef.GetCombatState() + ", inCombat=" + PlayerRef.IsInCombat() + ", State=" + GetState() + ", threat=" + threat, 1)
    If hint || threat > -1.0 || bPlayerInCombat
      bStopNotification = False
      Debug.MessageBox("!!! DANGER !!!\nYou entered combat.\nGet ready to defend yourself!")
    endif
    Self.GoToState("STOPPING")
  EndIf
EndFunction

Event actor.OnCombatStateChanged(Actor _actor, Actor _target, Int _state)

  Debug.Trace("AutoWalk: OnCombatStateChanged: combatState=" + _state)
  If _actor == PlayerRef
    bPlayerInCombat = (_state == 1)

    If _state == 0
      
    ElseIf _state == 1
      CheckCombatStateAndStop(True)
    ElseIf _state == 2
      
    EndIf
  EndIf
EndEvent

Event OnTimer(Int _timer)
  If _timer == TimerMenuKeyDown
    Debug.Trace("AutoWalk: OnTimer -> ShowMenu", 1)
    Self.ShowMenu()
  elseif _timer == TimerCheckArrival
    float dist = SUP_F4SE.GetDistanceBetweenPoints(CurrentCustomDstMarker.X, PlayerRef.x, CurrentCustomDstMarker.Y, PlayerRef.y, 0, 0 )
    Debug.Trace("AutoWalk: OnTimer: dist=" + dist +", bWalking=" + bWalking, 1)
    if dist <= 300.0
      CancelTimer(TimerCheckArrival)
      MorsAW_Scene.Stop()
    elseif bWalking
      if dist < 5000.0
        arrivalCheckInterval = 1.0
      else
        arrivalCheckInterval = 3.0
      endif
      StartTimer(arrivalCheckInterval, TimerCheckArrival)
    endif
  EndIf
EndEvent

Event scene.OnBegin(Scene _scene)
  ; Empty function
  Debug.Notification("AutoWalk: scene.OnBegin")
EndEvent

Event scene.OnEnd(Scene _scene)
  Debug.Notification("AutoWalk: scene.OnEnd")
EndEvent

Event Mors:AutoWalk.AutoWalk_SceneStopped(Mors:AutoWalk _sender, Var[] _args)
  ; Empty function
  Debug.Notification("AutoWalk: autowalk_SceneStopped[" + GetState() + "]")
EndEvent

;-- State -------------------------------------------
State RESTARTING

  Event Mors:AutoWalk.AutoWalk_SceneStopped(Mors:AutoWalk _sender, Var[] _args)
    Debug.trace("AutoWalk: autowalk_SceneStopped(RESTARTING)", 1)
    Self.ReleasePlayer()
    Self.GoToState("STARTING")
  EndEvent

  Event scene.OnEnd(Scene _scene)
    Debug.trace("AutoWalk: scene.OnEnd(RESTARTING)", 1)
    Self.SendCustomEvent("autowalk_SceneStopped", None)
  EndEvent

  Event OnBeginState(String _oldState)
    Debug.trace("AutoWalk: OnBeginState(RESTARTING)", 1)
    If MorsAW_Scene.IsPlaying()
      MorsAW_Scene.Stop()
    Else
      Self.ReleasePlayer()
      Self.GoToState("STARTING")
    EndIf
  EndEvent
EndState

;-- State -------------------------------------------
State STARTING
  Event Mors:AutoWalk.AutoWalk_SceneStopped(Mors:AutoWalk _sender, Var[] _args)
    Debug.trace("AutoWalk: autowalk_SceneStopped(STARTING): Calling CombatAlertAndStop()...", 1)
    ; Scene stopped immediately, and we need to clean up to avoid player locking up.
    Debug.trace("AutoWalk: autowalk_SceneStopped(STARTING): Calling CheckCombatStateAndStop(True)...", 1)
    CheckCombatStateAndStop(True)
  EndEvent

  Event scene.OnBegin(Scene _scene)
    Debug.Trace("AutoWalk: scene.OnBegin(STARTING)", 1)
    Self.ReservePlayer()
    Self.GoToState("walking")
  EndEvent
  
  Event scene.OnEnd(Scene _scene)
    Debug.trace("AutoWalk: OnEnd(STARTING)", 1)
    Self.SendCustomEvent("autowalk_SceneStopped", None)
  EndEvent

  Event OnBeginState(String _oldState)
    bWalking = True
    Debug.Trace("AutoWalk: OnBeginState(STARTING)", 1)
    If !MorsAW_Scene.IsPlaying()
      MorsAW_Scene.Start()
    Else
      Self.ReservePlayer()
      Self.GoToState("walking")
    EndIf
  EndEvent
EndState

;-- State -------------------------------------------
State STOPPED

  Event OnBeginState(String _oldState)
    bWalking = False
    If bStopNotification && bStopMessageBox
      Debug.MessageBox("You stopped walking")
    Else
      Debug.Notification("You stopped walking")
    EndIf
    Debug.trace("AutoWalk: OnBeginState(STOPPED): Player Position: " + "(" + PlayerRef.x + ", " + PlayerRef.y +", " + PlayerRef.z + ")", 1)
  EndEvent
EndState

;-- State -------------------------------------------
State STOPPING

  Event Mors:AutoWalk.AutoWalk_SceneStopped(Mors:AutoWalk _sender, Var[] _args)
    Debug.trace("AutoWalk: autowalk_SceneStopped(STOPPING)", 1)
    Self.ReleasePlayer()
    Self.GoToState("STOPPED") 
  EndEvent

  Event scene.OnEnd(Scene _scene)
    Debug.trace("AutoWalk: OnEnd(STOPPING)", 1)
    Self.SendCustomEvent("autowalk_SceneStopped", None)
  EndEvent

  Event OnBeginState(String _oldState)
    Debug.trace("AutoWalk: OnBeginState(STOPPING)", 1)
    Debug.trace("AutoWalk: OnBeginState(STOPPING): Canceling Timer...", 1)
    CancelTimer(TimerCheckArrival)
    If MorsAW_Scene.IsPlaying()
      Debug.trace("AutoWalk: OnBeginState(STOPPING): Calling MorsAW_Scene.Stop()...", 1)
      MorsAW_Scene.Stop()
    Else
      Debug.trace("AutoWalk: OnBeginState(STOPPING): Changing state to STOPPED...", 1)
      Self.ReleasePlayer()
      Self.GoToState("STOPPED")
    EndIf
  EndEvent
EndState

;-- State -------------------------------------------
State walking
    Event Mors:AutoWalk.AutoWalk_SceneStopped(Mors:AutoWalk _sender, Var[] _args)
    ; If distance to destination is far enough but scene is stopped without OnCombatStateChanged event or user pressing the hotkey, 
    ; then there must be some threat only the scene can detect.
    ; To avoid locking up the player, we need to ReleasePlayer by switching state to STOPPING.
    float dist = SUP_F4SE.GetDistanceBetweenPoints(CurrentCustomDstMarker.X, PlayerRef.x, CurrentCustomDstMarker.Y, PlayerRef.y, 0, 0 )
    bool hint = dist > 5000.0 && !bCaptive
    Debug.trace("AutoWalk: autowalk_SceneStopped(walking): Calling CheckCombatStateAndStop(" + hint + ")...", 1)
    CheckCombatStateAndStop(hint)
  EndEvent

  Event OnBeginState(string _oldState)
    Debug.trace("AutoWalk: OnBeginState(walking)", 1)
    Debug.Notification("Walking to " + dstName)
    ObjectReference obj = DstMarker.GetReference()
    Debug.Trace("AutoWalk: OnBeginState(walking): Walking to "+ dstName +"(" + obj.GetCurrentLocation() + "," + obj +")" + "(" + obj.X as Int+ ", " + Obj.Y as Int +", " + obj.Z as Int+ ")", 1)
  EndEvent
  Event scene.OnEnd(Scene _scene)
    Debug.trace("AutoWalk: scene.OnEnd(walking)", 1)
    Self.SendCustomEvent("autowalk_SceneStopped", None) 
  EndEvent
EndState

;-- Custom Marker ----------------------------------

ObjectReference Function GetCustomDstMarker()
  ; Define local aliases for DBSTATE constants (must match values in AutoWalkMarkerDB script)
  int DBSTATE_NOTREADY = 0
  int DBSTATE_BUILDING = 1
  ;int DBSTATE_READY = 2

  if MarkerDBScript.GetDBState() == DBSTATE_NOTREADY
    Debug.MessageBox("AutoWalk\n\nWalking to Custom Destination requires Map Marker Database.\nYou can start building it in MCM.")
    return None
  elseif MarkerDBScript.GetDBState() == DBSTATE_BUILDING
    Debug.MessageBox("AutoWalk\n\nMap Marker Database is currently building.\nPlease wait until it is finished.")
    return None
  endif
  RegisterForCustomEvent(MarkerDBScript, "UpdateCustomDestination")
  return MarkerDBScript.GetCustomDestinationMarkerAsync() 
EndFunction
  
Event Mors:AutoWalkMarkerDB.UpdateCustomDestination(AutoWalkMarkerDB akSender, Var[] _args)
  AutoWalkMarkerDB:CustomDestinationMarkerInfo markerInfo = _args[0] as AutoWalkMarkerDB:CustomDestinationMarkerInfo
  Debug.trace("AutoWalk: UpdateCustomDestination("+ GetState() +" State):" + "(" + markerInfo.nearestStaticMarker.x as Int+ ", " + markerInfo.nearestStaticMarker.y as Int +", " + markerInfo.playerMarkerZ as Int+ ")", 1)
  UpdateCustomDestination(markerInfo)
EndEvent
  
Function UpdateCustomDestination(AutoWalkMarkerDB:CustomDestinationMarkerInfo markerInfo)

  if bWalking
      CancelTimer(TimerCheckArrival)
      float dist = SUP_F4SE.GetDistanceBetweenPoints(CurrentCustomDstMarker.X, PlayerRef.x, CurrentCustomDstMarker.Y, PlayerRef.y, 0, 0 )
      if dist < 5000.0
        arrivalCheckInterval = 1.0
      else
        arrivalCheckInterval = 3.0
      endif
      StartTimer(arrivalCheckInterval, TimerCheckArrival)
  endif

  if markerInfo.nearestStaticMarkerDistance <= 3000
    if !bOnlyDiscovered || markerInfo.nearestStaticMarker.IsMapMarkerVisible()
      dstName = markerInfo.nearestStaticMarkerName
    else
      dstName = "Custom Destination"
    endif

    float X
    float y
    float Z
    if markerInfo.nearestStaticMarkerHasFix
      x = markerInfo.nearestStaticMarkerFixX
      y = markerInfo.nearestStaticMarkerFixY
      z = markerInfo.nearestStaticMarkerFixZ
      Debug.Trace("AutoWalk: UpdateCustomDestination: nearestStaticMarkerHasFix=" + markerInfo.nearestStaticMarkerHasFix, 1)
    else
      x = markerInfo.nearestStaticMarker.x
      y = markerInfo.nearestStaticMarker.y
      z = markerInfo.nearestStaticMarker.z
    endif

    Debug.Trace("AutoWalk: UpdateCustomDestination: PlayerMarker updated to exact static marker \"" + markerInfo.nearestStaticMarkerName + "\"" + "(" + x as Int+ ", " + y as Int +", " + z as Int+ ")[" + markerInfo.nearestStaticMarker +"]", 1)

    CurrentCustomDstMarker.SetPosition(x, y, z)
    Debug.Trace("AutoWalk: UpdateCustomDestination: Before SetPlayerMapMarker: " + PlayerRef.GetWorldSpace() + "(" + x + ", " + y +", " + z+ ")", 1)
    MarkerDBScript.SetPlayerMapMarker(PlayerRef.GetWorldSpace(), x, y, z)
    ; DstMarker.ForceRefTo(CurrentCustomDstMarker)
  else
    if !bOnlyDiscovered || markerInfo.nearestStaticMarker.IsMapMarkerVisible()
      dstName = "(Near) " + markerInfo.nearestStaticMarkerName
    else
      dstName = "Custom Destination"
    endif
    Debug.Trace("AutoWalk: UpdateCustomDestination: PlayerMarker updated to \"(Near) " + markerInfo.nearestStaticMarkerName + "\"" + "(" + markerInfo.playerMarkerX as Int+ ", " + markerInfo.playerMarkerY as Int +", " + markerInfo.playerMarkerZ as Int+ ")", 1)
    CurrentCustomDstMarker.SetPosition(markerInfo.playerMarkerX, markerInfo.playerMarkerY, markerInfo.playerMarkerZ)
    ; if markerInfo.playerMarkerCell == PlayerRef.GetParentCell()
    ;   ; 진입방향 맞추기
    ;   Debug.Trace("AutoWalk: UpdateCustomDestination: PlayerMarker angle " + "(" + CurrentCustomDstMarker.GetAngleX() as Int+ ", " + CurrentCustomDstMarker.GetAngleY() as Int +", " + CurrentCustomDstMarker.GetAngleZ() as Int+ ")", 1)
    ;   Debug.Trace("AutoWalk: UpdateCustomDestination: Player angle " + "(" + PlayerRef.GetAngleX() as Int+ ", " + PlayerRef.GetAngleY() as Int +", " + PlayerRef.GetAngleZ() as Int+ ")", 1)
    ;   Debug.Trace("AutoWalk: UpdateCustomDestination: MorsAW_PlayerMarker Parent Cell" + "[" + CurrentCustomDstMarker.GetParentCell() + "]", 1)
    ;   ; 동일 셀만 되는 것인지?
    ;   CurrentCustomDstMarker.TranslateTo(CurrentCustomDstMarker.GetPositionX(), CurrentCustomDstMarker.GetPositionY(), CurrentCustomDstMarker.GetPositionZ(), PlayerRef.GetAngleX(), PlayerRef.GetAngleY(), PlayerRef.GetAngleZ(), 40)
    ;   Debug.Trace("AutoWalk: UpdateCustomDestination: PlayerMarker angle " + "(" + CurrentCustomDstMarker.GetAngleX() as Int+ ", " + CurrentCustomDstMarker.GetAngleY() as Int +", " + CurrentCustomDstMarker.GetAngleZ() as Int+ ")", 1)
    ; endif
    
    MarkerDBScript.SetPlayerMapMarker(PlayerRef.GetWorldSpace(), markerInfo.playerMarkerX,  markerInfo.playerMarkerY, markerInfo.playerMarkerZ)
    ; DstMarker.ForceRefTo(CurrentCustomDstMarker)
  endif

  if GetState() == "walking"
    Debug.Notification("Walking to " + dstName)
    ;GoToState("RESTARTING")
  endif
EndFunction
