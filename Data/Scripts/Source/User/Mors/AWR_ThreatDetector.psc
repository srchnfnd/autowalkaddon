ScriptName Mors:AWR_ThreatDetector Extends Quest

Actor Property PlayerRef Auto Const Mandatory

; Variables used in the script to control lingering combat state
GlobalVariable Property AWR_StableFirstGV   Auto
GlobalVariable Property AWR_MaxFirstGV      Auto
GlobalVariable Property AWR_StableSecondGV  Auto
GlobalVariable Property AWR_MaxSecondGV     Auto
GlobalVariable property AWR_EnableCombatSettleTimersGV Auto

float AWR_StableFirst   = 6.0
float AWR_MaxFirst      = 25.0
float AWR_StableSecond  = 4.0
float AWR_MaxSecond     = 10.0
bool AWR_EnableCombatSettleTimers = true

Spell  Property AWR_ThreatSenseAbility Auto

; ----- Return codes (enum-like) -----
int Function AWR_WAIT_OK()
    Return 0 
EndFunction
int Function AWR_WAIT_TIMEOUT()
    Return 1 
EndFunction
int Function AWR_WAIT_INTERRUPTED() 
    Return 2
EndFunction

bool  AWR_ShowCombatWaitToasts = true ; may be property later
float AWR_CombatToastInterval  = 3.0 ; may be property later
float _lastToastRTS = 0.0
float _lastHitRTS = 0.0

float Property LastPingRTS = 0.0 Auto
float Property SpellCastIntervalSeconds = 1.5 Auto
Float Property PollIntervalSeconds = 0.5 Auto  ; how often to tick
Float Property StableSeconds       = 3.0  Auto  ; "soft clear" window (tunable)
Float Property MaxWaitSeconds      = 12.0 Auto  ; absolute timeout
; ---- Internal state ----
Bool  _waitActive
Float _startRTS
Float _lastCombatRTS

; Who to notify when finished
Quest  _cbQuest
String _cbFunc

; Timer ID
int TimerIDFirstPhase = 1324
int TimerIDSecondPhase = 2435
int TimerIDSpellCast = 9870

 ; RTS cutoff
Float _ignoreThreatsUntil = 0.0

Function _Log(string msg)
  ; Debug.TraceUser("AutoWalkRedux", msg) ; UserLog rotates too fast and ini settings no effect
  Debug.Trace("AutoWalkThreatDet: " + msg, 1)
EndFunction

Event OnQuestInit()
  RegisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")
  RegisterForExternalEvent("OnMCMOpen", "OnMCMOpen")
  RegisterForExternalEvent("OnMCMClose", "OnMCMClose")
  RegisterForHitEvent(PlayerRef)
  Debug.Trace("OnQuestInit() called.", 1)
EndEvent

Event OnInit()
  SUP_F4SE.RegisterForSUPEvent("OnPlayerMapMarkerStateChange", self as Form, "Mors:AutoWalkMarkerDB", "OnPlayerMapMarkerStateChange", true, false)
  ApplySettingsFromGlobals()
  _Log("OnInit() called.")
EndEvent

Function OnMCMOpen()
  
EndFunction

Function OnMCMClose()
  ApplySettingsFromGlobals()
EndFunction

Event OnHit(ObjectReference akTarget, ObjectReference akAggressor, Form akSource, Projectile akProjectile, bool abPowerAttack, bool abSneakAttack, bool abBashAttack, bool abHitBlocked, string apMaterial)
    _lastHitRTS = Utility.GetCurrentRealTime()
    _Log("AutoWalk: OnHit: akTarget=" + akTarget + ", akAggressor=" + akAggressor)
EndEvent

