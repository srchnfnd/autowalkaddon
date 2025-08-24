Scriptname Mors:AutoWalk extends Quest conditional

group Aliases
	referenceAlias property DstMarker auto const mandatory
	{the DstMarker alias on this quest - used as the travel package destination}
	referenceAlias property Traveler auto const mandatory
	{the Traveler alias on this quest - used to add the protective spells and perks to traveling player}
	referenceAlias property Captive auto const mandatory
	{the Captive alias on this quest - used to add Captive faction to traveling player}
endGroup

group References
	idle property IdleStop auto const mandatory
	actor property PlayerRef auto const mandatory
	objectReference property MorsAW_ContainerREF auto const mandatory
	{container in MorsAW_StorageCell reserved for "menu items" for the "Settlements" destination category}
	scene property MorsAW_Scene auto const mandatory
	{the AutoWalk scene on this quest}
endGroup

group MenuData
	formlist property MorsAW_ListCategories auto const mandatory
	{formlist with misc items serving as menu items for category selection}
	formlist property MorsAW_ListSettlements auto const mandatory
	{formlist with misc items serving as menu items for "Settlements" category}
	formlist property MorsAW_ListOtherAM auto const mandatory
	{formlist with misc items serving as menu items for "Other A-M" category}
	formlist property MorsAW_ListOtherNZ auto const mandatory
	{formlist with misc items serving as menu items for "Other N-Z" category}

	form property MorsAW_MnuSettlements auto const mandatory
	{misc item used as the "Settlements" category selection item.}
	form property MorsAW_MnuOtherAM auto const mandatory
	{misc item used as the "Other" category selection item.}
	form property MorsAW_MnuOtherNZ auto const mandatory
	{misc item used as the "Other" category selection item.}
	Form Property MorsAW_MenuCustomDestination Auto Const
	{misc item used as the "Custom Destination" category selection item.}
endGroup

group MenuData_FarHarbor
	location property DLC03FarHarborWorldLocation auto const
	{top parent location for all Far Harbor}
	formlist property MorsAW_ListCategories_FarHarbor auto const mandatory
	{formlist with misc items serving as menu items for category selection}
	formlist property MorsAW_ListOtherAM_FarHarbor auto const mandatory
	{formlist with misc items serving as menu items for "Far Harbor A-M" category}
	formlist property MorsAW_ListOtherNZ_FarHarbor auto const mandatory
	{formlist with misc items serving as menu items for "Far Harbor N-Z" category}

	form property MorsAW_MnuOtherAM_FarHarbor auto const mandatory
	{misc item used as the "Other" category selection item.}
	form property MorsAW_MnuOtherNZ_FarHarbor auto const mandatory
	{misc item used as the "Other" category selection item.}
endGroup

group MenuData_NukaWorld
	location property DLC04NukaWorldLocation auto const
	{top parent location for all Nuka World}
	formlist property MorsAW_ListCategories_NukaWorld auto const mandatory
	{formlist with misc items serving as menu items for category selection}
	formlist property MorsAW_ListOtherAM_NukaWorld auto const mandatory
	{formlist with misc items serving as menu items for "Nuka World A-M" category}
	formlist property MorsAW_ListOtherNZ_NukaWorld auto const mandatory
	{formlist with misc items serving as menu items for "Nuka World N-Z" category}

	form property MorsAW_MnuOtherAM_NukaWorld auto const mandatory
	{misc item used as the "Other" category selection item.}
	form property MorsAW_MnuOtherNZ_NukaWorld auto const mandatory
	{misc item used as the "Other" category selection item.}
endGroup

group Destinations
	locData[] property Settlements const auto
	locData[] property OtherAM const auto
	locData[] property OtherNZ const auto
	locData[] property OtherAM_FarHarbor const auto
	locData[] property OtherNZ_FarHarbor const auto
	locData[] property OtherAM_NukaWorld const auto
	locData[] property OtherNZ_NukaWorld const auto
endGroup

; Variables used in MCM settings
bool property bCombatWarning = true auto hidden
bool property bRadResistant = true auto hidden conditional
bool property bTrapSafety = true auto hidden conditional
bool property bCaptive = false auto hidden
bool property bInvincible = true auto hidden
float property HotkeyHoldTime = 0.40 auto hidden
bool property bOnlyDiscovered = true auto hidden
bool property bStopMessageBox = false auto hidden

