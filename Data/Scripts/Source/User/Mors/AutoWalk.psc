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

Form Property RotateGuideForm Auto Const
Bool Property IsRotating = false Auto Hidden
; Delay times before forcefully terminating the rotation.
float FailSafeRotateTimeoutSecs1 = 3.0 const
float FailSafeRotateTimeoutSecs2 = 5.0 const
; fail safe timer id
int TimerIdFailSafeRotate = 30 const
; fail safe rotate method: 1: SetPlayerAIDriven + EvaluatePackage(), 2: MoveTo
int FailSafeRotateMethod = 2
; an object reference used to guide the player rotation. It is placed a short distance from the player in the direction of the destination, and the player is rotated toward it instead of the real destination.
ObjectReference RotateGuide = None
; distance from the player to place the guide. If too close, the player may not turn far enough to face the real destination.
; 적당값 60~70. 100이면 FailSafeRotate()에서 MoveTo를 사용하는 단계까지 간다.
float RotateGuideDistance = 60.0 const

struct locData
	objectReference marker
	form miscItem
	objectReference dstMarker
endStruct

;int iMenu = 0 ; Stores the last used menu - 0:Categories, 1:Settlements, 2:Other
;form chosenItem = none ; selected destination (misc item), valid only right after destination has been selected, do not rely on this value after the choice has been processed
string dstName = "" ; to store the name of the last selected destination (primary use in notification when resuming walking)
int TimerMenuKeyDown = 10 ; ID of the hotkey timer
CustomEvent SceneStopped ; Custom event we sent from scene.OnEnd() handlers
int iWorldSpace = -1 ; 0: Commonwealth, 1: Far Harbor, 2: Nuka World
bool bStopNotification = true ; whether to show notification/messagebox when walking stops (we toggle this depending on the reason we are stopping - if the reason we stopped is due to user action, we set it to false)

int TimerCheckArrival = 20
bool bWalking = False ; MorsAW_Scene.IsPlaying() is not reliable
ObjectReference CurrentCustomDstMarker = None
bool bPlayerInCombat = false
float arrivalCheckInterval = 3.0

bool bContinueWalkingToCustomMarker = false

Mors:AutoWalkMarkerDB Property MarkerDBScript Auto const 
Mors:AWR_ThreatDetector Property ThreatDetectorScript Auto const 
Mors:AWR_DstMenu property AWR_DstMenuScript const auto

Event OnQuestInit()
  RegisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")
  RegisterForRemoteEvent(PlayerRef, "OnCombatStateChanged")
EndEvent

Event OnInit()
  SUP_F4SE.RegisterForSUPEvent("OnPlayerMapMarkerStateChange", self as Form, "Mors:AutoWalk", "OnPlayerMapMarkerStateChange", true, false)
EndEvent

Event Actor.OnPlayerLoadGame(Actor sender)
  SUP_F4SE.RegisterForSUPEvent("OnPlayerMapMarkerStateChange", self as Form, "Mors:AutoWalk", "OnPlayerMapMarkerStateChange", true, false)
EndEvent

function ShowMenu() 

	; If we are waiting for combat clear, cancel it
	ThreatDetectorScript.CancelCombatClearWait()

	; Determine where we are (Commonwealth/Nuka World/Far Harbor) and use appropriate function to display the menu
	location _location = PlayerRef.GetCurrentLocation()
	if DLC04NukaWorldLocation != none && _location == DLC04NukaWorldLocation || DLC04NukaWorldLocation.IsChild(_location)

		iWorldSpace = AWR_DstMenuScript.AWR_WORLDSPACE_NUKAWORLD()
	elseIf DLC03FarHarborWorldLocation != none && _location == DLC03FarHarborWorldLocation || DLC03FarHarborWorldLocation.IsChild(_location)

		iWorldSpace = AWR_DstMenuScript.AWR_WORLDSPACE_FARHARBOR()
	else
		iWorldSpace = AWR_DstMenuScript.AWR_WORLDSPACE_COMMONWEALTH()
	endIf

	ScriptObject receiver = self as ScriptObject
	Var[] args = new Var[4]
  	args[0] = receiver as Var
  	args[1] = "OnDestinationSelect" as Var
  	args[2] = iWorldSpace as Var
  	args[3] = bOnlyDiscovered as Var

	AWR_DstMenuScript.CallFunctionNoWait("Open", args)

	; Debug.Trace("============= Commonwealth Settlements ============")
	; dumpLocData(Settlements)
	; Debug.Trace("============= Commonwealth Other ============")
	; dumpLocData(OtherAM)
	; dumpLocData(OtherNZ)
	; Debug.Trace("============= Far Harbor Other ============")
	; dumpLocData(OtherAM_FarHarbor)
	; dumpLocData(OtherNZ_FarHarbor)
	; Debug.Trace("============= Nuka World Other ============")
	; dumpLocData(OtherAM_NukaWorld)
	; dumpLocData(OtherNZ_NukaWorld)
