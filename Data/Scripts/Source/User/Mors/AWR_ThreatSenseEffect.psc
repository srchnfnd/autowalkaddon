Scriptname Mors:AWR_ThreatSenseEffect extends ActiveMagicEffect

; Filled in the quest that owns your main logic
Mors:AWR_ThreatDetector  Property AWR_ThreatDetector Auto
Actor Property PlayerRef Auto
Float Property CooldownSeconds = 0.5 Auto ; per-instance throttle (optional)

Function _Log(string msg)
  Debug.Trace("AutoWalkThreatSense: " + msg, 1)
EndFunction

Event OnEffectStart(Actor akTarget, Actor akCaster)
    if PlayerRef == None
        PlayerRef = Game.GetPlayer()
    endif

    if akTarget.IsHostileToActor(PlayerRef) == 0
        return
    endif

    ; if AWR_ThreatDetector == None
    ;     _Log("ThreatSense: Core quest property is NONE; cannot notify.")
    ;     return
    ; endif

    ; Flooding control
    ; Random delay to reduce burst, data race
    Utility.Wait(Utility.RandomFloat(0.0, 0.5))
    float lastPingRTS = AWR_ThreatDetector.LastPingRTS
    if lastPingRTS == 0.0
        lastPingRTS = Utility.GetCurrentRealTime()
        ; if (now - lastPingRTS) < CooldownSeconds
        ;     _Log("ThreatSense: actor " + akTarget+" avoiding overly frequent update: time diff=" + (now - lastPingRTS))
        ;     return
        ; endif
        AWR_ThreatDetector.LastPingRTS = lastPingRTS
        ;_Log("ThreatSense: actor " + akTarget+" Updated lastPingRTS: lastPingRTS=" + lastPingRTS + ", LOS=" + akTarget.HasDetectionLOS(PlayerRef))
    else
        ;_Log("ThreatSense: actor " + akTarget+" avoiding notification: threat is already notified at " + lastPingRTS)
    endif

    ; _Log("ThreatSense: notifying core about " + akTarget)
    ; Fire-and-forget call into the core quest
    ; Var[] args = new Var[1]
    ; args[0] = akTarget
    ; AWR_ThreatDetector.CallFunctionNoWait("InterruptCombatClearWait", args)
    ;AWR_CoreQuest.InterruptCombatClearWait(akTarget)

EndEvent 
