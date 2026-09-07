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

group Subsystems
	Mors:AWR_JitterMonitor property AWR_JitterMonitor auto const mandatory
	{monitors jitter/footsteps and try to fix jittering issues during walking}
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

string StopReason = ""
string dstName = "" ; to store the name of the last selected destination (primary use in notification when resuming walking)
int TimerMenuKeyDown = 10 ; ID of the hotkey timer
CustomEvent SceneStopped ; Custom event we sent from scene.OnEnd() handlers
int iWorldSpace = -1 ; 0: Commonwealth, 1: Far Harbor, 2: Nuka World
bool bStopNotification = true ; whether to show notification/messagebox when walking stops (we toggle this depending on the reason we are stopping - if the reason we stopped is due to user action, we set it to false)

int TimerCheckArrival = 20
bool bWalking = false ; MorsAW_Scene.IsPlaying() is not reliable
ObjectReference CurrentCustomDstMarker = None
bool bPlayerInCombat = false

; ----- Stale-event 방지용 -----
; RESTARTING.OnBeginState()에서 재시작이 확정되는 순간 WalkGeneration을 증가시키고
; bWalkingReady를 False로 내린다. WALKING.OnBeginState()가 완전히 끝나야 bWalkingReady가 True가 된다.
; scene.OnEnd() 핸들러들이 SendCustomEvent("SceneStopped")로 보내는 이벤트에는 그 시점의
; WalkGeneration을 실어 보내서, 나중에 실제로 이벤트가 처리될 때 그 사이 재시작이 한 번 더
; 일어났는지(WalkGeneration 불일치) 또는 아직 WALKING 초기화가 끝나지 않았는지(bWalkingReady=false)를
; 판별해 낡은/때이른 이벤트를 무시할 수 있게 한다.
int WalkGeneration = 0
bool bWalkingReady = false
int iSceneStartRetry = 0
int iMaxSceneStartRetry = 3 const
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
			Debug.Trace("AutoWalk: OnControlDown(): No destination selected, showing menu.", 1)
			ShowMenu()
		else
			StartTimer(HotkeyHoldTime, TimerMenuKeyDown)
		endIf
	elseIf _ctl == "MorsAutoWalkJitterMarkHotkey"
		; 디버그용: 사용자가 화면에서 지터를 시각적으로 인지한 순간 누르는 핫키.
		; ExecuteSample()이 놓친(false negative) 케이스를 나중에 로그로 분석하기 위한 용도.
		Debug.Notification("AutoWalk: Jitter state marked.")
		AWR_JitterMonitor.MarkJitterObserved()
	else
		if AWR_JitterMonitor.iFootstepCheckPhase > 0
			Debug.Trace("AutoWalk: OnControlDown(): Footstep check in progress, ignoring input.", 1)
			Debug.Notification("AutoWalk: Footstep check in progress, please wait.")
			return
		endIf
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
		AWR_JitterMonitor.UpdateWalkSpeed(WalkSpeed)
		BeginNewWalkGeneration()
		GotoState("RESTARTING")
	endIf
endEvent

function OnCombatClearWaitResult(int resultCode)
    if resultCode == ThreatDetectorScript.AWR_WAIT_OK()
        ; resume autowalk
		if DstMarker.GetReference()
			Debug.Notification("Walking to "+ dstName)
			bStopNotification = true
			Debug.Trace("AutoWalk: OnCombatClearWaitResult(): Before calling CleanupCustomEventSubscriptions()", 1)
			CleanupCustomEventSubscriptions()
			RegisterForCustomEvent(Self, "SceneStopped")
			RegisterForRemoteEvent(MorsAW_Scene, "OnBegin")
			RegisterForRemoteEvent(MorsAW_Scene, "OnEnd")
			RegisterForCustomEvent(AWR_JitterMonitor, "MonitoringStopped")
			if MorsAW_Scene.IsPlaying()
				Debug.Trace("AutoWalk: OnCombatClearWaitResult(): RESTARTING", 1)
				BeginNewWalkGeneration()
				GoToState("RESTARTING")
			else
				Debug.Trace("AutoWalk: OnCombatClearWaitResult(): STARTING", 1)
				StopReason = ""
				AWR_JitterMonitor.PrepareForWalking()
				BeginNewWalkGeneration()
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