; Variables controlling the traveling style
int property WalkSpeed  = 0 auto conditional hidden ; 0: slow,   1: fast,   2: jogging,   3: running
int property DrawWeapon = 0 auto conditional hidden ; 0: holstered,   1: unholstered
int property Sneak      = 0 auto conditional hidden ; 0: normal,   1: sneaking

struct locData
	objectReference marker
	form miscItem
	objectReference dstMarker
endStruct

int iMenu = 0 ; Stores the last used menu - 0:Categories, 1:Settlements, 2:Other
form chosenItem = none ; selected destination (misc item), valid only right after destination has been selected, do not rely on this value after the choice has been processed
string dstName = "" ; to store the name of the last selected destination (primary use in notification when resuming walking)
int TimerMenuKeyDown = 10 ; ID of the hotkey timer
CustomEvent SceneStopped ; Custom event we sent from scene.OnEnd() handlers
int iWorldSpace = -1 ; 0: Commonwealth, 1: Far Harbor, 2: Nuka World
bool bStopNotification = true ; whether to show notification/messagebox when walking stops (we toggle this depending on the reason we are stopping - if the reason we stopped is due to user action, we set it to false)

int TimerCheckArrival = 20
bool bWalking = False ; MorsAW_Scene.IsPlaying() is not reliable
ObjectReference CurrentCustomDstMarker = None
bool bPlayerInCombat = false
bool bRegisteredCombatStateEvent = false
float arrivalCheckInterval = 3.0

Mors:AutoWalkMarkerDB Property MarkerDBScript Auto const 
Mors:AWR_ThreatDetector Property ThreatDetectorScript Auto const 

function ShowMenu()
	if Utility.IsInMenuMode() ; This shouldn't be true unless the Pipboy is open
		RegisterForMenuOpenCloseEvent("PipboyMenu") ; Register for the PipboyMenu event in case the pipboy is now open, so we can retry this proces after it is closed.
		Debug.Notification("Close the Pipboy please.")
		return
	endIf

	; Register for the ContainerMenu so we can tell when player closes it
	RegisterForMenuOpenCloseEvent("ContainerMenu")

	; Determine where we are (Commonwealth/Nuka World/Far Harbor) and use appropriate function to display the menu
	location _location = PlayerRef.GetCurrentLocation()
	if DLC04NukaWorldLocation != none && _location == DLC04NukaWorldLocation || DLC04NukaWorldLocation.IsChild(_location)
		if iMenu == 1 ; we dont use the 'Settlements' menu in Nuka World, so let's make sure iMenu value is reset to 0 to show the category choice
			iMenu = 0
		endIf
		iWorldSpace = 2
	elseIf DLC03FarHarborWorldLocation != none && _location == DLC03FarHarborWorldLocation || DLC03FarHarborWorldLocation.IsChild(_location)
		if iMenu == 1 ; we dont use the 'Settlements' menu in Far Harbor, so let's make sure iMenu value is reset to 0 to show the category choice
			iMenu = 0
		endIf
		iWorldSpace = 1
	else
		iWorldSpace = 0
	endIf

	; Add/Remove menu items depending on the availability of their map markers
	FilterMenuItems(iMenu)

	MorsAW_ContainerREF.Activate(PlayerRef)
endFunction

