Scriptname Mors:AWR_JitterMonitor extends Quest

actor property PlayerRef auto const mandatory
Mors:AutoWalk property AutoWalkScript auto const mandatory
idle property IdleStop auto const mandatory

; Footstep capability check results - persisted via ModLocalData by main script
bool bWalkFootstepSupported = false
bool bFastWalkFootstepSupported = false
bool bJogFootstepSupported = false
bool bRunFootstepSupported = false
bool bWalkFootstepChecked = false
bool bFastWalkFootstepChecked = false
bool bJogFootstepChecked = false
bool bRunFootstepChecked = false

bool property bUseAnimationFootstepCheck = true auto hidden; MCM option

Rochet2:EffortlessMovementControlQuestScript  EffortlessMovementControl = None

InputEnableLayer AutoWalkInputLayer = None

int WalkSpeedSave = 0
int TIMER_RESTORE_WALK_SPEED = 50 const
int TIMER_RESTORE_3RD_PERSON = 60 const
int TIMER_MONITOR_JITTER = 40 const
int TIMER_OVER_ENCUMBRANCE_CHECK = 70 const
bool bWalkSpeedRestoreScheduled = false
bool bIsPreparedForWalking = false
bool bWasUsingEffortlessMovementControl = false
float fSpeedMultSave = 100.0
float fSpeedMultBaseSave = 100.0
bool bHasNotifiedSpeedHandicap = false
float PENALTY_NOTIFY_THRESHOLD = 15.0 const
ActorValue SpeedMultAV = None ; Fallout4.esm|0x000002DA (SpeedMult)

Spell Property SpeedMultBuffSpell Auto
ActorValue Property CarryWeight auto
ActorValue Property RightMobilityCondition auto const
ActorValue Property LeftMobilityCondition auto const

bool bSpeedMultNormalizedBySpell = false
float fSpeedMultNormalizeDamage = 0.0

int  MaxResetPathingTryCount = 3
float MinResetPathingInterval = 20.0
float  LastResetPathingTime = 0.0
int  ResetPathingTryCount = 0

; SUP F4SE 플러그인(SUP_F4SE.dll)의 ActorIsSwimming()을 사용한다.
; 플러그인이 없으면 false를 반환하므로 순정 상태에서도 안전하게 실패한다.
bool bLastSampleSwimming = false

; 과적(overencumbered) 대응.
; 걷기 도중 과적 상태가 바뀌면 WalkSpeed를 제어하고, 과적 중에는 발자국 rate 판정을 건너뛴다.
; GetInventoryWeight()는 인벤토리 전체를 순회하므로 매 틱 호출하지 않는다. 검출은 두 갈래로 한다:
;  1) OnItemAdded/OnItemRemoved 이벤트 -> 즉시 재계산 (가장 흔한 아이템 기반 과적)
;  2) fEncumbranceCheckInterval마다 폴링     -> 다른 모드 디버프로 CarryWeight 임계값만 바뀌는
;     경우의 안전망. 이벤트로는 감지 불가능한 이 시나리오를 EMC는 놓치는데, 여기선 못 잡게 두지 않는다.
float fEncumbranceCheckInterval = 10.0 const
float LastEncumbranceCheckTime = -1.0
bool bOverEncumbered = false	; 마지막 계산 시점의 과적 상태 (ExecuteSample에서 사용)
bool bLastOverEncumbered = false	; 전이 감지용 이전 상태
bool bHasNotifiedEncumbrance = false

CustomEvent MonitoringStopped

struct MonitorData
	float distance
	float speed
	float yawDelta
	float animSpeed
	int footstepsLeft
	int footstepsRight
	int limpCount
	bool runModeMismatch
	float sampleTime
endStruct

struct MonitorResult
	int resultCode		; 0: continue, 1: jitter detected, 2: restart monitoring (WalkSpeed changed), 3: footstep checks complete, restore WalkSpeed
	int newWalkSpeed	; valid when resultCode == 2
endStruct

float fFootstepCheckDuration = 2.0 const
float fExpectedWalkFootstepRate = 0.21 const	; 초당 걷기 발자국 수 (실제 관찰된 값은 0.7~0.9, IsRunning=False)
float fExpectedFastWalkFootstepRate = 0.36 const ; 초당 빠른 걷기 발자국 수 (실제 관찰된 값은 1.2~1.2, IsRunning=False)
float fExpectedJogFootstepRate = 0.48 const ; 초당 Jogging 발자국 수 (실제 관찰된 값은 1.6, IsRunning=False)
float fExpectedRunFootstepRate = 0.44 const	; 초당 뛰기 발자국 수 (실제 관찰된 값은 1.5, IsRunning=True)

float fJitterSpeedThreshold = 15.0 const ; TODO: 관측값 확보(걷기 75, 뛰기 320)
float fJitterYawThreshold = 70.0 const ; TODO: 초당 회전 각으로 정의하고 로직 구성, 관측값 확보
float fJitterDistanceThreshold = 10.0 const ; TODO: 초당 이동 거리로 정의하고 로직 구성, 관측값 확보 

float fMonitorInterval = 0.4 const
int iSampleHistorySize = 12 const ; 이동평균을 구하기 위한 샘플 개수 (0.4초 * 12 = 4.8초)

; 샘플링 및 상태 추적 변수
float lastPositionX = 0.0
float lastPositionY = 0.0
float lastPositionZ = 0.0
float lastPositionYaw = 0.0
float lastSampleTime = 0.0

; 발걸음 이벤트 카운터
int currentSampleLeftFootsteps = 0
int currentSampleRightFootsteps = 0
int currentNotAlternatingCount = 0
string lastFootstep = ""
float lastFootstepTime = 0.0
int totalFootstepCount = 0
float fMonitorStartTime = 0.0

; 이동평균 보관용 순환 배열 및 인덱스
MonitorData[] sampleHistory
int sampleHistoryIndex = 0
int validSampleCount = 0

; Footstep check 상태
int property iFootstepCheckPhase = 0 auto hidden	; 0: not checking, 1: waiting for stabilize, 2: checking, 3: finished
float fFootstepCheckStartTime = 0.0

int iLastCheckedWalkSpeed = -1

Event OnInit()
	Debug.Trace("AutoWalk: [MONITOR] OnInit.", 1)
EndEvent

Event OnQuestInit()
	Debug.Trace("AutoWalk: [MONITOR] OnQuestInit.", 1)
	RegisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")
	; 인벤토리 무게 변화 감지: OnItemAdded/OnItemRemoved로 즉시 과적 상태를 재계산한다.
	; AddInventoryEventFilter(None)가 없으면 이벤트가 수신되지 않는다. (EffortlessMovementControl 패턴)
	RegisterForRemoteEvent(PlayerRef, "OnItemAdded")
	RegisterForRemoteEvent(PlayerRef, "OnItemRemoved")
	AddInventoryEventFilter(None)
	OnGameLoad()
EndEvent

Event Actor.OnPlayerLoadGame(Actor sender)
	OnGameLoad()
EndEvent

function OnGameLoad()
	SpeedMultAV = Game.GetFormFromFile(0x000002DA, "Fallout4.esm") as ActorValue
	if SpeedMultAV == None
		Debug.Trace("AutoWalk: [MONITOR] Failed to load SpeedMult ActorValue.", 1)
	endif

	bWalkFootstepChecked = SUP_F4SE.ModLocalDataGetInt("Mors:AutoWalk", "bWalkFootstepChecked") as bool
	bFastWalkFootstepChecked = SUP_F4SE.ModLocalDataGetInt("Mors:AutoWalk", "bFastWalkFootstepChecked") as bool
	bJogFootstepChecked = SUP_F4SE.ModLocalDataGetInt("Mors:AutoWalk", "bJogFootstepChecked") as bool
	bRunFootstepChecked = SUP_F4SE.ModLocalDataGetInt("Mors:AutoWalk", "bRunFootstepChecked") as bool
	bWalkFootstepSupported = SUP_F4SE.ModLocalDataGetInt("Mors:AutoWalk", "bWalkFootstepSupported") as bool
	bFastWalkFootstepSupported = SUP_F4SE.ModLocalDataGetInt("Mors:AutoWalk", "bFastWalkFootstepSupported") as bool
	bJogFootstepSupported = SUP_F4SE.ModLocalDataGetInt("Mors:AutoWalk", "bJogFootstepSupported") as bool
	bRunFootstepSupported = SUP_F4SE.ModLocalDataGetInt("Mors:AutoWalk", "bRunFootstepSupported") as bool

	Debug.Trace("AutoWalk: [MONITOR] OnPlayerLoadGame(): Anim Checked: " + bWalkFootstepChecked + ", " + bFastWalkFootstepChecked +\
				 ", " + bJogFootstepChecked + ", " + bRunFootstepChecked + \
				" Anim Supported: " + bWalkFootstepSupported + ", " + bFastWalkFootstepSupported + ", " + bJogFootstepSupported + \
				", " + bRunFootstepSupported, 1)

	ResetFootstepCheckPhase()

	; TODO: List all plugins which uses InputEnableLayer.EnableRunning(false)
	;       to resolve conflicts.
	EffortlessMovementControl = Game.GetFormFromFile(0x801, "EffortlessMovementControl.esl") as Rochet2:EffortlessMovementControlQuestScript 
	If (EffortlessMovementControl != None)
		if SUP_F4SE.ModLocalDataGetInt("Mors:AutoWalk", "bEffortlessMovementControlDetected") as bool == false
			Debug.Notification("AutoWalk: EffortlessMovementControl detected.")
			SUP_F4SE.ModLocalDataSetInt("Mors:AutoWalk", "bEffortlessMovementControlDetected", 1)
		endif
	endif

	bHasNotifiedSpeedHandicap = false

	;TODO: 모드 재설치 후에는 아래 이벤트 틍록 삭제. OnQuestInit에서 할 예정.
	RegisterForRemoteEvent(PlayerRef, "OnItemAdded")
	RegisterForRemoteEvent(PlayerRef, "OnItemRemoved")
	AddInventoryEventFilter(None)
