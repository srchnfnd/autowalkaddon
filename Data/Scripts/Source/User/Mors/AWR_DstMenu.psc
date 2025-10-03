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
DstEntry [] Property Entries_NukaWorld_Other Auto Const Mandatory

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

; ============================
; Worldspace IDs (keep in sync with old AutoWalk.psc)
; ============================
int Function AWR_WORLDSPACE_COMMONWEALTH()
    Return 0 
EndFunction
int Function AWR_WORLDSPACE_FARHARBOR()
    Return 1 
EndFunction
int Function AWR_WORLDSPACE_NUKAWORLD() 
    Return 2
EndFunction

; ============================
; Menu entry / callback types (must match ActionScript)
; ============================
int Function AWR_MENU_ENTRY_TYPE_CATEGORY()
    Return 0 
EndFunction
int Function AWR_MENU_ENTRY_TYPE_DST_LIST()
    Return 1 
EndFunction

int Function AWR_CALLBACK_TYPE_CATEGORY()
    Return 1
EndFunction
int Function AWR_CALLBACK_TYPE_DSTENTRY()
    Return 0 
EndFunction
int Function AWR_CALLBACK_TYPE_CANCEL()
    Return -1
EndFunction

; ============================
; Open params & state
; ============================
Struct OpenParams
    ScriptObject Receiver = None
    string FunctionName = ""
    bool OnlyDiscovered = true
    int Worldspace_ = -1
EndStruct

OpenParams gOpenParams = None

; Separate caches by category (settlements vs. other)
DstEntry[] gCachedEntries_Settlements = None
DstEntry[] gCachedEntries_Other = None
int gLastFilteredCount_Settlements = -1
int gLastFilteredCount_Other = -1

; ============================
; Lifecycle
; ============================
Event OnQuestInit()
	OnGameReload()
EndEvent

Event Actor.OnPlayerLoadGame(Actor akSender)
    OnGameReload()
EndEvent

Function OnGameReload()
    ; Reset caches on reload
    gCachedEntries_Settlements = None
    gCachedEntries_Other = None
    gLastFilteredCount_Settlements = -1
    gLastFilteredCount_Other = -1

	If (!IsRegistered)
        UI:MenuData data_ = new UI:MenuData
        data_.menuFlags = MenuFlag_PausesGame + \
            MenuFlag_UsesCursor + \
            MenuFlag_UsesMenuContext + \
            MenuFlag_Modal + \
            MenuFlag_DisablePauseMenu + \
            MenuFlag_TopmostRenderedMenu

        UI.RegisterCustomMenu(Name, Path, "root1", data_)
	EndIf
EndFunction

; ============================
; Open / Close
; ============================
bool Function Open(ScriptObject akReceiver, string asFunctionName, int _worldspace, bool bOnlyDiscovered = true)
    gOpenParams = new OpenParams
    gOpenParams.Receiver = akReceiver
    gOpenParams.FunctionName = asFunctionName
    gOpenParams.OnlyDiscovered = bOnlyDiscovered
    gOpenParams.Worldspace_ = _worldspace
    Debug.traceSelf(self, "Open", "akReceiver: " + akReceiver + " asFunctionName: " + asFunctionName + " worldspace: " + _worldspace + " bOnlyDiscovered: " + bOnlyDiscovered)
    If (IsOpen)
		Debug.traceSelf(self, "Open", "This menu is already open!")
		return false
	Else
		If (IsRegistered)
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

bool Function Close()
    ; Reset caches on close
    gCachedEntries_Settlements = None
    gCachedEntries_Other = None
    gLastFilteredCount_Settlements = -1
    gLastFilteredCount_Other = -1
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

; ============================
; Wait state & category selection
; ============================
State Waiting
    Event OnMenuOpenCloseEvent(string asMenuName, bool abOpening)
        Debug.traceSelf(self, "OnMenuOpenCloseEvent", "Menu: " + asMenuName + " Opening: " + abOpening + "gOpenParams: " + gOpenParams)
        If (abOpening)
            String [] entries
            if(gOpenParams.Worldspace_ == AWR_WORLDSPACE_COMMONWEALTH()) ; Commonwealth
                entries = new String[3]
                entries[0] = "Settlements"
                entries[1] = "Other Locations"
                entries[2] = "Custom Location"
            elseIf gOpenParams.Worldspace_ == AWR_WORLDSPACE_FARHARBOR() ; Far Harbor
                entries = new String[2]
                entries[0] = "Other Locations"
                entries[1] = "Custom Location"
            elseIf gOpenParams.Worldspace_ == AWR_WORLDSPACE_NUKAWORLD() ; Nuka World
                entries = new String[2]
                entries[0] = "Other Locations"
                entries[1] = "Custom Location"
            else
                Debug.traceSelf(self, "OnMenuOpenCloseEvent", "Unknown awr worldspace: " + gOpenParams.Worldspace_)
                var[] args = new var[2]
                args[0] = AWR_CALLBACK_TYPE_CANCEL()
                args[1] = None
                gOpenParams.Receiver.CallFunctionNoWait(gOpenParams.FunctionName, args)
            endif
            Debug.traceSelf(self, "OnMenuOpenCloseEvent", "entries : " + entries)
            UI.Invoke(Name, GetMember("clearSetup"), None)
            UI.Set(Name, GetMember("bodyText"), "<b>Destination Menu</b><br><br>Select a category(ESC to cancel):")
            var[] setupArgs = new var[4]
            setupArgs[0] = self
            setupArgs[1] = "OnSelectCategory"
            setupArgs[2] = AWR_MENU_ENTRY_TYPE_CATEGORY()
            setupArgs[3] = Utility.VarArrayToVar(entries as Var [])
            UI.Invoke(Name, GetMember("setupAwrMenu"), setupArgs)
            UI.Invoke(Name, GetMember("InvalidateMenu"), None)
            Debug.traceSelf(self, "OnMenuOpenCloseEvent", "Menu opend")
        Else
            UnregisterForMenuOpenCloseEvent(asMenuName)
            GotoState("")
        EndIf
    EndEvent
