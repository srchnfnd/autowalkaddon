Scriptname Mors:AWR_ThreatSenseEffect extends ActiveMagicEffect

; Filled in the quest that owns your main logic
Mors:AWR_ThreatDetector  Property AWR_ThreatDetector Auto
Actor Property PlayerRef Auto
GlobalVariable property AWR_ThreatSenseDetectionRangeGV Auto

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

    float range = AWR_ThreatSenseDetectionRangeGV.GetValue()
    float dist = akCaster.GetDistance(akTarget)
    _Log("Target=" + akTarget + " distance=" + dist + " range config=" + range)

    ; Ignore targets outside user-defined detection range
    if dist > range
        _Log("Target outside range; skipping threat update.")
        return
    endif

    ; optional randomized stagger to prevent synchronous spikes
    Utility.Wait(Utility.RandomFloat(0.0, 0.5))

    float lastPingRTS = AWR_ThreatDetector.LastPingRTS

    ; Only set LastPingRTS if currently zero (first detection after reset)
    if lastPingRTS == 0.0
    lastPingRTS = Utility.GetCurrentRealTime()
    AWR_ThreatDetector.LastPingRTS = lastPingRTS
    _Log("Threat detected; LastPingRTS set to " + lastPingRTS)
    else
    _Log("Threat already active; LastPingRTS unchanged.")
    endif
EndEvent 