Event Mors:AWR_JitterMonitor.MonitoringStopped(AWR_JitterMonitor _sender, Var[] _args)
	Debug.Trace("AutoWalk: MonitoringStopped(): Stopping AutoWalk due to navigation failure.", 1)
	if IsWalking()
		StopReason = "Walking stopped due to navigation failure."
		GoToState("STOPPING")
	endif
EndEvent

; Begin AutoWalk after checking combat state and clearing possible lingering combat state.
bool function StartWalking()
	Debug.Trace("AutoWalk: StartWalking(): Before calling CleanupCustomEventSubscriptions()", 1)
	CleanupCustomEventSubscriptions()
	if DstMarker.GetReference() == none
		Debug.Notification("AutoWalk: No destination selected! Cannot start walking.")
		return false
	endif
	if bCaptive
		Debug.Trace("AutoWalk: Walking in No Aggro mode...", 1)
		; No Aggro는 전투 정리 대기를 생략하므로, 이미 전투 중(CombatState=1)이면
		; Travel 패키지가 배치되지 못해 Scene이 즉시 끝나버린다.
		; Captive faction을 먼저 적용하고 현재 전투를 강제 해소한 뒤 출발한다.
		Captive.ForceRefTo(PlayerRef)
		PlayerRef.StopCombat()
		OnCombatClearWaitResult(ThreatDetectorScript.AWR_WAIT_OK())
		return true
	elseif(ThreatDetectorScript.BeginCombatClearWait(self as Quest, "OnCombatClearWaitResult")) == false
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
	; No Aggro(Captive) 모드에서는 faction 설정으로 공격이 차단되므로
	; 전투 감지로 인한 중단을 건너뛴다. (초기 버전의 락업 방지 테스트를 위함)
	if bCaptive
		Debug.Trace("AutoWalk: CheckCombatStateAndStop(): not going to stop because use selected 'No Aggro' mode", 1)
		return
	endif
	Debug.Trace("AutoWalk: CheckCombatStateAndStop(): bCombatWarning=" + bCombatWarning + ", bWalking=" + bWalking + ", state=" + GetState(), 1)
	If bCombatWarning && bWalking && GetState() != "STOPPING"
		float threat = GardenOfEden2.GetCurrentCombatThreatLevel(PlayerRef)
		Debug.Trace("AutoWalk: CheckCombatStateAndStop(): hint=" + hint +", bPlayerInCombat=" + bPlayerInCombat +", combatState=" + PlayerRef.GetCombatState() + ", inCombat=" + PlayerRef.IsInCombat() + ", State=" + GetState() + ", threat=" + threat, 1)
		If hint || threat > -1.0 || bPlayerInCombat
			bStopNotification = False
			Debug.MessageBox("!!! DANGER !!!\nYou entered combat.\nGet ready to defend yourself!")
		endif
		GoToState("STOPPING")
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

; scene.OnEnd() 핸들러들은 이 함수를 통해서만 SceneStopped 커스텀 이벤트를 보낸다.
; 보내는 시점의 WalkGeneration을 args[0]에 실어서, 나중에 이벤트가 실제로 처리될 때
; 그 사이 재시작이 한 번 더 일어났는지 판별할 수 있게 한다.
function SendSceneStoppedEvent()
	var[] args = new var[1]
	args[0] = WalkGeneration
	Debug.Trace("AutoWalk: SendSceneStoppedEvent(): tagging with generation=" + WalkGeneration, 1)
	SendCustomEvent("SceneStopped", args)
endFunction

; STARTING으로 향하는 모든 경로(최초 시작이든, RESTARTING을 거치든)에서 반드시 이 함수를 먼저 호출한다.
; 여기서 WalkGeneration을 증가시키고 bWalkingReady를 내려서, 그 뒤에 도착하는 낡은/때이른
; SceneStopped 이벤트를 걸러낼 수 있는 기준점을 만든다.
function BeginNewWalkGeneration()
	WalkGeneration += 1
	bWalkingReady = false
	Debug.Trace("AutoWalk: BeginNewWalkGeneration(): generation=" + WalkGeneration, 1)
endFunction

; 이벤트가 현재 재시작 사이클보다 낡았는지(그 사이 재시작이 한 번 더 일어남) 확인한다.
; RESTARTING/STARTING/STOPPING 등 어느 상태에서든 공통으로 쓸 수 있다.
bool function IsStaleGeneration(Var[] _args)
	int evtGen = -1
	if _args && _args.Length > 0
		evtGen = _args[0] as int
	endIf
	if evtGen != WalkGeneration
		Debug.Trace("AutoWalk: IsStaleGeneration(): stale (evtGen=" + evtGen + ", current=" + WalkGeneration + ")", 1)
		return true
	endIf
	return false