function FilterMenuItems(int _iMenu)
	
	UnregisterForRemoteEvent(MorsAW_ContainerREF, "OnItemRemoved")
	RemoveAllInventoryEventFilters()
	MorsAW_ContainerREF.RemoveAllItems()
	; 2019-10-30: moved the following three lines from the end up to here, because sometimes ppl "select" something before all
	;   options were added, before these lines were processed, before we started listening for OnItemRemoved,
	;   which resulted in roken functionality and the "choice" items staying in peoples inventory.
	chosenItem = none
  iMenu = _iMenu
	RegisterForRemoteEvent(MorsAW_ContainerREF, "OnItemRemoved")

	; Settlements
	if _iMenu == 1
		AddInventoryEventFilter(MorsAW_ListSettlements)
		int _i = 0
		while _i < Settlements.Length
			if !bOnlyDiscovered || Settlements[_i].marker == none || Settlements[_i].marker.IsMapMarkerVisible()
				MorsAW_ContainerREF.AddItem(Settlements[_i].miscItem, 1)
			endIf
			_i = _i + 1
		endWhile

	; Other A-M
	elseIf _iMenu == 2
		locData[] _data
		if iWorldSpace == 0 ; Commonwealth
			AddInventoryEventFilter(MorsAW_ListOtherAM)
			_data = OtherAM
		elseIf iWorldSpace == 1 ; Far Harbor
			AddInventoryEventFilter(MorsAW_ListOtherAM_FarHarbor)
			_data = OtherAM_FarHarbor
		elseIf iWorldSpace == 2 ; Nuka World
			AddInventoryEventFilter(MorsAW_ListOtherAM_NukaWorld)
			_data = OtherAM_NukaWorld
		endIf
		int _i = 0
		int _limit = _data.length
		while _i < _limit
			if !bOnlyDiscovered || Settlements[_i].marker == none || _data[_i].marker.IsMapMarkerVisible()
				MorsAW_ContainerREF.AddItem(_data[_i].miscItem, 1)
			endIf
			_i = _i + 1
		endWhile

	; Other N-Z
	elseIf _iMenu == 3
		locData[] _data
		if iWorldSpace == 0 ; Commonwealth
			AddInventoryEventFilter(MorsAW_ListOtherNZ)
			_data = OtherNZ
		elseIf iWorldSpace == 1 ; Far Harbor
			AddInventoryEventFilter(MorsAW_ListOtherNZ_FarHarbor)
			_data = OtherNZ_FarHarbor
		elseIf iWorldSpace == 2 ; Nuka World
			AddInventoryEventFilter(MorsAW_ListOtherNZ_NukaWorld)
			_data = OtherNZ_NukaWorld
		endIf
		int _i = 0
		int _limit = _data.length
		while _i < _limit
			if !bOnlyDiscovered || Settlements[_i].marker == none || _data[_i].marker.IsMapMarkerVisible()
				MorsAW_ContainerREF.AddItem(_data[_i].miscItem, 1)
			endIf
			_i = _i + 1
		endWhile

	; Categories (using the categories also as a fallback, just in case)
	else
		if iWorldSpace == 0 ; Commonwealth
			AddInventoryEventFilter(MorsAW_ListCategories)
			MorsAW_ContainerREF.AddItem(MorsAW_MnuSettlements, 1)
			MorsAW_ContainerREF.AddItem(MorsAW_MnuOtherAM, 1)
			MorsAW_ContainerREF.AddItem(MorsAW_MnuOtherNZ, 1)
			MorsAW_ContainerREF.AddItem(MorsAW_MenuCustomDestination, 1, False)
		elseIf iWorldSpace == 1 ; Far Harbor
			AddInventoryEventFilter(MorsAW_ListCategories_FarHarbor)
			MorsAW_ContainerREF.AddItem(MorsAW_MnuOtherAM_FarHarbor, 1)
			MorsAW_ContainerREF.AddItem(MorsAW_MnuOtherNZ_FarHarbor, 1)
			MorsAW_ContainerREF.AddItem(MorsAW_MenuCustomDestination, 1, False)
		elseIf iWorldSpace == 2 ; Nuka World
			AddInventoryEventFilter(MorsAW_ListCategories_NukaWorld)
			MorsAW_ContainerREF.AddItem(MorsAW_MnuOtherAM_NukaWorld, 1)
			MorsAW_ContainerREF.AddItem(MorsAW_MnuOtherNZ_NukaWorld, 1)
			MorsAW_ContainerREF.AddItem(MorsAW_MenuCustomDestination, 1, False)
		endIf
	endIf

	; 2019-10-30: moved the following to the beginning, because sometimes ppl "select" something before all options were added,
	;   before these lines were processed, before we started listening for OnItemRemoved, which resulted in roken functionality
	;   and the "choice" items staying in peoples inventory.
	;chosenItem = none
	;iMenu = _iMenu
	;RegisterForRemoteEvent(MorsAW_ContainerREF, "OnItemRemoved")
endFunction

