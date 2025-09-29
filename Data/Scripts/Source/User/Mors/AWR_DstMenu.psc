ScriptName Mors:AWR_DstMenu Extends Quest

string Property Name Hidden
    string Function Get()
        return "AWR_DstMenu"
    EndFunction
EndProperty
string Property Path Hidden
    string Function Get()
        return "AWR_DstMenu"
    EndFunction
EndProperty
string Property Root Hidden
    string Function Get()
        return "root1"
    EndFunction
EndProperty
bool Property IsRegistered Hidden
    bool Function Get()
        return UI.IsMenuRegistered(Name)
    EndFunction
EndProperty
bool Property IsOpen Hidden
    bool Function Get()
        return UI.IsMenuOpen(Name)
    EndFunction
EndProperty

Actor Property PlayerRef Auto Const Mandatory
DstEntry [] Property Entries_Commonwealth_Settlements Auto Const Mandatory
DstEntry [] Property Entries_Commonwealth_Other Auto Const Mandatory
DstEntry [] Property Entries_FarHarbor_Other Auto Const Mandatory
DstEntry [] Property Entries_FarHarbor_Settlements Auto Const Mandatory
DstEntry [] Property Entries_NukaWorld_Other Auto Const Mandatory
DstEntry [] Property Entries_NukaWorld_Settlements Auto Const Mandatory

Group MenuFlags
	int Property MenuFlag_None = 0x0 AutoReadOnly
	int Property MenuFlag_PausesGame = 0x1 AutoReadOnly
	int Property MenuFlag_UsesCursor = 0x4 AutoReadOnly
	int Property MenuFlag_UsesMenuContext = 0x8 AutoReadOnly
	int Property MenuFlag_Modal = 0x10 AutoReadOnly
	int Property MenuFlag_DisablePauseMenu = 0x80 AutoReadOnly
	int Property MenuFlag_TopmostRenderedMenu = 0x200 AutoReadOnly
	int Property MenuFlag_UsesBlurredBackground = 0x400000 AutoReadOnly
EndGroup

Struct DstEntry
    ObjectReference marker
    ObjectReference dstMarker
    String name
EndStruct

int Function AWR_COMMONWEALTH()
    Return 0 
EndFunction
int Function AWR_FARHARBOR()
    Return 1 
EndFunction
int Function AWR_NUKAWORLD() 
    Return 2
EndFunction

Struct OpenParams
    ScriptObject Receiver = None
    string FunctionName = ""
    bool OnlyDiscovered = true
EndStruct

OpenParams gOpenParams = None

DstEntry[] EntriesAll = None

DstEntry[] gCachedEntries = None
int gLastFilteredCount = 0

Event OnQuestInit()
	OnGameReload()
EndEvent

Event Actor.OnPlayerLoadGame(Actor akSender)
    OnGameReload()
EndEvent

Function OnGameReload()
	If (!IsRegistered)
		; UI:MenuData data_ = new UI:MenuData
        ; Debug.traceSelf(self, "OnGameReload", "Registering menu...")
		; UI.RegisterCustomMenu(Name, Path, Root, data_)

	UI:MenuData data_ = new UI:MenuData
	data_.menuFlags = MenuFlag_PausesGame + \
        MenuFlag_UsesCursor + \
		MenuFlag_UsesMenuContext + \
        MenuFlag_Modal + \
		MenuFlag_DisablePauseMenu + \
		MenuFlag_TopmostRenderedMenu

	; Same as the PauseMenu
	;data_.depth = 0xA

	UI.RegisterCustomMenu(Name, Path, "root1", data_)
	EndIf
EndFunction

bool Function Close()
	If (!IsOpen)
		Debug.traceSelf(self, "Close", "This menu is already closed!")
		return true
	Else
		If (IsRegistered)
			return UI.CloseMenu(Name)
		Else
			Debug.TraceSelf(self, "Close", "This menu is not registered.")
			return false
		EndIf
	EndIf
EndFunction