endFunction

function dumpLocData(locData[] debugData)
	;locData[] debugData = SUP_F4SE.MergeArrays(OtherAM_NukaWorld as var[], OtherNZ_NukaWorld as var[]) as locData[] <= broken
	;extract data for data source generation of Entries_Commonwealth, Entries_FarHarbor, Entries_NukaWorld
	int i = 0
	while debugData.length > i
		string name = debugData[i].miscItem.GetName()
		String markerFormID = ""
		String dstMarkerFormID = ""
		if debugData[i].dstMarker
			dstMarkerFormID = GardenOfEden.IntToHex(debugData[i].dstMarker.GetFormId(), false)
		else
			dstMarkerFormID = ""
		endIf
		if debugData[i].marker
			markerFormID = GardenOfEden.IntToHex(debugData[i].marker.GetFormId(), false)
		else
			markerFormID = ""
		endIf
		Debug.Trace( markerFormID + "," + dstMarkerFormID + "," + name, 1)
		i = i + 1
	endWhile
	return
endfunction

function OnDestinationSelect(int callback_type, var [] args)
	Debug.Trace("AutoWalk: OnDestinationSelect(): callback_type=" + callback_type + ", args=" + args, 1)
	AWR_DstMenuScript.CallFunctionNoWait("Close", None)
	if callback_type == AWR_DstMenuScript.AWR_CALLBACK_TYPE_DSTENTRY()
		AWR_DstMenu:DstEntry entry = args[0] as AWR_DstMenu:DstEntry
		if entry == None
			; user clicked custom destination
			CurrentCustomDstMarker = GetCustomDstMarker()
			Debug.Trace("AutoWalk: OnDestinationSelect: custom marker=" + CurrentCustomDstMarker, 1)
			if CurrentCustomDstMarker
				dstName = "Custom Destination"
				StartWalkingToCustomMarker(CurrentCustomDstMarker)
				bContinueWalkingToCustomMarker = true
			endif
		else
			; arg is DstEntry
			bContinueWalkingToCustomMarker = false
			Debug.Trace("AutoWalk: OnDestinationSelect: entry=" + entry, 1)
			dstName = entry.name
			if entry.dstMarker
				DstMarker.ForceRefTo(entry.dstMarker)
			else
				Debug.Trace("AutoWalk: OnDestinationSelect: searching for marker fix for " + entry.marker.GetFormId() )
				float [] fix = MarkerDBScript.GetMarkerFix(entry.marker)
				if fix && fix.Length > 2
      				entry.marker.SetPosition(fix[0], fix[1], fix[2])
      				Debug.Trace("AutoWalk: OnDestinationSelect: marker fix found: (" + fix[0] +"," + fix[0] + "," + fix[0] + ")", 1)
    			endif
				DstMarker.ForceRefTo(entry.marker)
			endIf
			StartWalking()
		endif
	elseIf callback_type == AWR_DstMenuScript.AWR_CALLBACK_TYPE_CANCEL()
		Debug.Trace("AutoWalk: OnDestinationSelect: user cancelled or error occurred", 1)
	else
		Debug.Trace("AutoWalk: OnDestinationSelect: unknown callback_type: " + callback_type, 1)
	endIf