event objectReference.OnItemRemoved(objectReference _sender, form _itemForm, int _count, objectReference _itemRef, objectReference _dstContainerRef)
	if _sender == MorsAW_ContainerREF ; TODO: this might be really needed later if we reg for more containers at once? consider removing for now.
		if _dstContainerRef == PlayerRef
			;PlayerRef.RemoveItem(_itemForm, _count, true, MorsAW_ContainerREF)
			PlayerRef.RemoveItem(_itemForm, _count, true)
			MorsAW_ContainerREF.AddItem(_itemForm, _count)
			
			if iMenu == 0 ; Category selection
				if _itemForm == MorsAW_MnuSettlements
					FilterMenuItems(1)
				elseIf _itemForm == MorsAW_MnuOtherAM || _itemForm == MorsAW_MnuOtherAM_FarHarbor || _itemForm == MorsAW_MnuOtherAM_NukaWorld
					FilterMenuItems(2)
				elseIf _itemForm == MorsAW_MnuOtherNZ || _itemForm == MorsAW_MnuOtherNZ_FarHarbor || _itemForm == MorsAW_MnuOtherNZ_NukaWorld
					FilterMenuItems(3)
				elseIf _itemForm == MorsAW_MenuCustomDestination
					chosenItem = _itemForm
				endIf
			else
				if _itemForm == MorsAW_MnuSettlements || _itemForm == MorsAW_MnuOtherAM || _itemForm == MorsAW_MnuOtherNZ
					FilterMenuItems(0)
				elseIf _itemForm == MorsAW_MnuOtherAM_FarHarbor || _itemForm == MorsAW_MnuOtherAM_NukaWorld
					FilterMenuItems(0)
				elseIf _itemForm == MorsAW_MnuOtherNZ_FarHarbor || _itemForm == MorsAW_MnuOtherNZ_NukaWorld
					FilterMenuItems(0)
				else
					; TODO: Can we close the inventory by script and call ProcessChoice() from here?
					chosenItem = _itemForm
				endIf
			endIf
		endIf
	endIf
endEvent

event OnMenuOpenCloseEvent(string _menu, bool _opening)
	;
	if _menu == "PipboyMenu" && !_opening					; Pipboy is closing - we must have been waiting for that before trying to ShowMenu(), so lets do that.
		UnregisterForMenuOpenCloseEvent("PipboyMenu")
		Utility.Wait(0.2)									; Seems like we must wait for the menu to completely close, otherwise the container activation doesn't seem to work.
		ShowMenu()
	elseIf _menu == "ContainerMenu" && !_opening			; Container menu is closing - unregister from ContainerMenu event and handle the choice (TODO)
		UnregisterForMenuOpenCloseEvent("ContainerMenu")
		UnregisterForMenuOpenCloseEvent("PipboyMenu")		; just in case things get messed up, unreg from Pipboy menu too
		if !chosenItem
			Debug.Notification("AutoWalk: No destination selected!")
		endif
		ProcessChoice()
	endIf
endEvent

function ProcessChoice()
	UnregisterForRemoteEvent(MorsAW_ContainerREF, "OnItemRemoved")
	if chosenItem
		locData[] _items
		if iMenu == 0 ; Categories
			
			if chosenItem == MorsAW_MenuCustomDestination
				CurrentCustomDstMarker = GetCustomDstMarker()
				Debug.Trace("AutoWalk: ProcessChoice: marker=" + CurrentCustomDstMarker, 1)
				if CurrentCustomDstMarker
					dstName = "Custom Destination"
					StartWalkingToCustomMarker(CurrentCustomDstMarker)
				endif
			endif
			return
		elseIf iMenu == 1 ; Settlements
			_items = Settlements
		elseIf iMenu == 2 ; Other A-M
			if iWorldSpace == 1 ; Far Harbor
				_items = OtherAM_FarHarbor
			elseIf iWorldSpace == 2 ; Nuka World
        _items = OtherAM_NukaWorld
			else
				_items = OtherAM
			endIf
		elseIf iMenu == 3 ; Other N-Z
			if iWorldSpace == 1 ; Far Harbor
				_items = OtherNZ_FarHarbor
			elseIf iWorldSpace == 2 ; Nuka World
				_items = OtherNZ_NukaWorld
			else
        _items = OtherNZ
			endIf
		endIf
		int _i = _items.Length
		while _i > 0
			_i = _i - 1
			if _items[_i].miscItem == chosenItem
				dstName = chosenItem.GetName()
				; force the map marker (or the assigned fallback marker) into an alias, serving as destination for the travel package
				if _items[_i].dstMarker
          DstMarker.ForceRefTo(_items[_i].dstMarker)
				else
					DstMarker.ForceRefTo(_items[_i].marker)
				endIf
				StartWalking()
				return
			endIf
		endWhile
	endIf