EndFunction

Function UpdateWalkSpeed(int newWalkSpeed)
	WalkSpeedSave = newWalkSpeed
	bWalkSpeedRestoreScheduled = false
EndFunction

bool function IsOverEncumbered()
	; TODO: 플레이어가 Strong Back을 가지고 있을 때 어떻게 되는지 확인
	If PlayerRef == None
		return false
	EndIf
	float max = PlayerRef.GetValue(CarryWeight)
	float curr = PlayerRef.GetInventoryWeight()
	Debug.Trace("AutoWalk: IsOverEncumbered(): CarryWeight=" + max + ", InventoryWeight=" + curr, 1)
	bool bRet =  curr > max
	if !bRet
		; 다리 절단(절뚝) 시 이동이 제한되므로 과적과 동일하게 취급한다.
		; Right/LeftMobilityCondition은 값이 0 이하(망가짐)면 절뚝거리는 애니메이션이 나온다.
		float leftLeg = PlayerRef.GetValue(LeftMobilityCondition)
		float rightLeg = PlayerRef.GetValue(RightMobilityCondition)
		bRet = (leftLeg <= 0.0) || (rightLeg <= 0.0)
		if bRet
			Debug.Trace("AutoWalk: IsOverEncumbered(): Limping detected (Left=" + leftLeg + ", Right=" + rightLeg + "), treated as overencumbered.", 1)
		endif
	endif
	Return bRet
endfunction