endFunction

function StartWalkingToCustomMarker(ObjectReference staticMarker)
	Debug.Trace("AutoWalk: StartWalkingToCustomMarker(): IsInCombat=" + PlayerRef.IsInCombat() + ", CombatState=" + PlayerRef.GetCombatState())
	DstMarker.ForceRefTo(staticMarker)
	StartWalking() 
EndFunction

Function OnPlayerMapMarkerStateChange(bool wasAdded, WorldSpace currentWorldSpace, float posX, float posY, float posZ)
	Debug.Trace("AutoWalk: OnPlayerMapMarkerStateChange()")
	; last destination was a menu-selected. switch to custom marker walking.
	if bContinueWalkingToCustomMarker == false
		bContinueWalkingToCustomMarker = true
		Debug.Trace("AutoWalk: OnPlayerMapMarkerStateChange(): selection type changed to custom marker")
	endif
EndFunction

event OnControlUp(string _ctl, float _time)
	Debug.Trace("AutoWalk: OnControlUp(): key=" + _ctl + ", time=" + _time, 1)
	if _ctl == "MorsAutoWalkHotkey1"
		if _time < HotkeyHoldTime
			CancelTimer(TimerMenuKeyDown)
			if bWalking || MorsAW_Scene.IsPlaying()
				
				bStopNotification = false
				GoToState("STOPPING")
				;StopWalking()
			else
				if bContinueWalkingToCustomMarker
					; If a message appears inside GetCustomDstMarker() indicating that the database needs to be rebuilt
					; in this situation (when the user briefly presses to attempt to continue walking to the existing destination),
					; it may confuse the user. Instead, silently revert to normal walking mode.
					if MarkerDBScript.GetDBState() != MarkerDBScript.AWR_DB_STATE_READY()
						Debug.Trace("AutoWalk: OnControlUp: DB not ready. falling back to normal walking.", 1)
						bContinueWalkingToCustomMarker = false
						StartWalking()
						return
					endif
					CurrentCustomDstMarker = GetCustomDstMarker()
					Debug.Trace("AutoWalk: OnControlUp: marker=" + CurrentCustomDstMarker, 1)
					if CurrentCustomDstMarker
						dstName = "Custom Destination"
						StartWalkingToCustomMarker(CurrentCustomDstMarker)
					else
						bContinueWalkingToCustomMarker = false
						StartWalking()
					endif
				else
					StartWalking()
				endIf
			endif
		endIf
	endIf
endEvent

event OnControlDown(string _ctl)
	Debug.Trace("AutoWalk: OnControlDown(): key=" + _ctl, 1)
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

function DebugRotate(ObjectReference obj)
	;ObjectReference obj = DstMarker.GetReference()
	Debug.Trace("AutoWalk: DebugRotate(): RotateGuide pos=(" + RotateGuide.GetPositionX() + "," + RotateGuide.GetPositionY() + "," + RotateGuide.GetPositionZ() + ")", 1)
	while IsRotating 
		float headingAngle = PlayerRef.GetHeadingAngle(obj)
		Debug.Trace("AutoWalk: DebugRotate(): Monitoring PathToReference(): HeadingAngle=" + headingAngle + ", Player pos=(" + PlayerRef.GetPositionX() + "," + PlayerRef.GetPositionY() + ")", 1)
		Utility.Wait(0.2)
	endWhile
endFunction