endFunction

; WALKING.SceneStopped 전용: 세대까지 맞아도 WALKING.OnBeginState()가 아직 안 끝났으면
; (DstMarker 등이 아직 안정화되지 않았을 수 있으므로) 때이른 이벤트로 보고 무시해야 한다.
bool function IsStaleOrPrematureWalkingEvent(Var[] _args)
	if IsStaleGeneration(_args)
		return true
	endIf
	if !bWalkingReady
		Debug.Trace("AutoWalk: IsStaleOrPrematureWalkingEvent(): premature (WALKING not ready yet, gen=" + WalkGeneration + ")", 1)
		return true
	endIf
	return false
endFunction

event OnTimer(int _timer)
	if _timer == TimerMenuKeyDown
		Debug.Trace("AutoWalk: OnTimer: TimerMenuKeyDown triggered, showing menu.", 1)
		ShowMenu()
	elseif _timer == TimerCheckArrival
		ObjectReference _dst = CurrentCustomDstMarker
		if _dst == None
			_dst = DstMarker.GetReference()
		endIf
		float dist = 9999.0
		if _dst
			dist = SUP_F4SE.GetDistanceBetweenPoints(_dst.X, PlayerRef.x, _dst.Y, PlayerRef.y, 0, 0 )
		endIf
		Debug.Trace("AutoWalk: OnTimer: early stop timer: dist=" + dist +", bWalking=" + bWalking, 1)
		; 커스텀 마커 목적지가 플레이어 로드 셀 범위(약 2셀 이내)에 들어오면
		; RayCast로 정확한 지상 Z를 재측정해 목적지 Z를 보정한다.
		; (출발 시점에 원격이라 navmesh로 실패했던 navmesh hole 목적지가
		;   셀이 로드된 지금은 정확한 Z를 얻을 수 있다.)
		if bWalking && CurrentCustomDstMarker && dist <= 8192.0
			MarkerDBScript.ReRequestGroundZ()
		endif
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

	else
		Debug.Trace("AutoWalk: OnTimer: Unknown timer ID=" + _timer, 1)
	endIf
endEvent

bool Function IsWalking()
	return bWalking
EndFunction

Function ResetFootstepDetection()
	if AWR_JitterMonitor.iFootstepCheckPhase > 0
		Debug.Notification("AutoWalk: Cannot reset — footstep check is currently in progress.")
		return
	endif
	AWR_JitterMonitor.ResetFootstepCheckResults()
	Debug.Notification("AutoWalk: Footstep check data cleared. A fresh check will run on your next walk.")
EndFunction

;/ ----- STARTING ------------------------------------------------------------------------------------------------ STARTING ----- /;
state STARTING
	event OnBeginState(string _oldState)
		bWalking = True
		Debug.Trace("AutoWalk: OnBeginState(STARTING)", 1)
		if !MorsAW_Scene.IsPlaying()
			Debug.Trace("AutoWalk: OnBeginState(STARTING): Scene is not playing, calling MorsAW_Scene.Start()...", 1)
			MorsAW_Scene.Start()
		else
			ReservePlayer()
			Debug.Trace("AutoWalk: OnBeginState(STARTING): Scene is already playing, skipping MorsAW_Scene.Start().", 1)
			GoToState("WALKING")
		endIf
	endEvent
	event scene.OnBegin(scene _scene)
		Debug.Trace("AutoWalk: scene.OnBegin(STARTING)", 1)
		ReservePlayer()
		GoToState("WALKING")
	endEvent
	event scene.OnEnd(Scene _scene)
		Debug.trace("AutoWalk: scene.OnEnd(STARTING)", 1)
		SendSceneStoppedEvent()
	endEvent
	event Mors:AutoWalk.SceneStopped(Mors:AutoWalk _sender, Var[] _args)
		if IsStaleGeneration(_args)
			Debug.trace("AutoWalk: SceneStopped(STARTING): Ignoring stale event.", 1)
			Debug.Notification("AutoWalk: SceneStopped(STARTING): Ignoring stale event.")
			return
		endIf
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
		SendSceneStoppedEvent()
	endEvent
	; NOTE: We must rely on custom event SceneStopped send from within the OnEnd handler to introduce additional delay without using a timer. The delay is needed for the Scene to have time to stop completely before we use Scene.IsPlaying() which would otherwise still return True!
	event Mors:AutoWalk.SceneStopped(Mors:AutoWalk _sender, Var[] _args)
		if IsStaleGeneration(_args)
			Debug.trace("AutoWalk: SceneStopped(RESTARTING): Ignoring stale event.", 1)
			Debug.Notification("AutoWalk: SceneStopped(RESTARTING): Ignoring stale event.")
			return
		endIf
		Debug.trace("AutoWalk: SceneStopped(RESTARTING)", 1)
		ReleasePlayer()
		GoToState("STARTING")
	endEvent