endFunction

function StartWalkingToCustomMarker(ObjectReference staticMarker)
	Debug.Trace("AutoWalk: StartWalkingToCustomMarker(): IsInCombat=" + PlayerRef.IsInCombat() + ", CombatState=" + PlayerRef.GetCombatState())
	DstMarker.ForceRefTo(staticMarker)
	StartWalking() 
EndFunction

event OnControlUp(string _ctl, float _time)
	if _ctl == "MorsAutoWalkHotkey1"
		if bRegisteredCombatStateEvent == False
			Self.RegisterForRemoteEvent(PlayerRef, "OnCombatStateChanged")
			Debug.Trace("AutoWalk: OnControlUp: registering combat state event", 1)
			bRegisteredCombatStateEvent = True
		endIf
		if _time < HotkeyHoldTime
			CancelTimer(TimerMenuKeyDown)
			if bWalking || MorsAW_Scene.IsPlaying()
				
				bStopNotification = false
				GoToState("STOPPING")
				;StopWalking()
			elseif !chosenItem
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
					StartWalking()
				endIf
			endif
		endIf
	endIf
endEvent

event OnControlDown(string _ctl)
	if _ctl == "MorsAutoWalkHotkey1"
		if !DstMarker.GetReference()
			
			ShowMenu()
		else
			
			StartTimer(HotkeyHoldTime, TimerMenuKeyDown)
		endIf
	else
		if GetState() == "STOPPING" || GetState() == "STOPPED"
			return
		elseIf _ctl == "Forward"  ; ----- 0: slow,   1: fast,   2: jogging,   3: running
			if Sneak == 1
				if WalkSpeed != 2
					WalkSpeed = 2
				else
					return
				endIf
			else
				if WalkSpeed < 3
					WalkSpeed = WalkSpeed + 1
				else
					return
				endIf
			endIf
		elseIf _ctl == "Back"     ; ----- 0: slow,   1: fast,   2: jogging,   3: running
			if Sneak == 1
				if WalkSpeed != 0
					WalkSpeed = 0
				else
					return
				endIf
			else
				if WalkSpeed > 0
					WalkSpeed = WalkSpeed - 1
				else
					return
				endIf
			endIf
		elseIf _ctl == "Sneak"
			if Sneak == 0
				Sneak = 1
				if WalkSpeed > 1
					WalkSpeed = 2
				else
					WalkSpeed = 0
				endIf
			else
				Sneak = 0
			endIf
		else
			return
		endIf
		GotoState("RESTARTING")
	endIf
endEvent

function OnCombatClearWaitResult(int resultCode)
    if resultCode == ThreatDetectorScript.AWR_WAIT_OK()
        ; resume autowalk
		if DstMarker.GetReference()
			Debug.Notification("Walking to "+ dstName)
			bStopNotification = true
			RegisterForCustomEvent(Self, "SceneStopped")
			RegisterForRemoteEvent(MorsAW_Scene, "OnBegin")
			RegisterForRemoteEvent(MorsAW_Scene, "OnEnd")
			if MorsAW_Scene.IsPlaying()
				GoToState("RESTARTING")
			else
				GoToState("STARTING")
			endIf
		endif
		return
    elseif resultCode == ThreatDetectorScript.AWR_WAIT_TIMEOUT()
    else ; AWR_WAIT_INTERRUPTED
    endif
	Debug.MessageBox("AutoWalk\n\nPlayer is in combat!\nPlease clear all threats or move to a\nsafe location before start.")
	Debug.Trace("AutoWalk: StartWalking(): Combat State is not clear or resumed, not starting walking.", 1)
endfunction

; Begin AutoWalk after checking combat state and clearing possible lingering combat state.
bool function StartWalking()
	if DstMarker.GetReference() == none
		Debug.Notification("AutoWalk: No destination selected! Cannot start walking.")
		return false
	endif
	if(ThreatDetectorScript.BeginCombatClearWait(self as Quest, "OnCombatClearWaitResult")) == false
		; if already waiting stop existing wait
		Debug.Notification("AutoWalk: Previous walking attempt cancelled.")
		ThreatDetectorScript.CancelCombatClearWait()
		return false
	endif

	return true