function FailSafeRotate()
	; PathToReference() never returns until the actor reaches its target (or pathing
	; permanently fails), so this function is scheduled via StartTimer() to force it to
	; return.
	ObjectReference obj = DstMarker.GetReference()
	float headingAngle = PlayerRef.GetHeadingAngle(obj)

	if(FailSafeRotateMethod == 1)
		Debug.Trace("AutoWalk: FailSafeRotate(): Forcing termination(method=" + FailSafeRotateMethod + "). HeadingAngle=" + headingAngle + ", pos=(" + PlayerRef.GetPositionX() + "," + PlayerRef.GetPositionY() + ")", 1)
		Game.SetPlayerAIDriven(false)
		PlayerRef.EvaluatePackage(true)
		Game.SetPlayerAIDriven(true)
		PlayerRef.EvaluatePackage()
		FailSafeRotateMethod = 2
		StartTimer(FailSafeRotateTimeoutSecs2, TimerIdFailSafeRotate)
	elseif(FailSafeRotateMethod == 2)
		if IsRotating
			Debug.Trace("AutoWalk: FailSafeRotate(): Forcing termination(method=" + FailSafeRotateMethod + "). HeadingAngle=" + headingAngle + ", pos=(" + PlayerRef.GetPositionX() + "," + PlayerRef.GetPositionY() + ")", 1)
			Debug.Trace("AutoWalk: FailSafeRotate(): RotateGuide pos=(" + RotateGuide.GetPositionX() + "," + RotateGuide.GetPositionY() + "," + RotateGuide.GetPositionZ() + ")", 1)
			PlayerRef.MoveTo(RotateGuide)
			Debug.Trace("AutoWalk: FailSafeRotate(): PlayerRef pos=(" + PlayerRef.GetPositionX() + "," + PlayerRef.GetPositionY() + "," + PlayerRef.GetPositionZ() + ")", 1)
			PlayerRef.EvaluatePackage()
		else
			;Debug.Trace("AutoWalk: FailSafeRotate(): Not rotating, skipping MoveTo() call. HeadingAngle=" + headingAngle + ", pos=(" + PlayerRef.GetPositionX() + "," + PlayerRef.GetPositionY() + ")", 1)
		endif
	else
		Debug.Trace("AutoWalk: FailSafeRotate(): Invalid FailSafeRotateMethod=" + FailSafeRotateMethod, 1)
	endif
endFunction

;/ Player rotation approaches tried, in order:
	1. PlayerRef.SetAngle() - safest option, but triggers a loading screen. Splitting the
	   turn into several small-angle calls does not avoid this.
	2. PlayerRef.SetLookAt() - no loading screen, smooth rotation. Occasionally, near cell
	   boundaries, the player sets off walking in the wrong direction first, then freezes
	   and shudders in place once real pathfinding takes over.
	3. PlayerRef.PathToReference() - no loading screen, smooth rotation. The smaller the
	   afWalkRunPercent value, the smoother the turn; larger values increase the chance the
	   player sets off in the wrong initial direction and never reaches the destination.
	   This is the approach currently in use below, called against a nearby temporary guide
	   object (RotateGuide) instead of the real, far-away destination, since the call blocks
	   until it arrives. See FailSafeRotate() for how the block is eventually cleared.