Event OnTimer(int timerID)

  if timerID == TimerIDSpellCast
    _Log("OnTimer: refreshing spell...")
    PlayerRef.RemoveSpell(AWR_ThreatSenseAbility)
    PlayerRef.AddSpell(AWR_ThreatSenseAbility, false)
    StartTimer(SpellCastIntervalSeconds, timerID)
    return
  endif
  
  if timerID != TimerIDFirstPhase && timerID != TimerIDSecondPhase
    _Log("OnTimer: Unknown timerID " + timerID + ", ignoring...")
    return
  endif

  if !_waitActive
    return
  endif
  Float now = Utility.GetCurrentRealTime()
  ; Observe combat status; treat "in combat" as breaking the stability window
  if Game.GetPlayer().IsInCombat()
      _lastCombatRTS = now
      _Log(" Tick: player in combat")
  else
      _Log(" Tick: player NOT in combat (stable for " + (now - _lastCombatRTS) + "s)")
  endif
  
  if LastPingRTS > _lastCombatRTS
    _lastCombatRTS = LastPingRTS
  endif

  bool wasHitRecent = (Utility.GetCurrentRealTime() - _lastHitRTS) <= 5; 5: AWR_HitRecentWindow
  bool threatPing   = (Utility.GetCurrentRealTime() - LastPingRTS) <= 5; AWR_ThreatPingWindow
  _Log(" Tick: wasHitRecent=" + wasHitRecent + ", threatPing=" + threatPing)
  ; stop immediately if interrupted, hit recently, or threat ping active
  if (wasHitRecent || threatPing)
    FinishWait(AWR_WAIT_INTERRUPTED(), timerID)
    return
  endif

  ; Check for stable-clear window
  if (now - _lastCombatRTS) >= StableSeconds
    FinishWait(AWR_WAIT_OK(), timerID)
    return
  endif

  ; Check for absolute timeout
  if (now - _startRTS) >= MaxWaitSeconds
    FinishWait(AWR_WAIT_TIMEOUT(), timerID)
    return
  endif

  CombatWaitToastTick(_startRTS, MaxWaitSeconds, AWR_CombatToastInterval)
  ; Keep ticking
  StartTimer(PollIntervalSeconds, timerID)
EndEvent

Function ApplySettingsFromGlobals()
    AWR_StableFirst  = AWR_StableFirstGV.GetValue()
    AWR_MaxFirst     = AWR_MaxFirstGV.GetValue()
    AWR_StableSecond = AWR_StableSecondGV.GetValue()
    AWR_MaxSecond    = AWR_MaxSecondGV.GetValue()
    AWR_EnableCombatSettleTimers = AWR_EnableCombatSettleTimersGV.GetValue()
    _Log("ApplySettingsFromGlobals(): AWR_StableFirst=" + AWR_StableFirst + ", AWR_MaxFirst=" + AWR_MaxFirst + ", AWR_StableSecond=" + AWR_StableSecond + ", AWR_MaxSecond=" + AWR_MaxSecond + ", AWR_EnableCombatSettleTimers=" + AWR_EnableCombatSettleTimers)
EndFunction

Function CombatWaitToastTick(float tStart, float maxWait, float interval = 4.0, string msg = "Waiting for combat to settle…")
    if (!AWR_ShowCombatWaitToasts) ; optional UX
        return
    endif
    float now = Utility.GetCurrentRealTime()
    if (now - _lastToastRTS >= interval)
        float remaining = (tStart + maxWait) - now
        if (remaining > 0.0)
            int remainInt = Math.Ceiling(remaining)
            Debug.Notification(msg + " (Max " + remainInt + "s left)")
            _lastToastRTS = now
        endif
    endif
EndFunction

; Function InterruptCombatClearWait(Actor akActor)
;   _Log("interrupt from: " + akActor)
;     if !_waitActive
;         return
;     endif

;     if _ignoreThreatsUntil > 0.0
;       Float now = Utility.GetCurrentRealTime()
;       if now < _ignoreThreatsUntil
;           _Log("_ignoreThreatsUntil=" + _ignoreThreatsUntil)
;           return
;       endif
;     endif

;     _interrupted = true
;     LastPingRTS = Utility.GetCurrentRealTime() ; reset stability window
;     _Log("Wait interrupted: stability window reset")
; EndFunction

Function _EnableThreatSense(bool on)
    _Log("EnableThreatSense(): AWR_ThreatSenseAbility=" + AWR_ThreatSenseAbility + ", on=" + on)

    if on
        if AWR_ThreatSenseAbility && !PlayerRef.HasSpell(AWR_ThreatSenseAbility)
            PlayerRef.AddSpell(AWR_ThreatSenseAbility, false)
            StartTimer(SpellCastIntervalSeconds, TimerIDSpellCast)
        endif
    else
        _ignoreThreatsUntil = Utility.GetCurrentRealTime() + 3.5
        if AWR_ThreatSenseAbility && PlayerRef.HasSpell(AWR_ThreatSenseAbility)
            PlayerRef.RemoveSpell(AWR_ThreatSenseAbility)
        endif
        CancelTimer(TimerIDSpellCast)
    endif
    
EndFunction

Function CancelCombatClearWait()
    if !_waitActive
        return
    endif
    _Log("Wait cancelled by caller")
    CancelTimer(TimerIDFirstPhase)
    CancelTimer(TimerIDSecondPhase)
    _waitActive = false
    _EnableThreatSense(false)
    _cbQuest = None
    _cbFunc  = ""