EndState

Function OnSelectCategory(int callback_type, var [] _args)
    Debug.traceSelf(self, "OnSelectCategory", "callback_type: " + callback_type + ", args: " + _args)
    bool bail = false
    if gOpenParams.Worldspace_ == -1
        Debug.traceSelf(self, "OnSelectCategory", "Worldspace is not set!")
        bail = true
    elseif gOpenParams.Receiver == None || gOpenParams.FunctionName == ""
        Debug.traceSelf(self, "OnSelectCategory", "Receiver or FunctionName is not set!")
        bail = true
    elseif gOpenParams.Worldspace_ < AWR_WORLDSPACE_COMMONWEALTH() || gOpenParams.Worldspace_ > AWR_WORLDSPACE_NUKAWORLD()
        Debug.traceSelf(self, "OnSelectCategory", "Worldspace is invalid: " + gOpenParams.Worldspace_)
        bail = true
    EndIf

    int index = -1
    if callback_type == AWR_CALLBACK_TYPE_CANCEL()
        Debug.traceSelf(self, "OnSelectCategory", "User cancelled or error occurred")
        bail = true
    elseif callback_type == AWR_CALLBACK_TYPE_CATEGORY()
        Debug.traceSelf(self, "OnSelectCategory", "Categories selected, reopening category menu")
        index = _args[0] as int
    else
        ; AWR_CALLBACK_TYPE_DSTENTRY() irrelevant here
        Debug.traceSelf(self, "OnSelectCategory", "Unknown callback_type: " + callback_type)
        bail = true
    EndIf

    if bail
        var[] args = new var[2]
        args[0] = AWR_CALLBACK_TYPE_CANCEL()
        args[1] = None
        gOpenParams.Receiver.CallFunctionNoWait(gOpenParams.FunctionName, args)
        return
    EndIf

    ; clear the menu and open the next one
    UI.Invoke(Name, GetMember("clearSetup"), None)

    if gOpenParams.Worldspace_ == AWR_WORLDSPACE_COMMONWEALTH() ; Commonwealth
        if index == 0
            Debug.traceSelf(self, "OnSelectCategory", "Opening settlements menu (Commonwealth)")
            OpenDestinations(true)
        elseif index == 1
            Debug.traceSelf(self, "OnSelectCategory", "Opening other locations menu (Commonwealth)")
            OpenDestinations(false)
        elseif index == 2
            Close()
            Debug.traceSelf(self, "OnSelectCategory", "Custom location selected")
            var[] args = new var[2]
            args[0] = AWR_CALLBACK_TYPE_DSTENTRY()
            args[1] = None
            gOpenParams.Receiver.CallFunctionNoWait(gOpenParams.FunctionName, args)
        else
            bail = true
        endif
    elseif gOpenParams.Worldspace_ == AWR_WORLDSPACE_FARHARBOR() ; Far Harbor
        if index == 0
            Debug.traceSelf(self, "OnSelectCategory", "Opening other locations menu (Far Harbor)")
            OpenDestinations(false)
        elseif index == 1
            Close()
            Debug.traceSelf(self, "OnSelectCategory", "Custom location selected")
            var[] args = new var[2]
            args[0] = AWR_CALLBACK_TYPE_DSTENTRY()
            args[1] = None
            gOpenParams.Receiver.CallFunctionNoWait(gOpenParams.FunctionName, args)
        else
            bail = true
        endif
    elseif gOpenParams.Worldspace_ == AWR_WORLDSPACE_NUKAWORLD() ; Nuka World
        if index == 0
            Debug.traceSelf(self, "OnSelectCategory", "Opening other locations menu (Nuka World)")
            OpenDestinations(false)
        elseif index == 1
            Debug.traceSelf(self, "OnSelectCategory", "Custom location selected")
            var[] args = new var[2]
            args[0] = AWR_CALLBACK_TYPE_DSTENTRY()
            args[1] = None
            gOpenParams.Receiver.CallFunctionNoWait(gOpenParams.FunctionName, args)
        else
            bail = true
        endif
    EndIf

    if bail
        var[] args = new var[2]
        args[0] = AWR_CALLBACK_TYPE_CANCEL()
        args[1] = None
        gOpenParams.Receiver.CallFunctionNoWait(gOpenParams.FunctionName, args)
    EndIf