/;
bool Function RotatePlayerToDestination()
	Debug.Trace("AutoWalk: RotatePlayerToDestination(): Traveler currently bound to=" + Traveler.GetRef() + ", PlayerRef=" + PlayerRef + ", IsRunning=" + PlayerRef.IsRunning(), 1)

	if IsRotating
		Debug.Trace("AutoWalk: RotatePlayerToDestination: Already in progress, skipping reentrant call.", 1)
		return false
	endif
	IsRotating = true



	ObjectReference targetObj = DstMarker.GetReference()
	if !targetObj
		IsRotating = false
		return false
	endif

	if RotateGuide
		RotateGuide.Disable()
		RotateGuide.Delete()
	endif

	float origX = RotateGuide.GetPositionX()
	float origY = RotateGuide.GetPositionY()
	float origZ = RotateGuide.GetPositionZ()
	RotateGuide = PlayerRef.PlaceAtMe(RotateGuideForm, 1) as ObjectReference
	RotateGuide.WaitFor3DLoad()
	RotateGuide.SetScale(0.1) ; make it small to be invisible.
	RotateGuide.MoveToNearestNavmeshLocation()
	; is moved to nearest navmesh location?
	if RotateGuide.GetPositionX() != origX || RotateGuide.GetPositionY() != origY || RotateGuide.GetPositionZ() != origZ
		Debug.Trace("AutoWalk: RotatePlayerToDestination: Successfully moved RotateGuide to nearest navmesh location. pos=(" + RotateGuide.GetPositionX() + "," + RotateGuide.GetPositionY() + "," + RotateGuide.GetPositionZ() + ")", 1)
		targetObj = RotateGuide
	endif

	float headingAngle = PlayerRef.GetHeadingAngle(targetObj)
	if headingAngle < 45.0 && headingAngle > -45.0
		Debug.Trace("AutoWalk: RotatePlayerToDestination: Already facing destination. Current HeadingAngle=" + headingAngle, 1)
		IsRotating = false
		return true
	endif

	; Place a temporary guide object a short distance from the player, in the direction of
	; the nearest navmesh location or real destination, and path the player toward it instead of the destination itself.
	float playerX = PlayerRef.GetPositionX()
	float playerY = PlayerRef.GetPositionY()
	float playerZ = PlayerRef.GetPositionZ()

	float dirX = targetObj.GetPositionX() - playerX
	float dirY = targetObj.GetPositionY() - playerY
	float dirZ = targetObj.GetPositionZ() - playerZ
	float dirLength = Math.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ)
	if dirLength != 0
		dirX = dirX / dirLength
		dirY = dirY / dirLength
		dirZ = dirZ / dirLength
	endif

	float zOffset = 100.0 ; spawn height above the player, to avoid spawn collision with the ground

	RotateGuide.SetPosition(playerX + dirX * RotateGuideDistance, playerY + dirY * RotateGuideDistance, playerZ + dirZ * RotateGuideDistance + zOffset)
	float freeFallTime = MarkerDBScript.GetFreeFallTime(zOffset) ; time for the guide to fall and settle on the ground
	Debug.Trace("AutoWalk: RotatePlayerToDestination: Placed RotateGuide at (" + (playerX + dirX * RotateGuideDistance) + ", " + (playerY + dirY * RotateGuideDistance) + ", " + (playerZ + dirZ * RotateGuideDistance + zOffset) + "), freeFallTime=" + freeFallTime, 1)
	Utility.Wait(freeFallTime + 0.1)
	; FailSafeRotate()에서 MoveTo를 하게될 경우에 대비하여 목적지 방향으로 돌려놓는다.
	RotateGuide.SetAngle(0.0, 0.0, PlayerRef.GetHeadingAngle(targetObj))
	; disable user input to avoid the player moving away from the guide and never reaching it
	InputEnableLayer myLayer = InputEnableLayer.Create()
	myLayer.DisablePlayerControls(abMovement = true, abFighting = true, abCamSwitch = false, \
		abLooking = false, abSneaking = true, abMenu = false, abActivate = false, \
 		abJournalTabs = false)

	; Rotating player is not necessary if the player is in 1st person or has weapon drawn, 
	; since the camera and player will rotate correctly to face the destination when scene starts.
	; TODO: MoveTo에 의한 PathToReference()강제 리턴 효과를 충분히 확인한 후 1인칭 및 무기장착 상태 판단 조건 살려놓을 것.
	if True;GardenOfEden.Is3rdPersonVisible() && !PlayerRef.IsWeaponDrawn()
		Debug.Trace("AutoWalk: RotatePlayerToDestination: 3rd person visible=" + GardenOfEden.Is3rdPersonVisible() + ", weapon drawn=" + PlayerRef.IsWeaponDrawn(), 1)

		Game.SetPlayerAIDriven(true)
		myLayer.EnableRunning(false)
		myLayer.EnableSprinting(false)

		var[] args = new var[1]
		args[0] = targetObj as var
		CallFunctionNoWait("DebugRotate", args)
		FailSafeRotateMethod = 1
		StartTimer(FailSafeRotateTimeoutSecs1, TimerIdFailSafeRotate)
		PlayerRef.PathToReference(RotateGuide, 0.4)
		CancelTimer(TimerIdFailSafeRotate)
		RotateGuide.Disable()
		RotateGuide.Delete()

		myLayer.EnableRunning(true)
		myLayer.EnableSprinting(true)

		headingAngle = PlayerRef.GetHeadingAngle(targetObj)
		Debug.Trace("AutoWalk: RotatePlayerToDestination: PathToReference() returned: headingAngle=" + headingAngle, 1)
		Game.SetPlayerAIDriven(false)
		
		PlayerRef.EvaluatePackage()
		PlayerRef.PlayIdle(IdleStop)
		
		IsRotating = false
	else
		Debug.Trace("AutoWalk: RotatePlayerToDestination: Player is not in 3rd person or has weapon drawn, skipping rotation.", 1)
		IsRotating = false
	endif

	myLayer.EnablePlayerControls()
	myLayer = None

	return true