endState

;/ ----- WALKING -------------------------------------------------------------------------------------------------- WALKING ----- /;
state WALKING
	Event OnBeginState(string _oldState)
		Debug.Notification("Walking to " + dstName)
		ObjectReference obj = DstMarker.GetReference()
		Debug.Trace("AutoWalk: OnBeginState(WALKING): Walking to "+ dstName +"(" + obj.GetCurrentLocation() + "," + obj +")" + "(" + obj.X as Int+ ", " + obj.Y as Int +", " + obj.Z as Int+ ")", 1)
		; WALKING 진입 시 필요한 초기화가 다 끝난 시점에만 ready를 True로 올린다.
		; 이 줄 이전에 도착하는 SceneStopped 이벤트는 IsStaleOrPrematureWalkingEvent()에서 걸러진다.
		bWalkingReady = true
	EndEvent

	; WALKING 상태에서는 scene.OnBegin 이벤트가 발생하지 않음.
	; event scene.OnBegin(scene _scene)
	; 	Debug.Trace("AutoWalk: scene.OnBegin(WALKING)", 1)
	; endEvent

	event scene.OnEnd(scene _scene)
		Debug.trace("AutoWalk: scene.OnEnd(WALKING)", 1)
		GoToState("STOPPING")
		SendSceneStoppedEvent()
	endEvent

	Event Mors:AutoWalk.SceneStopped(Mors:AutoWalk _sender, Var[] _args)
		if IsStaleGeneration(_args)
			; 이전 세대 이벤트: 그 사이 재시작이 이미 진행 중이므로 무시해도 안전하다.
			Debug.trace("AutoWalk: SceneStopped(WALKING): stale event. Ignoring.", 1)
			return
		endIf
		if !bWalkingReady
			; WALKING.OnBeginState()가 끝나기 전에 도착한 때이른 이벤트.
			if MorsAW_Scene.IsPlaying()
				; Scene은 정상 재생 중이다(그저 전달 순서가 빨랐을 뿐). 무시.
				Debug.trace("AutoWalk: SceneStopped(WALKING): premature but scene still playing. Ignoring.", 1)
				return
			endIf
			; Scene이 출발 직후 실제로 죽었다(예: No Aggro 중 전투로 Travel 패키지 배치 실패).
			; 여기서 멍하니 return하면 플레이어가 ReservePlayer() 상태로 남아 락업된다.
			; 전투를 재차 해소하고 STARTING부터 다시 시도한다. 시도 횟수를 초과하면
			; STOPPING으로 정리해 ReleasePlayer()까지 반드시 수행한다.
			if iSceneStartRetry < iMaxSceneStartRetry
				iSceneStartRetry += 1
				Debug.trace("AutoWalk: SceneStopped(WALKING): scene died at start, retrying (" + iSceneStartRetry + "/" + iMaxSceneStartRetry + ").", 1)
				PlayerRef.StopCombat()
				PlayerRef.StopCombatAlarm()
				PlayerRef.EvaluatePackage()
				BeginNewWalkGeneration()
				GoToState("STARTING")
			else
				Debug.trace("AutoWalk: SceneStopped(WALKING): scene died at start, giving up after " + iSceneStartRetry + " retries.", 1)
				GoToState("STOPPING")
			endIf
			return
		endIf
		; If distance to destination is far enough but scene is stopped without OnCombatStateChanged event or user pressing the hotkey, 
		; then there must be some threat only the scene can detect.
		; To avoid locking up the player, we need to ReleasePlayer by switching state to STOPPING.
		ObjectReference _dst = CurrentCustomDstMarker
		if _dst == None
			_dst = DstMarker.GetReference()
		endIf
		float dist = 9000.0
		if _dst
			dist = SUP_F4SE.GetDistanceBetweenPoints(_dst.X, PlayerRef.x, _dst.Y, PlayerRef.y, 0, 0 )
		endIf
		bool hint = dist > 5000.0 && !bCaptive
		Debug.trace("AutoWalk: SceneStopped(WALKING): Calling CheckCombatStateAndStop(" + hint + ")...", 1)
		CheckCombatStateAndStop(hint)
		AWR_JitterMonitor.CleanupAfterWalking()
	EndEvent