endFunction

function ReservePlayer()
	Traveler.ForceRefTo(PlayerRef)
	if bCaptive
		Captive.ForceRefTo(PlayerRef)
	endIf
	if bInvincible
		PlayerRef.SetGhost(true)
	endIf
	RegisterForControl("Forward")
	RegisterForControl("Back")
	RegisterForControl("Sneak")
	if Sneak == 1 && !PlayerRef.IsSneaking()
		PlayerRef.StartSneaking()
	elseIf Sneak == 0 && PlayerRef.IsSneaking()
		PlayerRef.StartSneaking()
	endIf
	Game.SetPlayerAIDriven(true)
	PlayerRef.EvaluatePackage()
endFunction

function ReleasePlayer()
	Traveler.Clear()
	Captive.Clear()
	PlayerRef.SetGhost(false)
	UnregisterForControl("Forward")
	UnregisterForControl("Back")
	UnregisterForControl("Sneak")
	
	Game.SetPlayerAIDriven(false)
	PlayerRef.EvaluatePackage()
	PlayerRef.PlayIdle(IdleStop)
endFunction

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

event actor.OnCombatStateChanged(actor _actor, actor _target, int _state)
	
	if _actor == PlayerRef
		bPlayerInCombat = (_state == 1)
		if _state == 0
			
		elseIf _state == 1
			
			if bCombatWarning
				Debug.trace("AutoWalk: OnCombatStateChanged: state=" + _state, 1)
				CheckCombatStateAndStop(True)
			endif
		elseIf _state == 2
		
		endIf
	endIf
endEvent

event OnBeginState(string _oldState)
	
endEvent
event OnEndState(string _newState)
	
endEvent
event scene.OnBegin(scene _scene)
	Debug.Notification("AutoWalk: scene.OnBegin")
endEvent
event scene.OnEnd(scene _scene)
	Debug.Notification("AutoWalk: scene.OnEnd")
	
endEvent
event Mors:AutoWalk.SceneStopped(Mors:AutoWalk _sender, Var[] _args)
	Debug.Notification("AutoWalk: SceneStopped[" + GetState() + "]")
endEvent
event OnTimer(int _timer)
	
	if _timer == TimerMenuKeyDown
		ShowMenu()
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
	endIf
endEvent


;/ ----- STARTING ------------------------------------------------------------------------------------------------ STARTING ----- /;
state STARTING
	event OnBeginState(string _oldState)
		bWalking = True
		Debug.Trace("AutoWalk: OnBeginState(STARTING)", 1)
			
		if !MorsAW_Scene.IsPlaying()
			
			MorsAW_Scene.Start()
		else
			
			ReservePlayer()
			GoToState("WALKING")
		endIf
	endEvent
	event scene.OnBegin(scene _scene)
		Debug.Trace("AutoWalk: scene.OnBegin(STARTING)", 1)
		ReservePlayer()
		GoToState("WALKING")
	endEvent
	event scene.OnEnd(Scene _scene)
		Debug.trace("AutoWalk: OnEnd(STARTING)", 1)
		SendCustomEvent("SceneStopped", None)
	endEvent
	event Mors:AutoWalk.SceneStopped(Mors:AutoWalk _sender, Var[] _args)
		Debug.trace("AutoWalk: SceneStopped(STARTING): Calling CombatAlertAndStop()...", 1)
		; Scene stopped immediately, and we need to clean up to avoid player locking up.
		Debug.trace("AutoWalk: SceneStopped(STARTING): Calling CheckCombatStateAndStop(True)...", 1)
		CheckCombatStateAndStop(True)
	endEvent
endState

;/ ----- RESTARTING -------------------------------------------------------------------------------------------- RESTARTING ----- /;
state RESTARTING
  event OnBeginState(string _oldState)
		
		Debug.trace("AutoWalk: OnBeginState(RESTARTING)", 1)
		if MorsAW_Scene.IsPlaying()
			
			MorsAW_Scene.Stop()
		else
			
			ReleasePlayer()
			GoToState("STARTING")
		endIf
	endEvent
	event scene.OnEnd(scene _scene)
		Debug.trace("AutoWalk: scene.OnEnd(RESTARTING)", 1)
		SendCustomEvent("SceneStopped")
	endEvent
	; NOTE: We must rely on custom event SceneStopped send from within the OnEnd handler to introduce additional delay without using a timer. The delay is needed for the Scene to have time to stop completely before we use Scene.IsPlaying() which would otherwise still return True!
	event Mors:AutoWalk.SceneStopped(Mors:AutoWalk _sender, Var[] _args)
		Debug.trace("AutoWalk: SceneStopped(RESTARTING)", 1)
		ReleasePlayer()
		GoToState("STARTING")
	endEvent