; 인벤토리 무게 변화 이벤트가 올 때마다 과적 상태를 즉시 재계산한다.
Event ObjectReference.OnItemAdded(ObjectReference akSender, Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
	CancelTimer(TIMER_OVER_ENCUMBRANCE_CHECK)
	StartTimer(0.5, TIMER_OVER_ENCUMBRANCE_CHECK)
EndEvent

Event ObjectReference.OnItemRemoved(ObjectReference akSender, Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
	CancelTimer(TIMER_OVER_ENCUMBRANCE_CHECK)
	StartTimer(0.5, TIMER_OVER_ENCUMBRANCE_CHECK)
EndEvent

; 과적 전이를 감지해 걷기 속도를 제어한다. 발자국 검사(진단) 중(iFootstepCheckPhase>0)에는
; WalkSpeed를 조작하지 않는다. OnItemAdded/OnItemRemoved 이벤트와 OnTimer의 안전망 폴링이 공용 호출한다.
function CheckEncumbranceState()
	if !bIsPreparedForWalking
		return
	endif
	if iFootstepCheckPhase > 0
		return
	endif
	bool bNewOver = IsOverEncumbered()
	if bNewOver != bLastOverEncumbered
		if bNewOver
			; 과적 시작: 이동 속도를 WalkSpeed 0으로 강제해 런/조그 애니메이션
			; 발자국 rate 불일치로 인한 거짓 jitter를 막는다.
			bLastOverEncumbered = true
			if AutoWalkScript.WalkSpeed != 0
				WalkSpeedSave = AutoWalkScript.WalkSpeed
				AutoWalkScript.WalkSpeed = 0
			endif
			if AutoWalkInputLayer != None
				AutoWalkInputLayer.EnableRunning(false)
				AutoWalkInputLayer.EnableSprinting(false)
			endif
			ResetPositionHistory()
			ResetFootstepCounters()
			validSampleCount = 0
			sampleHistoryIndex = 0
			Debug.Trace("AutoWalk: [MONITOR] Player became overencumbered. Forcing WalkSpeed 0.", 1)
			if !bHasNotifiedEncumbrance
				bHasNotifiedEncumbrance = true
				Debug.Notification("AutoWalk: Overencumbered - slowed to walking speed.")
			endif
		else
			; 과적 해제: 원래 걷기 속도로 복원한다.
			bLastOverEncumbered = false
			if AutoWalkScript.WalkSpeed != WalkSpeedSave
				AutoWalkScript.WalkSpeed = WalkSpeedSave
				ResetPathing(force1stPerson = false, withIdle = false)
			endif
			if AutoWalkInputLayer != None
				if GetExpectedRunning(WalkSpeedSave, true)
					AutoWalkInputLayer.EnableRunning(true)
					AutoWalkInputLayer.EnableSprinting(true)
				else
					AutoWalkInputLayer.EnableRunning(false)
					AutoWalkInputLayer.EnableSprinting(false)
				endif
			endif
			ResetPositionHistory()
			ResetFootstepCounters()
			validSampleCount = 0
			sampleHistoryIndex = 0
			Debug.Trace("AutoWalk: [MONITOR] Player became unencumbered. Restoring WalkSpeed to " + WalkSpeedSave, 1)
		endif
		bOverEncumbered = bLastOverEncumbered
	endif
EndFunction

bool restoreWeaponDrawnState = false
function _ChangeWalkSpeed(int newSpeed)
	if AutoWalkScript.WalkSpeed != newSpeed
		Debug.Trace("AutoWalk: ChangeWalkSpeed(): Changing WalkSpeed from " + AutoWalkScript.WalkSpeed + " to " + newSpeed, 1)
		WalkSpeedSave = AutoWalkScript.WalkSpeed
		AutoWalkScript.WalkSpeed = newSpeed
		ResetPathing(force1stPerson = false, withIdle = false)
	else
		Debug.Trace("AutoWalk: ChangeWalkSpeed(): WalkSpeed is already " + AutoWalkScript.WalkSpeed + ", no change needed.", 1)
	endif
	; InputEnableLayer의 run/sprint 상태를 현재 WalkSpeed에 맞춘다. 속도가 변하지 않아도 footstep check 시작 시에는 반드시 호출해야 한다.
	if AutoWalkInputLayer != None
		if GetExpectedRunning(newSpeed, true)
			Debug.Trace("AutoWalk: ChangeWalkSpeed(): Enabling running and sprinting for WalkSpeed=" + newSpeed, 1)
			AutoWalkInputLayer.EnableRunning(true)
			AutoWalkInputLayer.EnableSprinting(true)
		else
			Debug.Trace("AutoWalk: ChangeWalkSpeed(): Disabling running and sprinting for WalkSpeed=" + newSpeed, 1)
			AutoWalkInputLayer.EnableRunning(false)
			AutoWalkInputLayer.EnableSprinting(false)
		endif
	endif
endfunction

Function PrepareForWalking()
	Debug.Trace("AutoWalk: [MONITOR] PrepareForWalking()", 1)
	bIsPreparedForWalking = true
	bWalkSpeedRestoreScheduled = false
	; 새 걷기가 시작될 때만 재시도 카운터를 초기화한다. StartMonitoring()에서 초기화하면
	; 지터 감지 후 ResetPathingTryCount += 1 직후 리셋되어 카운트가 쌓이지 않는다.
	ResetPathingTryCount = 0
	LastResetPathingTime = Utility.GetCurrentRealTime()
	if EffortlessMovementControl != None
		bWasUsingEffortlessMovementControl = MCM.GetModSettingBool("EffortlessMovementControl", "bIsModEnabled:General")
		if bWasUsingEffortlessMovementControl
			;Debug.Notification("AutoWalk: Disabling EffortlessMovementControl...")
			EffortlessMovementControl.SetIsModEnabled(false)
		endif
	endif

	if AutoWalkInputLayer == None
		Debug.Trace("AutoWalk: PrepareForWalking(): Creating AutoWalkInputLayer", 1)
		AutoWalkInputLayer = InputEnableLayer.Create()
	endif
	fSpeedMultSave = PlayerRef.GetValue(SpeedMultAV)
	fSpeedMultBaseSave = PlayerRef.GetBaseValue(SpeedMultAV)
	if fSpeedMultSave < 100.0
		float externalPenalty = fSpeedMultBaseSave - fSpeedMultSave
		if externalPenalty > PENALTY_NOTIFY_THRESHOLD && !bHasNotifiedSpeedHandicap
			Debug.Notification("AutoWalk: Walk speed is being altered by another mod (e.g. limb injury effects). AutoWalk may behave unexpectedly.")
			bHasNotifiedSpeedHandicap = true
		endif
		if SpeedMultBuffSpell != None
			; base를 건드리지 않도록 Spell(임시 +100)을 적용한 뒤 DamageValue로 정확히 100으로 조정한다.(100을 더한 후 100을 초과하는 만큼 DamageValue)
			Debug.Trace("AutoWalk: PrepareForWalking(): Before SpeedMultBuffSpell: fSpeedMultSave=" + fSpeedMultSave + ", fSpeedMultBaseSave=" + fSpeedMultBaseSave+", externalPenalty=" + externalPenalty, 1)
			PlayerRef.AddSpell(SpeedMultBuffSpell, false)
			Utility.Wait(0.1)  ; 엔진이 액티브 이펙트를 실제로 적용할 시간을 줌
			fSpeedMultNormalizeDamage = PlayerRef.GetValue(SpeedMultAV) - 100.0
			if fSpeedMultNormalizeDamage > 0.0
				PlayerRef.DamageValue(SpeedMultAV, fSpeedMultNormalizeDamage)
				Debug.Trace("AutoWalk: PrepareForWalking(): After SpeedMultBuffSpell + DamageValue: SpeedMult=" + PlayerRef.GetValue(SpeedMultAV) + ", BaseValue=" + PlayerRef.GetBaseValue(SpeedMultAV), 1)
			else
				Debug.Trace("AutoWalk: PrepareForWalking(): Something is wrong with SpeedMultBuffSpell!", 1)
			endif
			bSpeedMultNormalizedBySpell = true
		else
			Debug.Trace("AutoWalk: PrepareForWalking(): SpeedMultBuffSpell is not assigned. Falling back to SetValue normalization.", 1)
			; externalPenalty = 현재 Base와 실제 체감값의 차이 = BLD 등이 깎아먹고 있는 총량
			float targetBase = 100.0 + externalPenalty
			Debug.Trace("AutoWalk: PrepareForWalking(): fSpeedMultSave=" + fSpeedMultSave + ", externalPenalty=" + externalPenalty + ", targetBase=" + targetBase, 1)
			PlayerRef.SetValue(SpeedMultAV, targetBase)
			Debug.Trace("AutoWalk: PrepareForWalking(): After correction: SpeedMult=" + PlayerRef.GetValue(SpeedMultAV) + ", BaseValue=" + PlayerRef.GetBaseValue(SpeedMultAV), 1)
		endif
	endif

	if bUseAnimationFootstepCheck == false
		ResetFootstepCheckResults()
	endif
	
	; 발자국 이벤트가 지원되면 jitter 감지를 더 안정적으로 할 수 있다.
	; 지원되지 않으면 다른 통계치에만 의존해야 한다. 
	; 발자국 이벤트가 지원되지 않는 불리한 상황이라면 걷기 시작시 카메라 동기화.
	if !AreAllFootstepChecksDone() || !IsFootstepSupported(0) || !IsFootstepSupported(1) || !IsFootstepSupported(2) || !IsFootstepSupported(3)
		if GardenOfEden.Is3rdPersonVisible() && !PlayerRef.IsWeaponDrawn()
			restoreWeaponDrawnState = true
			PlayerRef.DrawWeapon()
			StartTimer(2.0, TIMER_RESTORE_3RD_PERSON)
		endif
	endif

	if bUseAnimationFootstepCheck
		RegisterForAnimationEvent(PlayerRef, "FootLeft")
		RegisterForAnimationEvent(PlayerRef, "FootRight")

		if AreAllFootstepChecksDone()
			Debug.Trace("AutoWalk: PrepareForWalking(): All footstep checks already completed. Setting WalkSpeed to 0", 1)
			_ChangeWalkSpeed(0); 걷기 시작시 지터를  최소화하기 위해 0으로 바꿨다가 유저가 설정한 WalkSpeed로 복원하도록 한다.
			if IsOverEncumbered() == false
				Debug.Trace("AutoWalk: PrepareForWalking(): WalkSpeed set to 0, scheduling restoration to " + WalkSpeedSave, 1)
				StartTimer(1.0, TIMER_RESTORE_WALK_SPEED)
			else
				Debug.Trace("AutoWalk: PrepareForWalking(): WalkSpeed set to 0 from " + WalkSpeedSave + ", walkspeed will not be restored until autowalk stop", 1)
			endif
		else
			bool bOver = IsOverEncumbered()
			if bOver == false
				int nextSpeed = FindNextUncheckedFootstepSpeed(0)
				iFootstepCheckPhase = 1
				; 현재 WalkSpeed를 나중에 복원할 수 있도록 저장. _ChangeWalkSpeed()에서도 저장하지만,
				; 현재 속도가 nextSpeed와 같으면 _ChangeWalkSpeed()가 호출되지 않으므로 여기서 미리 저장한다.
				WalkSpeedSave = AutoWalkScript.WalkSpeed
				bWalkSpeedRestoreScheduled = true
				Debug.Trace("AutoWalk: PrepareForWalking(): Footstep check for WalkSpeed=" + nextSpeed + " not done, setting WalkSpeed=" + nextSpeed, 1)
				_ChangeWalkSpeed(nextSpeed)
			else
				; 과적 중에는 WalkSpeed 0이 강제되므로 그 속도에서만 진단 가능하다.
				; 걷기(0) 진단이 아직 안 끝났으면 WalkSpeed 0으로 진단을 진행하고,
				; 1/2/3 속도 진단은 과적이 풀린 후 새 걷기에서 수행하도록 남겨둔다.
				_ChangeWalkSpeed(0)
				if bWalkFootstepChecked
					Debug.Trace("AutoWalk: PrepareForWalking(): Overencumbered, WalkSpeed 0 footstep check already done.", 1)
				else
					Debug.Trace("AutoWalk: PrepareForWalking(): Overencumbered, starting footstep check at WalkSpeed 0.", 1)
					; 과적이므로 _ChangeWalkSpeed(0) 후 WalkSpeedSave를 덮어쓰지 않는다.
					; (WalkSpeedSave는 _ChangeWalkSpeed()에 의해 과적 전 속도로 저장되어 있다)
					bWalkSpeedRestoreScheduled = false
					iFootstepCheckPhase = 1
				endif
			endif
		endif
	else
		if IsOverEncumbered()
			_ChangeWalkSpeed(0)
		endif
	endif
	; 과적 초기 상태를 기록해 전이 감지(이벤트/폴링)가 걷기 시작 시점을 기준으로 헛돌지 않게 한다.
	bLastOverEncumbered = IsOverEncumbered()
	bOverEncumbered = bLastOverEncumbered
	LastEncumbranceCheckTime = Utility.GetCurrentRealTime()
	bHasNotifiedEncumbrance = false
	StartMonitoring()
EndFunction

Function CleanupAfterWalking()
	Debug.Trace("AutoWalk: [MONITOR] CleanupAfterWalking()", 1)
	if !bIsPreparedForWalking
		CancelTimer(TIMER_MONITOR_JITTER)
		CancelTimer(TIMER_RESTORE_WALK_SPEED)
		CancelTimer(TIMER_RESTORE_3RD_PERSON)
		CancelTimer(TIMER_OVER_ENCUMBRANCE_CHECK)
		return
	endif

	CancelTimer(TIMER_MONITOR_JITTER)
	CancelTimer(TIMER_RESTORE_WALK_SPEED)
	CancelTimer(TIMER_RESTORE_3RD_PERSON)
	CancelTimer(TIMER_OVER_ENCUMBRANCE_CHECK)
	if AutoWalkScript.WalkSpeed != WalkSpeedSave
		Debug.Trace("AutoWalk: CleanupAfterWalking(): Restoring WalkSpeed to " + WalkSpeedSave, 1)
		AutoWalkScript.WalkSpeed = WalkSpeedSave
	endif

	if bWasUsingEffortlessMovementControl
		;Debug.Notification("AutoWalk: Restoring EffortlessMovementControl...")
		EffortlessMovementControl.SetIsModEnabled(true)
	endif

	; PrepareForWalking()에서 정규화한 SpeedMult를 원래 현재값으로 복원한다.
	if fSpeedMultSave < 100.0
		if bSpeedMultNormalizedBySpell
			if SpeedMultBuffSpell != None
				PlayerRef.RestoreValue(SpeedMultAV, fSpeedMultNormalizeDamage)
				PlayerRef.RemoveSpell(SpeedMultBuffSpell)
				Utility.Wait(0.1)
				bSpeedMultNormalizedBySpell = false
				Debug.Trace("AutoWalk: CleanupAfterWalking(): After spell restore: SpeedMult=" + PlayerRef.GetValue(SpeedMultAV) + ", BaseValue=" + PlayerRef.GetBaseValue(SpeedMultAV), 1)
			endif
		else
			float externalPenalty = fSpeedMultBaseSave - fSpeedMultSave
			float targetBase = fSpeedMultSave + externalPenalty
			Debug.Trace("AutoWalk: CleanupAfterWalking(): fSpeedMultSave=" + fSpeedMultSave + ", externalPenalty=" + externalPenalty + ", targetBase=" + targetBase, 1)
			PlayerRef.SetValue(SpeedMultAV, targetBase)
			Debug.Trace("AutoWalk: CleanupAfterWalking(): After restore: SpeedMult=" + PlayerRef.GetValue(SpeedMultAV) + ", BaseValue=" + PlayerRef.GetBaseValue(SpeedMultAV), 1)
		endif
	endif

	if AutoWalkInputLayer != None
		Debug.Trace("AutoWalk: CleanupAfterWalking(): Deleting AutoWalkInputLayer", 1)
		AutoWalkInputLayer.EnableRunning(true)
		AutoWalkInputLayer.EnableSprinting(true)
		AutoWalkInputLayer.Delete()
		AutoWalkInputLayer = None
	endif

	UnregisterForAnimationEvent(PlayerRef, "FootLeft")
	UnregisterForAnimationEvent(PlayerRef, "FootRight")
	bWalkSpeedRestoreScheduled = false
	bIsPreparedForWalking = false
	bWasUsingEffortlessMovementControl = false
	StopMonitoring()
	ResetFootstepCheckPhase()
EndFunction

Function StartMonitoring()
	ResetPositionHistory()
	ResetFootstepCounters()
	fMonitorStartTime = lastSampleTime
	; ResetPathingTryCount/LastResetPathingTime는 여기서 초기화하지 않는다.
	; 지터 감지 후 +=1 직후 이 함수가 호출되어 카운트가 매번 0으로 리셋된다. 초기화는 PrepareForWalking()에서만 수행.
	CancelTimer(TIMER_MONITOR_JITTER)
	; ResetPathing, PrepareForWalking에서 걸어논 타이머를 덮어놓고 캔슬시키면 안된다
	; CancelTimer(TIMER_RESTORE_WALK_SPEED)
	; CancelTimer(TIMER_RESTORE_3RD_PERSON)
	StartTimer(fMonitorInterval, TIMER_MONITOR_JITTER)
	Debug.Trace("AutoWalk: [MONITOR] Jitter & Footstep Monitoring Started.", 1)
EndFunction

Function StopMonitoring()
	CancelTimer(TIMER_MONITOR_JITTER)
	; CancelTimer(TIMER_RESTORE_WALK_SPEED)
	; CancelTimer(TIMER_RESTORE_3RD_PERSON)
	float totalTime = Utility.GetCurrentRealTime() - fMonitorStartTime
	float avgStepRate = 0.0
	if totalTime > 0.0
		avgStepRate = totalFootstepCount / totalTime
	endif
	Debug.Trace("AutoWalk: [MONITOR] Stopped. Total Walking Time: " + totalTime + "s, Total Steps: " + totalFootstepCount + ", Avg Steps/Sec: " + avgStepRate, 1)
EndFunction

Function ResetFootstepCheckPhase()
	iFootstepCheckPhase = 0
	fFootstepCheckStartTime = 0.0
EndFunction

Event OnAnimationEvent(ObjectReference akSource, string asEventName)
	float currentTime = Utility.GetCurrentRealTime()
	float timeSinceLastStep = currentTime - lastFootstepTime

	bool bIsAlternating = true
	if lastFootstep == asEventName
		bIsAlternating = false
		currentNotAlternatingCount += 1
	endif

	if asEventName == "FootLeft" || asEventName == "footLeft"
		currentSampleLeftFootsteps += 1
	elseif asEventName == "FootRight" || asEventName == "footRight"
		currentSampleRightFootsteps += 1
	endif

	totalFootstepCount += 1
	lastFootstep = asEventName
	lastFootstepTime = currentTime

	; Debug.Trace("AutoWalk: [FOOTSTEP] Event=" + asEventName + \
	; 			" | DeltaTime=" + timeSinceLastStep + "s" + \
	; 			" | Alternating=" + bIsAlternating + \
	; 			" | LeftSteps=" + currentSampleLeftFootsteps + \
	; 			" | RightSteps=" + currentSampleRightFootsteps + \
	; 			" | NotAlternatingCount=" + currentNotAlternatingCount, 1)
EndEvent

int EXECUTE_SAMPLE_RESULT_CONTINUE = -1 const
int EXECUTE_SAMPLE_RESULT_JITTER_DETECTED = 1 const
int EXECUTE_SAMPLE_RESULT_WALK_SPEED_CHANGED = 2 const
int EXECUTE_SAMPLE_RESULT_FOOTSTEP_CHECKS_COMPLETE = 4 const

; ------------------------------------------------------------------------------
; 디버그: 사용자가 화면에서 지터("Crazy Dance")를 시각적으로 인지한 순간 MCM 핫키로 호출됨.
; ExecuteSample()이 매 틱 찍는 [JITTER] 요약 라인은 이동평균이라 어느 순간에 뭐가 어긋났는지
; 알기 어렵고, 반응 지연 때문에 "지금 이 순간"만 찍어봐야 진짜 원인 프레임은 이미 지나가 있는
; 경우가 많다. 그래서 여기서는 현재 sampleHistory 링버퍼(최근 iSampleHistorySize개 원시 샘플)를
; 오래된 것부터 순서대로 통째로 덤프해서, 나중에 로그만 보고도 그 순간의 개별 발자국/애니속도
; 변화를 재구성할 수 있게 한다.
function MarkJitterObserved()
	Debug.Notification("AutoWalk: Jitter mark recorded.")
	Debug.Trace("AutoWalk: [JITTER-MARK] ===== User-observed jitter ===== WalkSpeed=" + AutoWalkScript.WalkSpeed + \
				", IsSneaking=" + PlayerRef.IsSneaking() + ", IsRunning=" + PlayerRef.IsRunning() + \
				", bOverEncumbered=" + bOverEncumbered + ", iFootstepCheckPhase=" + iFootstepCheckPhase + \
				", validSampleCount=" + validSampleCount, 1)

	if validSampleCount == 0
		Debug.Trace("AutoWalk: [JITTER-MARK] No samples collected yet, nothing to dump.", 1)
		return
	endIf

	; Ring buffer를 오래된 샘플 -> 최신 샘플 순서로 정렬해서 출력한다.
	int count = validSampleCount
	int oldestIndex = (sampleHistoryIndex - count + iSampleHistorySize) % iSampleHistorySize
	int i = 0
	while i < count
		int idx = (oldestIndex + i) % iSampleHistorySize
		MonitorData s = sampleHistory[idx]
		Debug.Trace("AutoWalk: [JITTER-MARK] #" + i + \
					" t=" + s.sampleTime + \
					" distance=" + s.distance + \
					" speed=" + s.speed + \
					" yawDelta=" + s.yawDelta + \
					" animSpeed=" + s.animSpeed + \
					" footL=" + s.footstepsLeft + \
					" footR=" + s.footstepsRight + \
					" limpCount=" + s.limpCount + \
					" runModeMismatch=" + s.runModeMismatch, 1)
		i += 1
	endWhile
endFunction

; return 0: continue monitoring, 1: jitter detected, 2: restart monitoring (WalkSpeed changed), 3: footstep checks complete, restore WalkSpeed
MonitorResult Function ExecuteSample(int walkSpeed, bool bIsSneaking, bool bIsRunning)
	MonitorResult result = new MonitorResult
	result.resultCode = EXECUTE_SAMPLE_RESULT_CONTINUE
	result.newWalkSpeed = walkSpeed

	; 물속(수영)에서는 발자국 이벤트가 발생하지 않으므로 발자국 검사/지터 판정을 건너뛴다.
	; 상태 전환 시 샘플 히스토리를 비워 물 밖으로 나온 직후 이전(물속) 샘플 때문에 오판정하지 않도록 한다.
	; TODO: 물속 테스트
	;TODO: 메뉴모드에서도 체크 재시작
	if SUP_F4SE.ActorIsSwimming(PlayerRef)
		if !bLastSampleSwimming
			Debug.Trace("AutoWalk: [MONITOR] Player swimming, skipping footstep checks.", 1)
			bLastSampleSwimming = true
			ResetPositionHistory()
			ResetFootstepCounters()
			validSampleCount = 0
			sampleHistoryIndex = 0
		endif
		return result
	else
		if bLastSampleSwimming
			Debug.Trace("AutoWalk: [MONITOR] Player left water, resuming footstep checks.", 1)
			bLastSampleSwimming = false
			ResetPositionHistory()
			ResetFootstepCounters()
			validSampleCount = 0
			sampleHistoryIndex = 0
		endif
	endif

	; 과적 상태에서는 WalkSpeed 0이 강제되므로, WalkSpeed 0을 기준으로 샘플 수집/지터 판정/발자국 진단을
	; 계속 진행한다. 과적 이동은 일반 걷기와 발자국 rate가 다를 수 있지만 강제된 WalkSpeed 0을 기준으로
	; 삼으면 동일한 기준이므로, _ProcessFootstepCheck()가 1/2/3 속도로 진행하지 못하게만 막으면 된다.
	if bOverEncumbered
		walkSpeed = 0
	endif

	if iLastCheckedWalkSpeed != walkSpeed
		ResetPositionHistory()
		ResetFootstepCounters()
		validSampleCount = 0
		sampleHistoryIndex = 0
		iLastCheckedWalkSpeed = walkSpeed
	endif

	MonitorData currentSample = CollectSample()
	if currentSample == None
		return result
	endif

	; 히스토리 배열에 샘플 저장 (Ring Buffer)
	int currentSampleIndex = sampleHistoryIndex
	sampleHistory[sampleHistoryIndex] = currentSample
	sampleHistoryIndex = (sampleHistoryIndex + 1) % iSampleHistorySize
	if validSampleCount < iSampleHistorySize
		validSampleCount += 1
	endif

	; 이동평균 계산 (Moving Average)
	float sumAnimSpeed = 0.0
	float sumSpeed = 0.0
	float sumDistance = 0.0
	float sumYawDelta = 0.0
	int sumLeftFootsteps = 0
	int sumRightFootsteps = 0
	int sumLimpCount = 0
	float sumRunModeMismatch = 0.0

	int i = 0
	while i < validSampleCount
		sumAnimSpeed += sampleHistory[i].animSpeed
		sumSpeed += sampleHistory[i].speed
		sumDistance += sampleHistory[i].distance
		sumYawDelta += sampleHistory[i].yawDelta
		sumLeftFootsteps += sampleHistory[i].footstepsLeft
		sumRightFootsteps += sampleHistory[i].footstepsRight
		sumLimpCount += sampleHistory[i].limpCount
		sumRunModeMismatch += sampleHistory[i].runModeMismatch as float
		i += 1
	endWhile

	float avgAnimSpeed = sumAnimSpeed / validSampleCount
	float avgRunModeMismatch = sumRunModeMismatch / validSampleCount
	float avgLimpCount = sumLimpCount as float / validSampleCount

	if validSampleCount < iSampleHistorySize
		;Debug.Trace("AutoWalk: [MONITOR] Not enough samples for moving average. Current count: " + validSampleCount + ", required: " + iSampleHistorySize, 1)
		return result
	endif

	; 초당 평균 발자국 이벤트 수
	int newestIndex = (sampleHistoryIndex - 1 + iSampleHistorySize) % iSampleHistorySize
	int oldestIndex = (sampleHistoryIndex - validSampleCount + iSampleHistorySize) % iSampleHistorySize

	float newestTime = sampleHistory[newestIndex].sampleTime
	float oldestTime = sampleHistory[oldestIndex].sampleTime
	float totalWindowTime = newestTime - oldestTime

	float leftRatePerSec = 0.0
	float rightRatePerSec = 0.0
	float distancePerSec = 0.0
	float yawDeltaPerSec = 0.0
	if totalWindowTime > 0.0
		leftRatePerSec = sumLeftFootsteps as float / totalWindowTime
		rightRatePerSec = sumRightFootsteps as float / totalWindowTime
		distancePerSec = sumDistance / totalWindowTime
		yawDeltaPerSec = sumYawDelta / totalWindowTime
		; Use total traveled distance over the whole window rather than summing per-sample speeds again.
	endif

	Debug.Trace("AutoWalk: [JITTER] samples=" + validSampleCount + \
				" | AvgAnimSpeed=" + avgAnimSpeed + \
				" | YawDeltaPerSec=" + yawDeltaPerSec + \
				" | DistancePerSec=" + distancePerSec + \
				" | AvgRunModeMismatch=" + avgRunModeMismatch + \
				" | AvgLimpCount=" + avgLimpCount + \
				" | LeftRatePerSec=" + leftRatePerSec + \
				" | RightRatePerSec=" + rightRatePerSec + \
				" | IsRunning=" + bIsRunning + \
				" | WalkSpeed=" + walkSpeed, 1)

	float minExpectedFootstepRate = 0.0
	bool bIsSupportedAnim = false
	; 0=walk, 1=fast walk, 2=jog, 3=run
	if bIsSneaking == false
		if walkSpeed >= 0 && walkSpeed <= 3
			bIsSupportedAnim = IsFootstepSupported(walkSpeed)
			minExpectedFootstepRate = GetExpectedFootstepRate(walkSpeed)
		endif
	endif

	; WalkSpeed 0~3 모두 발자국 이벤트 체크
	if bIsSupportedAnim
		if rightRatePerSec == 0.0 || leftRatePerSec == 0.0
			Debug.Trace("AutoWalk: [JITTER] Detected potential jittering due to zero footstep events. LeftRatePerSec=" + \
			 			leftRatePerSec + ", RightRatePerSec=" + rightRatePerSec + \
						", sumLeftFootsteps=" + sumLeftFootsteps + ", sumRightFootsteps=" + sumRightFootsteps, 1)
			result.resultCode = EXECUTE_SAMPLE_RESULT_JITTER_DETECTED
			return result
		endif

		if avgLimpCount > 0.3
			Debug.Trace("AutoWalk: [JITTER] Detected potential jittering due to excessive non-alternating footsteps. AvgLimpCount=" + avgLimpCount + \
						", sumLeftFootsteps=" + sumLeftFootsteps + ", sumRightFootsteps=" + sumRightFootsteps, 1)
			result.resultCode = EXECUTE_SAMPLE_RESULT_JITTER_DETECTED
			return result
		endif

		if (leftRatePerSec < minExpectedFootstepRate || rightRatePerSec < minExpectedFootstepRate)
			Debug.Trace("AutoWalk: [JITTER] Detected potential jittering due to insufficient footstep events. LeftRatePerSec=" + \
			 			leftRatePerSec + ", RightRatePerSec=" + rightRatePerSec + \
						", sumLeftFootsteps=" + sumLeftFootsteps + ", sumRightFootsteps=" + sumRightFootsteps, 1)
			result.resultCode = EXECUTE_SAMPLE_RESULT_JITTER_DETECTED
			return result
		endif

		float ratio = 0.0
		if leftRatePerSec > rightRatePerSec
			if leftRatePerSec > 0.0
				ratio = rightRatePerSec / leftRatePerSec
			endif
		else
			if rightRatePerSec > 0.0
				ratio = leftRatePerSec / rightRatePerSec
			endif
		endif

		if ratio < 0.4 && (leftRatePerSec > 0.0 || rightRatePerSec > 0.0)
			Debug.Trace("AutoWalk: [JITTER] Detected potential jittering due to uneven footstep events. LeftRatePerSec=" + \
						 leftRatePerSec + ", RightRatePerSec=" + rightRatePerSec + ", ratio=" + ratio, 1)
			result.resultCode = EXECUTE_SAMPLE_RESULT_JITTER_DETECTED
			return result
		endif
	else
		if iFootstepCheckPhase > 0
			; 지원여부를 알기 전인 진단 단계부터 footstep이 0이 나온다면 일단 ResetPathing을 해본다.
			if rightRatePerSec == 0.0 || leftRatePerSec == 0.0
				Debug.Trace("AutoWalk: [JITTER] Detected potential jittering while checking footstep capabilities. LeftRatePerSec=" + \
							leftRatePerSec + ", RightRatePerSec=" + rightRatePerSec + \
							", sumLeftFootsteps=" + sumLeftFootsteps + ", sumRightFootsteps=" + sumRightFootsteps, 1)
				result.resultCode = EXECUTE_SAMPLE_RESULT_JITTER_DETECTED
				return result
			endif
			if avgLimpCount > 0.25
				Debug.Trace("AutoWalk: [JITTER] Detected potential jittering while checking footstep capabilities due to excessive non-alternating footsteps. AvgLimpCount=" + avgLimpCount + \
							", sumLeftFootsteps=" + sumLeftFootsteps + ", sumRightFootsteps=" + sumRightFootsteps, 1)
				result.resultCode = EXECUTE_SAMPLE_RESULT_JITTER_DETECTED
				return result
			endif
		endif
	endif

	int jitterCase = 0
	float absoluteAnimSpeed = Math.Abs(avgAnimSpeed)
	if absoluteAnimSpeed > 0.0
		float walkSpeedRatio = distancePerSec / absoluteAnimSpeed
		if walkSpeedRatio < 0.3
			jitterCase = 1
		elseif walkSpeedRatio > 2.0
			jitterCase = 2
		endif
	endif

	; TODO: runmode mismatch 유용?
	; if avgRunModeMismatch > 0.9
	; 	jitterCase = 6 ; run mode mismatch detected
	; endif

	; TODO: 학습데이터 확보된 경우 좀더 엄격한 체크


	; TODO: unusual yaw change detection
	; if avgYawDelta > JitterYawThreshold
	; 	jitteringCase = 4 ; unusual yaw change detected
	; endif

	; if avgDistance < JitterDistanceThreshold
	; 	jitteringCase = 5 ; actual distance moved is too small
	; endif

	if jitterCase > 0
		if bIsSneaking == false
			Debug.Trace("AutoWalk: [JITTER] Detected potential jittering. jitterCase=" + jitterCase + ", LeftRatePerSec=" + leftRatePerSec + ", RightRatePerSec=" + rightRatePerSec + ", DistancePerSec=" + distancePerSec + ", YawDeltaPerSec=" + yawDeltaPerSec + ", AvgLimpCount=" + avgLimpCount, 1)
			Debug.Notification("AutoWalk: Jittering detected!: case " + jitterCase)
			result.resultCode = EXECUTE_SAMPLE_RESULT_JITTER_DETECTED
			return result
		else
			Debug.Trace("AutoWalk: [JITTER] Detected potential jittering, but player is sneaking. not supported yet. jitterCase=" + jitterCase + ", LeftRatePerSec=" + leftRatePerSec + ", RightRatePerSec=" + rightRatePerSec + ", DistancePerSec=" + distancePerSec + ", YawDeltaPerSec=" + yawDeltaPerSec, 1)
		endif
	endif

	; Footstep capability check
	int footstepResultCode = _ProcessFootstepCheck(walkSpeed, bIsRunning, distancePerSec, yawDeltaPerSec, leftRatePerSec, rightRatePerSec, currentSampleIndex)
	if footstepResultCode >= 0 && footstepResultCode <= 3
		result.resultCode = EXECUTE_SAMPLE_RESULT_WALK_SPEED_CHANGED
		result.newWalkSpeed = footstepResultCode
		return result
	elseif footstepResultCode == 4
		result.resultCode = EXECUTE_SAMPLE_RESULT_FOOTSTEP_CHECKS_COMPLETE
		return result
	endif

	return result
EndFunction

; ------------------------------------------------------------------------------
; Internal Functions
; ------------------------------------------------------------------------------

; Footstep check helpers for WalkSpeed 0~3
string Function GetFootstepAnimationName(int walkSpeed)
	if walkSpeed == 0
		return "WALK"
	elseif walkSpeed == 1
		return "FASTWALK"
	elseif walkSpeed == 2
		return "JOG"
	elseif walkSpeed == 3
		return "RUN"
	endif
	return "UNKNOWN"
EndFunction

float Function GetExpectedFootstepRate(int walkSpeed)
	if walkSpeed == 0
		return fExpectedWalkFootstepRate
	elseif walkSpeed == 1
		return fExpectedFastWalkFootstepRate
	elseif walkSpeed == 2
		return fExpectedJogFootstepRate
	elseif walkSpeed == 3
		return fExpectedRunFootstepRate
	endif
	return 0.0
EndFunction

; TODO: 실측데이터 수집
float Function GetFootstepCheckMinDistance(int walkSpeed)
	if walkSpeed == 0
		return 20.0
	elseif walkSpeed == 1
		return 40.0
	elseif walkSpeed == 2
		return 60.0
	elseif walkSpeed == 3
		return 80.0
	endif
	return 0.0
EndFunction

bool Function GetExpectedRunning(int walkSpeed, bool forInputLayer = false)
	;함정: fast walk, jogg가 가능하기 위해서는 InputEnableLayer.EnableRunning(true)로 설정되어 있어야 한다.
	;     그렇지만 PlayerRef.IsRunning()는 false로 나온다.
	if walkSpeed == 0
		return false
	elseif walkSpeed == 1
		if forInputLayer
			return true
		else
			return false
		endif
	elseif walkSpeed == 2
		if forInputLayer
			return true
		else
			return false
		endif
	elseif walkSpeed == 3
		return true
	endif
	return false
EndFunction

bool Function IsFootstepCheckDone(int walkSpeed)
	if walkSpeed == 0
		return bWalkFootstepChecked
	elseif walkSpeed == 1
		return bFastWalkFootstepChecked
	elseif walkSpeed == 2
		return bJogFootstepChecked
	elseif walkSpeed == 3
		return bRunFootstepChecked
	endif
	return false
EndFunction

bool Function IsFootstepSupported(int walkSpeed)
	if walkSpeed == 0
		return bWalkFootstepSupported
	elseif walkSpeed == 1
		return bFastWalkFootstepSupported
	elseif walkSpeed == 2
		return bJogFootstepSupported
	elseif walkSpeed == 3
		return bRunFootstepSupported
	endif
	return false
EndFunction

int Function FindNextUncheckedFootstepSpeed(int startIndex)
	int i = startIndex
	while i < 4
		if !IsFootstepCheckDone(i)
			return i
		endif
		i += 1
	endWhile
	return -1
EndFunction

Function SaveFootstepCheckResult(int walkSpeed)
	string resultStr = "Unknown"
	if walkSpeed == 0
		SUP_F4SE.ModLocalDataSetInt("Mors:AutoWalk", "bWalkFootstepChecked", bWalkFootstepChecked as int)
		SUP_F4SE.ModLocalDataSetInt("Mors:AutoWalk", "bWalkFootstepSupported", bWalkFootstepSupported as int)
	elseif walkSpeed == 1
		SUP_F4SE.ModLocalDataSetInt("Mors:AutoWalk", "bFastWalkFootstepChecked", bFastWalkFootstepChecked as int)
		SUP_F4SE.ModLocalDataSetInt("Mors:AutoWalk", "bFastWalkFootstepSupported", bFastWalkFootstepSupported as int)
	elseif walkSpeed == 2
		SUP_F4SE.ModLocalDataSetInt("Mors:AutoWalk", "bJogFootstepChecked", bJogFootstepChecked as int)
		SUP_F4SE.ModLocalDataSetInt("Mors:AutoWalk", "bJogFootstepSupported", bJogFootstepSupported as int)
	elseif walkSpeed == 3
		SUP_F4SE.ModLocalDataSetInt("Mors:AutoWalk", "bRunFootstepChecked", bRunFootstepChecked as int)
		SUP_F4SE.ModLocalDataSetInt("Mors:AutoWalk", "bRunFootstepSupported", bRunFootstepSupported as int)
	endif
EndFunction

Function ResetFootstepCheckResults()
	bWalkFootstepChecked = false
	bFastWalkFootstepChecked = false
	bJogFootstepChecked = false
	bRunFootstepChecked = false
	bWalkFootstepSupported = false
	bFastWalkFootstepSupported = false
	bJogFootstepSupported = false
	bRunFootstepSupported = false
EndFunction

bool Function AreAllFootstepChecksDone()
	return bWalkFootstepChecked && bFastWalkFootstepChecked && bJogFootstepChecked && bRunFootstepChecked
EndFunction

Function ResetPositionHistory()
	lastPositionX = PlayerRef.GetPositionX()
	lastPositionY = PlayerRef.GetPositionY()
	lastPositionZ = PlayerRef.GetPositionZ()
	lastPositionYaw = PlayerRef.GetAngleZ()
	lastSampleTime = Utility.GetCurrentRealTime()
	sampleHistory = new MonitorData[iSampleHistorySize]
	sampleHistoryIndex = 0
	validSampleCount = 0
	Debug.Trace("AutoWalk: [MONITOR] Player Position History Reset.", 1)
EndFunction

Function ResetFootstepCounters()
	totalFootstepCount = 0
	lastFootstep = ""
	lastFootstepTime = 0.0
	currentSampleLeftFootsteps = 0
	currentSampleRightFootsteps = 0
	currentNotAlternatingCount = 0
	Debug.Trace("AutoWalk: [MONITOR] Footstep Counters Reset.", 1)
EndFunction

float Function _GetAngularDistance(float currentYaw, float lastYaw)
	float diff = currentYaw - lastYaw

	while diff > 180.0
		diff -= 360.0
	endWhile
	while diff < -180.0
		diff += 360.0
	endWhile

	return Math.Abs(diff)
EndFunction

MonitorData Function CollectSample()
	float currentTime = Utility.GetCurrentRealTime()
	float deltaTime = currentTime - lastSampleTime

	if deltaTime <= 0.0
		Debug.Trace("AutoWalk: [MONITOR] Time difference is zero or negative. deltaTime=" + deltaTime + ", lastSampleTime=" + lastSampleTime + ", currentTime=" + currentTime, 1)
		return None
	endif

	float currentX = PlayerRef.GetPositionX()
	float currentY = PlayerRef.GetPositionY()
	float currentZ = PlayerRef.GetPositionZ()
	float currentYaw = PlayerRef.GetAngleZ()

	if deltaTime > fMonitorInterval * 3.0
		Debug.Trace("AutoWalk: [MONITOR] Abnormal deltaTime detected: " + deltaTime + "s, resetting sample history.", 1)
		lastPositionX = currentX
		lastPositionY = currentY
		lastPositionZ = currentZ
		lastPositionYaw = currentYaw
		lastSampleTime = currentTime
		currentSampleLeftFootsteps = 0
		currentSampleRightFootsteps = 0
		currentNotAlternatingCount = 0
		return None
	endif

	MonitorData sample = new MonitorData

	float deltaX = currentX - lastPositionX
	float deltaY = currentY - lastPositionY
	float deltaZ = currentZ - lastPositionZ
	float actualDistance = Math.sqrt(deltaX*deltaX + deltaY*deltaY)
	float actualSpeed = actualDistance / deltaTime

	float yawDelta = _GetAngularDistance(currentYaw, lastPositionYaw)
	float animSpeed = PlayerRef.GetAnimationVariableFloat("Speed")

	sample.distance = actualDistance
	sample.animSpeed = animSpeed
	sample.speed = actualSpeed
	sample.yawDelta = yawDelta
	sample.footstepsLeft = currentSampleLeftFootsteps
	sample.footstepsRight = currentSampleRightFootsteps
	sample.limpCount = currentNotAlternatingCount
	sample.runModeMismatch = PlayerRef.IsRunning() != GetExpectedRunning(AutoWalkScript.WalkSpeed)
	sample.sampleTime = currentTime

	;Debug.Trace("AutoWalk: [MONITOR] Sample Collected: distance=" + actualDistance + ", speed=" + actualSpeed + ", yawDelta=" + yawDelta + ", animSpeed=" + animSpeed + ", footstepsLeft=" + currentSampleLeftFootsteps + ", footstepsRight=" + currentSampleRightFootsteps + ", runModeMismatch=" + sample.runModeMismatch + ", limpCount=" + sample.limpCount, 1)
	currentSampleLeftFootsteps = 0
	currentSampleRightFootsteps = 0
	currentNotAlternatingCount = 0

	lastPositionX = currentX
	lastPositionY = currentY
	lastPositionZ = currentZ
	lastPositionYaw = currentYaw
	lastSampleTime = currentTime

	return sample
EndFunction

; FootstepCheckDuration 동안 minExpectedFootstepRate 이하로 떨어진 적이 없으면 footstep 이벤트를 지원하는 것으로 판단
var[] Function _CheckFootstep(float leftRatePerSec, float rightRatePerSec, float minExpectedFootstepRate)
	var[] result = new var[2]
	result[0] = False	; bChecked
	result[1] = False	; bFootstepSupported

	if validSampleCount < 2; 이미 ExecuteSample()에서 체크를 하고 있지만 newestIndex/secondNewestIndex 참조 오류를 차단한다는 의미
		Debug.Trace("AutoWalk: [_CheckFootstep] Not enough samples for footstep check. validSampleCount=" + validSampleCount + ", required=" + iSampleHistorySize, 1)
		return result
	endif

	string walkRunAnimationName = GetFootstepAnimationName(iLastCheckedWalkSpeed)

	if Utility.GetCurrentRealTime() - fFootstepCheckStartTime >= fFootstepCheckDuration; TODO: 조건 추가 '실제 타당한 거리를 이동을 했을 경우에만'
		result[0] = true
		if leftRatePerSec >= minExpectedFootstepRate && rightRatePerSec >= minExpectedFootstepRate
			result[1] = true
			Debug.Trace("AutoWalk: [_CheckFootstep] Footstep check passed. WalkSpeed=" + iLastCheckedWalkSpeed + ", LeftRate=" + leftRatePerSec + ", RightRate=" + rightRatePerSec, 1)
		else
			result[1] = false
			Debug.Notification("AutoWalk: " + walkRunAnimationName + " animation does not support footstep event.")
		endif
	endif

	int newestIndex = (sampleHistoryIndex - 1 + iSampleHistorySize) % iSampleHistorySize
	int secondNewestIndex = (sampleHistoryIndex - 2 + iSampleHistorySize) % iSampleHistorySize
	if (sampleHistory[newestIndex].distance < 1.0 || sampleHistory[secondNewestIndex].distance < 1.0)
		result[0] = false; 체크 실패로 판단. 다음 타이머 틱에서 다시 체크하거나 ExecuteSample()에서 EXECUTE_SAMPLE_RESULT_JITTER_DETECTED -> ResetPathing() 후 샘플링 재시작 후 다시 체크. TODO: 이걸로 이동평균에 징후가 나타나기 전 감지하여 오염방지 할 수 있는지 확인
		result[1] = false
		Debug.Trace("AutoWalk: [_CheckFootstep] Footstep check failed due to insufficient movement. WalkSpeed=" + iLastCheckedWalkSpeed + ", LeftRate=" + leftRatePerSec + ", RightRate=" + rightRatePerSec, 1)
		Debug.Notification("AutoWalk: " + walkRunAnimationName + " animation check failed due to insufficient movement.")
	elseif leftRatePerSec < minExpectedFootstepRate || rightRatePerSec < minExpectedFootstepRate
		result[0] = true
		result[1] = false
		Debug.Trace("AutoWalk: [_CheckFootstep] Footstep check failed. WalkSpeed=" + iLastCheckedWalkSpeed + ", LeftRate=" + leftRatePerSec + ", RightRate=" + rightRatePerSec, 1)
	endif

	return result
EndFunction

; return -1: continue, 0-3: restart monitoring with new WalkSpeed, 4: footstep checks complete, restore WalkSpeed
int Function _ProcessFootstepCheck(int walkSpeed, bool bIsRunning, float distancePerSec, float yawDeltaPerSec, float leftRatePerSec, float rightRatePerSec, int currentSampleIndex)
	if iFootstepCheckPhase == 0
		return EXECUTE_SAMPLE_RESULT_CONTINUE
	endif

	; 과적 중에는 WalkSpeed 0 외의 속도로 진단을 진행하지 않는다. (걷기는 그 속도에서 가능)
	if bOverEncumbered && walkSpeed != 0
		return EXECUTE_SAMPLE_RESULT_CONTINUE
	endif

	if iFootstepCheckPhase > 0 && fFootstepCheckStartTime > 0.0
		float elapsed = Utility.GetCurrentRealTime() - fFootstepCheckStartTime
		if elapsed > fFootstepCheckDuration * 2.0
			Debug.Trace("AutoWalk: [MONITOR] Footstep check interrupted by pause, resetting.", 1)
			fFootstepCheckStartTime = 0.0
			iFootstepCheckPhase = 0
			ResetFootstepCheckResults()
		endif
	endif

	if iFootstepCheckPhase == 1
		float minDistance = GetFootstepCheckMinDistance(walkSpeed)
		if distancePerSec >= minDistance && yawDeltaPerSec < 10.0
			if bIsRunning == GetExpectedRunning(walkSpeed)
				string walkRunAnimationName = GetFootstepAnimationName(walkSpeed)
				Debug.Notification("AutoWalk: Footstep check in progress, please wait...")
				iFootstepCheckPhase = 2
				Debug.Trace("AutoWalk: [MONITOR] Footstep check started for WalkSpeed=" + walkSpeed + ". MinDistance=" + minDistance + ", DistancePerSec=" + distancePerSec + ", YawDeltaPerSec=" + yawDeltaPerSec, 1)
			else
				Debug.Trace("AutoWalk: [MONITOR] Footstep check skipped due to unexpected player state. WalkSpeed=" + walkSpeed + ", IsRunning=" + bIsRunning + ", ExpectedRunning=" + GetExpectedRunning(walkSpeed), 1)
				Debug.Notification("AutoWalk: Unable to detect footstep. Conflicting mod?")
				iFootstepCheckPhase = 0
			endif
		endif
		return EXECUTE_SAMPLE_RESULT_CONTINUE
	endif

	if iFootstepCheckPhase == 2
		if !IsFootstepCheckDone(walkSpeed)
			if fFootstepCheckStartTime == 0.0
				fFootstepCheckStartTime = Utility.GetCurrentRealTime()
			endif
			var[] footstepCheckResult = _CheckFootstep(leftRatePerSec, rightRatePerSec, GetExpectedFootstepRate(walkSpeed))
			if walkSpeed == 0
				bWalkFootstepChecked = footstepCheckResult[0]
				bWalkFootstepSupported = footstepCheckResult[1]
			elseif walkSpeed == 1
				bFastWalkFootstepChecked = footstepCheckResult[0]
				bFastWalkFootstepSupported = footstepCheckResult[1]
			elseif walkSpeed == 2
				bJogFootstepChecked = footstepCheckResult[0]
				bJogFootstepSupported = footstepCheckResult[1]
			elseif walkSpeed == 3
				bRunFootstepChecked = footstepCheckResult[0]
				bRunFootstepSupported = footstepCheckResult[1]
			endif
			if footstepCheckResult[0]
				; 과적 중 측정된 진단 결과는 정상 걷기와 기준이 다를 수 있으므로
				; ModLocalData에 영구 저장하지 않는다. (메모리 플래그는 이번 걷기 세션에만 사용)
				if bOverEncumbered
					Debug.Trace("AutoWalk: [MONITOR] Not persisting footstep check result measured while overencumbered.", 1)
				else
					SaveFootstepCheckResult(walkSpeed)
				endif
				string resultStr = "Unknown"
				if IsFootstepSupported(walkSpeed)
					resultStr = "Supported"
				else
					resultStr = "Not Supported"
				endif
				Debug.Notification("AutoWalk: Footstep check result for " + GetFootstepAnimationName(walkSpeed) + ": " + resultStr)
				fFootstepCheckStartTime = 0.0
				if bOverEncumbered
					; 과적 중에는 WalkSpeed 0만 유효하므로 이후 속도로 전진하지 않고 진단을 종료한다.
					Debug.Trace("AutoWalk: [MONITOR] Overencumbered, stopping footstep check sequence after WalkSpeed 0.", 1)
					iFootstepCheckPhase = 3
				else
					int nextSpeed = FindNextUncheckedFootstepSpeed(walkSpeed + 1)
					if nextSpeed >= 0
						return nextSpeed
					else
						iFootstepCheckPhase = 3
					endif
				endif
			else
			endif
		else
			; already checked while in phase 2 (shouldn't happen); advance to next unchecked
			fFootstepCheckStartTime = 0.0
			if bOverEncumbered
				iFootstepCheckPhase = 3
			else
				int nextSpeed = FindNextUncheckedFootstepSpeed(walkSpeed + 1)
				if nextSpeed >= 0
					return nextSpeed
				else
					iFootstepCheckPhase = 3
				endif
			endif
		endif
		return EXECUTE_SAMPLE_RESULT_CONTINUE
	endif

	if iFootstepCheckPhase == 3
		iFootstepCheckPhase = 0
		return EXECUTE_SAMPLE_RESULT_FOOTSTEP_CHECKS_COMPLETE
	endif

	return EXECUTE_SAMPLE_RESULT_CONTINUE 
EndFunction

Event OnTimer(int timerID)
	if timerID == TIMER_MONITOR_JITTER
		; 과적 안전망 폴링: OnItemAdded/OnItemRemoved 이벤트만으로는 다른 모드 디버프가 CarryWeight 임계값을
		; 바꾸는 경우를 감지하지 못하므로, 걷는 동안엔 fEncumbranceCheckInterval마다 한 번씩만 재계산한다.
		; 여기서의 비교는 단순 시간 차이라 매 틱 저렴하고, GetInventoryWeight()는 간격마다만 호출된다.
		if iFootstepCheckPhase == 0
			float now = Utility.GetCurrentRealTime()
			if LastEncumbranceCheckTime < 0.0 || now - LastEncumbranceCheckTime >= fEncumbranceCheckInterval
				LastEncumbranceCheckTime = now
				CheckEncumbranceState()
			endif
		endif
		MonitorResult result = ExecuteSample(AutoWalkScript.WalkSpeed, PlayerRef.IsSneaking(), PlayerRef.IsRunning())
		int rc = result.resultCode
		if rc == EXECUTE_SAMPLE_RESULT_JITTER_DETECTED
			Debug.Trace("AutoWalk: OnTimer: Jitter detected! Call ResetPathing(): TryCount=" + ResetPathingTryCount, 1)
			; 마지막 재시도로부터 MinResetPathingInterval 이상 지났으면 누적 카운트를 초기화한다.
			; 같은 에스컬레이션 상황 안에서만 카운트가 의미 있으므로, 간격이 지난 뒤의 지터는 새로 시작된 문제로 본다.
			if Utility.GetCurrentRealTime() - LastResetPathingTime >= MinResetPathingInterval
				ResetPathingTryCount = 0
			endif
			if Utility.GetCurrentRealTime() - LastResetPathingTime < MinResetPathingInterval && ResetPathingTryCount >= MaxResetPathingTryCount
				Debug.Trace("AutoWalk: OnTimer: Max ResetPathingTryCount reached. giving up.", 1)
				if AutoWalkScript.IsWalking()
					var[] eventData = new var[1]
					eventData[0] = "NavigationFailure"
					SendCustomEvent("MonitoringStopped", eventData)
				endif
				StopMonitoring()
			else
				StopMonitoring()
				ResetPathingTryCount += 1
				Debug.Trace("AutoWalk: OnTimer: ResetPathingTryCount=" + ResetPathingTryCount, 1)
				LastResetPathingTime = Utility.GetCurrentRealTime()
				ResetPathing(true, false)
				if AutoWalkScript.IsWalking()
					StartMonitoring()
				endif
			endif
		elseif rc == EXECUTE_SAMPLE_RESULT_CONTINUE
			if AutoWalkScript.IsWalking()
				StartTimer(fMonitorInterval, TIMER_MONITOR_JITTER)
			else
				Debug.Trace("AutoWalk: OnTimer: Stopping jitter monitor: bWalking=false before StopJitterMonitor()?", 1)
				StopMonitoring()
			endif
		elseif rc == EXECUTE_SAMPLE_RESULT_WALK_SPEED_CHANGED
			AutoWalkScript.WalkSpeed = result.newWalkSpeed
			Debug.Trace("AutoWalk: OnTimer: WalkSpeed changed during footstep check: newWalkSpeed=" + result.newWalkSpeed + ". Restarting jitter monitor.", 1)
			if AutoWalkInputLayer != None
				if GetExpectedRunning(result.newWalkSpeed, true)
					Debug.Trace("AutoWalk: OnTimer: WalkSpeed changed to " + result.newWalkSpeed + ". Enabling running and sprinting.", 1)
					AutoWalkInputLayer.EnableRunning(true)
					AutoWalkInputLayer.EnableSprinting(true)
				else
					Debug.Trace("AutoWalk: OnTimer: WalkSpeed changed to " + result.newWalkSpeed + ". Disabling running and sprinting.", 1)
					AutoWalkInputLayer.EnableRunning(false)
					AutoWalkInputLayer.EnableSprinting(false)
				endif
			endif
			StopMonitoring()
			if AutoWalkScript.IsWalking()
				ResetPathing(false, false)
			endif
			if AutoWalkScript.IsWalking()
				StartMonitoring()
			endif
		elseif rc == EXECUTE_SAMPLE_RESULT_FOOTSTEP_CHECKS_COMPLETE
			Debug.Trace("AutoWalk: OnTimer: Footstep checks complete. Restoring WalkSpeed.", 1)
			Debug.Notification("AutoWalk: Footstep checks complete.")
			if bWalkSpeedRestoreScheduled
				Debug.Trace("AutoWalk: [MONITOR] Restoring WalkSpeed scheduled.", 1)
				StartTimer(0.1, TIMER_RESTORE_WALK_SPEED)
			endif
			if AutoWalkScript.IsWalking()
				StartTimer(fMonitorInterval, TIMER_MONITOR_JITTER)
			else
				StopMonitoring()
			endif
		endif
	elseif timerID == TIMER_RESTORE_WALK_SPEED
		bWalkSpeedRestoreScheduled = false
		if AutoWalkInputLayer != None
			Debug.Trace("AutoWalk: OnTimer: Deleting AutoWalkInputLayer", 1)
			AutoWalkInputLayer.EnableRunning(true)
			AutoWalkInputLayer.EnableSprinting(true)
			AutoWalkInputLayer.Delete()
			AutoWalkInputLayer = None
		endif
		if AutoWalkScript.WalkSpeed != WalkSpeedSave
			Debug.Trace("AutoWalk: OnTimer: Restoring WalkSpeed to " + WalkSpeedSave, 1)
			AutoWalkScript.WalkSpeed = WalkSpeedSave
			ResetPathing(force1stPerson = false, withIdle = false)
		else
			Debug.Trace("AutoWalk: OnTimer: WalkSpeed is already " + AutoWalkScript.WalkSpeed + ", no restoration needed.", 1)
		endif
	elseif timerID == TIMER_RESTORE_3RD_PERSON
		Debug.Trace("AutoWalk: OnTimer: Restoring 3rd person view", 1)
		if restoreWeaponDrawnState
			restoreWeaponDrawnState = false
			if playerref.IsWeaponDrawn()
				; Fallout4.esm의 RaiderSheath
				Idle lowerWeapon = Game.GetForm(0x00017ADD) as Idle
				if lowerWeapon
					playerref.PlayIdle(lowerWeapon)
				endif
			endif
		else
			Game.ForceThirdPerson()
			; GetCameraCurrentZoomOffset is None???
			;Debug.Notification("AutoWalk: After ForceThirdPerson: zoom=" + GardenOfEden2.GetCameraCurrentZoomOffset())
			Utility.Wait(0.1)
			ResetPathing(force1stPerson = false, withIdle = false)
		endif
	elseif timerID == TIMER_OVER_ENCUMBRANCE_CHECK
		Debug.Trace("AutoWalk: OnTimer: Checking over encumbrance...") 
		CheckEncumbranceState()
	endif
EndEvent

function ResetPathing(bool force1stPerson = false, bool withIdle = false)
	Debug.Trace("AutoWalk: ResetPathing(): Resetting pathing state: force1stPerson=" + force1stPerson + ", withIdle=" + withIdle, 1)
	Game.SetPlayerAIDriven(false)
	PlayerRef.EvaluatePackage(true)
	if withIdle
		PlayerRef.PlayIdle(IdleStop)
		Utility.Wait(0.5)
	endIf
	Game.SetPlayerAIDriven(true)
	bool restore3rdPerson = false
	if force1stPerson
		restore3rdPerson = GardenOfEden.Is3rdPersonVisible()
		if restore3rdPerson
			; GetCameraCurrentZoomOffset is None???
			; Debug.Notification("AutoWalk: Before ForceFirstPerson: zoom=" + GardenOfEden2.GetCameraCurrentZoomOffset())
		endif
		Game.ForceFirstPerson()
	endif
	PlayerRef.EvaluatePackage(true)
	if restore3rdPerson
		CancelTimer(TIMER_RESTORE_3RD_PERSON)
		StartTimer(3.0, TIMER_RESTORE_3RD_PERSON)
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
	   This can be called from a thread, but syncronization issues can occur.
	   ex) State can go to STOPPING while the thread is still running, and the function returns
	   trying to start walking again.
    4. PlayerRef.DrawWeapon() - no loading screen, smooth rotation. Path Finder will rotate the player to
	   face the destination automatically and perfectly. Settled on this approach finally.
	
	Reason for player rotation: If the player is facing the wrong direction in 3rd person when starting to walk,
	   jittering(Crazy Dance) can occur, and the player may not reach the destination.
/;