endState

;/ ----- STOPPING ------------------------------------------------------------------------------------------------ STOPPING ----- /;
state STOPPING
	event OnBeginState(string _oldState)
	Debug.trace("AutoWalk: OnBeginState(STOPPING)", 1)
	Debug.trace("AutoWalk: OnBeginState(STOPPING): Canceling Timer...", 1)
	CancelTimer(TimerCheckArrival)
	ThreatDetectorScript.CancelCombatClearWait()
	
	AWR_JitterMonitor.CleanupAfterWalking()

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
		if StopReason == ""
			StopReason = "You stopped walking"
		endif
		if bStopNotification && bStopMessageBox
			Debug.MessageBox(StopReason)
		else
			Debug.Notification(StopReason)
		endIf
		Debug.trace("AutoWalk: OnBeginState(STOPPED): Player Position: " + "(" + PlayerRef.x + ", " + PlayerRef.y +", " + PlayerRef.z + "), world space: " + PlayerRef.GetCurrentLocation(), 1)
		CleanupCustomEventSubscriptions()

		StopReason = ""
		; 모든 애니메이션에 대해 체크를 했으나 발자국 이벤트가 지원되지 않는 경우 MCM에서 재시도 버튼을 눌러보라고 안내한다.
		if AWR_JitterMonitor.bUseAnimationFootstepCheck
			bool bNotifiedFootstepCheckNotSupported = SUP_F4SE.ModLocalDataGetInt("Mors:AutoWalk", "bNotifiedFootstepCheckNotSupported") as bool
			if bNotifiedFootstepCheckNotSupported == false
				bNotifiedFootstepCheckNotSupported = True
				SUP_F4SE.ModLocalDataSetInt("Mors:AutoWalk", "bNotifiedFootstepCheckNotSupported", 1)
				if  AWR_JitterMonitor.AreAllFootstepChecksDone() && \
					( !AWR_JitterMonitor.IsFootstepSupported(0) || \
					!AWR_JitterMonitor.IsFootstepSupported(1) || \
					!AWR_JitterMonitor.IsFootstepSupported(2) || \
					!AWR_JitterMonitor.IsFootstepSupported(3) )
					Debug.MessageBox("AutoWalk\n\nYour current animation set does not support footstep detection.\n" + \
									"Please disable \"Use Animation Footstep Check\" in the MCM, or use \"Reset Footstep Detection\" to run a fresh check.")
				endif
			endif
		endif
	endEvent
endState

;-- Custom Marker ----------------------------------

function CleanupCustomEventSubscriptions()
	UnregisterForCustomEvent(Self, "SceneStopped")
	UnregisterForCustomEvent(AWR_JitterMonitor, "MonitoringStopped")
; NOTE: MarkerDBScript의 UpdateCustomDestination 등록은 해제하지 않는다.
; 커스텀 목적지 Z는 비동기 보정(CalibrateCustomDestinationMarker)이 끝난 뒤에 정확한 지상 Z로 갱신된다.
; 여기서 해제하면 마커 Z가 최신값으로 반영되지 않아 목적지가 지표면에 묻힌 채 남는다.
endFunction

ObjectReference Function GetCustomDstMarker()
	if MarkerDBScript.GetDBState() == MarkerDBScript.AWR_DB_STATE_NOT_READY()
		Debug.MessageBox("AutoWalk\n\nWalking to Custom Destination requires Map Marker Database.\nYou can start building it in MCM.")
		return None
	elseif MarkerDBScript.GetDBState() == MarkerDBScript.AWR_DB_STATE_BUILDING()
		Debug.MessageBox("AutoWalk\n\nMap Marker Database is currently building.\nPlease wait until it is finished.")
		return None
	endif
	UnregisterForCustomEvent(MarkerDBScript, "UpdateCustomDestination")
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
		ObjectReference _dst = CurrentCustomDstMarker
		if _dst == None
			_dst = DstMarker.GetReference()
		endIf
		float dist = 9999.0
		if _dst
			dist = SUP_F4SE.GetDistanceBetweenPoints(_dst.X, PlayerRef.x, _dst.Y, PlayerRef.y, 0, 0 )
		endIf
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