endState

;/ ----- WALKING -------------------------------------------------------------------------------------------------- WALKING ----- /;
state WALKING
	event scene.OnEnd(scene _scene)
		
		Debug.trace("AutoWalk: scene.OnEnd(walking)", 1)
		GoToState("STOPPING")
		SendCustomEvent("SceneStopped")
	endEvent
	Event Mors:AutoWalk.SceneStopped(Mors:AutoWalk _sender, Var[] _args)
		; If distance to destination is far enough but scene is stopped without OnCombatStateChanged event or user pressing the hotkey, 
		; then there must be some threat only the scene can detect.
		; To avoid locking up the player, we need to ReleasePlayer by switching state to STOPPING.
		float dist = SUP_F4SE.GetDistanceBetweenPoints(CurrentCustomDstMarker.X, PlayerRef.x, CurrentCustomDstMarker.Y, PlayerRef.y, 0, 0 )
		bool hint = dist > 5000.0 && !bCaptive
		Debug.trace("AutoWalk: SceneStopped(walking): Calling CheckCombatStateAndStop(" + hint + ")...", 1)
		CheckCombatStateAndStop(hint)
	EndEvent

	Event OnBeginState(string _oldState)
		Debug.trace("AutoWalk: OnBeginState(walking)", 1)
		Debug.Notification("Walking to " + dstName)
		ObjectReference obj = DstMarker.GetReference()
		Debug.Trace("AutoWalk: OnBeginState(walking): Walking to "+ dstName +"(" + obj.GetCurrentLocation() + "," + obj +")" + "(" + obj.X as Int+ ", " + Obj.Y as Int +", " + obj.Z as Int+ ")", 1)
	EndEvent

endState

;/ ----- STOPPING ------------------------------------------------------------------------------------------------ STOPPING ----- /;
state STOPPING
	event OnBeginState(string _oldState)
	Debug.trace("AutoWalk: OnBeginState(STOPPING)", 1)
	Debug.trace("AutoWalk: OnBeginState(STOPPING): Canceling Timer...", 1)
	CancelTimer(TimerCheckArrival)
	ThreatDetectorScript.CancelCombatClearWait()

	if MorsAW_Scene.IsPlaying()
		Debug.trace("AutoWalk: OnBeginState(STOPPING): Calling MorsAW_Scene.Stop()...", 1)
			MorsAW_Scene.Stop()
		else
			
		Debug.trace("AutoWalk: OnBeginState(STOPPING): Changing state to STOPPED...", 1)
			ReleasePlayer()
			GoToState("STOPPED")
		endIf
	endEvent
	event scene.OnEnd(scene _scene)
		
		Debug.trace("AutoWalk: OnEnd(STOPPING)", 1)
		SendCustomEvent("SceneStopped")
	endEvent
	; NOTE: We must rely on custom event SceneStopped send from within the OnEnd handler to introduce additional delay without using a timer. The delay is needed for the Scene to have time to stop completely before we use Scene.IsPlaying() which would otherwise still return True!
	event Mors:AutoWalk.SceneStopped(Mors:AutoWalk _sender, Var[] _args)
		Debug.trace("AutoWalk: SceneStopped(STOPPING)", 1)
		ReleasePlayer()
		GoToState("STOPPED")
	endEvent
endState

;/ ----- STOPPED -------------------------------------------------------------------------------------------------- STOPPED ----- /;
state STOPPED
	event OnBeginState(string _oldState)
		bWalking = False
		if bStopNotification && bStopMessageBox
			Debug.MessageBox("You stopped walking")
		else
			Debug.Notification("You stopped walking")
		endIf
		Debug.trace("AutoWalk: OnBeginState(STOPPED): Player Position: " + "(" + PlayerRef.x + ", " + PlayerRef.y +", " + PlayerRef.z + ")", 1)
	endEvent
endState

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