EndFunction

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
				Debug.Trace("AutoWalk: OnCombatClearWaitResult(): RESTARTING", 1)
				GoToState("RESTARTING")
			else
				Debug.Trace("AutoWalk: OnCombatClearWaitResult(): STARTING", 1)
				GoToState("STARTING")
			endIf
		endif
		return
    elseif resultCode == ThreatDetectorScript.AWR_WAIT_TIMEOUT()
    else ; AWR_WAIT_INTERRUPTED
    endif
	Debug.MessageBox("AutoWalk\n\nPlayer is in combat!\nClear all threats,\nsneak until enemies calm down,\nor move to a safe location before starting.")
	Debug.Trace("AutoWalk: OnCombatClearWaitResult(): Combat State is not clear or resumed, not starting walking.", 1)
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
		Debug.Trace("AutoWalk: OnTimer: early stop timer: dist=" + dist +", bWalking=" + bWalking, 1)
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
	elseif _timer == TimerIdFailSafeRotate
		FailSafeRotate()
	endIf
endEvent

;/ ----- STARTING ------------------------------------------------------------------------------------------------ STARTING ----- /;
state STARTING
	event OnBeginState(string _oldState)
		bWalking = True
		Debug.Trace("AutoWalk: OnBeginState(STARTING)", 1)
		if !IsRotating
			RotatePlayerToDestination()
			Debug.Trace("AutoWalk: OnBeginState(STARTING): RotatePlayerToDestination() returned. IsRotating=" + IsRotating, 1)
			if !MorsAW_Scene.IsPlaying()
				MorsAW_Scene.Start()
			else
				ReservePlayer()
				GoToState("WALKING")
			endIf
		else
			Debug.Trace("AutoWalk: OnBeginState(STARTING): Not starting walking because previous walking preparation is still in progress. IsRotating=" + IsRotating, 1)
		endif
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
		; Scene stopped immediately, and we need to clean up to avoid player locking up.
		Debug.trace("AutoWalk: SceneStopped(STARTING): Calling CheckCombatStateAndStop(True)...", 1)
		CheckCombatStateAndStop(True)
	endEvent
endState

;/ ----- RESTARTING -------------------------------------------------------------------------------------------- RESTARTING ----- /;
state RESTARTING
  event OnBeginState(string _oldState)
		
		Debug.trace("AutoWalk: OnBeginState(RESTARTING): IsPlaying=" + MorsAW_Scene.IsPlaying(), 1)
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
		Debug.trace("AutoWalk: OnBeginState(STOPPED): Player Position: " + "(" + PlayerRef.x + ", " + PlayerRef.y +", " + PlayerRef.z + "), world space: " + PlayerRef.GetCurrentLocation(), 1)
	endEvent
endState

;-- Custom Marker ----------------------------------

ObjectReference Function GetCustomDstMarker()
	if MarkerDBScript.GetDBState() == MarkerDBScript.AWR_DB_STATE_NOT_READY()
		Debug.MessageBox("AutoWalk\n\nWalking to Custom Destination requires Map Marker Database.\nYou can start building it in MCM.")
		return None
	elseif MarkerDBScript.GetDBState() == MarkerDBScript.AWR_DB_STATE_BUILDING()
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
	endif
	;GoToState("RESTARTING")
EndFunction