EndFunction

; ============================
; Unified destination opener with per-category caching
; ============================
Function OpenDestinations(bool settlements)
    UI.Set(Name, GetMember("bodyText"), "<b>Destination Menu</b><br><br>Please wait...")
    UI.Invoke(Name, GetMember("InvalidateMenu"), None)

    DstEntry[] entriesAll = None
    if settlements
        if gOpenParams.Worldspace_ == AWR_WORLDSPACE_COMMONWEALTH()
            entriesAll = Entries_Commonwealth_Settlements
        else
            Debug.traceSelf(self, "OpenDestinations", "No settlements for this worldspace: " + gOpenParams.Worldspace_)
            var[] args = new var[2]
            args[0] = AWR_CALLBACK_TYPE_CANCEL()
            args[1] = None
            gOpenParams.Receiver.CallFunctionNoWait(gOpenParams.FunctionName, args)
            return
        endif
    else
        if gOpenParams.Worldspace_ == AWR_WORLDSPACE_COMMONWEALTH()
            entriesAll = Entries_Commonwealth_Other
        elseif gOpenParams.Worldspace_ == AWR_WORLDSPACE_FARHARBOR()
            entriesAll = Entries_FarHarbor_Other
        elseif gOpenParams.Worldspace_ == AWR_WORLDSPACE_NUKAWORLD()
            entriesAll = Entries_NukaWorld_Other
        else
            Debug.traceSelf(self, "OpenDestinations", "No other entries for this worldspace: " + gOpenParams.Worldspace_)
            var[] args = new var[2]
            args[0] = AWR_CALLBACK_TYPE_CANCEL()
            args[1] = None
            gOpenParams.Receiver.CallFunctionNoWait(gOpenParams.FunctionName, args)
            return
        endif
    endif

    float currentTime = Utility.GetCurrentRealTime()
    int filteredCount = 0
    int i = 0
    while i < entriesAll.Length
        if !gOpenParams.OnlyDiscovered || entriesAll[i].marker == none || entriesAll[i].marker.IsMapMarkerVisible()
            filteredCount += 1
        endif
        i += 1
    endwhile

    Debug.traceSelf(self, "OpenDestinations", "Filtered count: " + filteredCount + " from total: " + entriesAll.Length)
    if settlements
        if filteredCount != gLastFilteredCount_Settlements
            Debug.traceSelf(self, "OpenDestinations", "Rebuilding settlements entries array")
            gLastFilteredCount_Settlements = filteredCount
            gCachedEntries_Settlements = new DstEntry[filteredCount]
            i = 0
            int j = 0
            while i < entriesAll.Length
                if !gOpenParams.OnlyDiscovered || entriesAll[i].marker == none || entriesAll[i].marker.IsMapMarkerVisible()
                    gCachedEntries_Settlements[j] = entriesAll[i]
                    j += 1
                endif
                i += 1
            endwhile
        else
            Debug.traceSelf(self, "OpenDestinations", "Using cached settlements entries")
        endif
    else
        if filteredCount != gLastFilteredCount_Other
            Debug.traceSelf(self, "OpenDestinations", "Rebuilding other entries array")
            gLastFilteredCount_Other = filteredCount
            gCachedEntries_Other = new DstEntry[filteredCount]
            i = 0
            int j2 = 0
            while i < entriesAll.Length
                if !gOpenParams.OnlyDiscovered || entriesAll[i].marker == none || entriesAll[i].marker.IsMapMarkerVisible()
                    gCachedEntries_Other[j2] = entriesAll[i]
                    j2 += 1
                endif
                i += 1
            endwhile
        else
            Debug.traceSelf(self, "OpenDestinations", "Using cached other entries")
        endif
    endif

    var[] setupArgs = new var[4]
    setupArgs[0] = gOpenParams.Receiver
    setupArgs[1] = gOpenParams.FunctionName
    setupArgs[2] = AWR_MENU_ENTRY_TYPE_DST_LIST() ; Dst list type
    if settlements
        setupArgs[3] = Utility.VarArrayToVar(gCachedEntries_Settlements as var[])
    else
        setupArgs[3] = Utility.VarArrayToVar(gCachedEntries_Other as var[])
    endif

    Debug.traceSelf(self, "OpenDestinations", "Setup args prepared in " + (Utility.GetCurrentRealTime() - currentTime) + " seconds")
    currentTime = Utility.GetCurrentRealTime()
    UI.Set(Name, GetMember("bodyText"), "<b>Destination Menu</b><br>Select a destination(ESC to cancel):")
    UI.Invoke(Name, GetMember("setupAwrMenu"), setupArgs)
    UI.Invoke(Name, GetMember("InvalidateMenu"), None)
    Debug.traceSelf(self, "OpenDestinations", "Menu setup invoked in " + (Utility.GetCurrentRealTime() - currentTime) + " seconds")
EndFunction

string Function GetMember(string member)
	return Root+".Menu_mc."+member
    ;return Root+"."+member
EndFunction