EndFunction

; ----- PUBLIC API -----
; Begin a non-blocking "wait for combat to clear".
; When done, calls _cbQuest._cbFunc(resultCode)
; resultCode is one of:
;   AWR_WAIT_OK()          = combat cleared successfully
;   AWR_WAIT_TIMEOUT()     = combat did not clear in time
;   AWR_WAIT_INTERRUPTED() = wait was interrupted (stability window reset)
; Returns true if wait started, false if already waiting.
bool Function BeginCombatClearWait(Quest callbackQuest, String callbackFunc)

  if _waitActive
    ; If already waiting, you can choose to restart or ignore
    _Log("BeginCombatClearWait: already active, ignoring new request")
    return false
  endif
  
  _waitActive     = true
  if !AWR_EnableCombatSettleTimers
    _Log("GateStartWithCombatSettle(): AWR_EnableCombatSettleTimers is false, returning early...")
    _cbQuest = callbackQuest
    _cbFunc  = callbackFunc
    FinishWait(AWR_WAIT_OK(), TimerIDFirstPhase)
    return true
  endif

  if (PlayerRef.IsInCombat() == false)
    _Log("GateStartWithCombatSettle(): Player not in combat, returning early...")
    _cbQuest = callbackQuest
    _cbFunc  = callbackFunc
    FinishWait(AWR_WAIT_OK(), TimerIDFirstPhase)
    _waitActive = false
    return true
  endif

  Debug.Notification("AutoWalk: Waiting for combat to settle…")

  _EnableThreatSense(true)

  _cbQuest = callbackQuest
  _cbFunc  = callbackFunc

  _startRTS       = Utility.GetCurrentRealTime()
  _lastCombatRTS  = _startRTS ; assume in combat at start to require a stable window
  _lastHitRTS = -1000.0
  LastPingRTS = 0.0
  _lastToastRTS = 0.0
  _ignoreThreatsUntil = 0.0

  StableSeconds = AWR_StableFirst
  MaxWaitSeconds = AWR_MaxFirst

  ; prime the timer loop
  StartTimer(PollIntervalSeconds, TimerIDFirstPhase)

  _Log("Wait started: stable=" + StableSeconds + "s, timeout=" + MaxWaitSeconds + "s")
  return true
EndFunction

; ----- INTERNAL: complete & notify -----
Function FinishWait(Int code, int timerID)
  _Log("FinishWait: code=" + code + ", timerID=" + timerID)
  String s = None
  if (code == AWR_WAIT_OK())
    s = "OK"
    if timerID == TimerIDSecondPhase
      _Log("FinishWait: combat state cleared after soft-clear, returning AWR_WAIT_OK...")
    endif
  elseif (code == AWR_WAIT_TIMEOUT())
    s = "TIMEOUT"
    if timerID == TimerIDFirstPhase
      Debug.Notification("AutoWalk: Soft-clearing & re-checking combat state…")
      SoftClearLingeringCombat()

      _startRTS       = Utility.GetCurrentRealTime()
      _lastCombatRTS  = _startRTS ; assume in combat at start to require a stable window

      StableSeconds = AWR_StableSecond
      MaxWaitSeconds = AWR_MaxSecond
      StartTimer(PollIntervalSeconds, TimerIDSecondPhase) ; re-check after a short delay
      _Log("Second wait started: stable=" + StableSeconds + "s, timeout=" + MaxWaitSeconds + "s")
      return
    elseif timerID == TimerIDSecondPhase
      _Log("FinishWait: combat state still not cleared after soft-clear, returning AWR_WAIT_TIMEOUT...")
    endif
  elseif (code == AWR_WAIT_INTERRUPTED())
    s = "INTERRUPTED"
  endif

  _EnableThreatSense(false)
  _waitActive = false
  _Log("Wait finished: " + s)

  if _cbQuest != None && _cbFunc != ""
    Var[] args = new Var[1]
    args[0] = code
    _cbQuest.CallFunctionNoWait(_cbFunc, args)
  endif

  ; clear callback references (safety)
  _cbQuest = None
  _cbFunc  = ""
EndFunction

Function SoftClearLingeringCombat()
    PlayerRef.StopCombat()
    PlayerRef.StopCombatAlarm()
    PlayerRef.EvaluatePackage()
    ; If you manage companion aliases, do the same for them:
    ; CompanionAlias1.GetActorRef().StopCombat()
    ; CompanionAlias1.GetActorRef().StopCombatAlarm()
    ; CompanionAlias1.GetActorRef().EvaluatePackage()
EndFunction