State Waiting
    bool Function OpenOther(ScriptObject akReceiver, string asFunctionName, int worldspace, bool bOnlyDiscovered = true)
        return false
    EndFunction
    bool Function OpenSettlements(ScriptObject akReceiver, string asFunctionName, int worldspace, bool bOnlyDiscovered = true)
        return false 
    endfunction

    Event OnMenuOpenCloseEvent(string asMenuName, bool abOpening)
        Debug.traceSelf(self, "OnMenuOpenCloseEvent", "Menu: " + asMenuName + " Opening: " + abOpening)
        If (abOpening)
            ; build var[] of var[] (one subarray per entry)
            UI.Set(asMenuName, GetMember("bodyText"), "<b>AutoWalk</b><br><br>Please wait...")
            UI.Invoke(asMenuName, GetMember("InvalidateMenu"), None)
            float currentTime = Utility.GetCurrentRealTime()
            int filteredCount = 0
            int i = 0
            While i < EntriesAll.Length
                If !gOpenParams.OnlyDiscovered || EntriesAll[i].marker == none || EntriesAll[i].marker.IsMapMarkerVisible()
                    filteredCount += 1
                EndIf
                i += 1
            EndWhile
            
            Debug.traceSelf(self, "OnMenuOpenCloseEvent", "Filtered count: " + filteredCount + " from total: " + EntriesAll.Length)

            var[] setupArgs = new var[3]
            setupArgs[0] = gOpenParams.Receiver
            setupArgs[1] = gOpenParams.FunctionName
            ; Cache entries array if filteredCount is unchanged
            DstEntry[] entries
            if gLastFilteredCount == filteredCount && gCachedEntries != None
                Debug.traceSelf(self, "OnMenuOpenCloseEvent", "Using cached entries")
                entries = gCachedEntries
            else
                Debug.traceSelf(self, "OnMenuOpenCloseEvent", "Rebuilding entries array")
                entries = new DstEntry[filteredCount]
                gLastFilteredCount = filteredCount
                gCachedEntries = entries
                i=0
                int j = 0
                while i < EntriesAll.Length
                    If !gOpenParams.OnlyDiscovered || EntriesAll[i].marker == none || EntriesAll[i].marker.IsMapMarkerVisible()
                        entries[j] = EntriesAll[i]
                        j += 1
                    EndIf
                    i += 1
                EndWhile
            endif

            setupArgs[2] = Utility.VarArrayToVar(gCachedEntries as var[])
            Debug.traceSelf(self, "OnMenuOpenCloseEvent", "Setup args prepared in " + (Utility.GetCurrentRealTime() - currentTime) + " seconds")
            currentTime = Utility.GetCurrentRealTime()
            UI.Set(asMenuName, GetMember("bodyText"), "<b>AutoWalk</b><br>Select a destination(ESC to cancel):")
            UI.Invoke(asMenuName, GetMember("setup"), setupArgs)
            UI.Invoke(asMenuName, GetMember("InvalidateMenu"), None)
            Debug.traceSelf(self, "OnMenuOpenCloseEvent", "Menu setup invoked in " + (Utility.GetCurrentRealTime() - currentTime) + " seconds")
            gOpenParams = None
        Else
            UnregisterForMenuOpenCloseEvent(asMenuName)
            GotoState("")
        EndIf
    EndEvent
EndState

bool Function OpenSettlements(ScriptObject akReceiver, string asFunctionName, int worldspace, bool bOnlyDiscovered = true)
    ; OnlyDiscovered = bOnlyDiscovered
    ; Receiver = akReceiver
    ; FunctionName = asFunctionName
    return false
endfunction

bool Function OpenOther(ScriptObject akReceiver, string asFunctionName, int _worldspace, bool bOnlyDiscovered = true)
    gOpenParams = new OpenParams
    gOpenParams.Receiver = akReceiver
    gOpenParams.FunctionName = asFunctionName
    gOpenParams.OnlyDiscovered = bOnlyDiscovered
    Debug.traceSelf(self, "OpenOther", "akReceiver: " + akReceiver + " asFunctionName: " + asFunctionName + " worldspace: " + _worldspace + " bOnlyDiscovered: " + bOnlyDiscovered)
    If (IsOpen)
		Debug.traceSelf(self, "Open", "This menu is already open!")
		return false
	Else
		If (IsRegistered)
            If _worldspace == AWR_COMMONWEALTH() ; Commonwealth
                EntriesAll = Entries_Commonwealth_Other
                Debug.TraceSelf(self, "Open", "EntriasAll length: " + EntriesAll.Length)
            ElseIf _worldspace == AWR_FARHARBOR() ; Far Harbor
                EntriesAll = Entries_FarHarbor_Other
            ElseIf _worldspace == AWR_NUKAWORLD() ; Nuka World
                EntriesAll = Entries_NukaWorld_Other
            else 
                EntriesAll == None
                Debug.traceSelf(self, "Open", "No entries for this worldspace: " + _worldspace)
                return false
            EndIf
            Debug.TraceSelf(self, "Open", "Opening menu...")
            RegisterForMenuOpenCloseEvent(Name)
            GotoState("Waiting")
			return UI.OpenMenu(Name)
		Else
			Debug.TraceSelf(self, "Open", "This menu is not registered.")
			return false
		EndIf
	EndIf
EndFunction

string Function GetMember(string member)
	return Root+".Menu_mc."+member
    ;return Root+"."+member
EndFunction