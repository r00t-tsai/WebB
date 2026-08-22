; not updated
#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
#Warn VarUnset, Off

#Include WebView2\WebView2.ahk

global MainGui := 0
global URL_Input
global UrlStatusText
global BrowserHost
global TabBar
global HistoryGui := ""
global SettingsBtn
global HistoryBtn
global DownloadBtn
global SuggestionGui := ""
global SuggestionLB := ""
global CurrentSuggestions := []
global CookieGui := ""
global CookieLV := ""
global CookieObjects := []
global DeleteCookieBtn := ""
global DeleteAllCookiesBtn := ""
global AppTheme := "Light"
global NewTabBgType := "Color"
global NewTabBgVal := "#2B2B2B"
global MinBtn := ""
global MaxBtn := ""
global CloseBtn := ""
global MainGuiControlsReady := false
global ActiveHoverHwnd := 0
global HBRUSH_HOVER := 0
global TabSeparator
global EnableSuspendTabs := false
global ExtraCmdFlags := ""
global HistoryCache := []
global FavoritesBtn
global UrlStarFavorited := false
global UrlStarHovered := false
global UrlInputSubclassProc := 0
global FavoritesFile := ""
global FavoritesCache := []
global startupUrl :=""
global startupUrlExpanded := false
global startupUrlChanged := false
global startupUrlInternalUpdate := false
global CustomNewTabActive := false
global EditorHtmlPath := ""
global EditorModeActive := false
global PreLiveThemeSnapshot := ""
global SuppressAutoComplete
global LastKeyWasDelete := false
global LockOverlayGui := ""
global LockOverlayFullCover := false
global ActiveEditorTab := ""
global FavGui := ""


global CurrentThemeBg     := "F3F3F3"
global CurrentThemeText   := "000000"
global CurrentThemeBtn    := "FFFFFF"
global CurrentThemeCtrlBg := "FFFFFF"
global CurrentThemeIsDark := false

global CustomThemeBg     := "1E1E1E"
global CustomThemeText   := "FFFFFF"
global CustomThemeBtn    := "333333"
global CustomThemeCtrlBg := "2B2B2B"

global HBRUSH_BG   := 0
global HBRUSH_BTN  := 0
global HBRUSH_CTRL := 0

global ColorPresetNames := ["Dark Grey", "Charcoal", "Black", "Slate Gray", "Midnight Blue",
    "Deep Purple", "Forest Green", "Maroon", "White", "Light Gray", "Custom..."]
global ColorPresetMap := Map(
    "Dark Grey",    "#2B2B2B",
    "Charcoal",     "#1B1B1B",
    "Black",        "#000000",
    "Slate Gray",   "#3A4750",
    "Midnight Blue","#0F172A",
    "Deep Purple",  "#2E1A47",
    "Forest Green", "#1B3A2B",
    "Maroon",       "#3A1B1B",
    "White",        "#FFFFFF",
    "Light Gray",   "#E0E0E0")

global CurrentGuiFontName := "Arial"
global CurrentGuiFontFile := ""
global FontPresetNames := ["Arial", "Verdana", "Georgia", "Consolas"]
global IconCtrlHwnds := Map()

global Tabs := []
global ActiveTabIdx := 0
global TabWidthPadding := "                "
global IgnoreTabChange := false
global IsUrlFocused := false
global DisplayedFullURL := ""

global ConfigFile := A_ScriptDir . "\settings.ini"

global IsHistoryDisabled := (IniRead(ConfigFile, "History", "DisableHistory", "0") == "1")
global HistoryFile := ""

global CurrentSession := "Default"
global SingleInstanceMutex := 0
global IsRestartLaunch := false
global ProxyEnabled := false
global ProxyHost := ""
global ProxyPort := ""
global ProxyUser := ""
global ProxyPass := ""
global ProxyBypass := "localhost;127.0.0.1"
global StartupURL := "https://www.google.com"

global ExtDir := A_ScriptDir . "\Extensions"
global uBlockPath := ExtDir . "\uBlock"
global NewTabHtmlPath := ""


LoadSettings()
IsRestartLaunch := (A_Args.Length >= 1 && A_Args[1] = "--browser-restart")
AcquireSingleInstance(IsRestartLaunch)

LoadHistoryToMemory() {
    global HistoryCache, HistoryFile
    HistoryCache := []
    if FileExist(HistoryFile) {
        content := FileRead(HistoryFile)
        for line in StrSplit(content, "`n", "`r") {
            if (line != "")
                HistoryCache.Push(line)
        }
    }
}

LoadFavoritesToMemory() {
    global FavoritesCache, FavoritesFile
    FavoritesCache := []
    if FileExist(FavoritesFile) {
        content := FileRead(FavoritesFile)
        for line in StrSplit(content, "`n", "`r") {
            if (line != "")
                FavoritesCache.Push(line)
        }
    }
}

IsUrlFavorited(url) {
    global FavoritesCache
    for line in FavoritesCache {
        parts := StrSplit(line, "`t")
        if (parts.Length >= 1 && parts[1] = url)
            return true
    }
    return false
}

AddFavorite(url, title) {
    global FavoritesFile, FavoritesCache
    if (url = "" || url = "about:blank" || InStr(url, "newtab_page.html") || IsUrlFavorited(url))
        return
    FavLine := url . "`t" . (title != "" ? title : url)
    FavoritesCache.Push(FavLine)
    FileAppend(FavLine . "`n", FavoritesFile)
}

RemoveFavorite(url) {
    global FavoritesFile, FavoritesCache
    NewCache := []
    for line in FavoritesCache {
        parts := StrSplit(line, "`t")
        if (parts.Length >= 1 && parts[1] = url)
            continue
        NewCache.Push(line)
    }
    FavoritesCache := NewCache
    FileOpen(FavoritesFile, "w").Close()
    for line in FavoritesCache
        FileAppend(line . "`n", FavoritesFile)
}

ToggleFavoriteCurrentUrl(*) {
    global DisplayedFullURL, Tabs, ActiveTabIdx
    url := DisplayedFullURL
    if (url = "" || url = "about:blank")
        return
    title := ""
    if (ActiveTabIdx > 0 && ActiveTabIdx <= Tabs.Length)
        try title := Tabs[ActiveTabIdx].WB.DocumentTitle
    if IsUrlFavorited(url)
        RemoveFavorite(url)
    else
        AddFavorite(url, title)
    UpdateStarIcon()
}

UpdateStarIcon() {
    global UrlStarFavorited, DisplayedFullURL, URL_Input
    UrlStarFavorited := IsUrlFavorited(DisplayedFullURL)
    if IsSet(URL_Input) && URL_Input != ""
        DllCall("user32\InvalidateRect", "Ptr", URL_Input.Hwnd, "Ptr", 0, "Int", 0)
}

UrlStarRect(hwnd) {
    rect := Buffer(16, 0)
    DllCall("user32\GetClientRect", "Ptr", hwnd, "Ptr", rect)
    right := NumGet(rect, 8, "Int")
    bottom := NumGet(rect, 12, "Int")
    out := Buffer(16, 0)
    NumPut("Int", right - 32, out, 0)
    NumPut("Int", 0, out, 4)
    NumPut("Int", right, out, 8)
    NumPut("Int", bottom, out, 12)
    return out
}

DrawUrlStarOverlay(hwnd) {
    global UrlStarFavorited, UrlStarHovered, CurrentThemeCtrlBg, CurrentThemeText, CurrentThemeIsDark

    starRect := UrlStarRect(hwnd)
    hdc := DllCall("user32\GetDC", "Ptr", hwnd, "Ptr")
    if !hdc
        return

    bgHex := UrlStarHovered ? (CurrentThemeIsDark ? "3A3A3A" : "E5E5E5") : CurrentThemeCtrlBg
    hBrush := DllCall("gdi32\CreateSolidBrush", "UInt", HexToColorRef(bgHex), "Ptr")
    DllCall("user32\FillRect", "Ptr", hdc, "Ptr", starRect, "Ptr", hBrush)
    DllCall("gdi32\DeleteObject", "Ptr", hBrush)

    hFont := DllCall("gdi32\CreateFont", "Int", -18, "Int", 0, "Int", 0, "Int", 0, "Int", 400,
        "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 4, "UInt", 0,
        "Str", "Segoe MDL2 Assets", "Ptr")
    oldFont := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")

    glyph := UrlStarFavorited ? Chr(0xE735) : Chr(0xE734)
    glyphColor := UrlStarFavorited ? "FFC107" : CurrentThemeText
    DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", HexToColorRef(glyphColor))
    DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", 1)

    DllCall("user32\DrawText", "Ptr", hdc, "Str", glyph, "Int", -1, "Ptr", starRect, "UInt", 0x25)

    DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont)
    DllCall("gdi32\DeleteObject", "Ptr", hFont)
    DllCall("user32\ReleaseDC", "Ptr", hwnd, "Ptr", hdc)
}

UrlInput_Subclass(hwnd, msg, wParam, lParam, uIdSubclass, dwRefData) {
    global UrlStarHovered, IsUrlFocused, LastKeyWasDelete

    switch msg {
		case 0x0100:
			global LastKeyWasDelete
			if !IsSet(LastKeyWasDelete)
				LastKeyWasDelete := false
			LastKeyWasDelete := (wParam = 0x08 || wParam = 0x2E)
			return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam)

        case 0x000F:
            ret := DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam)
            DrawUrlStarOverlay(hwnd)
            return ret

        case 0x000F:
            ret := DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam)
            DrawUrlStarOverlay(hwnd)
            return ret

        case 0x0200:
            ret := DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam)
            if (wParam & 0x0001)
                DrawUrlStarOverlay(hwnd)
            return ret

        case 0x0008, 0x0007:
            ret := DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam)
            DrawUrlStarOverlay(hwnd)
            return ret

        case 0x0201:
            x := lParam & 0xFFFF
            y := (lParam >> 16) & 0xFFFF
            starRect := UrlStarRect(hwnd)
            if (x >= NumGet(starRect, 0, "Int") && x <= NumGet(starRect, 8, "Int")
                && y >= NumGet(starRect, 4, "Int") && y <= NumGet(starRect, 12, "Int")) {
                ToggleFavoriteCurrentUrl()
                return 0
            }
            return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam)
    }

    return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam)
}

ShowFavorites(*) {
    global FavoritesCache, MainGui, FavoritesBtn, FavGui

    if (IsSet(FavGui) && FavGui != "" && WinExist("ahk_id " . FavGui.Hwnd)) {
        CloseFavGui()
        return
    }

    FavGui := Gui("+Owner" . MainGui.Hwnd . " +ToolWindow -Caption +Border", "Favorites")
    FavGui.MarginX := 6
    FavGui.MarginY := 6

    FavGui.OnEvent("Escape", (*) => CloseFavGui())

    yPos := 6
    if (FavoritesCache.Length = 0) {
        FavGui.Add("Text", "x10 y" . yPos . " w200 h24 Center 0x200", "(No favorites yet)")
    } else {
        for line in FavoritesCache {
            parts := StrSplit(line, "`t")
            if (parts.Length < 1 || parts[1] = "")
                continue
            url := parts[1]
            title := (parts.Length >= 2 && parts[2] != "") ? parts[2] : url
            displayTitle := StrLen(title) > 50 ? SubStr(title, 1, 47) . "..." : title

            xBtn := FavGui.Add("Text", "x8 y" . yPos . " w22 h22 Center 0x200 -Tabstop", "✕")
            xBtn.SetFont("s9 Bold", "Segoe UI")
            xBtn.OnEvent("Click", DeleteFavoriteItem.Bind(url))

            siteBtn := FavGui.Add("Text", "x34 y" . yPos . " w280 h22 0x200 -Tabstop", displayTitle)
            siteBtn.SetFont("s9")
            siteBtn.OnEvent("Click", OnFavoriteClick.Bind(url))

            yPos += 26
        }
    }

    ApplyGuiTheme(FavGui)

    FavoritesBtn.GetPos(&bx, &by, &bw, &bh)
    pt := Buffer(8, 0)
    NumPut("Int", bx, pt, 0)
    NumPut("Int", by + bh, pt, 4)
    DllCall("user32\ClientToScreen", "Ptr", MainGui.Hwnd, "Ptr", pt)
    gx := NumGet(pt, 0, "Int")
    gy := NumGet(pt, 4, "Int")

    FavGui.Show("x" . gx . " y" . gy . " Autosize")
}

DeleteFavoriteItem(url, *) {
    RemoveFavorite(url)
    UpdateStarIcon()
    CloseFavGui()
    ShowFavorites()
}

OnFavoriteClick(url, *) {
    CloseFavGui()
    NavigateToFavorite(url)
}

NavigateToFavorite(url, *) {
    global Tabs, ActiveTabIdx, DisplayedFullURL, URL_Input
    if (ActiveTabIdx > 0 && ActiveTabIdx <= Tabs.Length) {
        try Tabs[ActiveTabIdx].WB.Navigate(url)
        DisplayedFullURL := url
        URL_Input.Text := TruncateUrl(DisplayedFullURL)
        UpdateStarIcon()
    }
}

CreateComOrDie(clsid, iid, label) {
    try {
        return ComObject(clsid, iid)
    } catch as e {
        throw Error("Failed creating [" . label . "]  CLSID=" . clsid . "  IID=" . iid . "`n" . e.Message)
    }
}

SetupTaskbarJumpList() {
    appID := "Browser"
    DllCall("shell32\SetCurrentProcessExplicitAppUserModelID", "Str", appID)

	if A_IsAdmin || !A_IsCompiled
		return

    if !IsClassRegistered("{2D3468C1-36A7-43B6-AC24-D3F04FDB7C31}") {
        OutputDebug("Jumplist: EnumerableObjectCollection not registered, skipping.")
        return
    }

    try {
        cdl := ComObject("{77F10CF0-3DB5-4966-B520-B7C54FD35ED6}", "{6332DEBF-87B5-4670-90C0-5E57B408A49E}")
        ComCall(3, cdl, "Str", appID)

        maxSlots := 0
        IID_IObjectArray := Buffer(16)
        DllCall("ole32\CLSIDFromString", "Str", "{92CA9DCD-5622-4BBA-A805-5E9F541BD8C9}", "Ptr", IID_IObjectArray)
        pRemoved := 0
        ComCall(4, cdl, "UInt*", &maxSlots, "Ptr", IID_IObjectArray, "Ptr*", &pRemoved)

        BuildJumpListCategory(cdl, "Favorites", GetFavoritesForJumpList())
        BuildJumpListCategory(cdl, "Recently Closed", GetRecentHistoryForJumpList())

        tasks := ComObject("{2D3468C1-36A7-43B6-AC24-D3F04FDB7C31}", "{5632B1A4-E38A-400A-928A-D4CD63230295}")
        newWinLink := ComObject("{00021401-0000-0000-C000-000000000046}", "{000214F9-0000-0000-C000-000000000046}")
        ComCall(20, newWinLink, "Str", A_ScriptFullPath)
        ComCall(17, newWinLink, "Str", A_ScriptFullPath, "Int", 0)
        SetShellLinkTitle(newWinLink, "New Window")
        ComCall(5, tasks, "Ptr", newWinLink)

        ComCall(7, cdl, "Ptr", tasks)
        ComCall(8, cdl)
    } catch as e {
        OutputDebug("Jumplist setup failed: " . e.Message . " | What: " . e.What . " | Line: " . e.Line)
    }
}

IsClassRegistered(clsid) {
    try {
        RegRead("HKCR\CLSID\" . clsid . "\InprocServer32")
        return true
    }
    try {
        RegRead("HKCR\CLSID\" . clsid . "\LocalServer32")
        return true
    }
    return false
}

BuildJumpListShellLink(url, title) {
    link := ComObject("{00021401-0000-0000-C000-000000000046}", "{000214F9-0000-0000-C000-000000000046}")
    ComCall(20, link, "Str", A_ScriptFullPath)
    ComCall(11, link, "Str", '"' . url . '"')
    ComCall(17, link, "Str", A_ScriptFullPath, "Int", 0)

    displayTitle := (title != "") ? title : url
    if StrLen(displayTitle) > 60
        displayTitle := SubStr(displayTitle, 1, 57) . "..."
    SetShellLinkTitle(link, displayTitle)

    return link
}

SetShellLinkTitle(link, title) {
    propStore := ComObjQuery(link, "{886D8EEB-8CF2-4446-8D02-CDBA24C4E3D3}")
    if !propStore
        return

    PROPERTYKEY := Buffer(20, 0)
    DllCall("ole32\CLSIDFromString", "Str", "{F29F85E0-4FF9-1068-AB91-08002B27B3D9}", "Ptr", PROPERTYKEY)
    NumPut("UInt", 2, PROPERTYKEY, 16)

    PROPVARIANT := Buffer(A_PtrSize == 8 ? 24 : 16, 0)
    NumPut("UShort", 31, PROPVARIANT, 0)
    NumPut("Ptr", StrPtr(title), PROPVARIANT, 8)

    ComCall(6, propStore, "Ptr", PROPERTYKEY, "Ptr", PROPVARIANT)
    ComCall(7, propStore)
}

BuildJumpListCategory(cdl, categoryName, items) {
    if (items.Length = 0)
        return

    coll := ComObject("{2D3468C1-36A7-43B6-AC24-D3F04FDB7C31}", "{5632B1A4-E38A-400A-928A-D4CD63230295}")
    for it in items
        ComCall(5, coll, "Ptr", BuildJumpListShellLink(it.url, it.title))

    try ComCall(5, cdl, "Str", categoryName, "Ptr", coll)
}

GetFavoritesForJumpList(maxItems := 6) {
    global FavoritesCache
    result := []
    Loop FavoritesCache.Length {
        line := FavoritesCache[FavoritesCache.Length - A_Index + 1]
        parts := StrSplit(line, "`t", , 2)
        if (parts.Length < 1 || parts[1] = "")
            continue
        url := parts[1]
        title := (parts.Length >= 2 && parts[2] != "") ? parts[2] : url
        result.Push({ url: url, title: title })
        if (result.Length >= maxItems)
            break
    }
    return result
}

GetRecentHistoryForJumpList(maxItems := 6) {
    global HistoryFile
    result := []
    if !FileExist(HistoryFile)
        return result

    lines := StrSplit(FileRead(HistoryFile), "`n", "`r")
    seen := Map()
    Loop lines.Length {
        line := lines[lines.Length - A_Index + 1]
        if (line = "")
            continue
        parts := StrSplit(line, "`t", , 3)
        if (parts.Length < 2)
            continue
        url := parts[2]
        if seen.Has(url)
            continue
        seen[url] := true
        title := (parts.Length >= 3 && parts[3] != "") ? parts[3] : url
        result.Push({ url: url, title: title })
        if (result.Length >= maxItems)
            break
    }
    return result
}

ExistingSessions := GetSessionList()
if (ExistingSessions.Length = 0)
{
    CurrentSession := "Default"
    DirCreate(A_ScriptDir . "\Sessions\" . CurrentSession)
    IniWrite(CurrentSession, ConfigFile, "Session", "Name")
}
else if !ArrayHasValue(ExistingSessions, CurrentSession)
{
    CurrentSession := ExistingSessions[1]
    IniWrite(CurrentSession, ConfigFile, "Session", "Name")
}

SessionDir := A_ScriptDir . "\Sessions\" . CurrentSession
if !DirExist(SessionDir)
    DirCreate(SessionDir)

global HistoryFilePath := A_ScriptDir . "\history.dat"
HistoryFile := SessionDir . "\history.dat"
NewTabHtmlPath := SessionDir . "\newtab_page.html"
EditorHtmlPath := SessionDir . "\newtab_editor.html"
FavoritesFile := SessionDir . "\favorites.dat"
LoadFavoritesToMemory()

SetupTaskbarJumpList()

GenerateNewTabPage(false)

global LoaderPath := FindWebView2Loader()
StartupURL := IniRead(ConfigFile, "General", "StartupURL", "")

if (A_Args.Length >= 1 && Trim(A_Args[1]) != "" && A_Args[1] != "--browser-restart")
    StartupURL := Trim(A_Args[1])

if (LoaderPath = "")
{
    MsgBox("WebView2Loader.dll was not found.", "WebView2 Loader Missing", "Iconx")
    ExitApp
}

if (GetWebView2RuntimeVersion() = "")
{
    Result := MsgBox("WebView2 Runtime is not installed. Download now?", "Missing Runtime", "YesNo")
    if (Result = "Yes")
        Run("https://developer.microsoft.com/en-us/microsoft-edge/webview2/consumer/")
    ExitApp
}

MainGui := Gui("+Resize +MinSize600x400 -Caption +Border", "Browser")
MainGui.OnEvent("Size", MainGui_Size)
OnMessage(0x0083, WM_NCCALCSIZE)
OnMessage(0x0084, WM_NCHITTEST)

MainGui.OnEvent("Size", Gui_Size)
MainGui.OnEvent("Close", Gui_Close)

TabBar := MainGui.Add("Tab3", "x0 y8 w1200 h40 -Wrap +0x2000 +0x04000000")
SendMessage(0x132B, 0, (8 << 16) | 10,, "ahk_id " TabBar.Hwnd)
TabBar.SetFont("s10")
TabBar.OnEvent("Change", OnTabChange)
TabBar.UseTab()


MinBtn := MainGui.Add("Text", "x0 y0 w35 h28 Center 0x200 -Tabstop", Chr(0xE921))
MinBtn.SetFont("s9", "Segoe MDL2 Assets")
MinBtn.OnEvent("Click", (*) => MainGui.Minimize())

MaxBtn := MainGui.Add("Text", "x0 y0 w35 h28 Center 0x200 -Tabstop", Chr(0xE922))
MaxBtn.SetFont("s9", "Segoe MDL2 Assets")
MaxBtn.OnEvent("Click", ToggleMaximize)

CloseBtn := MainGui.Add("Text", "x0 y0 w40 h28 Center 0x200 -Tabstop", Chr(0xE8BB))
CloseBtn.SetFont("s9", "Segoe MDL2 Assets")
CloseBtn.OnEvent("Click", (*) => Gui_Close())

BackBtn := MainGui.Add("Text", "x10 y48 w35 h29 Center 0x200 -Tabstop", Chr(0xE72B))
BackBtn.SetFont("s14", "Segoe MDL2 Assets")
BackBtn.OnEvent("Click", GoBack)

ForwardBtn := MainGui.Add("Text", "x50 y48 w35 h29 Center 0x200 -Tabstop", Chr(0xE72A))
ForwardBtn.SetFont("s14", "Segoe MDL2 Assets")
ForwardBtn.OnEvent("Click", GoForward)

ReloadBtn := MainGui.Add("Text", "x90 y48 w35 h29 Center 0x200 -Tabstop", Chr(0xE72C))
ReloadBtn.SetFont("s14", "Segoe MDL2 Assets")
ReloadBtn.OnEvent("Click", ReloadPage)

UrlStatusText := MainGui.Add("Text", "x130 y48 w35 h29 Center 0x200", "🌐")
UrlStatusText.SetFont("s16")

URL_Input := MainGui.Add("Edit", "x170 y48 w420 h29 -Wrap -Multi +0x80 -VScroll", "")
URL_Input.SetFont("s11")

DllCall("SendMessage", "Ptr", URL_Input.Hwnd, "UInt", 0x00D3, "Ptr", 0x2, "Ptr", (32 << 16))
URL_Input.OnEvent("Focus", OnUrlFocus)
URL_Input.OnEvent("LoseFocus", OnUrlLoseFocus)
URL_Input.OnEvent("Change", OnUrlChange)

UrlInputSubclassProc := CallbackCreate(UrlInput_Subclass, "F", 6)
DllCall("comctl32\SetWindowSubclass", "Ptr", URL_Input.Hwnd, "Ptr", UrlInputSubclassProc, "UPtr", 9998, "UPtr", 0)

InitSuggestionGui()

HiddenGoBtn := MainGui.Add("Button", "x-100 y-100 w40 h20 Hidden", "Go")
HiddenGoBtn.OnEvent("Click", Navigate)

BrowserHost := MainGui.Add("Text", "x10 y82 w1180 h708")
BrowserHost.BackColor := "1E1E1E"

FavoritesBtn := MainGui.Add("Text", "x590 y48 w35 h29 Center 0x200 -Tabstop", Chr(0xE734))
FavoritesBtn.SetFont("s14", "Segoe MDL2 Assets")
FavoritesBtn.OnEvent("Click", ShowFavorites)

DownloadBtn := MainGui.Add("Text", "x630 y48 w35 h29 Center 0x200 -Tabstop", Chr(0xE896))
DownloadBtn.SetFont("s14", "Segoe MDL2 Assets")
DownloadBtn.OnEvent("Click", ShowDownloads)

HistoryBtn := MainGui.Add("Text", "x670 y48 w35 h29 Center 0x200 -Tabstop", Chr(0xE81C))
HistoryBtn.SetFont("s14", "Segoe MDL2 Assets")
HistoryBtn.OnEvent("Click", (*) => ShowHistory())

SettingsBtn := MainGui.Add("Text", "x710 y48 w35 h29 Center 0x200 -Tabstop", Chr(0xE713))
SettingsBtn.SetFont("s14", "Segoe MDL2 Assets")
SettingsBtn.OnEvent("Click", OpenSettings)

for ctrl in [MinBtn, MaxBtn, CloseBtn, BackBtn, ForwardBtn, ReloadBtn, FavoritesBtn, DownloadBtn, HistoryBtn, SettingsBtn]
    IconCtrlHwnds[ctrl.Hwnd] := true

MainGuiControlsReady := true

TransparentControls := [
    MinBtn, MaxBtn, CloseBtn,
    BackBtn, ForwardBtn, ReloadBtn,
    FavoritesBtn, DownloadBtn, HistoryBtn, SettingsBtn
]

OnMessage(0x0201, WM_LBUTTONDOWN)
OnMessage(0x0207, WM_MBUTTONDOWN)
OnMessage(0x0014, WM_ERASEBKGND)
OnMessage(0x002B, WM_DRAWITEM)
OnMessage(0x004E, WM_NOTIFY)
OnMessage(0x0133, WM_CTLCOLOREDIT)
OnMessage(0x0134, WM_CTLCOLORLISTBOX)
OnMessage(0x0135, WM_CTLCOLORBTN)
OnMessage(0x0136, WM_CTLCOLORDLG)
OnMessage(0x0138, WM_CTLCOLORSTATIC)
OnMessage(0x0201, WM_LBUTTONDOWN_DRAG)
OnMessage(0x0200, WM_MOUSEMOVE)

OnMessage(0x0006, WM_ACTIVATE_FavGui)

WM_ACTIVATE_FavGui(wParam, lParam, msg, hwnd) {
    global FavGui
    if (IsSet(FavGui) && FavGui != "" && hwnd == FavGui.Hwnd && (wParam & 0xFFFF) == 0) {
        SetTimer(CloseFavGui, -10)
    }
}

CloseFavGui() {
    global FavGui
    if (IsSet(FavGui) && FavGui != "" && WinExist("ahk_id " . FavGui.Hwnd)) {
        FavGui.Destroy()
        FavGui := ""
    }
}


SetTimer(CheckMouseHoverOut, 200)

WM_NCHITTEST(wParam, lParam, msg, hwnd) {
    global MainGui

    if (!IsSet(MainGui))
        return

    rootHwnd := DllCall("user32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    if (rootHwnd != MainGui.Hwnd)
        return

    if DllCall("user32\IsZoomed", "Ptr", MainGui.Hwnd)
        return

    borderWidth := 8

    x := lParam & 0xFFFF
    x := (x >= 0x8000) ? x - 0x10000 : x
    y := (lParam >> 16) & 0xFFFF
    y := (y >= 0x8000) ? y - 0x10000 : y

    rect := Buffer(16, 0)
    DllCall("user32\GetWindowRect", "Ptr", MainGui.Hwnd, "Ptr", rect)
    wx := NumGet(rect, 0, "Int")
    wy := NumGet(rect, 4, "Int")
    ww := NumGet(rect, 8, "Int") - wx
    wh := NumGet(rect, 12, "Int") - wy

    left   := (x >= wx && x < wx + borderWidth)
    right  := (x >= wx + ww - borderWidth && x < wx + ww)
    top    := (y >= wy && y < wy + borderWidth)
    bottom := (y >= wy + wh - borderWidth && y < wy + wh)

    if (top && left)
        return 13
    if (top && right)
        return 14
    if (bottom && left)
        return 16
    if (bottom && right)
        return 17
    if (left)
        return 10
    if (right)
        return 11
    if (top)
        return 12
    if (bottom)
        return 15
}

MainGui_Size(thisGui, MinMax, Width, Height)
{
    if (MinMax == -1)
        return

    topMargin := 45

    if IsSet(UrlEdit) && HasProp(UrlEdit, "Hwnd")
        UrlEdit.Move(,, Width - 180)

    if IsSet(wv) && HasProp(wv, "Move")
        wv.Move(0, topMargin, Width, Height - topMargin)
}



WM_MOUSEMOVE(wParam, lParam, msg, hwnd)
{
    global TransparentControls, ActiveHoverHwnd, HBRUSH_HOVER, CurrentThemeIsDark

    ctrl := GuiCtrlFromHwnd(hwnd)
    hoveredHwnd := 0

    if (ctrl) {
        for btn in TransparentControls {
            if (btn.Hwnd == ctrl.Hwnd) {
                hoveredHwnd := ctrl.Hwnd
                break
            }
        }
    }

    if (hoveredHwnd != ActiveHoverHwnd) {
        if (ActiveHoverHwnd) {
            oldHwnd := ActiveHoverHwnd
            ActiveHoverHwnd := 0
            SetWindowBorder(oldHwnd, false)
            DllCall("user32\InvalidateRect", "Ptr", oldHwnd, "Ptr", 0, "Int", 1)
        }

        ActiveHoverHwnd := hoveredHwnd

        if (ActiveHoverHwnd) {
            if (HBRUSH_HOVER)
                DllCall("gdi32\DeleteObject", "Ptr", HBRUSH_HOVER)
            hoverHex := CurrentThemeIsDark ? "3A3A3A" : "E5E5E5"
            HBRUSH_HOVER := DllCall("gdi32\CreateSolidBrush", "UInt", HexToColorRef(hoverHex), "Ptr")

            SetWindowBorder(ActiveHoverHwnd, true)
            DllCall("user32\InvalidateRect", "Ptr", ActiveHoverHwnd, "Ptr", 0, "Int", 1)
        }
    }
}

AddCustomGroupBox(guiObj, x, y, w, h, titleText)
{
    global CurrentThemeBg, AppTheme, ColorPresetMap

    cleanTextColor := GetAutoTextColor(CurrentThemeBg)

    cleanBgColor := ColorPresetMap.Has(AppTheme)
        ? StrReplace(ColorPresetMap[AppTheme], "#", "")
        : "Default"

    guiObj.Add(
        "GroupBox",
        Format("x{} y{} w{} h{}", x, y, w, h),
        ""
    )

    bgOpt := (cleanBgColor != "" && cleanBgColor != "Default")
        ? " Background" . cleanBgColor
        : ""

    return guiObj.Add(
        "Text",
        Format(
            "x{} y{} c{} {}",
            x + 8,
            y - 3,
            cleanTextColor,
            bgOpt
        ),
        " " . titleText . " "
    )
}

AddThemedCheckbox(guiObj, x, y, w, checked, labelText)
{
    global CurrentThemeBg, CurrentGuiFontName

    textColor := GetAutoTextColor(CurrentThemeBg)

    chk := guiObj.Add(
        "Checkbox",
        "x" . x . " y" . y . " w20 h20 Checked" . checked
    )

    label := guiObj.Add(
        "Text",
        "x" . (x + 24)
        . " y" . (y + 3)
        . " w" . (w - 24)
        . " h20 +BackgroundTrans c" . textColor,
        labelText
    )

    label.SetFont(
        "c" . textColor,
        CurrentGuiFontName
    )

    label.OnEvent(
        "Click",
        (*) => chk.Value := !chk.Value
    )

    try DllCall(
        "uxtheme\SetWindowTheme",
        "Ptr", chk.Hwnd,
        "Ptr", 0,
        "Ptr", 0
    )

    return chk
}
SetWindowBorder(hwnd, enable) {
    WS_BORDER := 0x00800000
    style := DllCall("user32\GetWindowLong", "Ptr", hwnd, "Int", -16, "UInt")
    newStyle := enable ? (style | WS_BORDER) : (style & ~WS_BORDER)
    if (style != newStyle) {
        DllCall("user32\SetWindowLong", "Ptr", hwnd, "Int", -16, "UInt", newStyle)
        DllCall("user32\SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0037)
    }
}

CheckMouseHoverOut() {
    global ActiveHoverHwnd
    if (!ActiveHoverHwnd)
        return

    MouseGetPos ,, &winHwnd, &ctrlHwnd, 2
    if (ctrlHwnd != ActiveHoverHwnd) {
        oldHwnd := ActiveHoverHwnd
        ActiveHoverHwnd := 0
        SetWindowBorder(oldHwnd, false)
        DllCall("user32\InvalidateRect", "Ptr", oldHwnd, "Ptr", 0, "Int", 1)
    }
}

SetTimer(CheckMouseHoverOut, 200)

WM_LBUTTONDOWN_DRAG(wParam, lParam, msg, hwnd) {
    if (hwnd == MainGui.Hwnd) {
        PostMessage(0xA1, 2,,, "ahk_id " MainGui.Hwnd)
    }
}

OnMessage(0x0024, WM_GETMINMAXINFO)

WM_GETMINMAXINFO(wParam, lParam, msg, hwnd) {
    global MainGui

    if (IsSet(MainGui) && MainGui && hwnd == MainGui.Hwnd) {
        SPI_GETWORKAREA := 0x0030
        rect := Buffer(16, 0)
        if DllCall("user32\SystemParametersInfo", "UInt", SPI_GETWORKAREA, "UInt", 0, "Ptr", rect.Ptr, "UInt", 0) {
            waLeft   := NumGet(rect, 0, "Int")
            waTop    := NumGet(rect, 4, "Int")
            waWidth  := NumGet(rect, 8, "Int") - waLeft
            waHeight := NumGet(rect, 12, "Int") - waTop

            borderX := DllCall("user32\GetSystemMetrics", "Int", 32)
            borderY := DllCall("user32\GetSystemMetrics", "Int", 33)
            padding := DllCall("user32\GetSystemMetrics", "Int", 92)

            offsetX := borderX + padding
            offsetY := borderY + padding

            NumPut("Int", waWidth + (offsetX * 2),  lParam, 8)
            NumPut("Int", waHeight + (offsetY * 2), lParam, 12)
            NumPut("Int", waLeft - offsetX,         lParam, 16)
            NumPut("Int", waTop - offsetY,          lParam, 20)
            return 0
        }
    }
}

ApplyGuiTheme(MainGui)
ApplyGuiTheme(SuggestionGui)

MainGui.Show("w1200 h800")
MainGui.Maximize()
WinRedraw("ahk_id " . MainGui.Hwnd)

SetTimer(() => OpenStartupTabs(), -50)


CreateNewTab(url := "", onReady := "")
{
    global Tabs, ActiveTabIdx, URL_Input, DisplayedFullURL, NewTabHtmlPath

    if (url = "")
        url := "file:///" . StrReplace(StrReplace(NewTabHtmlPath, "\", "/"), " ", "%20")

    tabObj := {
        Controller: "",
        WB: "",
        Title: "Loading...",
        LastURL: url,
        IsLoading: true,

        TitleToken: "",
        SourceToken: "",
        NavStartToken: "",
        NavCompleteToken: "",
        NewWindowToken: "",
        WindowCloseToken: ""
    }

    Tabs.Push(tabObj)

    ActiveTabIdx := Tabs.Length
    RefreshTabs()
    SwitchToTab(ActiveTabIdx)

    InitWebViewForTab(tabObj, url, onReady)

    if (IsNewTabUrl(url))
    {
        DisplayedFullURL := ""

        if IsSet(URL_Input) && URL_Input
        {
            URL_Input.Text := ""
            URL_Input.Focus()
        }
    }
    else
    {
        DisplayedFullURL := url

        if IsSet(URL_Input) && URL_Input
            URL_Input.Text := TruncateUrl(DisplayedFullURL)
    }
}


RefreshTabs()
{
    global Tabs, TabBar, ActiveTabIdx, IgnoreTabChange, TabWidthPadding, MainGui

    IgnoreTabChange := true
    TabBar.Delete()

    AvailWidth := 1085
    if (IsSet(MainGui) && MainGui) {
        MainGui.GetPos(,, &w)
        AvailWidth := Max(100, w - 120)
    }

    PlusTabWidth := 40
    AvailWidthForTabs := Max(60, AvailWidth - PlusTabWidth)

    MaxTabWidth := 180

    PixelsPerTab := Tabs.Length > 0
        ? Min(MaxTabWidth, Floor(AvailWidthForTabs / Tabs.Length))
        : MaxTabWidth
    PixelsPerTab := Max(1, PixelsPerTab)

    TotalCharsPerTab := Max(1, Floor(PixelsPerTab / 8))
    MaxTitleLen := Max(1, Min(30, TotalCharsPerTab - 3))

    tabList := []
    for i, tab in Tabs {
        tName := (tab.Title != "") ? tab.Title : "New Tab"

        if (StrLen(tName) > MaxTitleLen) {
            if (MaxTitleLen <= 2)
                tName := SubStr(tName, 1, MaxTitleLen)
            else
                tName := SubStr(tName, 1, MaxTitleLen - 1) . "…"
        } else {
            while (StrLen(tName) < MaxTitleLen)
                tName .= " "
        }

        tabList.Push(tName . "  x")
    }

    tabList.Push(" + ")
    TabBar.Add(tabList)

    if (ActiveTabIdx > 0 && ActiveTabIdx <= Tabs.Length)
        TabBar.Choose(ActiveTabIdx)

    IgnoreTabChange := false
}
OnTabChange(guiCtrl, *)
{
    global Tabs, IgnoreTabChange

    if (IgnoreTabChange)
        return

    selectedIdx := guiCtrl.Value
    if (selectedIdx == 0)
        return

    if (selectedIdx > Tabs.Length) {
        CreateNewTab()
    } else {
        SwitchToTab(selectedIdx)
    }
}

SwitchToTab(index)
{
    global Tabs, ActiveTabIdx, TabBar, URL_Input, MainGui, IgnoreTabChange, UrlStatusText, DisplayedFullURL, EnableSuspendTabs

    if (index < 1 || index > Tabs.Length)
        return

    SetTimer(FetchAndShowSuggestions, 0)
    SetTimer(HideSuggestions, 0)
    HideSuggestions()

    ActiveTabIdx := index

    IgnoreTabChange := true
    TabBar.Choose(index)
    IgnoreTabChange := false

    targetTab := Tabs[index]

    DisplayedFullURL := (targetTab.Controller != "" && targetTab.WB.Source != "")
        ? targetTab.WB.Source
        : targetTab.LastURL

    if IsSet(URL_Input) && URL_Input {
        if (IsNewTabUrl(DisplayedFullURL)) {
            URL_Input.Text := ""
        } else {
            URL_Input.Text := TruncateUrl(DisplayedFullURL)
        }
    }

    if (targetTab.Controller != "")
    {
        if (EnableSuspendTabs)
            try targetTab.WB.Resume()

        targetTab.Controller.IsVisible := true
        targetTab.Controller.Fill()

        UpdateStarIcon()
        docTitle := targetTab.WB.DocumentTitle
        MainGui.Title := "Browser - " . (docTitle != "" ? docTitle : "Untitled")
        UrlStatusText.Text := targetTab.IsLoading ? "҉҉" : "🌐"
    }
    else
    {
        MainGui.Title := "Browser - " . (targetTab.Title != "" ? targetTab.Title : "Loading...")
        UrlStatusText.Text := "҉҉"
    }

    for i, tab in Tabs
    {
        if (i != index && tab.Controller != "")
        {
            tab.Controller.IsVisible := false
            if (EnableSuspendTabs)
                try tab.WB.TrySuspend()
        }
    }
}

CloseTab(idx) {
    global Tabs, ActiveTabIdx

    if (idx < 1 || idx > Tabs.Length)
        return

    try tab := Tabs[idx]
    catch
        return

    try tab.WB.remove_DocumentTitleChanged(tab.TitleToken)
    try tab.WB.remove_SourceChanged(tab.SourceToken)
    try tab.WB.remove_NavigationStarting(tab.NavStartToken)
    try tab.WB.remove_NavigationCompleted(tab.NavCompleteToken)
	try tab.WB.remove_WebMessageReceived(tab.WebMsgToken)
    try tab.WB.remove_NewWindowRequested(tab.NewWindowToken)
    try tab.WB.remove_WindowCloseRequested(tab.WindowCloseToken)

    try {
        if (tab.Controller)
            tab.Controller.Close()
    }

    tab.WB := ""
    tab.Controller := ""

    if (idx >= 1 && idx <= Tabs.Length)
        Tabs.RemoveAt(idx)


    if (Tabs.Length == 0) {
        ActiveTabIdx := 0
        CreateNewTab()
        return
    }

    if (ActiveTabIdx > Tabs.Length)
        ActiveTabIdx := Tabs.Length
    else if (ActiveTabIdx == idx)
        ActiveTabIdx := Max(1, idx - 1)
    else if (ActiveTabIdx > idx)
        ActiveTabIdx -= 1

    RefreshTabs()
    SwitchToTab(ActiveTabIdx)
}

OnButtonHover(ctrl, *)
{
    global CurrentThemeIsDark
    hoverColor := CurrentThemeIsDark ? "3A3A3A" : "E5E5E5"
    ctrl.Opt("+Border Background" . hoverColor)
    ctrl.Redraw()
}

OnButtonLeave(ctrl, *)
{
    ctrl.Opt("-Border BackgroundTrans")
    ctrl.Redraw()
}

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global TabBar, Tabs

    if (hwnd == TabBar.Hwnd) {
        x := lParam & 0xFFFF
        y := lParam >> 16

        hti := Buffer(12, 0)
        NumPut("Int", x, hti, 0)
        NumPut("Int", y, hti, 4)

        tabIndex := SendMessage(0x130D, 0, hti.Ptr,, "ahk_id " TabBar.Hwnd)

        if (tabIndex >= 0) {
            if (tabIndex == Tabs.Length)
                return

            rect := Buffer(16, 0)
            SendMessage(0x130A, tabIndex, rect.Ptr,, "ahk_id " TabBar.Hwnd)

            rightEdge := NumGet(rect, 8, "Int")
            HitBoxWidth := 20 * (A_ScreenDPI / 96)
            if (rightEdge - x < HitBoxWidth) {
                CloseTab(tabIndex + 1)
                return 1
            }
        }
    }
}

WM_MBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global TabBar, Tabs
    if (hwnd == TabBar.Hwnd) {
        x := lParam & 0xFFFF
        y := lParam >> 16
        hti := Buffer(12, 0)
        NumPut("Int", x, hti, 0)
        NumPut("Int", y, hti, 4)

        tabIndex := SendMessage(0x130D, 0, hti.Ptr,, "ahk_id " TabBar.Hwnd)

        if (tabIndex >= 0 && tabIndex < Tabs.Length) {
            CloseTab(tabIndex + 1)
            return 1
        }
    }
}

SetTabTitle(tabIndex, newTitle) {
    global TabBar, TabWidthPadding
    fullTitle := newTitle . TabWidthPadding . "   x"
    mask := 0x0001
    tcitem := Buffer(A_PtrSize = 8 ? 40 : 28, 0)

    NumPut("UInt", mask, tcitem, 0)
    NumPut("Ptr", StrPtr(fullTitle), tcitem, A_PtrSize = 8 ? 16 : 12)

    SendMessage(0x133D, tabIndex - 1, tcitem.Ptr,, "ahk_id " TabBar.Hwnd)
}

InitWebViewForTab(tabObj, startUrl, onReady := "")
{
    global BrowserHost, LoaderPath
    global CurrentSession, ProxyEnabled, ProxyHost, ProxyPort, ProxyUser, ProxyPass, ProxyBypass
    global uBlockPath, ExtraCmdFlags

    Options := ""
    if (ProxyEnabled && ProxyHost != "" && ProxyPort != "")
    {
        Options := "--proxy-server=" . ProxyHost . ":" . ProxyPort
        if (ProxyBypass != "")
            Options .= " --proxy-bypass-list=" . ProxyBypass
    }

    if DirExist(uBlockPath) && FileExist(uBlockPath . "\manifest.json")
    {
        Options .= (Options != "" ? " " : "") . "--load-extension=`"" . uBlockPath . "`""
    }

    if (ExtraCmdFlags != "")
        Options .= (Options != "" ? " " : "") . ExtraCmdFlags

    UserDataFolder := A_ScriptDir . "\Sessions\" . CurrentSession
    if !DirExist(UserDataFolder)
        DirCreate(UserDataFolder)

    EnvOptions := { AreBrowserExtensionsEnabled: true }
    if (Options != "")
        EnvOptions.AdditionalBrowserArguments := Options

    WebView2.CreateControllerAsync(BrowserHost.Hwnd, EnvOptions, UserDataFolder, "", LoaderPath).Then(
        (Controller) => OnControllerCreated(tabObj, Controller, startUrl, onReady),
        (err) => MsgBox("WebView2 failed to start:`n`n" . err.Message, "WebView2 Error", "Iconx")
    )
}

OnControllerCreated(tabObj, Controller, startUrl, onReady := "")
{
    global ProxyEnabled, ProxyUser
    try
    {
        try Controller.DefaultBackgroundColor := 0x00000000

        WB := Controller.CoreWebView2

        tabObj.Controller := Controller
        tabObj.WB := WB

		tabObj.TitleToken :=
			WB.add_DocumentTitleChanged(
				OnTitleChanged.Bind(tabObj)
			)
		tabObj.SourceToken :=
			WB.add_SourceChanged(
				OnSourceChanged.Bind(tabObj)
			)
		tabObj.NavStartToken :=
			WB.add_NavigationStarting(
				OnNavigationStarting.Bind(tabObj)
			)
		tabObj.NavCompleteToken :=
			WB.add_NavigationCompleted(
				OnNavigationCompleted.Bind(tabObj)
			)

		tabObj.WebMsgToken :=
			WB.add_WebMessageReceived(
				OnWebMessageReceived.Bind(tabObj)
			)

		tabObj.NewWindowToken :=
			WB.add_NewWindowRequested(
				OnNewWindowRequested.Bind(tabObj)
			)
		tabObj.WindowCloseToken :=
			WB.add_WindowCloseRequested(
				OnWindowCloseRequested.Bind(tabObj)
			)

        if (ProxyEnabled && ProxyUser != "")
            WB.add_BasicAuthenticationRequested(OnBasicAuthRequested)

        Settings := WB.Settings
        Settings.IsScriptEnabled := true
        Settings.AreDefaultContextMenusEnabled := true
        Settings.IsZoomControlEnabled := true
        Settings.AreDefaultScriptDialogsEnabled := true

        if (startUrl != "")
            WB.Navigate(startUrl)

        if (IsTabActive(tabObj)) {
            Controller.IsVisible := true
            Controller.Fill()
        } else {
            Controller.IsVisible := false
        }

        if (onReady)
            onReady(tabObj)
    }
    catch as err
    {
        MsgBox("WebView2 layout error:`n`n" . err.Message . "`n`nLine: " . err.Line . "`nWhat: " . err.What,
            "WebView2 Error", "Iconx")
    }
}
HandlePopupInMainWindow(args, deferral)
{
    global Tabs, ActiveTabIdx

    tabObj := { Controller: "", WB: "", Title: "Loading...", LastURL: "", IsLoading: true }
    Tabs.Push(tabObj)

    ActiveTabIdx := Tabs.Length
    RefreshTabs()
    SwitchToTab(ActiveTabIdx)

    InitWebViewForTab(tabObj, "", (readyTab) => (
        args.NewWindow := readyTab.WB,
        args.Handled := true,
        deferral.Complete()
    ))
}
OnNavigationStarting(tabObj, sender, args)
{
    global UrlStatusText
    tabObj.IsLoading := true
    if (IsTabActive(tabObj))
        try UrlStatusText.Text := "҉҉"
}

OnNavigationCompleted(tabObj, sender, args)
{
    global UrlStatusText, EditorModeActive, ActiveEditorTab
    tabObj.IsLoading := false
    if (IsTabActive(tabObj))
        try UrlStatusText.Text := "🌐"

    if (EditorModeActive && ActiveEditorTab != "" && tabObj == ActiveEditorTab)
        ShowLockOverlay(false)
}

OnWebMessageReceived(tabObj, sender, args)
{
    msg := ""
    try msg := args.TryGetWebMessageAsString()
    if (msg = "")
        return

    if (msg = "OPEN_EDITOR")
    {
        OpenNewTabEditor()
    }
    else if (InStr(msg, "SAVE_EDITOR:") = 1)
    {
        htmlContent := SubStr(msg, StrLen("SAVE_EDITOR:") + 1)
        SaveCustomNewTabHtml(htmlContent, tabObj)
    }
    else if (msg = "CANCEL_EDITOR")
    {
        CancelNewTabEditor(tabObj)
    }
    else if (InStr(msg, "LIVE_THEME:") = 1)
    {
        parts := StrSplit(SubStr(msg, StrLen("LIVE_THEME:") + 1), "|")
        if (parts.Length = 4)
            ApplyCustomTheme(parts[1], parts[2], parts[3], parts[4], false)
    }
    else if (InStr(msg, "SAVE_THEME:") = 1)
    {
        parts := StrSplit(SubStr(msg, StrLen("SAVE_THEME:") + 1), "|")
        if (parts.Length = 4)
            ApplyCustomTheme(parts[1], parts[2], parts[3], parts[4], true)
    }

    else if (msg = "REVERT_THEME")
    {
        RevertLiveTheme()
    }
    else if (msg = "IMPORT_HTML")
    {
        ImportHtmlIntoEditor(tabObj)
    }
    else if (msg = "IMPORT_FONT")
    {
        ImportFontFile(tabObj)
    }
    else if (InStr(msg, "LIVE_FONT:") = 1)
    {
        fontName := SubStr(msg, StrLen("LIVE_FONT:") + 1)
        CurrentGuiFontFile := ""
        ApplyCustomFont(fontName, false)
    }
    else if (InStr(msg, "SAVE_FONT:") = 1)
    {
        fontName := SubStr(msg, StrLen("SAVE_FONT:") + 1)
        ApplyCustomFont(fontName, true)
    }
    else if (msg = "REVERT_FONT")
    {
        RevertLiveFont()
    }
}
SavePaletteColors(data)
{
    global ColorPresetMap, ConfigFile, AppTheme, MainGui

    for entry in StrSplit(data, ";")
    {
        if (entry = "")
            continue
        parts := StrSplit(entry, "|")
        if (parts.Length != 2)
            continue
        pName := parts[1]
        pHex  := parts[2]
        if (SubStr(pHex, 1, 1) != "#")
            pHex := "#" . pHex
        ColorPresetMap[pName] := pHex
        IniWrite(pHex, ConfigFile, "Palette", pName)
    }

    if (IsSet(MainGui) && ColorPresetMap.Has(AppTheme))
        try ApplyGuiTheme(MainGui)
}

OpenNewTabEditor()
{
    global EditorModeActive, EditorHtmlPath, Tabs, MainGui

    if (EditorModeActive)
        return

    EditorModeActive := true

    MainGui.Opt("-Disabled")
    BlurActivePage(false)
    SetEditorLockUI(false, false)
    if (LockOverlayGui != "")
        HideLockOverlay()

    pid := ProcessExist()
    if WinExist("Settings ahk_pid " . pid)
        WinClose("Settings ahk_pid " . pid)

    html := BuildEditorPageHtml()
    try FileDelete(EditorHtmlPath)
    FileAppend(html, EditorHtmlPath, "UTF-8")

    editorUrl := "file:///" . StrReplace(StrReplace(EditorHtmlPath, "\", "/"), " ", "%20")
    CreateNewTab(editorUrl)
    editorTabObj := Tabs[Tabs.Length]
    ActiveEditorTab := editorTabObj

    idx := Tabs.Length - 1
    while (idx >= 1)
    {
        if (Tabs[idx] != editorTabObj)
        {
            url := ""
            try url := Tabs[idx].WB.Source
            if (IsNewTabUrl(url) || url = "")
                CloseTab(idx)
        }
        idx--
    }
}

SaveCustomNewTabHtml(htmlContent, editorTabObj := "")
{
    global NewTabHtmlPath

    if (SubStr(htmlContent, 1, 21) != "<!--CUSTOM_NEWTAB-->")
        htmlContent := "<!--CUSTOM_NEWTAB-->`n" . htmlContent

    try
    {
        f := FileOpen(NewTabHtmlPath, "w", "UTF-8")
        f.Write(htmlContent)
        f.Close()
    }
    catch as err
    {
        MsgBox("Failed to save custom tab HTML:`n" . err.Message, "Save Error", "Iconx")
        SetEditorLockUI(false)
        return
    }

    FinishEditorSession(editorTabObj)
}

CancelNewTabEditor(editorTabObj := "")
{
    FinishEditorSession(editorTabObj)
}

FinishEditorSession(editorTabObj)
{
    global EditorModeActive, Tabs, ActiveTabIdx, ActiveEditorTab

    EditorModeActive := false
    ActiveEditorTab := ""
    SetEditorLockUI(false)

    idx := 0
    if (editorTabObj != "")
    {
        for i, t in Tabs
        {
            if (t == editorTabObj)
            {
                idx := i
                break
            }
        }
    }

    if (idx == 0 && ActiveTabIdx > 0)
        idx := ActiveTabIdx

    if (idx > 0 && idx <= Tabs.Length)
        CloseTab(idx)
    else
        CreateNewTab()
}

SetEditorLockUI(lock, full := false)
{
    global URL_Input, BackBtn, ForwardBtn, ReloadBtn, FavoritesBtn, DownloadBtn, HistoryBtn, SettingsBtn, TabBar

    try URL_Input.Enabled := !lock
    try BackBtn.Enabled := !lock
    try ForwardBtn.Enabled := !lock
    try ReloadBtn.Enabled := !lock
    try FavoritesBtn.Enabled := !lock
    try DownloadBtn.Enabled := !lock
    try HistoryBtn.Enabled := !lock
    try SettingsBtn.Enabled := !lock
    try TabBar.Enabled := !lock

    if lock
        ShowLockOverlay(full)
    else
        HideLockOverlay()
}
CreateLockOverlay() {
    global MainGui, LockOverlayGui

    LockOverlayGui := Gui("+Owner" . MainGui.Hwnd . " +ToolWindow -Caption +AlwaysOnTop -DPIScale", "")
    LockOverlayGui.BackColor := "000000"
    LockOverlayGui.MarginX := 0
    LockOverlayGui.MarginY := 0
    LockOverlayGui.Add("Edit", "x-100 y-100 w1 h1 -TabStop -Border")

	DetectHiddenWindows true
	WinSetTransparent(120, "ahk_id " . LockOverlayGui.Hwnd)
	DetectHiddenWindows false
}

ShowLockOverlay(full := false) {
    global MainGui, LockOverlayGui, LockOverlayFullCover
    if (LockOverlayGui = "")
        CreateLockOverlay()

    LockOverlayFullCover := full

    MainGui.GetClientPos(&cx, &cy, &cw, &ch)
    pt := Buffer(8, 0)
    NumPut("Int", cx, pt, 0)
    NumPut("Int", cy, pt, 4)
    DllCall("user32\ClientToScreen", "Ptr", MainGui.Hwnd, "Ptr", pt)
    sx := NumGet(pt, 0, "Int")
    sy := NumGet(pt, 4, "Int")

    overlayH := full ? ch : 82
    if full {
        LockOverlayGui.Show("x" . sx . " y" . sy . " w" . cw . " h" . overlayH)
    } else {
        LockOverlayGui.Show("x" . sx . " y" . sy . " w" . cw . " h" . overlayH . " NoActivate")
        WinActivate("ahk_id " . MainGui.Hwnd)
    }
}

RepositionLockOverlay() {
    global MainGui, LockOverlayGui, LockOverlayFullCover
    if (LockOverlayGui = "" || !DllCall("IsWindowVisible", "Ptr", LockOverlayGui.Hwnd))
        return

    MainGui.GetClientPos(&cx, &cy, &cw, &ch)
    pt := Buffer(8, 0)
    NumPut("Int", cx, pt, 0)
    NumPut("Int", cy, pt, 4)
    DllCall("user32\ClientToScreen", "Ptr", MainGui.Hwnd, "Ptr", pt)
    sx := NumGet(pt, 0, "Int")
    sy := NumGet(pt, 4, "Int")

    overlayH := LockOverlayFullCover ? ch : 82
    LockOverlayGui.Move(sx, sy, cw, overlayH)
}

HideLockOverlay() {
    global LockOverlayGui
    if (LockOverlayGui != "")
        LockOverlayGui.Hide()
}

OnNewWindowRequested(tabObj, sender, args)
{
    global MainGui
    deferral := args.GetDeferral()
    try
    {
        uri := args.Uri
        if (InStr(uri, "accounts.google.com") || InStr(uri, "facebook.com/dialog/oauth"))
        {
            popupGui := Gui("+Resize +Owner" . MainGui.Hwnd, "Authentication")
            SetTimer(() => InitWebViewForPopup(popupGui, args, deferral), -1)
            return
        }
        SetTimer(() => HandlePopupInMainWindow(args, deferral), -1)
    }
    catch Error as err
    {
        args.Handled := true
        deferral.Complete()
    }
}
InitWebViewForPopup(popupGui, args, deferral)
{
    global LoaderPath, CurrentSession, ProxyEnabled, ProxyHost, ProxyPort, ProxyBypass, uBlockPath

    Options := ""
    if (ProxyEnabled && ProxyHost != "" && ProxyPort != "")
    {
        Options := "--proxy-server=" . ProxyHost . ":" . ProxyPort
        if (ProxyBypass != "")
            Options .= " --proxy-bypass-list=" . ProxyBypass
    }

    if DirExist(uBlockPath) && FileExist(uBlockPath . "\manifest.json")
    {
        Options .= (Options != "" ? " " : "") . "--load-extension=`"" . uBlockPath . "`""
    }

    UserDataFolder := A_ScriptDir . "\Sessions\" . CurrentSession
    EnvOptions := { AreBrowserExtensionsEnabled: true }
    if (Options != "")
        EnvOptions.AdditionalBrowserArguments := Options

    WebView2.CreateControllerAsync(popupGui.Hwnd, EnvOptions, UserDataFolder, "", LoaderPath).Then(
        (Controller) => OnPopupControllerCreated(popupGui, Controller, args, deferral),
        (err) => (deferral.Complete(), popupGui.Destroy())
    )
}

OnPopupControllerCreated(popupGui, Controller, args, deferral)
{
    WB := Controller.CoreWebView2

    WB.add_DocumentTitleChanged((sender, *) => popupGui.Title := sender.DocumentTitle)

    WB.add_WindowCloseRequested((*) => popupGui.Destroy())

    popupGui.OnEvent("Size", (*) => Controller.Fill())

    args.NewWindow := WB
    args.Handled := true
    deferral.Complete()

    popupGui.Show("w800 h600 Center")
    Controller.Fill()
}

OnWindowCloseRequested(tabObj, sender, args)
{
    global Tabs
    try {
        for i, t in Tabs {
            if (t == tabObj) {
                CloseTab(i)
                break
            }
        }
    }
}

LogHistory(url, title) {
    global HistoryFile, HistoryCache, IsHistoryDisabled
    if (IsHistoryDisabled || url = "" || url = "about:blank" || InStr(url, "newtab_page.html"))
        return

    TimeString := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    HistoryLine := TimeString . "`t" . url . "`t" . (title != "" ? title : "Untitled")
    HistoryCache.Push(HistoryLine)
    FileAppend(HistoryLine . "`n", HistoryFile)
}

GetHistoryMatches(query, maxResults := 5) {
    global HistoryCache
    queryLower := StrLower(query)
    Stats := Map()

    for line in HistoryCache {
        parts := StrSplit(line, "`t")
        if (parts.Length < 2)
            continue

        timeStr := parts[1]
        url := parts[2]
        title := parts.Length >= 3 ? parts[3] : ""

        if !(InStr(StrLower(url), queryLower) || InStr(StrLower(title), queryLower))
            continue

        key := StrLower(url)
        timeNum := RegExReplace(timeStr, "[^0-9]", "") + 0

        if !Stats.Has(key) {
            bareUrl := StrLower(RegExReplace(RegExReplace(url, "i)^https?://", ""), "i)^www\.", ""))
            Stats[key] := {url: url, count: 0, lastTime: timeNum,
                           isPrefix: (SubStr(bareUrl, 1, StrLen(queryLower)) = queryLower)}
        }
        Stats[key].count += 1
        if (timeNum > Stats[key].lastTime)
            Stats[key].lastTime := timeNum
    }

    Scored := []
    for key, s in Stats {
        daysAgo := 0
        try daysAgo := DateDiff(A_Now, s.lastTime, "Days")
        recencyScore := 1 / (Max(daysAgo, 0) + 1)
        score := (s.count * 10) + (recencyScore * 5) + (s.isPrefix ? 1000 : 0)
        Scored.Push({url: s.url, score: score})
    }

    Loop Scored.Length - 1 {
        i := A_Index + 1
        cur := Scored[i]
        j := i - 1
        while (j >= 1 && Scored[j].score < cur.score) {
            Scored[j + 1] := Scored[j]
            j--
        }
        Scored[j + 1] := cur
    }

    matches := []
    for item in Scored {
        matches.Push(item.url)
        if (matches.Length >= maxResults)
            break
    }
    return matches
}

OnTitleChanged(tabObj, sender, args)
{
    global MainGui, Tabs

    try {
        newTitle := tabObj.WB.DocumentTitle
        url := tabObj.WB.Source
        if (newTitle == "")
            newTitle := "Untitled"

        if (StrLen(newTitle) > 18)
            newTitle := SubStr(newTitle, 1, 15) . "..."

        if (url != "" && url != "about:blank" && url != tabObj.LastURL) {
            tabObj.LastURL := url
            LogHistory(url, tabObj.WB.DocumentTitle)
        }

        if (tabObj.Title != newTitle) {
            tabObj.Title := newTitle

            for i, t in Tabs {
                if (t == tabObj) {
                    SetTabTitle(i, newTitle)
                    break
                }
            }
        }

        if (IsTabActive(tabObj)) {
            MainGui.Title := "Browser - " . tabObj.WB.DocumentTitle
        }
    }
}

OnSourceChanged(tabObj, sender, args)
{
    global URL_Input, IsUrlFocused, DisplayedFullURL
    if (IsTabActive(tabObj) && !IsUrlFocused) {
        src := tabObj.WB.Source
        if (src != "" && src != "about:blank") {
            DisplayedFullURL := src
            try URL_Input.Text := TruncateUrl(DisplayedFullURL)
            UpdateStarIcon()
        }
    }
}

IsTabActive(tabObj)
{
    global Tabs, ActiveTabIdx
    if (ActiveTabIdx > 0 && ActiveTabIdx <= Tabs.Length)
        return (Tabs[ActiveTabIdx] == tabObj)
    return false
}

GetActiveWB()
{
    global Tabs, ActiveTabIdx
    if (ActiveTabIdx > 0 && ActiveTabIdx <= Tabs.Length)
        return Tabs[ActiveTabIdx].WB
    return ""
}

Navigate(*)
{
    HideSuggestions()
    global URL_Input, DisplayedFullURL, BrowserHost
    WB := GetActiveWB()
    if !WB
        return

    URL := Trim(URL_Input.Text)

    if (URL = "") {
        URL_Input.Text := TruncateUrl(DisplayedFullURL)
        try BrowserHost.Focus()
        return
    }

    if RegExMatch(URL, "i)^https?://")
    {
        targetURL := URL
    }
    else if RegExMatch(URL, "i)^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$")
    {
        targetURL := "https://" . URL
    }
    else
    {
        targetURL := "https://www.google.com/search?q=" . UriEncode(URL)
    }

    DisplayedFullURL := targetURL
    URL_Input.Text := TruncateUrl(targetURL)
	UpdateStarIcon()

    try BrowserHost.Focus()
    try WB.Navigate(targetURL)
    catch as err
        MsgBox("Navigation failed:`n`n" . err.Message, "Navigation Error", "Iconx")
}

OnUrlFocus(*)
{
    global IsUrlFocused, URL_Input, DisplayedFullURL
    IsUrlFocused := true

    URL_Input.Text := TruncateUrl(DisplayedFullURL)

    SetEditFormattingRect(URL_Input.Hwnd, 32)
    DllCall("SendMessage", "Ptr", URL_Input.Hwnd, "UInt", 0x00D3, "Ptr", 0x2, "Ptr", (32 << 16))

    SetTimer(() => PostMessage(0x00B1, 0, -1,, URL_Input.Hwnd), -10)

    SetTimer(() => DrawUrlStarOverlay(URL_Input.Hwnd), -20)
}

OnUrlLoseFocus(*)
{
    global IsUrlFocused, URL_Input, DisplayedFullURL
    IsUrlFocused := false

    if (Trim(URL_Input.Text) = "") {
        URL_Input.Text := TruncateUrl(DisplayedFullURL)
    } else {
        URL_Input.Text := TruncateUrl(DisplayedFullURL)
    }

    SetTimer(HideSuggestions, -150)
}
TruncateUrl(url, maxLen := 70)
{
    global NewTabHtmlPath

    NewTabUrl := "file:///" . StrReplace(StrReplace(NewTabHtmlPath, "\", "/"), " ", "%20")
    if (url = "" || url = "about:blank" || url = NewTabUrl)
        return ""

    if (StrLen(url) <= maxLen)
        return url
    return SubStr(url, 1, maxLen) . "..."
}

IsNewTabUrl(url)
{
    global NewTabHtmlPath
    NewTabUrl := "file:///" . StrReplace(StrReplace(NewTabHtmlPath, "\", "/"), " ", "%20")
    return (url = "" || url = "about:blank" || url = NewTabUrl)
}

GoBack(*)
{
    WB := GetActiveWB()
    try if (WB && WB.CanGoBack)
        WB.GoBack()
}

GoForward(*)
{
    WB := GetActiveWB()
    try if (WB && WB.CanGoForward)
        WB.GoForward()
}

ReloadPage(*)
{
    WB := GetActiveWB()
    try if (WB)
        WB.Reload()
}

OnBasicAuthRequested(sender, args)
{
    global ProxyUser, ProxyPass
    args.Response.UserName := ProxyUser
    args.Response.Password := ProxyPass
}

Gui_Size(GuiObj, MinMax, Width, Height)
{
    global Tabs, ActiveTabIdx, URL_Input, SettingsBtn, HistoryBtn, DownloadBtn, FavoritesBtn, BrowserHost, TabBar
    global MinBtn, MaxBtn, CloseBtn, TabSeparator, MainGuiControlsReady

    if !MainGuiControlsReady
        return

    if (MinMax = -1 || Width = 0 || Height = 0)
        return

    if (MaxBtn) {
        isMax := DllCall("user32\IsZoomed", "Ptr", GuiObj.Hwnd)
        MaxBtn.Text := isMax ? Chr(0xE923) : Chr(0xE922)
    }

    bw := (MinMax = 1) ? 0 : 8

    CloseBtn.Move(Width - 40 - bw, 6, 40, 28)
    MaxBtn.Move(Width - 75 - bw, 6, 35, 28)
    MinBtn.Move(Width - 110 - bw, 6, 35, 28)

    TabBarWidth := Max(100, Width - (bw * 2))
    TabBar.Move(bw, 8, TabBarWidth, 40)
    RefreshTabs()

    if (IsSet(TabSeparator) && TabSeparator)
        TabSeparator.Move(bw, 46, Width - (bw * 2), 2)

    SettingsBtn.Move(Width - 45 - bw, 48, 35, 29)
    HistoryBtn.Move(Width - 85 - bw, 48, 35, 29)
    DownloadBtn.Move(Width - 125 - bw, 48, 35, 29)
    FavoritesBtn.Move(Width - 165 - bw, 48, 35, 29)

    UrlBarWidth := Max(100, Width - 340 - bw)
    URL_Input.Move(170, 48, UrlBarWidth, 29)
    DllCall("user32\InvalidateRect", "Ptr", URL_Input.Hwnd, "Ptr", 0, "Int", 0)

    BrowserHost.Move(bw, 82, Width - (bw * 2), Max(100, Height - 82 - bw))

    if (ActiveTabIdx > 0 && ActiveTabIdx <= Tabs.Length) {
        ctrl := Tabs[ActiveTabIdx].Controller
        try if (ctrl) {
            ctrl.IsVisible := true
            ctrl.Fill()
        }
    }

    RepositionLockOverlay()
}
AcquireSingleInstance(waitForRestart := false) {
    global SingleInstanceMutex

    mutexName := "Local\WebBrowser_SingleInstance_" . StrReplace(A_ScriptDir, "\", "_")
    hMutex := DllCall("kernel32\CreateMutexW", "Ptr", 0, "Int", 1, "WStr", mutexName, "Ptr")
    if !hMutex {
        MsgBox("The browser could not create its single-instance lock.", "Browser", "Iconx")
        ExitApp
    }

    lastError := DllCall("kernel32\GetLastError", "UInt")
    if (lastError = 183) {
        if waitForRestart {
            waitResult := DllCall("kernel32\WaitForSingleObject", "Ptr", hMutex, "UInt", 5000, "UInt")
            if (waitResult = 0) {
                SingleInstanceMutex := hMutex
                return
            }
        }

        DllCall("kernel32\CloseHandle", "Ptr", hMutex)
        existingHwnd := WinExist("Browser ahk_class AutoHotkeyGUI")
        if existingHwnd {
            try {
                if DllCall("user32\IsIconic", "Ptr", existingHwnd)
                    DllCall("user32\ShowWindow", "Ptr", existingHwnd, "Int", 9)
                DllCall("user32\SetForegroundWindow", "Ptr", existingHwnd)
            }
        }
        ExitApp
    }

    SingleInstanceMutex := hMutex
}

ReleaseSingleInstanceLock() {
    global SingleInstanceMutex
    if SingleInstanceMutex {
        try DllCall("kernel32\ReleaseMutex", "Ptr", SingleInstanceMutex)
        try DllCall("kernel32\CloseHandle", "Ptr", SingleInstanceMutex)
        SingleInstanceMutex := 0
    }
}

RestartBrowser() {
    global MainGui

    if A_IsCompiled
        Run('"' . A_ScriptFullPath . '" --browser-restart')
    else
        Run('"' . A_AhkPath . '" "' . A_ScriptFullPath . '" --browser-restart')

    ReleaseSingleInstanceLock()
    try MainGui.Destroy()
    ExitApp
}

Gui_Close(*)
{
    global Tabs
    for tab in Tabs {
        if (tab.Controller != "") {
            try tab.Controller.Close()
        }
    }
    ReleaseSingleInstanceLock()
    ExitApp
}

ToggleMaximize(*) {
    global MainGui, MaxBtn
    if DllCall("user32\IsZoomed", "Ptr", MainGui.Hwnd) {
        MainGui.Restore()
        try MaxBtn.Text := Chr(0xE922)
    } else {
        MainGui.Maximize()
        try MaxBtn.Text := Chr(0xE923)
    }
}

LoadSettings()
{
    global CurrentSession, ProxyEnabled, ProxyHost, ProxyPort, ProxyUser, ProxyPass, ProxyBypass, ConfigFile, StartupURL, AppTheme, NewTabBgType, NewTabBgVal
    global EnableSuspendTabs, ExtraCmdFlags
	global CustomNewTabActive
	global CurrentGuiFontName

    StartupURL        := IniRead(ConfigFile, "General", "StartupURL", "")
    CurrentSession    := IniRead(ConfigFile, "Session", "Name", "Default")
    ProxyEnabled      := IniRead(ConfigFile, "Proxy", "Enabled", "0") = "1"
    ProxyHost         := IniRead(ConfigFile, "Proxy", "Host", "")
    ProxyPort         := IniRead(ConfigFile, "Proxy", "Port", "")
    ProxyUser         := IniRead(ConfigFile, "Proxy", "User", "")
    ProxyPass         := IniRead(ConfigFile, "Proxy", "Pass", "")
    ProxyBypass       := IniRead(ConfigFile, "Proxy", "Bypass", "localhost;127.0.0.1")
    AppTheme          := IniRead(ConfigFile, "Appearance", "Theme", "Dark")

	global CustomThemeBg, CustomThemeText, CustomThemeBtn, CustomThemeCtrlBg
    CustomThemeBg     := IniRead(ConfigFile, "Appearance", "CustomThemeBg", "#1E1E1E")
    CustomThemeText   := IniRead(ConfigFile, "Appearance", "CustomThemeText", "#FFFFFF")
    CustomThemeBtn    := IniRead(ConfigFile, "Appearance", "CustomThemeBtn", "#333333")
    CustomThemeCtrlBg := IniRead(ConfigFile, "Appearance", "CustomThemeCtrlBg", "#2B2B2B")
	CurrentGuiFontName := IniRead(ConfigFile, "Appearance", "FontName", "Segoe UI")
    CurrentGuiFontFile := IniRead(ConfigFile, "Appearance", "FontFile", "")

    if (CurrentGuiFontFile != "" && FileExist(CurrentGuiFontFile))
        try DllCall("gdi32\AddFontResourceExW", "Str", CurrentGuiFontFile, "UInt", 0x10, "Ptr", 0)

    NewTabBgType      := IniRead(ConfigFile, "Appearance", "NewTabBgType", "Color")
    NewTabBgVal       := IniRead(ConfigFile, "Appearance", "NewTabBgVal", "#2B2B2B")

    EnableSuspendTabs := (IniRead(ConfigFile, "Performance", "SuspendTabs", "0") == "1")
    ExtraCmdFlags     := IniRead(ConfigFile, "Performance", "CmdFlags", "--disable-background-networking --disable-component-update --disable-domain-reliability --disable-speech-api --disable-sync --disable-breakpad")


    if (AppTheme = "System")
        AppTheme := "Dark"
    if (NewTabBgType = "Default" || NewTabBgType = "Device")
    {
        NewTabBgType := "Color"
        if (NewTabBgVal = "" || SubStr(NewTabBgVal, 1, 1) != "#")
            NewTabBgVal := "#2B2B2B"
    }
}

SaveSettingsToIni()
{
    global CurrentSession, ProxyEnabled, ProxyHost, ProxyPort, ProxyUser, ProxyPass, ProxyBypass, ConfigFile, StartupURL, AppTheme, NewTabBgType, NewTabBgVal
    global EnableSuspendTabs, ExtraCmdFlags
	global CustomNewTabActive
	global CustomThemeBg, CustomThemeText, CustomThemeBtn, CustomThemeCtrlBg
	global CurrentGuiFontName

    IniWrite(CurrentSession, ConfigFile, "Session", "Name")
    IniWrite(ProxyEnabled ? "1" : "0", ConfigFile, "Proxy", "Enabled")
    IniWrite(ProxyHost, ConfigFile, "Proxy", "Host")
    IniWrite(ProxyPort, ConfigFile, "Proxy", "Port")
    IniWrite(ProxyUser, ConfigFile, "Proxy", "User")
    IniWrite(ProxyPass, ConfigFile, "Proxy", "Pass")
    IniWrite(ProxyBypass, ConfigFile, "Proxy", "Bypass")
    IniWrite(StartupURL, ConfigFile, "General", "StartupURL")
    IniWrite(AppTheme, ConfigFile, "Appearance", "Theme")
    IniWrite(NewTabBgType, ConfigFile, "Appearance", "NewTabBgType")
    IniWrite(NewTabBgVal, ConfigFile, "Appearance", "NewTabBgVal")
    IniWrite(CustomThemeBg,     ConfigFile, "Appearance", "CustomThemeBg")
    IniWrite(CustomThemeText,   ConfigFile, "Appearance", "CustomThemeText")
    IniWrite(CustomThemeBtn,    ConfigFile, "Appearance", "CustomThemeBtn")
    IniWrite(CustomThemeCtrlBg, ConfigFile, "Appearance", "CustomThemeCtrlBg")
	IniWrite(CurrentGuiFontName, ConfigFile, "Appearance", "FontName")
    IniWrite(CurrentGuiFontFile, ConfigFile, "Appearance", "FontFile")
    IniWrite(EnableSuspendTabs ? "1" : "0", ConfigFile, "Performance", "SuspendTabs")
    IniWrite(ExtraCmdFlags, ConfigFile, "Performance", "CmdFlags")
}

GetEffectiveStartupURL()
{
    global StartupURL, NewTabHtmlPath

    parts := StrSplit(StartupURL, ";")
    firstUrl := (parts.Length >= 1) ? NormalizeStartupUrl(parts[1]) : ""

    if (firstUrl = "")
        return "file:///" . StrReplace(NewTabHtmlPath, " ", "%20")

    return firstUrl
}
NormalizeStartupUrl(URL)
{
    URL := Trim(URL)
    if (URL = "")
        return ""

    if RegExMatch(URL, "i)^https?://")
        return URL
    else if RegExMatch(URL, "i)^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$")
        return "https://" . URL
    else
        return "https://www.google.com/search?q=" . UriEncode(URL)
}

OpenStartupTabs()
{
    global StartupURL

    urls := []
    for part in StrSplit(StartupURL, ";") {
        u := NormalizeStartupUrl(part)
        if (u != "")
            urls.Push(u)
    }

    if (urls.Length = 0) {
        CreateNewTab()
        return
    }

    OpenNextStartupTab(urls, 1)
}

OpenNextStartupTab(urls, idx)
{
    if (idx > urls.Length)
        return

    CreateNewTab(urls[idx], (readyTab) => SetTimer(() => OpenNextStartupTab(urls, idx + 1), -1))
}

GetSessionList()
{
    sessions := []
    SessionsRoot := A_ScriptDir . "\Sessions"

    if !DirExist(SessionsRoot)
        return sessions

    Loop Files, SessionsRoot . "\*", "D"
        sessions.Push(A_LoopFileName)

    return sessions
}

ArrayHasValue(arr, val)
{
    for v in arr
        if (v = val)
            return true
    return false
}

SanitizeSessionName(name)
{
    for badChar in StrSplit('\/:*?"<>|')
        name := StrReplace(name, badChar, "")
    return Trim(name)
}

GetUniqueSessionName(baseName)
{
    if !DirExist(A_ScriptDir . "\Sessions\" . baseName)
        return baseName

    counter := 2
    Loop
    {
        candidate := baseName . " (" . counter . ")"
        if !DirExist(A_ScriptDir . "\Sessions\" . candidate)
            return candidate
        counter++
    }
}

BlurActivePage(enable := true)
{
    global Tabs, ActiveTabIdx

    if (ActiveTabIdx < 1 || ActiveTabIdx > Tabs.Length)
        return

    tab := Tabs[ActiveTabIdx]

    if (!tab.WB)
        return

    try
    {
        if (enable)
        {
            js := "
            (
                (() => {
                    const root = document.documentElement
                    if (!root) return

                    root.dataset.ahkSettingsBlur = root.style.filter || ""
                    root.style.filter = "blur(8px)"
                    root.style.transform = "scale(1.01)"
                    root.style.transformOrigin = "center center"
                })()
            )"
        }
        else
        {
            js := "
            (
                (() => {
                    const root = document.documentElement
                    if (!root) return

                    root.style.filter = root.dataset.ahkSettingsBlur || ""
                    root.style.transform = ""
                    root.style.transformOrigin = ""
                    delete root.dataset.ahkSettingsBlur
                })()
            )"
        }

        tab.WB.ExecuteScriptAsync(js)
    }
    catch
    {
    }
}

OpenSettings(*)
{
    global MainGui, CurrentSession, ProxyEnabled, ProxyHost, ProxyPort, ProxyUser, ProxyPass, ProxyBypass, uBlockPath, StartupURL
    global startupUrlExpanded, startupUrlChanged, startupUrlInternalUpdate, StartupUrlEdit
    global CurrentThemeText, AppTheme, ColorPresetMap

    cleanTextColor := StrReplace(CurrentThemeText, "#", "")
    SettingsGui := Gui("+Owner" . MainGui.Hwnd . " +ToolWindow", "Settings")
    SettingsGui.SetFont("c" . cleanTextColor)
    BlurActivePage(true)

    if ColorPresetMap.Has(AppTheme) {
        SettingsGui.BackColor := StrReplace(ColorPresetMap[AppTheme], "#", "")
    }

    SettingsGui.MarginX := 15
    SettingsGui.MarginY := 15

    MainGui.Opt("+Disabled")

    LockSettingsPosition(wParam, lParam, msg, hwnd) {
        if (hwnd == SettingsGui.Hwnd && (wParam & 0xFFF0) == 0xF010)
            return 0
    }
    OnMessage(0x0112, LockSettingsPosition)

    IsAnySubPanelOpen() {
        pid := ProcessExist()
        panelTitles := ["Customization", "Manage Cookies", "Cookie Manager", "Cookies", "Performance", "Edit Session", "New Session"]
        for title in panelTitles {
            if WinExist(title . " ahk_pid " . pid)
                return true
        }
        return false
    }

    CheckSubPanelsStatus() {
        if !IsAnySubPanelOpen() {
            SetTimer(CheckSubPanelsStatus, 0)
            try {
                SettingsGui.Opt("-Disabled")
                WinActivate(MainGui.Hwnd)
                WinActivate(SettingsGui.Hwnd)
            }
        }
    }

    LaunchSubPanel(fn, args*) {
        SettingsGui.Opt("+Disabled")
        fn(args*)
        SetTimer(CheckSubPanelsStatus, 10)
    }

    CloseSettings(*) {
        if IsAnySubPanelOpen()
            return 1

        SetTimer(CheckSubPanelsStatus, 0)
        OnMessage(0x0112, LockSettingsPosition, 0)
        MainGui.Opt("-Disabled")
        BlurActivePage(false)
        SettingsGui.Destroy()
        WinActivate(MainGui.Hwnd)
    }
    SettingsGui.OnEvent("Close", CloseSettings)

    AddCustomGroupBox(SettingsGui, 15, 15, 330, 145, "General")
    SettingsGui.Add("Text", "x25 y38 w80 h20 +BackgroundTrans c" . cleanTextColor, "Startup URLs:")

    displayUrl := (StrLen(StartupURL) > 30)
        ? SubStr(StartupURL, 1, 27) . "..."
        : StartupURL

    StartupUrlEdit := SettingsGui.Add(
        "Edit",
        "x105 y35 w225 h22 -Multi",
        displayUrl
    )

    DllCall(
        "user32\SendMessage",
        "Ptr", StartupUrlEdit.Hwnd,
        "UInt", 0x1501,
        "Ptr", 1,
        "WStr", "e.g. google.com; youtube.com; ..."
    )

    startupUrlExpanded := false
    startupUrlChanged := false
    startupUrlInternalUpdate := false

    StartupUrlEdit.OnEvent("Focus", (*) => ExpandStartupUrl())
    StartupUrlEdit.OnEvent("Change", (*) => StartupUrlWasChanged())
    StartupUrlEdit.OnEvent("LoseFocus", (*) => CollapseStartupUrl())

    ExpandStartupUrl()
    {
        global StartupUrlEdit, StartupURL, startupUrlExpanded, startupUrlInternalUpdate

        if (startupUrlExpanded)
            return

        startupUrlExpanded := true
        startupUrlInternalUpdate := true
        StartupUrlEdit.Text := StartupURL
        startupUrlInternalUpdate := false

        try
            DllCall(
                "user32\SendMessage",
                "Ptr", StartupUrlEdit.Hwnd,
                "UInt", 0x00B1,
                "Ptr", -1,
                "Ptr", -1
            )
    }

    StartupUrlWasChanged()
    {
        global startupUrlInternalUpdate, startupUrlChanged, startupUrlExpanded

        if (startupUrlInternalUpdate)
            return

        startupUrlExpanded := true
        startupUrlChanged := true
    }

    CollapseStartupUrl()
    {
        global StartupUrlEdit, StartupURL, startupUrlExpanded, startupUrlChanged, startupUrlInternalUpdate

        if (startupUrlChanged)
            return

        if (!startupUrlExpanded)
            return

        startupUrlInternalUpdate := true
        current := StartupUrlEdit.Text

        if (current = StartupURL)
        {
            StartupUrlEdit.Text := (StrLen(StartupURL) > 30)
                ? SubStr(StartupURL, 1, 27) . "..."
                : StartupURL
        }

        startupUrlInternalUpdate := false
        startupUrlExpanded := false
    }

    CustBtn := SettingsGui.Add("Button", "x25 y72 w310 h26", "Customization")
    CustBtn.OnEvent("Click", (*) => LaunchSubPanel(OpenCustomizationPanel))

    PerfBtn := SettingsGui.Add("Button", "x25 y105 w310 h26", "Performance")
    PerfBtn.OnEvent("Click", (*) => LaunchSubPanel(OpenPerformancePanel))

    AddCustomGroupBox(SettingsGui, 15, 170, 330, 130, "Session Manager")

    CurrentSessionText := SettingsGui.Add("Text", "x25 y190 w310 h20 +BackgroundTrans c" . cleanTextColor, "Current Session:  " . CurrentSession)
    CurrentSessionText.SetFont("bold c" . cleanTextColor)

    SessionListDDL := SettingsGui.Add("DropDownList", "x25 y215 w210 h200", GetSessionList())
    SessionListDDL.Choose(CurrentSession)

    LoadSessionBtn := SettingsGui.Add("Button", "x240 y214 w95 h25", "Load")
    LoadSessionBtn.OnEvent("Click", (*) => LoadSelectedSession())

    NewSessionBtn := SettingsGui.Add("Button", "x25 y248 w150 h26", "Add New Session")
    NewSessionBtn.OnEvent("Click", (*) => LaunchSubPanel(CreateNewSession))

    EditSessionBtn := SettingsGui.Add("Button", "x185 y248 w150 h26", "Edit Session")
    EditSessionBtn.OnEvent("Click", (*) => LaunchSubPanel(ShowEditSessionManager, RefreshSessionUI, SettingsGui))

    AddCustomGroupBox(SettingsGui, 15, 310, 330, 165, "Proxy Settings")
	EnableChk := AddThemedCheckbox(
		SettingsGui,
		25, 330, 310,
		ProxyEnabled,
		"Enable Proxy"
	)
    DllCall("uxtheme\SetWindowTheme", "Ptr", EnableChk.Hwnd, "Str", "", "Str", "")

    SettingsGui.Add("Text", "x25 y358 w40 h20 +BackgroundTrans c" . cleanTextColor, "Host:")
    HostEdit := SettingsGui.Add("Edit", "x70 y355 w140 h22", ProxyHost)

    SettingsGui.Add("Text", "x218 y358 w32 h20 +BackgroundTrans c" . cleanTextColor, "Port:")
    PortEdit := SettingsGui.Add("Edit", "x252 y355 w83 h22", ProxyPort)

    SettingsGui.Add("Text", "x25 y386 w75 h20 +BackgroundTrans c" . cleanTextColor, "Username:")
    UserEdit := SettingsGui.Add("Edit", "x105 y383 w230 h22", ProxyUser)

    SettingsGui.Add("Text", "x25 y414 w75 h20 +BackgroundTrans c" . cleanTextColor, "Password:")
    PassEdit := SettingsGui.Add("Edit", "x105 y411 w230 h22 Password", ProxyPass)

    SettingsGui.Add("Text", "x25 y442 w75 h20 +BackgroundTrans c" . cleanTextColor, "Bypass List:")
    BypassEdit := SettingsGui.Add("Edit", "x105 y439 w230 h22", ProxyBypass)

    AddCustomGroupBox(SettingsGui, 15, 485, 330, 85, "AdBlocker Extension (uBlock Origin)")

    isInstalled := DirExist(uBlockPath) && FileExist(uBlockPath . "\manifest.json")
    AdblockStatusText := SettingsGui.Add("Text", "x25 y505 w310 h20 +BackgroundTrans c" . cleanTextColor, "Status: " . (isInstalled ? "Installed" : "Not Installed"))

    AdblockBtn := SettingsGui.Add("Button", "x25 y530 w310 h26", isInstalled ? "Uninstall" : "Download & Install")
    AdblockBtn.OnEvent("Click", (*) => ToggleUblock())

    AddCustomGroupBox(SettingsGui, 15, 580, 330, 70, "Privacy & Browsing Data")

    ClearHistBtn := SettingsGui.Add("Button", "x25 y602 w150 h28", "Clear History")
    ClearHistBtn.OnEvent("Click", (*) => ClearHistory())

    OptCookieBtn := SettingsGui.Add("Button", "x185 y602 w150 h28", "Manage Cookies")
    OptCookieBtn.OnEvent("Click", (*) => LaunchSubPanel(ShowCookieManager))

    SaveBtn := SettingsGui.Add("Button", "x120 y662 w120 h30 Default", "Save")
    SaveBtn.OnEvent("Click", (*) => OnSaveClicked())

    OnSaveClicked(*) {
        if IsAnySubPanelOpen()
            return
        SaveSettings()
        CloseSettings()
    }

    Fields := [StartupUrlEdit, HostEdit, PortEdit, UserEdit, PassEdit, BypassEdit]
    for f in Fields
        f.OnEvent("Change", (*) => UpdateSaveState())
    EnableChk.OnEvent("Click", (*) => UpdateSaveState())

    UpdateSaveState()
    ApplyGuiTheme(SettingsGui)

    ToggleUblock()
    {
        global uBlockPath

        if (DirExist(uBlockPath) && FileExist(uBlockPath . "\manifest.json"))
            UninstallUblock(SettingsGui)
        else
            InstallUblock(SettingsGui)

        nowInstalled := DirExist(uBlockPath) && FileExist(uBlockPath . "\manifest.json")
        AdblockStatusText.Text := "Status: " . (nowInstalled ? "Installed" : "Not Installed")
        AdblockBtn.Text := nowInstalled ? "Uninstall" : "Download & Install"
    }

    RefreshSessionUI()
    {
        CurrentSessionText.Text := "Current Session:  " . CurrentSession

        sessions := GetSessionList()
        SessionListDDL.Delete()
        SessionListDDL.Add(sessions)
        SessionListDDL.Choose(CurrentSession)
    }

    CreateNewSession()
    {
        global CurrentSession

        ib := InputBox("Enter a name for the new session:", "New Session", "w300 h130")
        if (ib.Result = "Cancel")
            return

        name := SanitizeSessionName(Trim(ib.Value))

        if (name = "")
        {
            MsgBox("Please enter a valid session name.", "Invalid Name", "Iconx")
            return
        }

        name := GetUniqueSessionName(name)

        newDir := A_ScriptDir . "\Sessions\" . name
        DirCreate(newDir)

        CurrentSession := name
        SaveSettingsToIni()
        GReload()
        RefreshSessionUI()
    }

    LoadSelectedSession()
    {
        global CurrentSession

        selected := SessionListDDL.Text
        if (selected = "" || selected = CurrentSession)
            return

        CurrentSession := selected
        SaveSettingsToIni()
        GReload()
        RefreshSessionUI()
    }

    UpdateSaveState()
    {
        changed := (Trim(StartupUrlEdit.Text) != StartupURL)
            || (EnableChk.Value != ProxyEnabled)
            || (Trim(HostEdit.Text) != ProxyHost)
            || (Trim(PortEdit.Text) != ProxyPort)
            || (UserEdit.Text != ProxyUser)
            || (PassEdit.Text != ProxyPass)
            || (Trim(BypassEdit.Text) != ProxyBypass)

        SaveBtn.Enabled := changed
    }

    SaveSettings()
    {
        global ProxyEnabled, ProxyHost, ProxyPort, ProxyUser, ProxyPass, ProxyBypass, StartupURL

        StartupURL     := Trim(StartupUrlEdit.Text)
        ProxyEnabled   := EnableChk.Value
        ProxyHost      := Trim(HostEdit.Text)
        ProxyPort      := Trim(PortEdit.Text)
        ProxyUser      := UserEdit.Text
        ProxyPass      := PassEdit.Text
        ProxyBypass    := Trim(BypassEdit.Text)

        SaveSettingsToIni()
        GenerateNewTabPage(false)
        GReload()
    }

    SettingsGui.Show()
}
ShowEditSessionManager(onClose := "", ParentGui := "")
{
    global MainGui

    ownerHwnd := ParentGui ? ParentGui.Hwnd : MainGui.Hwnd
    EditGui := Gui("+Owner" . ownerHwnd . " +ToolWindow", "Edit Session")
    EditGui.MarginX := 15
    EditGui.MarginY := 15

    EditGui.Add("Text", "w300", "Select a session to edit:")
    SessionLB := EditGui.Add("ListBox", "w300 h140", GetSessionList())

    RenameBtn   := EditGui.Add("Button", "x15 yp+150 w135 h28 Disabled", "Rename Session")
    BackupBtn   := EditGui.Add("Button", "x160 yp w135 h28 Disabled", "Backup Session")
    TransferBtn := EditGui.Add("Button", "x15 yp+35 w135 h28 Disabled", "Transfer Session")
    DeleteBtn   := EditGui.Add("Button", "x160 yp w135 h28 Disabled", "Delete Session")

    SessionLB.OnEvent("Change", (*) => UpdateButtonStates())

    UpdateButtonStates()
    {
        hasSelection := (SessionLB.Text != "")
        RenameBtn.Enabled   := hasSelection
        BackupBtn.Enabled   := hasSelection
        TransferBtn.Enabled := hasSelection
        DeleteBtn.Enabled   := hasSelection
    }

    RefreshList()
    {
        SessionLB.Delete()
        SessionLB.Add(GetSessionList())
        UpdateButtonStates()
    }

    RenameBtn.OnEvent("Click", (*) => (RenameSessionFlow(SessionLB.Text, EditGui, ParentGui), RefreshList()))
    BackupBtn.OnEvent("Click", (*) => BackupSessionFlow(SessionLB.Text, EditGui, ParentGui))
    TransferBtn.OnEvent("Click", (*) => (TransferSessionFlow(SessionLB.Text, EditGui, ParentGui), RefreshList()))
    DeleteBtn.OnEvent("Click", (*) => (DeleteSessionFlow(SessionLB.Text, EditGui, ParentGui), RefreshList()))

    EditGui.OnEvent("Close", CloseHandler)
    CloseHandler(*)
    {
        EditGui.Destroy()
        if (onClose != "")
            onClose()
    }

    ApplyGuiTheme(EditGui)
    EditGui.Show("w330 h270")
}

LockUIForSessionOp(Guis*)
{
    global MainGui
    try MainGui.Opt("+Disabled")
    for g in Guis
        try g.Opt("+Disabled")
}

UnlockUIAfterSessionOp(Guis*)
{
    global MainGui
    try MainGui.Opt("-Disabled")
    for g in Guis
        try g.Opt("-Disabled")
}

RenameSessionFlow(oldName, Guis*)
{
    global CurrentSession

    if (oldName = "")
        return

    ib := InputBox("Enter a new name for '" . oldName . "':", "Rename Session", "w300 h130", oldName)
    if (ib.Result = "Cancel")
        return

    newName := SanitizeSessionName(Trim(ib.Value))
    if (newName = "")
    {
        MsgBox("Please enter a valid session name.", "Invalid Name", "Iconx")
        return
    }
    if (newName = oldName)
        return

    newName := GetUniqueSessionName(newName)

    oldDir := A_ScriptDir . "\Sessions\" . oldName
    newDir := A_ScriptDir . "\Sessions\" . newName

    LockUIForSessionOp(Guis*)
    try
    {
        WasActive := (CurrentSession = oldName)
        UrlsToRestore := CloseAllTabsForFileOp()

        try
            DirMove(oldDir, newDir)
        catch as err
        {
            MsgBox("Failed to rename session folder:`n" . err.Message, "Rename Failed", "Iconx")
            RestoreTabsAfterFileOp(UrlsToRestore)
            return
        }

        if (WasActive)
        {
            CurrentSession := newName
            SaveSettingsToIni()
        }

        MsgBox("Session renamed to '" . newName . "'.", "Renamed", "Iconi")
        RestoreTabsAfterFileOp(UrlsToRestore)
    }
    finally
        UnlockUIAfterSessionOp(Guis*)
}

BackupSessionFlow(sessionName, Guis*)
{
    if (sessionName = "")
        return

    SessionDir := A_ScriptDir . "\Sessions\" . sessionName
    if !DirExist(SessionDir)
    {
        MsgBox("Session folder not found.", "Backup Failed", "Iconx")
        return
    }

    BackupsDir := A_ScriptDir . "\Backups"
    if !DirExist(BackupsDir)
        DirCreate(BackupsDir)

    baseZipName := "BACKUP - " . sessionName
    zipName := baseZipName . ".zip"
    counter := 2
    while FileExist(BackupsDir . "\" . zipName)
    {
        zipName := baseZipName . " (" . counter . ").zip"
        counter++
    }
    zipPath := BackupsDir . "\" . zipName

    ps1Path := A_Temp . "\ahk_session_backup_" . A_TickCount . ".ps1"
    ps1Content := 'Compress-Archive -Path "' . SessionDir . '\*" -DestinationPath "' . zipPath . '" -Force'

    try
        FileAppend(ps1Content, ps1Path, "UTF-8")
    catch as err
    {
        MsgBox("Could not prepare the backup script:`n" . err.Message, "Backup Failed", "Iconx")
        return
    }

    LockUIForSessionOp(Guis*)
    try
    {
        UrlsToRestore := CloseAllTabsForFileOp()

        RunWait('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' . ps1Path . '"', , "Hide")

        try FileDelete(ps1Path)

        if FileExist(zipPath)
            MsgBox("Session '" . sessionName . "' backed up to:`n" . zipPath, "Backup Complete", "Iconi")
        else
            MsgBox("Backup failed. PowerShell's Compress-Archive may not be available on this system.", "Backup Failed", "Iconx")

        RestoreTabsAfterFileOp(UrlsToRestore)
    }
    finally
        UnlockUIAfterSessionOp(Guis*)
}

ApplyTabBarTheme(tabHwnd)
{
    static SubclassProc := 0
    if (!SubclassProc)
        SubclassProc := CallbackCreate(TabBar_Subclass, "F", 6)

    try DllCall("uxtheme\SetWindowTheme", "Ptr", tabHwnd, "Str", "", "Str", "")
    try WinSetStyle("+0x2000", "ahk_id " tabHwnd)

    DllCall("comctl32\SetWindowSubclass", "Ptr", tabHwnd, "Ptr", SubclassProc, "UPtr", 9999, "UPtr", 0)

    childHwnd := 0
    while (childHwnd := DllCall("user32\FindWindowEx", "Ptr", tabHwnd, "Ptr", childHwnd, "Str", "#32770", "Ptr", 0))
    {
        DllCall("comctl32\SetWindowSubclass", "Ptr", childHwnd, "Ptr", SubclassProc, "UPtr", 9999, "UPtr", 0)
    }
}
TabBar_Subclass(hwnd, msg, wParam, lParam, uIdSubclass, dwRefData)
{
    global HBRUSH_BG, CurrentThemeIsDark, MinBtn, MaxBtn, CloseBtn
    if (msg = 0x000F)
    {
        ret := DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam)

        hdc := DllCall("user32\GetDC", "Ptr", hwnd, "Ptr")
		if (hdc := DllCall("user32\GetDC", "Ptr", hwnd, "Ptr"))
		{
			rect := Buffer(16, 0)
			DllCall("user32\GetClientRect", "Ptr", hwnd, "Ptr", rect)

			h := NumGet(rect, 12, "Int")
			NumPut("Int", Max(0, h - 12), rect, 4)

			if (HBRUSH_BG)
				DllCall("user32\FillRect", "Ptr", hdc, "Ptr", rect, "Ptr", HBRUSH_BG)

			DllCall("user32\ReleaseDC", "Ptr", hwnd, "Ptr", hdc)

			for ctrl in [MinBtn, MaxBtn, CloseBtn]
				if (ctrl)
					DllCall("user32\RedrawWindow", "Ptr", ctrl.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x105)
		}
        return ret
    }
    else if (msg = 0x0014)
    {
        if (HBRUSH_BG)
        {
            rect := Buffer(16, 0)
            DllCall("user32\GetClientRect", "Ptr", hwnd, "Ptr", rect)
            DllCall("user32\FillRect", "Ptr", wParam, "Ptr", rect, "Ptr", HBRUSH_BG)
            return 1
        }
    }
    else if (msg = 0x0082)
    {
        DllCall("comctl32\RemoveWindowSubclass", "Ptr", hwnd, "Ptr", uIdSubclass, "UPtr", dwRefData)
    }
    return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam)
}

CloseAllTabsForFileOp()
{
    global Tabs, ActiveTabIdx

    UrlsToRestore := []
    for tab in Tabs {
        url := ""
        try url := tab.WB.Source
        if (url = "about:blank")
            url := ""
        UrlsToRestore.Push(url)
    }
    if (UrlsToRestore.Length = 0)
        UrlsToRestore.Push("")

    for tab in Tabs {
        if (tab.Controller != "") {
            try tab.Controller.Close()
        }
    }

    Tabs := []
    ActiveTabIdx := 0
    Sleep(200)

    return UrlsToRestore
}

RestoreTabsAfterFileOp(UrlsToRestore)
{
    global StartupURL, CurrentSession, HistoryFile, NewTabHtmlPath, ConfigFile

    LoadSettings()
    StartupURL := IniRead(ConfigFile, "General", "StartupURL", StartupURL)

    SessionDir := A_ScriptDir . "\Sessions\" . CurrentSession
    if !DirExist(SessionDir)
        DirCreate(SessionDir)
    HistoryFile := SessionDir . "\history.dat"
    NewTabHtmlPath := SessionDir . "\newtab_page.html"
    GenerateNewTabPage()

    for url in UrlsToRestore
        CreateNewTab(url = "" ? GetEffectiveStartupURL() : url)
}

TransferSessionFlow(sessionName, OwnerGui, ExtraGuis*)
{
    global CurrentSession

    if (sessionName = "")
        return

    destinations := []
    for s in GetSessionList()
        if (s != sessionName)
            destinations.Push(s)

    if (destinations.Length = 0)
    {
        MsgBox("There are no other sessions to transfer into. Create another session first.", "No Destination Sessions", "Iconx")
        return
    }

    PickGui := Gui("+Owner" . OwnerGui.Hwnd . " +ToolWindow", "Transfer Session")
    PickGui.MarginX := 15
    PickGui.MarginY := 15
    PickGui.Add("Text", "w270", "Transfer all files from '" . sessionName . "' into:")
    DestDDL := PickGui.Add("DropDownList", "w270 h200", destinations)
    DestDDL.Choose(1)

    ConfirmBtn := PickGui.Add("Button", "yp+35 w130 h28 Default", "Transfer")
    CancelBtn := PickGui.Add("Button", "x+10 yp w130 h28", "Cancel")

    CancelBtn.OnEvent("Click", (*) => PickGui.Destroy())
    PickGui.OnEvent("Close", (*) => PickGui.Destroy())
    ConfirmBtn.OnEvent("Click", DoTransfer)

    DoTransfer(*)
    {
        global CurrentSession

        destName := DestDDL.Text
        if (destName = "")
            return

        result := MsgBox("This copies every file from '" . sessionName . "' into '" . destName . "' (overwriting any files with the same name), then deletes '" . sessionName . "'.`n`nThe browser will close its tabs and reload to release the session's files before transferring.`n`nContinue?", "Confirm Transfer", "YesNo Icon!")
        if (result = "No")
            return

        LockUIForSessionOp(OwnerGui, PickGui, ExtraGuis*)
        try
        {
            UrlsToRestore := CloseAllTabsForFileOp()

            srcDir := A_ScriptDir . "\Sessions\" . sessionName
            dstDir := A_ScriptDir . "\Sessions\" . destName

            try
                DirCopy(srcDir, dstDir, true)
            catch as err
            {
                MsgBox("Transfer failed while copying files:`n" . err.Message, "Transfer Failed", "Iconx")
                RestoreTabsAfterFileOp(UrlsToRestore)
                return
            }

            try
                DirDelete(srcDir, true)
            catch as err
                MsgBox("Files were copied, but the original session folder could not be removed:`n" . err.Message, "Cleanup Warning", "Icon!")

            if (CurrentSession = sessionName)
            {
                CurrentSession := destName
                SaveSettingsToIni()
            }

            PickGui.Destroy()
            MsgBox("Transferred '" . sessionName . "' into '" . destName . "'.", "Transfer Complete", "Iconi")

            RestoreTabsAfterFileOp(UrlsToRestore)
        }
        finally
            UnlockUIAfterSessionOp(OwnerGui, PickGui, ExtraGuis*)
    }

    ApplyGuiTheme(PickGui)
    PickGui.Show("w300 h115")
}

DeleteSessionFlow(sessionName, Guis*)
{
    global CurrentSession

    if (sessionName = "")
        return

    if (sessionName = CurrentSession)
    {
        MsgBox("You can't delete the session that's currently active. Switch to a different session first.", "Can't Delete", "Iconx")
        return
    }

    result := MsgBox("Are you sure you want to permanently delete session '" . sessionName . "'?`n`nThis deletes its history and all saved data. This cannot be undone.", "Delete Session", "YesNo Icon!")
    if (result = "No")
        return

    dir := A_ScriptDir . "\Sessions\" . sessionName

    LockUIForSessionOp(Guis*)
    try
    {
        try
            DirDelete(dir, true)
        catch as err
        {
            MsgBox("Failed to delete session folder:`n" . err.Message, "Delete Failed", "Iconx")
            return
        }

        MsgBox("Session '" . sessionName . "' deleted.", "Deleted", "Iconi")
    }
    finally
        UnlockUIAfterSessionOp(Guis*)
}

InstallUblock(GuiObj, IsUpdate := false) {
    global ExtDir, uBlockPath

    GuiObj.Opt("+OwnDialogs")

    PromptText := IsUpdate
        ? "Check for and install the latest uBlock Origin build from GitHub?`n`nThis will remove the currently installed version and fetch the latest chromium release."
        : "Do you want to download and install uBlock Origin directly from GitHub?`n`nThis will fetch the latest chromium release."

    Result := MsgBox(PromptText, IsUpdate ? "Check for Updates" : "Install uBlock", "YesNo")
    if (Result = "No")
        return

    if !DirExist(ExtDir)
        DirCreate(ExtDir)

    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", "https://api.github.com/repos/gorhill/uBlock/releases/latest", false)
        req.Send()

        if !RegExMatch(req.ResponseText, '"browser_download_url":\s*"(https://github\.com/gorhill/uBlock/releases/download/[^"]+chromium\.zip)"', &match) {
            MsgBox("Could not find the chromium.zip link in the latest GitHub release.", "Download Error", "Iconx")
            return
        }
        DownloadURL := match[1]
    } catch as err {
        MsgBox("Failed to connect to GitHub API.`n" err.Message, "Network Error", "Iconx")
        return
    }

    ZipPath := ExtDir . "\ublock_temp.zip"

    try {
        Download(DownloadURL, ZipPath)
    } catch as err {
        MsgBox("Failed to download the zip file.`n" err.Message, "Download Error", "Iconx")
        return
    }

    if DirExist(uBlockPath) {
        try {
            DirDelete(uBlockPath, true)
        } catch OSError as err {
            MsgBox("Failed to remove the existing uBlock directory. It might still be in use by WebView2.`n`nError: " err.Message, "Removal Error", "Iconx")
            return
        }
    }
    DirCreate(uBlockPath)

    try {
        RunWait("tar -xf `"" . ZipPath . "`" -C `"" . uBlockPath . "`"", , "Hide")

        ManifestDir := ""
        Loop Files, uBlockPath . "\manifest.json", "R"
        {
            ManifestDir := A_LoopFileDir
            break
        }

        if (ManifestDir != "" && ManifestDir != uBlockPath) {
            TempDir := ExtDir . "\uBlock_TempExtracted"
            DirMove(ManifestDir, TempDir)
            DirDelete(uBlockPath, true)
            DirMove(TempDir, uBlockPath)
        }

    } catch {
        MsgBox("Extraction failed. Make sure your system supports the 'tar' command.", "Extraction Error", "Iconx")
        return
    }

    if FileExist(ZipPath)
        FileDelete(ZipPath)

    MsgBox(IsUpdate ? "uBlock Origin updated successfully! The browser will now reload." : "uBlock Origin installed successfully! The browser will now reload.", "Success", "Iconi")
    GReload()
}

UninstallUblock(GuiObj) {
    global uBlockPath

    GuiObj.Opt("+OwnDialogs")
    Result := MsgBox("Are you sure you want to uninstall uBlock Origin?`n`nThe extension folder will be deleted and the browser will reload without it.", "Uninstall uBlock", "YesNo Icon!")
    if (Result = "No")
        return

    if DirExist(uBlockPath) {
        try {
            DirDelete(uBlockPath, true)
        } catch OSError as err {
            MsgBox("Failed to remove the uBlock directory. It might still be in use by WebView2.`n`nError: " err.Message, "Removal Error", "Iconx")
            return
        }
    }

    MsgBox("uBlock Origin has been uninstalled. The browser will now reload.", "Uninstalled", "Iconi")
    GReload()
}

GReload()
{
    global Tabs, ActiveTabIdx, StartupURL, CurrentSession, HistoryFile, NewTabHtmlPath

    LoadSettings()
    StartupURL := IniRead(ConfigFile, "General", "StartupURL", StartupURL)

    SessionDir := A_ScriptDir . "\Sessions\" . CurrentSession
    if !DirExist(SessionDir)
        DirCreate(SessionDir)
    HistoryFile := SessionDir . "\history.dat"
    NewTabHtmlPath := SessionDir . "\newtab_page.html"
    GenerateNewTabPage()

    UrlsToRestore := []
    for tab in Tabs {
        url := ""
        try url := tab.WB.Source
        if (url = "about:blank")
            url := ""
        UrlsToRestore.Push(url)
    }
    if (UrlsToRestore.Length = 0)
        UrlsToRestore.Push("")

    for tab in Tabs {
        if (tab.Controller != "") {
            try tab.Controller.Close()
        }
    }

    Tabs := []
    ActiveTabIdx := 0
    Sleep(200)

    for url in UrlsToRestore
        CreateNewTab(url = "" ? GetEffectiveStartupURL() : url)
}

GetWebView2RuntimeVersion()
{
    static RuntimeGUID := "{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
    RegPaths := [
        "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\" . RuntimeGUID,
        "HKLM\SOFTWARE\Microsoft\EdgeUpdate\Clients\" . RuntimeGUID,
        "HKCU\SOFTWARE\Microsoft\EdgeUpdate\Clients\" . RuntimeGUID
    ]
    for RegPath in RegPaths {
        try {
            Version := RegRead(RegPath, "pv")
            if (Version != "")
                return Version
        }
    }
    return ""
}

FindWebView2Loader()
{
    if (A_PtrSize = 8) {
        Candidates := [
            A_ScriptDir "\WebView2\x64\WebView2Loader.dll",
            A_ScriptDir "\WebView2Loader.dll",
            A_ScriptDir "\WebView2\WebView2Loader.dll",
            A_ScriptDir "\WebView2\64bit\WebView2Loader.dll"
        ]
    } else {
        Candidates := [
            A_ScriptDir "\WebView2\x86\WebView2Loader.dll",
            A_ScriptDir "\WebView2Loader.dll",
            A_ScriptDir "\WebView2\WebView2Loader.dll",
            A_ScriptDir "\WebView2\32bit\WebView2Loader.dll"
        ]
    }
    for Path in Candidates {
        if FileExist(Path)
            return Path
    }
    return ""
}

Join(arr, sep := ",")
{
    out := ""
    for i, v in arr
        out .= (i = 1 ? "" : sep) . v
    return out
}

ShowDownloads(*) {
    global Tabs, ActiveTabIdx
    if (ActiveTabIdx > 0 && ActiveTabIdx <= Tabs.Length && Tabs[ActiveTabIdx].Controller != "") {
        try Tabs[ActiveTabIdx].Controller.MoveFocus(0)
    }
    Send("^j")
}

ShowHistory() {
    global HistoryGui, HistoryLV, MainGui, HistoryFile, IsHistoryDisabled, ChkDisableHistory, HistoryDisabledText, HistoryHintText

    if (HistoryGui != "" && WinExist("ahk_id " HistoryGui.Hwnd)) {
        WinActivate("ahk_id " HistoryGui.Hwnd)
        return
    }

    HistoryGui := Gui("+Owner" MainGui.Hwnd " +ToolWindow", "History")

    ChkDisableHistory := HistoryGui.Add("Checkbox", "x10 y8 w200 " . (IsHistoryDisabled ? "Checked" : ""), "Disable History Logging")
    ChkDisableHistory.OnEvent("Click", OnToggleHistoryDisable)

    HistoryHintText := HistoryGui.Add("Text", "x220 y10 w370 Right " . (IsHistoryDisabled ? "Hidden" : ""), "Double-click an entry to open it in the active tab.")

    HistoryLV := HistoryGui.Add("ListView", "x10 y35 w580 h345 -Multi " . (IsHistoryDisabled ? "Hidden" : ""), ["Time", "URL", "Title"])
    HistoryLV.ModifyCol(1, 130)
    HistoryLV.ModifyCol(2, 200)
    HistoryLV.ModifyCol(3, 230)

    HistoryDisabledText := HistoryGui.Add("Text", "x10 y35 w580 h345 Center +0x200 +Disabled " . (IsHistoryDisabled ? "" : "Hidden"), "History logging is disabled")

    if (!IsHistoryDisabled)
        PopulateHistoryLV()

    HistoryLV.OnEvent("DoubleClick", HistoryLV_DoubleClick)
    ApplyGuiTheme(HistoryGui)
    HistoryGui.Show("w600 h390")
}

PopulateHistoryLV() {
    global HistoryLV, HistoryFile

    HistoryLV.Delete()
    if FileExist(HistoryFile) {
        HistoryContent := FileRead(HistoryFile)
        HistoryLines := StrSplit(HistoryContent, "`n", "`r")

        Loop HistoryLines.Length {
            i := HistoryLines.Length - A_Index + 1
            line := HistoryLines[i]
            if (line = "")
                continue

            parts := StrSplit(line, "`t")
            if (parts.Length >= 2) {
                HistoryLV.Add("", parts[1], parts[2], parts.Length >= 3 ? parts[3] : "")
            }
        }
    }
}

OnToggleHistoryDisable(chkCtrl, *) {
    global IsHistoryDisabled, HistoryFile, HistoryLV, HistoryDisabledText, HistoryHintText, ConfigFile

    IsHistoryDisabled := chkCtrl.Value
    IniWrite(IsHistoryDisabled ? "1" : "0", ConfigFile, "History", "DisableHistory")

    if (IsHistoryDisabled) {
        if FileExist(HistoryFile)
            FileOpen(HistoryFile, "w").Close()

        HistoryLV.Delete()
        HistoryLV.Visible := false
        HistoryHintText.Visible := false
        HistoryDisabledText.Visible := true
    } else {
        HistoryDisabledText.Visible := false
        HistoryHintText.Visible := true
        HistoryLV.Visible := true
        PopulateHistoryLV()
    }
}

ClearHistory(*) {
    global HistoryLV, HistoryFile, HistoryGui
    if FileExist(HistoryFile) {
        FileDelete(HistoryFile)
    }
    if (HistoryGui != "" && WinExist("ahk_id " HistoryGui.Hwnd)) {
        try HistoryLV.Delete()
    }
    MsgBox("Browsing history has been cleared.", "History Cleared", "Iconi")
}
BuildDefaultNewTabHtml()
{
    global NewTabBgType, NewTabBgVal, AppTheme

    Geo := GetUserGeo()

    IntlFeed  := "https://news.google.com/rss/headlines/section/topic/WORLD?hl=en-US&gl=US&ceid=US:en"

    localQuery := (Geo.HasProp("city") && Geo.city != "") ? Geo.city : ((Geo.HasProp("name") && Geo.name != "") ? Geo.name : "news")
    LocalFeed := "https://news.google.com/rss/search?q=" . UriEncode(localQuery) . "&hl=en-" . Geo.code . "&gl=" . Geo.code . "&ceid=" . Geo.code . ":en"

    EntFeed   := "https://news.google.com/rss/search?q=movies%20OR%20anime%20OR%20%22video%20games%22%20OR%20celebrity&hl=en-US&gl=US&ceid=US:en"

    IntlItems  := FetchRssHeadlines(IntlFeed, 6)
    LocalItems := FetchRssHeadlines(LocalFeed, 6)
    EntItems   := FetchRssHeadlines(EntFeed, 6)

    PageColors := ComputeThemeColors(AppTheme)
    IsDarkPage := PageColors.isDark

    if (NewTabBgType = "Image" && FileExist(NewTabBgVal))
    {
        ImgUrl := "file:///" . StrReplace(StrReplace(NewTabBgVal, "\", "/"), " ", "%20")
        BgCss := "background: url('" . ImgUrl . "') no-repeat center center fixed; background-size: cover; color:#eee;"
    }
    else
    {
        PageBgVal := (NewTabBgVal != "") ? NewTabBgVal : "#" . PageColors.bg
        PageTextColor := IsDarkPage ? "#eee" : "#1a1a1a"
        BgCss := "background:" . PageBgVal . "; color:" . PageTextColor . ";"
    }

    if (NewTabBgType = "Image")
    {
        cardBg := "background:rgba(30,30,30,0.78); backdrop-filter:blur(8px);"
        inputBg := "#2a2a2a", inputText := "#eee", borderCol := "#444"
        mutedText := "#ccc", dimText := "#888", linkColor := "#8ab4f8"
        navBg := "#333", navHover := "#444", navText := "#ccc"
    }
    else if (IsDarkPage)
    {
        cardBg := "background:#252525;"
        inputBg := "#2a2a2a", inputText := "#eee", borderCol := "#444"
        mutedText := "#ccc", dimText := "#888", linkColor := "#8ab4f8"
        navBg := "#333", navHover := "#444", navText := "#ccc"
    }
    else
    {
        cardBg := "background:#ffffff; box-shadow:0 1px 3px rgba(0,0,0,0.12);"
        inputBg := "#ffffff", inputText := "#1a1a1a", borderCol := "#ccc"
        mutedText := "#333", dimText := "#777", linkColor := "#1a73e8"
        navBg := "#eee", navHover := "#ddd", navText := "#333"
    }

    html := "<html><head><meta charset='UTF-8'><meta http-equiv='X-UA-Compatible' content='IE=edge'><title>New Tab</title>"
    html .= "<style>"
    html .= "body{font-family:Segoe UI,Arial,sans-serif;" . BgCss . "margin:0;padding:40px 20px;}"
    html .= ".search-wrap{max-width:600px;margin:0 auto 40px auto;text-align:center;}"
    html .= ".search-wrap input[type=text]{width:70%;padding:12px 16px;font-size:16px;border-radius:24px 0 0 24px;border:1px solid " . borderCol . ";background:" . inputBg . ";color:" . inputText . ";outline:none;}"
    html .= ".search-wrap button{padding:12px 20px;font-size:16px;border-radius:0 24px 24px 0;border:1px solid " . borderCol . ";background:" . navBg . ";color:" . inputText . ";cursor:pointer;}"
    html .= "h1{text-align:center;font-size:26px;margin-bottom:30px;}"
    html .= ".columns{display:flex;gap:20px;max-width:1000px;margin:0 auto;flex-wrap:wrap;}"
    html .= ".col{flex:1;min-width:280px;" . cardBg . "border-radius:10px;padding:16px 20px;}"
    html .= ".col h2{font-size:16px;border-bottom:1px solid " . borderCol . ";padding-bottom:8px;margin-top:0;}"
    html .= ".carousel{position:relative;height:100px;overflow:hidden;margin-top:12px;}"
    html .= ".slide{position:absolute;top:0;left:0;width:100%;transition:transform 0.6s ease;}"
    html .= ".slide-card{display:block;text-decoration:none;color:" . linkColor . ";}"
    html .= ".slide-card:hover .slide-title{text-decoration:underline;}"
    html .= ".slide-title{font-size:14px;font-weight:600;line-height:1.5;color:" . linkColor . ";display:-webkit-box;-webkit-line-clamp:5;-webkit-box-orient:vertical;overflow:hidden;}"
    html .= ".slide-empty{color:" . dimText . ";font-size:13px;padding-top:10px;}"
    html .= ".carousel-nav{display:flex;justify-content:space-between;align-items:center;margin-top:8px;}"
    html .= ".carousel-nav button{background:" . navBg . ";color:" . navText . ";border:1px solid " . borderCol . ";border-radius:6px;padding:4px 10px;font-size:12px;cursor:pointer;}"
    html .= ".carousel-nav button:hover{background:" . navHover . ";}"
    html .= ".carousel-dots{font-size:11px;color:" . dimText . ";}"

    html .= ".shortcuts{max-width:1000px;margin:30px auto 0 auto;" . cardBg . "border-radius:10px;padding:16px 20px;display:flex;gap:20px;flex-wrap:wrap;}"
    html .= ".shortcuts-col{flex:1;min-width:240px;}"
    html .= ".shortcuts h2{font-size:16px;border-bottom:1px solid " . borderCol . ";padding-bottom:8px;margin-top:0;}"
    html .= ".shortcuts table{width:100%;border-collapse:collapse;font-size:13px;}"
    html .= ".shortcuts td{padding:4px 0;color:" . mutedText . ";}"
    html .= ".shortcuts td.key{color:" . linkColor . ";font-family:Consolas,monospace;width:110px;}"
    html .= ".rate-item{display:flex;justify-content:space-between;font-size:13px;padding:3px 0;color:" . mutedText . ";}"
    html .= ".rate-val{font-weight:600;color:" . linkColor . ";}"
    html .= "</style></head><body>"

    html .= "<div class='search-wrap'>"
    html .= "<h1 style='font-size:64px;margin:0 0 20px 0;'>🌐</h1>"
    html .= "<form action='https://www.google.com/search' method='GET'>"
    html .= "<input type='text' name='q' placeholder='Search Google or type a URL' autofocus>"
    html .= "<button type='submit'>Search</button>"
    html .= "</form></div>"

    html .= "<div class='columns'>"
    html .= "<div class='col'><h2>🌐 International News</h2><div class='carousel' id='col-intl'></div>" . CarouselNavHtml("col-intl") . "</div>"
    html .= "<div class='col'><h2>📍 Local News (" . EscapeHtml(Geo.HasProp("name") ? Geo.name : "Local") . ")</h2><div class='carousel' id='col-local'></div>" . CarouselNavHtml("col-local") . "</div>"
    html .= "<div class='col'><h2>🎬 Games / Showbiz / Movies / Anime</h2><div class='carousel' id='col-ent'></div>" . CarouselNavHtml("col-ent") . "</div>"
    html .= "</div>"

    html .= "<div class='shortcuts'>"
    html .= "<div class='shortcuts-col'><h2>⌨️ Keyboard Shortcuts</h2><table>"
    html .= "<tr><td class='key'>Ctrl + T</td><td>Open a new tab</td></tr>"
    html .= "<tr><td class='key'>Ctrl + W</td><td>Close current tab</td></tr>"
    html .= "<tr><td class='key'>Ctrl + R</td><td>Reload page</td></tr>"
    html .= "<tr><td class='key'>Ctrl + L</td><td>Focus address bar</td></tr>"
    html .= "<tr><td class='key'>Ctrl + H</td><td>Open history</td></tr>"
    html .= "<tr><td class='key'>Ctrl + N</td><td>New Window</td></tr>"
    html .= "</table></div>"

    html .= "<div class='shortcuts-col' style='border-left:1px solid " . borderCol . ";padding-left:20px;'>"
    html .= "<h2>📍 <span id='city-display'>" . EscapeHtml(Geo.HasProp("city") ? Geo.city : "Local") . "</span> Info</h2>"
    html .= "<div style='font-size:26px;font-weight:bold;margin:8px 0;' id='clock-display'>--:--:--</div>"
    html .= "<div style='font-size:14px;color:" . mutedText . ";' id='weather-display'>🌤️ Loading weather...</div>"
    html .= "</div>"

    html .= "<div class='shortcuts-col' style='border-left:1px solid " . borderCol . ";padding-left:20px;'>"
    html .= "<h2>📈 Rates & Crypto</h2>"
    html .= "<div id='fiat-display' style='margin-bottom:8px;'><div style='font-size:12px;color:" . dimText . ";'>Loading currency...</div></div>"
    html .= "<div id='crypto-display'><div style='font-size:12px;color:" . dimText . ";'>Loading crypto...</div></div>"
    html .= "</div></div>"

    html .= "<script>"
    html .= "function updateClock(){"
    html .= "var d = new Date();"
    html .= "document.getElementById('clock-display').textContent = d.toLocaleTimeString();"
    html .= "}"
    html .= "setInterval(updateClock, 1000); updateClock();"

    html .= "(function fetchWeather(){"
    html .= "var lat='" . (Geo.HasProp("lat") ? Geo.lat : "") . "', lon='" . (Geo.HasProp("lon") ? Geo.lon : "") . "';"
    html .= "function getWeather(latVal, lonVal){"
    html .= "  fetch('https://api.open-meteo.com/v1/forecast?latitude=' + latVal + '&longitude=' + lonVal + '&current_weather=true')"
    html .= "  .then(function(r){ return r.json(); })"
    html .= "  .then(function(d){"
    html .= "    if(d && d.current_weather){"
    html .= "      var temp = Math.round(d.current_weather.temperature);"
    html .= "      var code = d.current_weather.weathercode;"
    html .= "      var icons = {0:'☀️ Clear', 1:'🌤️ Mainly Clear', 2:'⛅ Partly Cloudy', 3:'☁️ Overcast', 45:'🌫️ Foggy', 51:'🌧️ Drizzle', 61:'🌧️ Rain', 71:'❄️ Snow', 95:'🌩️ Thunderstorm'};"
    html .= "      var cond = icons[code] || '🌡️ Weather';"
    html .= "      document.getElementById('weather-display').textContent = cond + ' ' + temp + '°C';"
    html .= "    } else { document.getElementById('weather-display').textContent = '🌡️ Weather unavailable'; }"
    html .= "  }).catch(function(){ document.getElementById('weather-display').textContent = '🌡️ Weather unavailable'; });"
    html .= "}"
    html .= "if(lat && lon){ getWeather(lat, lon); } else {"
    html .= "  fetch('https://ipapi.co/json/')"
    html .= "  .then(function(r){ return r.json(); })"
    html .= "  .then(function(loc){"
    html .= "     if(loc.city) document.getElementById('city-display').textContent = loc.city;"
    html .= "     getWeather(loc.latitude, loc.longitude);"
    html .= "  }).catch(function(){ document.getElementById('weather-display').textContent = '🌡️ Weather unavailable'; });"
    html .= "}"
    html .= "})();"

    html .= "(function fetchRates(){"
    html .= "var localCurr = '" . (Geo.HasProp("currency") ? Geo.currency : "USD") . "';"
    html .= "fetch('https://open.er-api.com/v6/latest/USD')"
    html .= ".then(function(r){ return r.json(); })"
    html .= ".then(function(d){"
    html .= "if(d && d.rates){"
    html .= "var eur = d.rates.EUR ? d.rates.EUR.toFixed(2) : '--';"
    html .= "var gbp = d.rates.GBP ? d.rates.GBP.toFixed(2) : '--';"
    html .= "var loc = (localCurr !== 'USD' && d.rates[localCurr]) ? d.rates[localCurr].toFixed(2) : null;"
    html .= "var h = '<div class=rate-item><span>USD/EUR</span><span class=rate-val>€' + eur + '</span></div>';"
    html .= "h += '<div class=rate-item><span>USD/GBP</span><span class=rate-val>£' + gbp + '</span></div>';"
    html .= "if(loc){ h += '<div class=rate-item><span>USD/' + localCurr + '</span><span class=rate-val>' + loc + '</span></div>'; }"
    html .= "document.getElementById('fiat-display').innerHTML = h;"
    html .= "} else { document.getElementById('fiat-display').textContent = 'Fiat unavailable'; }"
    html .= "}).catch(function(){ document.getElementById('fiat-display').textContent = 'Fiat unavailable'; });"

    html .= "Promise.all(["
    html .= "fetch('https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT').then(function(r){return r.json();}),"
    html .= "fetch('https://api.binance.com/api/v3/ticker/price?symbol=ETHUSDT').then(function(r){return r.json();}),"
    html .= "fetch('https://api.binance.com/api/v3/ticker/price?symbol=SOLUSDT').then(function(r){return r.json();})"
    html .= "]).then(function(res){"
    html .= "var btc = parseFloat(res[0].price).toLocaleString('en-US', {maximumFractionDigits:0});"
    html .= "var eth = parseFloat(res[1].price).toLocaleString('en-US', {maximumFractionDigits:0});"
    html .= "var sol = parseFloat(res[2].price).toLocaleString('en-US', {maximumFractionDigits:2});"
    html .= "var ch = '<div class=rate-item><span>BTC</span><span class=rate-val>$' + btc + '</span></div>';"
    html .= "ch += '<div class=rate-item><span>ETH</span><span class=rate-val>$' + eth + '</span></div>';"
    html .= "ch += '<div class=rate-item><span>SOL</span><span class=rate-val>$' + sol + '</span></div>';"
    html .= "document.getElementById('crypto-display').innerHTML = ch;"
    html .= "}).catch(function(){ document.getElementById('crypto-display').textContent = 'Crypto unavailable'; });"
    html .= "})();"

    html .= "function initCarousel(id, items){"
    html .= "var el = document.getElementById(id);"
    html .= "var dots = document.getElementById(id + '-dots');"
    html .= "if(!items || !items.length){ el.innerHTML = '<div class=slide-empty>No headlines available right now.</div>'; return; }"
    html .= "var idx = 0, timer = null;"
    html .= "function render(){"
    html .= "el.innerHTML = items.map(function(it,i){"
    html .= "var offset = i - idx;"
    html .= "return '<div class=slide style=\'transform:translateX(' + (offset*100) + '%)\'><a href=\'' + it.link + '\' target=_self class=slide-card><div class=slide-title>' + it.title + '</div></a></div>';"
    html .= "}).join('');"
    html .= "if(dots) dots.textContent = (idx+1) + ' / ' + items.length;"
    html .= "}"
    html .= "function goTo(newIdx){ idx = (newIdx + items.length) % items.length; render(); resetTimer(); }"
    html .= "function resetTimer(){ if(timer) clearInterval(timer); timer = setInterval(function(){ idx = (idx+1) % items.length; render(); }, 10000); }"
    html .= "render();"
    html .= "resetTimer();"
    html .= "window['nav_' + id] = function(dir){ goTo(idx + dir); };"
    html .= "}"
    html .= "initCarousel('col-intl', [" . BuildJsItemArray(IntlItems) . "]);"
    html .= "initCarousel('col-local', [" . BuildJsItemArray(LocalItems) . "]);"
    html .= "initCarousel('col-ent', [" . BuildJsItemArray(EntItems) . "]);"
    html .= "</script>"

    html .= "</body></html>"

    return html
}

UriEncode(Text)
{
    static Safe := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"
    Result := ""
    Loop Parse, Text
    {
        Char := A_LoopField
        if InStr(Safe, Char)
            Result .= Char
        else {
            Code := Ord(Char)
            if (Code <= 0x7F)
                Result .= "%" . Format("{:02X}", Code)
            else {
                Buffer := Buffer(4, 0)
                Length := StrPut(Char, Buffer, "UTF-8") - 1
                Loop Length {
                    Byte := NumGet(Buffer, A_Index - 1, "UChar")
                    Result .= "%" . Format("{:02X}", Byte)
                }
            }
        }
    }
    return Result
}

BuildEditorPageHtml()
{
    global AppTheme, NewTabHtmlPath, CurrentGuiFontName, FontPresetNames, CurrentThemeBg, CurrentThemeText, CurrentThemeBtn, CurrentThemeCtrlBg

    PageColors := ComputeThemeColors(AppTheme)
    IsDarkPage := PageColors.isDark

    bg       := IsDarkPage ? "#1e1e1e" : "#f5f5f5"
    fg       := IsDarkPage ? "#eee" : "#1a1a1a"
    panelBg  := IsDarkPage ? "#2a2a2a" : "#ffffff"
    border   := IsDarkPage ? "#444" : "#ccc"
    headerBg := IsDarkPage ? "#333" : "#e8e8e8"
    hintCol  := IsDarkPage ? "#999" : "#777"

    DefaultHtml := BuildDefaultNewTabHtml()

    CurrentHtml := DefaultHtml
    if (FileExist(NewTabHtmlPath))
    {
        try CurrentHtml := FileRead(NewTabHtmlPath, "UTF-8")
    }

    html := "<html><head><meta charset='UTF-8'><title>Editor</title>"
    html .= "<script src='https://cdnjs.cloudflare.com/ajax/libs/ace/1.32.7/ace.js'></script>"
    html .= "<style>"
    html .= "html,body{margin:0;padding:0;height:100%;background:" . bg . ";color:" . fg . ";font-family:Segoe UI,Arial,sans-serif;}"
    html .= "#editorPanel{position:fixed;top:60px;left:60px;width:640px;height:460px;min-width:320px;min-height:220px;background:" . panelBg . ";border:1px solid " . border . ";border-radius:8px;box-shadow:0 6px 24px rgba(0,0,0,0.35);display:flex;flex-direction:column;overflow:hidden;z-index:1000;}"
    html .= "#editorHeader{background:" . headerBg . ";padding:8px 12px;cursor:move;display:flex;align-items:center;justify-content:space-between;user-select:none;border-bottom:1px solid " . border . ";}"
    html .= "#editorHeader span{font-size:13px;font-weight:600;}"
    html .= "#editorCloseBtn{background:#e64545;color:#fff;border:none;border-radius:4px;padding:4px 10px;font-size:12px;cursor:pointer;}"
    html .= "#editorCloseBtn:hover{background:#c93030;}"

    html .= "#editorTextarea{flex:1;width:100%;background:" . panelBg . ";color:" . fg . ";font-size:13px;}"

    html .= "#editorFooter{padding:8px 12px;border-top:1px solid " . border . ";display:flex;justify-content:flex-end;gap:8px;}"
    html .= "#editorResetBtn{background:" . headerBg . ";color:" . fg . ";border:1px solid " . border . ";border-radius:4px;padding:6px 12px;font-size:12px;cursor:pointer;}"
    html .= "#editorResetBtn:hover{filter:brightness(1.1);}"
    html .= "#editorCancelBtn{background:" . headerBg . ";color:" . fg . ";border:1px solid " . border . ";border-radius:4px;padding:6px 12px;font-size:12px;cursor:pointer;}"
    html .= "#editorCancelBtn:hover{filter:brightness(1.1);}"
    html .= "#editorHint{padding:6px 12px;font-size:11px;color:" . hintCol . ";}"
    html .= "#editorHeaderBtns{display:flex;gap:6px;}"
    html .= "#editorPaletteBtn{background:" . headerBg . ";color:" . fg . ";border:1px solid " . border . ";border-radius:4px;padding:4px 10px;font-size:12px;cursor:pointer;}"
    html .= "#editorPaletteBtn:hover{filter:brightness(1.15);}"
    html .= "#paletteOverlay{display:none;position:fixed;inset:0;background:rgba(0,0,0,0.45);z-index:2000;align-items:center;justify-content:center;}"
    html .= "#palettePanel{width:360px;max-height:70vh;overflow-y:auto;background:" . panelBg . ";border:1px solid " . border . ";border-radius:8px;box-shadow:0 6px 24px rgba(0,0,0,0.4);display:flex;flex-direction:column;}"
    html .= "#paletteHead{padding:10px 14px;font-size:13px;font-weight:600;border-bottom:1px solid " . border . ";}"
    html .= "#paletteRows{padding:10px 14px;display:flex;flex-direction:column;gap:8px;}"
    html .= ".palRow{display:flex;align-items:center;gap:8px;}"
    html .= ".palRow input[type=color]{width:32px;height:26px;padding:0;border:1px solid " . border . ";border-radius:4px;background:none;cursor:pointer;}"
    html .= ".palRow input[type=text]{flex:1;font-family:Consolas,monospace;font-size:12px;padding:4px 6px;border:1px solid " . border . ";border-radius:4px;background:" . panelBg . ";color:" . fg . ";}"
    html .= ".palRow span{width:110px;font-size:12px;}"
    html .= "#paletteFoot{padding:10px 14px;border-top:1px solid " . border . ";display:flex;justify-content:flex-end;gap:8px;}"
    html .= "#paletteSaveBtn{background:#3a7bd5;color:#fff;border:none;border-radius:4px;padding:6px 12px;font-size:12px;cursor:pointer;}"
    html .= "#paletteSaveBtn:hover{filter:brightness(1.1);}"
    html .= "#paletteCloseBtn{background:" . headerBg . ";color:" . fg . ";border:1px solid " . border . ";border-radius:4px;padding:6px 12px;font-size:12px;cursor:pointer;}"
    html .= "#editorImportBtn{background:" . headerBg . ";color:" . fg . ";border:1px solid " . border . ";border-radius:4px;padding:4px 10px;font-size:12px;cursor:pointer;}"
    html .= "#editorImportBtn:hover{filter:brightness(1.15);}"
    html .= "#editorFontBtn{background:" . headerBg . ";color:" . fg . ";border:1px solid " . border . ";border-radius:4px;padding:4px 10px;font-size:12px;cursor:pointer;}"
    html .= "#editorFontBtn:hover{filter:brightness(1.15);}"

    html .= "#fontOverlay{display:none;position:fixed;inset:0;background:rgba(0,0,0,0.45);z-index:2000;align-items:center;justify-content:center;}"
    html .= "#fontPanel{width:340px;max-height:70vh;overflow-y:auto;background:" . panelBg . ";border:1px solid " . border . ";border-radius:8px;box-shadow:0 6px 24px rgba(0,0,0,0.4);display:flex;flex-direction:column;}"
    html .= "#fontHead{padding:10px 14px;font-size:13px;font-weight:600;border-bottom:1px solid " . border . ";}"
    html .= "#fontList{padding:10px 14px;display:flex;flex-direction:column;gap:6px;max-height:220px;overflow-y:auto;}"
    html .= ".fontOpt{padding:6px 10px;border:1px solid " . border . ";border-radius:4px;cursor:pointer;font-size:13px;}"
    html .= ".fontOpt.active{border-color:#3a7bd5;background:rgba(58,123,213,0.15);}"
    html .= "#fontCustomWrap{padding:0 14px 10px;display:flex;gap:6px;}"
    html .= "#fontImportBtn{flex:1;background:" . headerBg . ";color:" . fg . ";border:1px solid " . border . ";border-radius:4px;padding:6px 10px;font-size:12px;cursor:pointer;}"
    html .= "#fontImportBtn:hover{filter:brightness(1.15);}"
    html .= "#fontCustomLabel{padding:0 14px 8px;font-size:11px;color:" . hintCol . ";}"
    html .= "#fontFoot{padding:10px 14px;border-top:1px solid " . border . ";display:flex;justify-content:flex-end;gap:8px;}"
    html .= "#fontSaveBtn{background:#3a7bd5;color:#fff;border:none;border-radius:4px;padding:6px 12px;font-size:12px;cursor:pointer;}"
    html .= "#fontCloseBtn{background:" . headerBg . ";color:" . fg . ";border:1px solid " . border . ";border-radius:4px;padding:6px 12px;font-size:12px;cursor:pointer;}"
    html .= "#previewFrame{position:fixed;inset:0;width:100%;height:100%;border:none;background:#fff;}"

    html .= ".resizer{position:absolute;z-index:1001;}"
    html .= ".resizer-r{cursor:e-resize;width:6px;right:0;top:0;bottom:0;}"
    html .= ".resizer-b{cursor:s-resize;height:6px;bottom:0;left:0;right:0;}"
    html .= ".resizer-l{cursor:w-resize;width:6px;left:0;top:0;bottom:0;}"
    html .= ".resizer-t{cursor:n-resize;height:6px;top:0;left:0;right:0;}"
    html .= ".resizer-br{cursor:se-resize;width:10px;height:10px;right:0;bottom:0;}"
    html .= ".resizer-bl{cursor:sw-resize;width:10px;height:10px;left:0;bottom:0;}"
    html .= ".resizer-tr{cursor:ne-resize;width:10px;height:10px;right:0;top:0;}"
    html .= ".resizer-tl{cursor:nw-resize;width:10px;height:10px;left:0;top:0;}"
    html .= "</style></head><body>"

    html .= "<iframe id='previewFrame'></iframe>"
    html .= "<div id='editorPanel'>"

    html .= "<div class='resizer resizer-t'></div>"
    html .= "<div class='resizer resizer-r'></div>"
    html .= "<div class='resizer resizer-b'></div>"
    html .= "<div class='resizer resizer-l'></div>"
    html .= "<div class='resizer resizer-tl'></div>"
    html .= "<div class='resizer resizer-tr'></div>"
    html .= "<div class='resizer resizer-bl'></div>"
    html .= "<div class='resizer resizer-br'></div>"

    html .= "<div id='editorHeader'><span>GUI Editor</span><div id='editorHeaderBtns'><button type='button' id='editorImportBtn'>Import HTML</button><button type='button' id='editorFontBtn'>Font Styles</button><button type='button' id='editorPaletteBtn'>Interface Colors</button><button type='button' id='editorCloseBtn'>Save &amp; Close</button></div></div>"
    html .= "<div id='editorHint'><strong>Custom New Tab</strong><br>Press save &amp; close to save it as your new tab page, or cancel to restore previous design.</div>"
    html .= "<div id='editorTextarea'></div>"
    html .= "<div id='editorFooter'><button type='button' id='editorCancelBtn'>Cancel</button><button type='button' id='editorResetBtn'>Reset to Defaults</button></div>"
    html .= "</div>"

    html .= "<div id='paletteOverlay'><div id='palettePanel'>"
    html .= "<div id='paletteHead'>Edit Interface Colors</div>"
    html .= "<div id='paletteRows'></div>"
    html .= "<div id='paletteFoot'><button type='button' id='paletteCloseBtn'>Close</button><button type='button' id='paletteSaveBtn'>Save Palette</button></div>"
    html .= "</div></div>"

    html .= "<div id='fontOverlay'><div id='fontPanel'>"
    html .= "<div id='fontHead'>Font Styles</div>"
    html .= "<div id='fontList'></div>"
    html .= "<div id='fontCustomWrap'><button type='button' id='fontImportBtn'>Choose Font File (.ttf / .otf)...</button></div>"
    html .= "<div id='fontCustomLabel'></div>"
    html .= "<div id='fontFoot'><button type='button' id='fontCloseBtn'>Close</button><button type='button' id='fontSaveBtn'>Save Font</button></div>"
    html .= "</div></div>"

    html .= "<script>"
    html .= "var CURRENT_HTML = '" . EscapeJsString(CurrentHtml) . "';"
    html .= "var DEFAULT_HTML = '" . EscapeJsString(DefaultHtml) . "';"
    html .= "var preview = document.getElementById('previewFrame');"

    html .= "var editor = ace.edit('editorTextarea');"
    html .= "editor.setTheme(" . (IsDarkPage ? "'ace/theme/monokai'" : "'ace/theme/chrome'") . ");"
    html .= "editor.session.setMode('ace/mode/html');"
    html .= "editor.setOptions({"
    html .= "  fontSize: '13px',"
    html .= "  fontFamily: 'Consolas, Monaco, Courier New, monospace',"
    html .= "  showPrintMargin: false,"
    html .= "  wrap: true,"
    html .= "  tabSize: 4"
    html .= "});"

    html .= "function getCode() { return editor.getValue(); }"
    html .= "function setCode(val) { editor.setValue(val, -1); }"

	html .= "function formatHTML(htmlStr) {"
	html .= "  var scripts = [];"
	html .= "  htmlStr = htmlStr.replace(/<script[\s\S]*?<\/script>/gi, function(m) {"
	html .= "    scripts.push(m);"
	html .= "    return '@@SCRIPT' + (scripts.length - 1) + '@@';"
	html .= "  });"
	html .= "  var indent = '';"
	html .= "  var formatted = '';"
	html .= "  var reg = /(>)(<)(\/*)/g;"
	html .= "  htmlStr = htmlStr.replace(reg, '$1\r\n$2$3');"
	html .= "  var pad = 0;"
	html .= "  htmlStr.split('\r\n').forEach(function(node) {"
	html .= "    var indent = 0;"
	html .= "    if (node.match(/.+<\/\w[^>]*>$/)) {"
	html .= "      indent = 0;"
	html .= "    } else if (node.match(/^<\/\w/)) {"
	html .= "      if (pad !== 0) pad -= 1;"
	html .= "    } else if (node.match(/^<\w[^>]*[^\/]>.*$/)) {"
	html .= "      indent = 1;"
	html .= "    }"
	html .= "    var padding = '';"
	html .= "    for (var i = 0; i < pad; i++) padding += '  ';"
	html .= "    formatted += padding + node + '\r\n';"
	html .= "    pad += indent;"
	html .= "  });"
	html .= "  formatted = formatted.trim();"
	html .= "  formatted = formatted.replace(/@@SCRIPT(\d+)@@/g, function(m, i) { return scripts[parseInt(i, 10)]; });"
	html .= "  return formatted;"
	html .= "}"

    html .= "setCode(formatHTML(CURRENT_HTML));"

    html .= "var previewTimer = null;"
    html .= "function updatePreview(){ preview.srcdoc = getCode(); }"
    html .= "editor.on('change', function(){ if(previewTimer) clearTimeout(previewTimer); previewTimer = setTimeout(updatePreview, 400); });"
    html .= "updatePreview();"

    html .= "document.getElementById('editorCloseBtn').addEventListener('click', function(){"
    html .= "try{ window.chrome.webview.postMessage('SAVE_EDITOR:' + getCode()); }catch(e){}"
    html .= "});"

    html .= "document.getElementById('editorResetBtn').addEventListener('click', function(){ setCode(formatHTML(DEFAULT_HTML)); updatePreview(); });"

    html .= "document.getElementById('editorCancelBtn').addEventListener('click', function(){"
    html .= "try{ window.chrome.webview.postMessage('CANCEL_EDITOR'); }catch(e){}"
    html .= "try{ window.chrome.webview.postMessage('REVERT_THEME'); }catch(e){}"
    html .= "});"

    html .= "var THEME_VARS = ["
    html .= "{key:'bg',label:'Window / Dialog Background',hex:'#" . CurrentThemeBg . "'},"
    html .= "{key:'text',label:'Text Color',hex:'#" . CurrentThemeText . "'},"
    html .= "{key:'btn',label:'Button Background',hex:'#" . CurrentThemeBtn . "'},"
    html .= "{key:'ctrlBg',label:'Input / List Background',hex:'#" . CurrentThemeCtrlBg . "'}"
    html .= "];"
    html .= "(function(){"
    html .= "var overlay = document.getElementById('paletteOverlay');"
    html .= "var rows = document.getElementById('paletteRows');"
    html .= "var liveTimer = null;"
    html .= "var themeSaved = false;"
    html .= "function revertIfUnsaved(){"
    html .= "if(!themeSaved){ try{ window.chrome.webview.postMessage('REVERT_THEME'); }catch(e){} }"
    html .= "}"

    html .= "function currentValues(){"
    html .= "var vals = {};"
    html .= "rows.querySelectorAll('input[type=text]').forEach(function(inp){ vals[inp.dataset.key] = inp.value; });"
    html .= "return vals;"
    html .= "}"
    html .= "function sendLive(){"
    html .= "var v = currentValues();"
    html .= "try{ window.chrome.webview.postMessage('LIVE_THEME:' + v.bg + '|' + v.text + '|' + v.btn + '|' + v.ctrlBg); }catch(e){}"
    html .= "}"
    html .= "function buildRows(){"
    html .= "rows.innerHTML = '';"
    html .= "THEME_VARS.forEach(function(v){"
    html .= "var row = document.createElement('div'); row.className = 'palRow';"
    html .= "var label = document.createElement('span'); label.textContent = v.label;"
    html .= "var colorInp = document.createElement('input'); colorInp.type = 'color'; colorInp.value = v.hex; colorInp.dataset.key = v.key;"
    html .= "var textInp = document.createElement('input'); textInp.type = 'text'; textInp.value = v.hex; textInp.dataset.key = v.key;"
    html .= "colorInp.addEventListener('input', function(){"
    html .= "textInp.value = colorInp.value;"
    html .= "if(liveTimer) clearTimeout(liveTimer);"
    html .= "liveTimer = setTimeout(sendLive, 60);"
    html .= "});"
    html .= "textInp.addEventListener('input', function(){"
    html .= "if(/^#[0-9A-Fa-f]{6}$/.test(textInp.value)){"
    html .= "colorInp.value = textInp.value;"
    html .= "if(liveTimer) clearTimeout(liveTimer);"
    html .= "liveTimer = setTimeout(sendLive, 60);"
    html .= "}"
    html .= "});"
    html .= "row.appendChild(label); row.appendChild(colorInp); row.appendChild(textInp);"
    html .= "rows.appendChild(row);"
    html .= "});"
    html .= "}"
    html .= "document.getElementById('editorPaletteBtn').addEventListener('click', function(){ buildRows(); overlay.style.display = 'flex'; });"

    html .= "document.getElementById('paletteCloseBtn').addEventListener('click', function(){ revertIfUnsaved(); overlay.style.display = 'none'; });"

    html .= "document.getElementById('paletteSaveBtn').addEventListener('click', function(){"
    html .= "var v = currentValues();"
    html .= "try{ window.chrome.webview.postMessage('SAVE_THEME:' + v.bg + '|' + v.text + '|' + v.btn + '|' + v.ctrlBg); }catch(e){}"
    html .= "themeSaved = true;"
    html .= "overlay.style.display = 'none';"
    html .= "});"
    html .= "})();"

    html .= "document.getElementById('editorImportBtn').addEventListener('click', function(){"
    html .= "try{ window.chrome.webview.postMessage('IMPORT_HTML'); }catch(e){}"
    html .= "});"

    html .= "var CURRENT_FONT = '" . EscapeJsString(CurrentGuiFontName) . "';"
    fontList := ""
    for fName in FontPresetNames
        fontList .= (fontList = "" ? "" : ",") . "'" . EscapeJsString(fName) . "'"
    html .= "var FONT_PRESETS = [" . fontList . "];"

    html .= "(function(){"
    html .= "var fOverlay = document.getElementById('fontOverlay');"
    html .= "var fList = document.getElementById('fontList');"
    html .= "var customLabel = document.getElementById('fontCustomLabel');"
    html .= "var fontSaved = false;"
    html .= "var selectedFont = CURRENT_FONT;"
    html .= "function revertIfUnsaved(){ if(!fontSaved){ try{ window.chrome.webview.postMessage('REVERT_FONT'); }catch(e){} } }"
    html .= "function applyLive(name){ try{ window.chrome.webview.postMessage('LIVE_FONT:' + name); }catch(e){} }"
    html .= "function buildFontList(){"
    html .= "fList.innerHTML = '';"
    html .= "FONT_PRESETS.forEach(function(name){"
    html .= "var opt = document.createElement('div');"
    html .= "opt.className = 'fontOpt' + (name === selectedFont ? ' active' : '');"
    html .= "opt.textContent = name;"
    html .= "opt.style.fontFamily = name;"
    html .= "opt.addEventListener('click', function(){"
    html .= "selectedFont = name;"
    html .= "customLabel.textContent = '';"
    html .= "Array.from(fList.children).forEach(function(c){ c.classList.remove('active'); });"
    html .= "opt.classList.add('active');"
    html .= "applyLive(name);"
    html .= "});"
    html .= "fList.appendChild(opt);"
    html .= "});"
    html .= "}"
    html .= "document.getElementById('editorFontBtn').addEventListener('click', function(){ buildFontList(); fOverlay.style.display = 'flex'; });"
    html .= "document.getElementById('fontImportBtn').addEventListener('click', function(){"
    html .= "try{ window.chrome.webview.postMessage('IMPORT_FONT'); }catch(e){}"
    html .= "});"
    html .= "window.setCustomFontLabel = function(name){"
    html .= "selectedFont = name;"
    html .= "Array.from(fList.children).forEach(function(c){ c.classList.remove('active'); });"
    html .= "customLabel.textContent = 'Custom font selected: ' + name;"
    html .= "};"
    html .= "document.getElementById('fontCloseBtn').addEventListener('click', function(){ revertIfUnsaved(); fOverlay.style.display = 'none'; });"
    html .= "document.getElementById('fontSaveBtn').addEventListener('click', function(){"
    html .= "try{ window.chrome.webview.postMessage('SAVE_FONT:' + selectedFont); }catch(e){}"
    html .= "fontSaved = true;"
    html .= "fOverlay.style.display = 'none';"
    html .= "});"
    html .= "})();"

    html .= "(function(){"
    html .= "var panel = document.getElementById('editorPanel');"
    html .= "var header = document.getElementById('editorHeader');"
    html .= "var preview = document.getElementById('previewFrame');"
    html .= "var resizers = document.querySelectorAll('#editorPanel .resizer');"
    html .= "var minW = 320, minH = 220;"
    html .= "var isDragging = false, isResizing = false;"
    html .= "var offX = 0, offY = 0;"
    html .= "var origW = 0, origH = 0, origX = 0, origY = 0, origMX = 0, origMY = 0;"
    html .= "var currentResizer = null;"

    html .= "function enableDragLock(locking){"
    html .= "  preview.style.pointerEvents = locking ? 'none' : 'auto';"
    html .= "  document.body.style.userSelect = locking ? 'none' : 'auto';"
    html .= "}"

    html .= "header.addEventListener('mousedown', function(e){"
    html .= "  if(e.target.closest('button')) return;"
    html .= "  isDragging = true;"
    html .= "  enableDragLock(true);"
    html .= "  var r = panel.getBoundingClientRect();"
    html .= "  offX = e.clientX - r.left; offY = e.clientY - r.top;"
    html .= "});"

    html .= "window.addEventListener('mousemove', function(e){"
    html .= "  if(!isDragging) return;"
    html .= "  var x = e.clientX - offX, y = e.clientY - offY;"
    html .= "  x = Math.max(0, Math.min(x, window.innerWidth - panel.offsetWidth));"
    html .= "  y = Math.max(0, Math.min(y, window.innerHeight - panel.offsetHeight));"
    html .= "  panel.style.left = x + 'px'; panel.style.top = y + 'px';"
    html .= "});"

    html .= "for(var i = 0; i < resizers.length; i++){"
    html .= "  resizers[i].addEventListener('mousedown', function(e){"
    html .= "    e.preventDefault();"
    html .= "    isResizing = true;"
    html .= "    enableDragLock(true);"
    html .= "    currentResizer = e.target;"
    html .= "    var r = panel.getBoundingClientRect();"
    html .= "    origW = r.width; origH = r.height; origX = r.left; origY = r.top;"
    html .= "    origMX = e.clientX; origMY = e.clientY;"
    html .= "  });"
    html .= "}"

    html .= "window.addEventListener('mousemove', function(e){"
    html .= "  if(!isResizing || !currentResizer) return;"
    html .= "  var dx = e.clientX - origMX, dy = e.clientY - origMY;"
    html .= "  if(currentResizer.classList.contains('resizer-r')){"
    html .= "    if(origW + dx > minW) panel.style.width = (origW + dx) + 'px';"
    html .= "  } else if(currentResizer.classList.contains('resizer-b')){"
    html .= "    if(origH + dy > minH) panel.style.height = (origH + dy) + 'px';"
    html .= "  } else if(currentResizer.classList.contains('resizer-l')){"
    html .= "    if(origW - dx > minW){ panel.style.width = (origW - dx) + 'px'; panel.style.left = (origX + dx) + 'px'; }"
    html .= "  } else if(currentResizer.classList.contains('resizer-t')){"
    html .= "    if(origH - dy > minH){ panel.style.height = (origH - dy) + 'px'; panel.style.top = (origY + dy) + 'px'; }"
    html .= "  } else if(currentResizer.classList.contains('resizer-br')){"
    html .= "    if(origW + dx > minW) panel.style.width = (origW + dx) + 'px';"
    html .= "    if(origH + dy > minH) panel.style.height = (origH + dy) + 'px';"
    html .= "  } else if(currentResizer.classList.contains('resizer-bl')){"
    html .= "    if(origW - dx > minW){ panel.style.width = (origW - dx) + 'px'; panel.style.left = (origX + dx) + 'px'; }"
    html .= "    if(origH + dy > minH) panel.style.height = (origH + dy) + 'px';"
    html .= "  } else if(currentResizer.classList.contains('resizer-tr')){"
    html .= "    if(origW + dx > minW) panel.style.width = (origW + dx) + 'px';"
    html .= "    if(origH - dy > minH){ panel.style.height = (origH - dy) + 'px'; panel.style.top = (origY + dy) + 'px'; }"
    html .= "  } else if(currentResizer.classList.contains('resizer-tl')){"
    html .= "    if(origW - dx > minW){ panel.style.width = (origW - dx) + 'px'; panel.style.left = (origX + dx) + 'px'; }"
    html .= "    if(origH - dy > minH){ panel.style.height = (origH - dy) + 'px'; panel.style.top = (origY + dy) + 'px'; }"
    html .= "  }"
    html .= "});"

    html .= "window.addEventListener('mouseup', function(){"
    html .= "  if(isDragging || isResizing){"
    html .= "    isDragging = false;"
    html .= "    isResizing = false;"
    html .= "    currentResizer = null;"
    html .= "    enableDragLock(false);"
    html .= "  }"
    html .= "});"

    html .= "if(window.ResizeObserver){"
    html .= "  new ResizeObserver(function(){ if(window.editor) window.editor.resize(); }).observe(panel);"
    html .= "}"
    html .= "})();"

    html .= "</script>"
    html .= "</body></html>"
    return html
}

GenerateNewTabPage(force := false)
{
    global NewTabHtmlPath

    if (!force && FileExist(NewTabHtmlPath))
    {
        content := FileRead(NewTabHtmlPath)
        if InStr(content, "<!--CUSTOM_NEWTAB-->")
            return
    }

    html := BuildDefaultNewTabHtml()
    try
    {
        f := FileOpen(NewTabHtmlPath, "w", "UTF-8")
        f.Write(html)
        f.Close()
    }
}

IsCustomNewTabFile(path)
{
    content := ""
    try content := FileRead(path, "UTF-8")
    return (SubStr(content, 1, 21) = "<!--CUSTOM_NEWTAB-->")
}
GetUserGeo()
{
    code     := "US"
    name     := "Global"
    city     := "Your Location"
    lat      := "37.7749"
    lon      := "-122.4194"
    currency := "USD"

    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", "http://ip-api.com/json/?fields=status,country,countryCode,city,lat,lon,currency", false)
        req.SetTimeouts(3000, 3000, 3000, 3000)
        req.Send()
        body := req.ResponseText

        if RegExMatch(body, '"status"\s*:\s*"success"') {
            if RegExMatch(body, '"countryCode"\s*:\s*"([^"]+)"', &m)
                code := m[1]
            if RegExMatch(body, '"country"\s*:\s*"([^"]+)"', &m2)
                name := m2[1]
            if RegExMatch(body, '"city"\s*:\s*"([^"]+)"', &m3)
                city := m3[1]
            if RegExMatch(body, '"lat"\s*:\s*([\d.-]+)', &m4)
                lat := m4[1]
            if RegExMatch(body, '"lon"\s*:\s*([\d.-]+)', &m5)
                lon := m5[1]
            if RegExMatch(body, '"currency"\s*:\s*"([^"]+)"', &m6)
                currency := m6[1]
        }
    }
    return { code: code, name: name, city: city, lat: lat, lon: lon, currency: currency }
}

CarouselNavHtml(id)
{
    html := "<div class='carousel-nav'>"
    html .= "<button type='button' onclick=`"window['nav_" . id . "'](-1)`">‹ Prev</button>"
    html .= "<span class='carousel-dots' id='" . id . "-dots'></span>"
    html .= "<button type='button' onclick=`"window['nav_" . id . "'](1)`">Next ›</button>"
    html .= "</div>"
    return html
}

FetchRssHeadlines(url, maxItems := 6)
{
    items := []
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", url, false)
        req.SetTimeouts(4000, 4000, 4000, 4000)
        req.Send()
        xml := req.ResponseText

        pos := 1
        while (items.Length < maxItems) {
            itemStart := InStr(xml, "<item>", , pos)
            if !itemStart
                break
            itemEnd := InStr(xml, "</item>", , itemStart)
            if !itemEnd
                break
            chunk := SubStr(xml, itemStart, itemEnd - itemStart)
            pos := itemEnd + 7

            title := ""
            if RegExMatch(chunk, "s)<title>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</title>", &tm)
                title := Trim(tm[1])

            link := ""
            if RegExMatch(chunk, "s)<link>(.*?)</link>", &lm)
                link := Trim(lm[1])

            if (title != "" && link != "")
                items.Push({ title: title, link: link })
        }
    }
    return items
}

BuildJsItemArray(items)
{
    parts := []
    for it in items
        parts.Push("{title:'" . JsEscape(it.title) . "',link:'" . JsEscape(it.link) . "'}")
    return parts.Length ? Join(parts, ",") : ""
}

JsEscape(Text)
{
    Text := StrReplace(Text, "\", "\\")
    Text := StrReplace(Text, "'", "\'")
    Text := StrReplace(Text, "`n", " ")
    Text := StrReplace(Text, "`r", "")
    return Text
}

EscapeHtml(Text)
{
    Text := StrReplace(Text, "&", "&amp;")
    Text := StrReplace(Text, "<", "&lt;")
    Text := StrReplace(Text, ">", "&gt;")
    return Text
}

EscapeJsString(Text)
{
    Text := StrReplace(Text, "\", "\\")
    Text := StrReplace(Text, "'", "\'")
    Text := StrReplace(Text, "`r`n", "\n")
    Text := StrReplace(Text, "`n", "\n")
    Text := StrReplace(Text, "`r", "\n")
    Text := StrReplace(Text, "</script", "<\/script")
    return Text
}

HistoryLV_DoubleClick(LV, RowNumber) {
    global Tabs, ActiveTabIdx, HistoryGui, DisplayedFullURL, URL_Input

    if (RowNumber = 0)
        return

    url := LV.GetText(RowNumber, 2)

    if (ActiveTabIdx > 0 && ActiveTabIdx <= Tabs.Length) {
        WB := Tabs[ActiveTabIdx].WB
        try WB.Navigate(url)

        DisplayedFullURL := url
        URL_Input.Text := TruncateUrl(DisplayedFullURL)

        HistoryGui.Destroy()
        HistoryGui := ""
    }
}

InitSuggestionGui()
{
    global MainGui, SuggestionGui, SuggestionLB

    SuggestionGui := Gui("+Owner" . MainGui.Hwnd . " +ToolWindow -Caption +AlwaysOnTop", "Search Suggestions")
    SuggestionGui.MarginX := 0
    SuggestionGui.MarginY := 0

    SuggestionLB := SuggestionGui.Add("ListBox", "x0 y0 w450 h150 vLBChoice -0x40000")
    SuggestionLB.SetFont("s10", "Segoe UI")
    SuggestionLB.OnEvent("Change", OnSuggestionClick)
}

OnUrlChange(*)
{
    global IsUrlFocused, SuppressAutoComplete
    if !IsSet(SuppressAutoComplete)
        SuppressAutoComplete := false

    if (!IsUrlFocused || SuppressAutoComplete)
        return

    SetTimer(FetchAndShowSuggestions, -100)
}

FetchAndShowSuggestions() {
    global URL_Input, CurrentSuggestions

    query := Trim(URL_Input.Text)
    if (query = "" || RegExMatch(query, "i)^https?://") || StrLen(query) < 2) {
        HideSuggestions()
        return
    }

    HistoryMatches := GetHistoryMatches(query, 5)

    GetGoogleSuggestionsAsync(query, (WebSuggestions) => ProcessSuggestions(query, HistoryMatches, WebSuggestions))
}

GetGoogleSuggestionsAsync(query, callback) {
    req := ComObject("MSXML2.XMLHTTP")
    url := "https://suggestqueries.google.com/complete/search?client=chrome&q=" . UriEncode(query)
    req.open("GET", url, true)

    req.onreadystatechange := () => (
        (req.readyState == 4 && req.status == 200) ? callback(ParseSuggestions(req.responseText)) : 0
    )
    try req.send()
}

ParseSuggestions(resp) {
    suggestions := []
    if RegExMatch(resp, '\["[^"]*",\s*\[(.*?)\]', &m) {
        Loop Parse, m[1], "," {
            cleanItem := Trim(A_LoopField, ' "`'')
            cleanItem := StrReplace(cleanItem, '\"', '"')
            if (cleanItem != "")
                suggestions.Push(cleanItem)
        }
    }
    return suggestions
}

ProcessSuggestions(query, HistoryMatches, WebSuggestions) {
    global URL_Input, SuggestionGui, SuggestionLB, CurrentSuggestions,
	if !IsSet(LastKeyWasDelete)
        LastKeyWasDelete := false

    if (Trim(URL_Input.Text) != query)
        return

    Merged := []
    Seen := Map()

    for item in HistoryMatches {
        key := StrLower(item)
        if !Seen.Has(key) {
            Seen[key] := true
            Merged.Push(item)
        }
    }
    for item in WebSuggestions {
        key := StrLower(item)
        if !Seen.Has(key) {
            Seen[key] := true
            Merged.Push(item)
        }
    }

    CurrentSuggestions := Merged
    if (CurrentSuggestions.Length = 0) {
        HideSuggestions()
        return
    }

    SuggestionLB.Delete()
    SuggestionLB.Add(CurrentSuggestions)
    SuggestionLB.Value := 1

    rect := Buffer(16, 0)
    DllCall("user32\GetWindowRect", "Ptr", URL_Input.Hwnd, "Ptr", rect)
    screenX := NumGet(rect, 0, "Int")
    screenY := NumGet(rect, 12, "Int") + 2
    inputWidth := NumGet(rect, 8, "Int") - screenX
    lbHeight := (Min(CurrentSuggestions.Length, 8) * 22) + 6

    SuggestionLB.Move(0, 0, inputWidth, lbHeight)
    SuggestionGui.Show("NoActivate x" . screenX . " y" . screenY . " w" . inputWidth . " h" . lbHeight)

    if (!LastKeyWasDelete && HistoryMatches.Length > 0)
        ApplyInlineAutocomplete(query, HistoryMatches[1])
}

ApplyInlineAutocomplete(typedQuery, completionUrl) {
    global URL_Input, SuppressAutoComplete
    if !IsSet(SuppressAutoComplete)
        SuppressAutoComplete := false

    bareCompletion := RegExReplace(RegExReplace(completionUrl, "i)^https?://", ""), "i)^www\.", "")
    if (StrLen(bareCompletion) <= StrLen(typedQuery))
        return
    if (SubStr(StrLower(bareCompletion), 1, StrLen(typedQuery)) != StrLower(typedQuery))
        return

    fullText := typedQuery . SubStr(bareCompletion, StrLen(typedQuery) + 1)

    SuppressAutoComplete := true
    URL_Input.Text := fullText
    DllCall("user32\SendMessage", "Ptr", URL_Input.Hwnd, "UInt", 0x00B1,
        "Ptr", StrLen(typedQuery), "Ptr", StrLen(fullText))
    SuppressAutoComplete := false
}

ReadLastLines(filePath, maxLines, maxBytes := 200000)
{
    lines := []

    f := FileOpen(filePath, "r")
    if !f
        return lines

    fileLen := f.Length
    readFrom := (fileLen > maxBytes) ? (fileLen - maxBytes) : 0
    f.Seek(readFrom, 0)
    content := f.Read()
    f.Close()

    if (content = "")
        return lines

    lines := StrSplit(content, "`n", "`r")

    if (readFrom > 0 && lines.Length > 0)
        lines.RemoveAt(1)

    if (lines.Length > maxLines)
    {
        trimmed := []
        startIdx := lines.Length - maxLines + 1
        Loop maxLines
            trimmed.Push(lines[startIdx + A_Index - 1])
        lines := trimmed
    }

    return lines
}

GetGoogleSuggestions(query)
{
    suggestions := []
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        url := "https://suggestqueries.google.com/complete/search?client=chrome&q=" . UriEncode(query)
        req.Open("GET", url, false)
        req.SetTimeouts(1500, 1500, 1500, 1500)
        req.Send()

        if (req.Status = 200)
        {
            resp := req.ResponseText
            if RegExMatch(resp, '\["[^"]*",\s*\[(.*?)\]', &m)
            {
                Loop Parse, m[1], ","
                {
                    cleanItem := Trim(A_LoopField, ' "`'')
                    cleanItem := StrReplace(cleanItem, '\"', '"')
                    if (cleanItem != "")
                        suggestions.Push(cleanItem)
                }
            }
        }
    }
    return suggestions
}

OnSuggestionClick(*)
{
    global SuggestionLB, URL_Input, CurrentSuggestions
    if (SuggestionLB.Value > 0 && SuggestionLB.Value <= CurrentSuggestions.Length)
    {
        selectedItem := CurrentSuggestions[SuggestionLB.Value]
        URL_Input.Text := selectedItem
        HideSuggestions()
        Navigate()
    }
}

HideSuggestions()
{
    global SuggestionGui
    if (SuggestionGui)
        SuggestionGui.Hide()
}

IsSuggestionVisible()
{
    global SuggestionGui
    try return DllCall("IsWindowVisible", "Ptr", SuggestionGui.Hwnd)
    return false
}


ShowCookieManager() {
    global CookieGui, CookieLV, DeleteCookieBtn, DeleteAllCookiesBtn, MainGui

    if (CookieGui != "" && WinExist("ahk_id " CookieGui.Hwnd)) {
        WinActivate("ahk_id " CookieGui.Hwnd)
        return
    }

    CookieGui := Gui("+Owner" MainGui.Hwnd " +ToolWindow", "Cookie Manager")
    CookieGui.Add("Text", "x10 y10 w580", "Select cookie(s) using the check boxes below:")

    CookieLV := CookieGui.Add("ListView", "x10 y30 w580 h310 +Checked -Multi", ["Domain", "Name", "Value", "Path"])
    CookieLV.ModifyCol(1, 150)
    CookieLV.ModifyCol(2, 130)
    CookieLV.ModifyCol(3, 180)
    CookieLV.ModifyCol(4, 100)

    CookieLV.OnEvent("ItemCheck", (*) => UpdateCookieBtnStates())

    DeleteCookieBtn := CookieGui.Add("Button", "x10 y355 w120 h28 Disabled", "Delete Cookie")
    DeleteCookieBtn.OnEvent("Click", DeleteSelectedCookies)

    DeleteAllCookiesBtn := CookieGui.Add("Button", "x140 y355 w140 h28 Disabled", "Delete All Cookies")
    DeleteAllCookiesBtn.OnEvent("Click", DeleteAllCookies)

    ApplyGuiTheme(CookieGui)
    CookieGui.Show("w600 h395")
    LoadCookiesList()
}

LoadCookiesList() {
    global CookieLV, CookieObjects
    if (!CookieLV)
        return

    CookieLV.Delete()
    CookieObjects := []

    WB := GetActiveWB()
    if (!WB || !HasProp(WB, "CookieManager") || !WB.CookieManager) {
        UpdateCookieBtnStates()
        return
    }

    try {
        cm := WB.CookieManager
        if (cm) {
            cookieList := cm.GetCookiesAsync("").await()
            if (cookieList) {
                Loop cookieList.Count {
                    cookie := cookieList.GetValueAtIndex(A_Index - 1)
                    CookieObjects.Push(cookie)
                    CookieLV.Add("", cookie.Domain, cookie.Name, cookie.Value, cookie.Path)
                }
            }
        }
    } catch as err {
    }

    UpdateCookieBtnStates()
}

UpdateCookieBtnStates() {
    global CookieLV, DeleteCookieBtn, DeleteAllCookiesBtn
    if (!CookieLV)
        return

    checkedCount := 0
    row := 0
    while (row := CookieLV.GetNext(row, "Checked")) {
        checkedCount++
    }

    hasCookies := (CookieLV.GetCount() > 0)

    DeleteCookieBtn.Enabled := (checkedCount > 0)
    DeleteAllCookiesBtn.Enabled := hasCookies

    DeleteCookieBtn.Text := (checkedCount > 1) ? "Delete Cookies" : "Delete Cookie"
}

DeleteSelectedCookies(*) {
    global CookieLV, CookieObjects
    WB := GetActiveWB()
    if (!WB || !WB.CookieManager)
        return

    checkedRows := []
    row := 0
    while (row := CookieLV.GetNext(row, "Checked")) {
        checkedRows.Push(row)
    }

    if (checkedRows.Length = 0)
        return

    try {
        cm := WB.CookieManager
        for r in checkedRows {
            if (r <= CookieObjects.Length) {
                cm.DeleteCookie(CookieObjects[r])
            }
        }
    }

    LoadCookiesList()
}

DeleteAllCookies(*) {
    WB := GetActiveWB()
    if (!WB || !WB.CookieManager)
        return

    Result := MsgBox("Are you sure you want to delete all cookies?", "Delete All Cookies", "YesNo Icon!")
    if (Result = "No")
        return

    try {
        WB.CookieManager.DeleteAllCookies()
    }

    LoadCookiesList()
}

IsHexDark(hex)
{
    hex := StrReplace(hex, "#", "")
    if (StrLen(hex) != 6)
        return true
    r := Integer("0x" . SubStr(hex, 1, 2))
    g := Integer("0x" . SubStr(hex, 3, 2))
    b := Integer("0x" . SubStr(hex, 5, 2))
    return (0.299 * r + 0.587 * g + 0.114 * b) < 128
}

GetAutoTextColor(bgHex)
{
    return IsHexDark(bgHex) ? "FFFFFF" : "000000"
}

HexToColorRef(hex)
{
    hex := StrReplace(hex, "#", "")
    r := Integer("0x" . SubStr(hex, 1, 2))
    g := Integer("0x" . SubStr(hex, 3, 2))
    b := Integer("0x" . SubStr(hex, 5, 2))
    return (b << 16) | (g << 8) | r
}

LightenHex(hex, amt)
{
    hex := StrReplace(hex, "#", "")
    r := Integer("0x" . SubStr(hex, 1, 2)) + amt
    g := Integer("0x" . SubStr(hex, 3, 2)) + amt
    b := Integer("0x" . SubStr(hex, 5, 2)) + amt
    r := r > 255 ? 255 : (r < 0 ? 0 : r)
    g := g > 255 ? 255 : (g < 0 ? 0 : g)
    b := b > 255 ? 255 : (b < 0 ? 0 : b)
    return Format("{:02X}{:02X}{:02X}", r, g, b)
}

DarkenHex(hex, amt) => LightenHex(hex, -amt)

ComputeThemeColors(themeName)
{
    global CustomThemeBg, CustomThemeText, CustomThemeBtn, CustomThemeCtrlBg

    isDark := true
    bgHex := "1E1E1E"

    if (themeName = "Light")
    {
        isDark := false
        bgHex     := "F3F3F3"
        textHex   := "000000"
        btnHex    := "FFFFFF"
        ctrlBgHex := "FFFFFF"
    }
    else if (themeName = "Midnight Blue")
    {
        isDark := true
        bgHex     := "0F172A"
        textHex   := "FFFFFF"
        btnHex    := "1E3A8A"
        ctrlBgHex := "1E293B"
    }
    else if (themeName = "Gothic Dark")
    {
        isDark := true
        bgHex     := "121212"
        textHex   := "FFFFFF"
        btnHex    := "000000"
        ctrlBgHex := "000000"
    }
    else if (themeName = "Dracula")
    {
        isDark := true
        bgHex     := "282A36"
        textHex   := "F8F8F2"
        btnHex    := "6272A4"
        ctrlBgHex := "44475A"
    }
    else if (themeName = "Cyberpunk")
    {
        isDark := true
        bgHex     := "120458"
        textHex   := "FFFFFF"
        btnHex    := "9D00FF"
        ctrlBgHex := "2C0070"
    }
    else if (themeName = "Emerald Forest")
    {
        isDark := true
        bgHex     := "0B2B26"
        textHex   := "E8F1F2"
        btnHex    := "1E5E52"
        ctrlBgHex := "164A41"
    }
    else if (themeName = "Nord")
    {
        isDark := true
        bgHex     := "2E3440"
        textHex   := "ECEFF4"
        btnHex    := "4C566A"
        ctrlBgHex := "3B4252"
    }
    else if (themeName = "Custom")
    {
        bgHex     := StrReplace(CustomThemeBg, "#", "")
        textHex   := StrReplace(CustomThemeText, "#", "")
        btnHex    := StrReplace(CustomThemeBtn, "#", "")
        ctrlBgHex := StrReplace(CustomThemeCtrlBg, "#", "")
        isDark    := IsHexDark(bgHex)
    }

    else
    {
        isDark := true
        bgHex     := "1E1E1E"
        textHex   := "FFFFFF"
        btnHex    := "333333"
        ctrlBgHex := "2B2B2B"
    }

    return { bg: bgHex, text: textHex, btn: btnHex, ctrlBg: ctrlBgHex, isDark: isDark }
}

RebuildThemeBrushes()
{
    global HBRUSH_BG, HBRUSH_BTN, HBRUSH_CTRL
    global CurrentThemeBg, CurrentThemeBtn, CurrentThemeCtrlBg

    if (HBRUSH_BG)
        DllCall("gdi32\DeleteObject", "Ptr", HBRUSH_BG)
    if (HBRUSH_BTN)
        DllCall("gdi32\DeleteObject", "Ptr", HBRUSH_BTN)
    if (HBRUSH_CTRL)
        DllCall("gdi32\DeleteObject", "Ptr", HBRUSH_CTRL)

    HBRUSH_BG   := DllCall("gdi32\CreateSolidBrush", "UInt", HexToColorRef(CurrentThemeBg), "Ptr")
    HBRUSH_BTN  := DllCall("gdi32\CreateSolidBrush", "UInt", HexToColorRef(CurrentThemeBtn), "Ptr")
    HBRUSH_CTRL := DllCall("gdi32\CreateSolidBrush", "UInt", HexToColorRef(CurrentThemeCtrlBg), "Ptr")
}

ThemeListView(lvHwnd)
{
    global CurrentThemeCtrlBg, CurrentThemeText

    ctrlBgRef := HexToColorRef(CurrentThemeCtrlBg)
    textRef   := HexToColorRef(CurrentThemeText)

    try DllCall("uxtheme\SetWindowTheme", "Ptr", lvHwnd, "Str", "", "Str", "")

    try {
        headerHwnd := SendMessage(0x101F, 0, 0,, "ahk_id " lvHwnd)
        if (headerHwnd)
        {
            try DllCall("uxtheme\SetWindowTheme", "Ptr", headerHwnd, "Str", "", "Str", "")
            try WinRedraw("ahk_id " . headerHwnd)
        }
    }

    SendMessage(0x1001, 0, ctrlBgRef,, "ahk_id " lvHwnd)
    SendMessage(0x1026, 0, ctrlBgRef,, "ahk_id " lvHwnd)
    SendMessage(0x1024, 0, textRef,, "ahk_id " lvHwnd)

    try WinRedraw("ahk_id " . lvHwnd)
}

AddThemedGroupBox(guiObj, options, title, textWidth := 200)
{
    global CurrentThemeBg, CurrentThemeText, CurrentGuiFontName

    group := guiObj.Add("GroupBox", options)

    if RegExMatch(options, "x(\d+)", &mx)
        x := Integer(mx[1])
    else
        x := 15

    if RegExMatch(options, "y(\d+)", &my)
        y := Integer(my[1])
    else
        y := 15

    titleCtrl := guiObj.Add(
        "Text",
        "x" . (x + 10) . " y" . (y - 7) .
        " w" . textWidth . " h20 +Background" . CurrentThemeBg,
        title
    )

    titleCtrl.SetFont("c" . CurrentThemeText, CurrentGuiFontName)

    return group
}

ThemeAllControls(guiObj)
{
    global CurrentThemeIsDark, CurrentThemeCtrlBg, CurrentThemeText, CurrentThemeBg, CurrentThemeBtn
    global IconCtrlHwnds, CurrentGuiFontName

    for hwnd, ctrl in guiObj
    {
        cls := Type(ctrl)

        if (IconCtrlHwnds.Has(ctrl.Hwnd))
        {
            try ctrl.SetFont("c" . CurrentThemeText)
        }
        else
        {
            try ctrl.SetFont("c" . CurrentThemeText, CurrentGuiFontName)
        }

        if (cls = "Gui.Edit" || cls = "Gui.ComboBox" || cls = "Gui.DropDownList" || cls = "Gui.ListBox")
        {
            try ctrl.Opt("Background" . CurrentThemeCtrlBg)
            try DllCall(
                "uxtheme\SetWindowTheme",
                "Ptr", ctrl.Hwnd,
                "Str", CurrentThemeIsDark ? "DarkMode_CFD" : "",
                "Ptr", 0
            )
        }
        else if (cls = "Gui.GroupBox")
        {

            try ctrl.Opt("-Theme +Background" . CurrentThemeBg)
            try DllCall(
                "uxtheme\SetWindowTheme",
                "Ptr", ctrl.Hwnd,
                "Ptr", 0,
                "Ptr", 0
            )

            try ctrl.SetFont("c" . CurrentThemeText, CurrentGuiFontName)

            try DllCall(
                "user32\InvalidateRect",
                "Ptr", ctrl.Hwnd,
                "Ptr", 0,
                "Int", 1
            )

            try ctrl.Redraw()
        }
        else if (cls = "Gui.Button")
        {
            try ctrl.Opt("-Theme +Background" . CurrentThemeBtn)
            try DllCall(
                "uxtheme\SetWindowTheme",
                "Ptr", ctrl.Hwnd,
                "Ptr", 0,
                "Ptr", 0
            )
        }
		else if (cls = "Gui.CheckBox" || cls = "Gui.Radio")
		{
			checkboxTextColor := GetAutoTextColor(CurrentThemeBg)

			try ctrl.Opt("-Theme +Background" . CurrentThemeBg)

			try DllCall(
				"uxtheme\SetWindowTheme",
				"Ptr", ctrl.Hwnd,
				"Ptr", 0,
				"Ptr", 0
			)

			try ctrl.SetFont(
				"c" . checkboxTextColor,
				CurrentGuiFontName
			)

			try DllCall(
				"user32\InvalidateRect",
				"Ptr", ctrl.Hwnd,
				"Ptr", 0,
				"Int", 1
			)

			try ctrl.Redraw()
		}
        else if (cls = "Gui.Tab3" || cls = "Gui.Tab")
        {
            ApplyTabBarTheme(ctrl.Hwnd)
        }
        else if (cls = "Gui.ListView")
        {
            ThemeListView(ctrl.Hwnd)
        }
        else if (cls = "Gui.Text")
        {
            try ctrl.Opt("BackgroundTrans")
        }

        try DllCall(
            "user32\InvalidateRect",
            "Ptr", ctrl.Hwnd,
            "Ptr", 0,
            "Int", 1
        )

        try ctrl.Redraw()
    }
}
WM_DRAWITEM(wParam, lParam, msg, hwnd)
{
    global CurrentThemeText, HBRUSH_BTN, HBRUSH_BG, CurrentThemeIsDark, CurrentThemeBg

    ctlType := NumGet(lParam, 0, "UInt")

    if (ctlType = 4)
    {
        hwndItem := NumGet(lParam, A_PtrSize = 8 ? 24 : 20, "Ptr")
        hDC      := NumGet(lParam, A_PtrSize = 8 ? 32 : 24, "Ptr")

        style := DllCall("user32\GetWindowLongPtr"
            , "Ptr", hwndItem
            , "Int", -16
            , "Ptr")

        if ((style & 0x0F) = 0x07)
        {
            offRC := A_PtrSize = 8 ? 40 : 28

            rLeft   := NumGet(lParam, offRC, "Int")
            rTop    := NumGet(lParam, offRC + 4, "Int")
            rRight  := NumGet(lParam, offRC + 8, "Int")
            rBottom := NumGet(lParam, offRC + 12, "Int")

            textLen := DllCall("user32\GetWindowTextLength", "Ptr", hwndItem, "Int")
            textBuf := Buffer((textLen + 1) * 2, 0)

            DllCall("user32\GetWindowText"
                , "Ptr", hwndItem
                , "Ptr", textBuf
                , "Int", textLen + 1)

            groupText := StrGet(textBuf, "UTF-16")

            bgBrush := DllCall(
                "gdi32\CreateSolidBrush",
                "UInt", HexToColorRef(CurrentThemeBg),
                "Ptr"
            )

            if (bgBrush)
            {
                bgRect := Buffer(16, 0)
                NumPut("Int", rLeft,   bgRect, 0)
                NumPut("Int", rTop,    bgRect, 4)
                NumPut("Int", rRight,  bgRect, 8)
                NumPut("Int", rBottom, bgRect, 12)

                DllCall("user32\FillRect"
                    , "Ptr", hDC
                    , "Ptr", bgRect
                    , "Ptr", bgBrush)

                DllCall("gdi32\DeleteObject", "Ptr", bgBrush)
            }

            borderColor := CurrentThemeIsDark ? "666666" : "999999"

            borderPen := DllCall(
                "gdi32\CreatePen",
                "Int", 0,
                "Int", 1,
                "UInt", HexToColorRef(borderColor),
                "Ptr"
            )

            if (borderPen)
            {
                oldPen := DllCall(
                    "gdi32\SelectObject",
                    "Ptr", hDC,
                    "Ptr", borderPen,
                    "Ptr"
                )

                oldBrush := DllCall(
                    "gdi32\SelectObject",
                    "Ptr", hDC,
                    "Ptr", DllCall("gdi32\GetStockObject", "Int", 5, "Ptr"),
                    "Ptr"
                )

                textSize := Buffer(8, 0)

                hFont := SendMessage(0x0031, 0, 0,, "ahk_id " hwndItem)
                oldFont := 0

                if (hFont)
                    oldFont := DllCall(
                        "gdi32\SelectObject",
                        "Ptr", hDC,
                        "Ptr", hFont,
                        "Ptr"
                    )

                DllCall(
                    "user32\GetTextExtentPoint32W",
                    "Ptr", hDC,
                    "Str", groupText,
                    "Int", StrLen(groupText),
                    "Ptr", textSize
                )

                textWidth := NumGet(textSize, 0, "Int")

                textX := rLeft + 10
                textY := rTop

                borderY := rTop + 7

                DllCall(
                    "gdi32\MoveToEx",
                    "Ptr", hDC,
                    "Int", rLeft,
                    "Int", borderY,
                    "Ptr", 0
                )

                DllCall(
                    "gdi32\LineTo",
                    "Ptr", hDC,
                    "Int", textX - 3,
                    "Int", borderY
                )

                DllCall(
                    "gdi32\MoveToEx",
                    "Ptr", hDC,
                    "Int", textX + textWidth + 7,
                    "Int", borderY,
                    "Ptr", 0
                )

                DllCall(
                    "gdi32\LineTo",
                    "Ptr", hDC,
                    "Int", rRight,
                    "Int", borderY
                )

                DllCall(
                    "gdi32\MoveToEx",
                    "Ptr", hDC,
                    "Int", rLeft,
                    "Int", borderY,
                    "Ptr", 0
                )

                DllCall(
                    "gdi32\LineTo",
                    "Ptr", hDC,
                    "Int", rLeft,
                    "Int", rBottom
                )

                DllCall(
                    "gdi32\MoveToEx",
                    "Ptr", hDC,
                    "Int", rRight - 1,
                    "Int", borderY,
                    "Ptr", 0
                )

                DllCall(
                    "gdi32\LineTo",
                    "Ptr", hDC,
                    "Int", rRight - 1,
                    "Int", rBottom
                )

                DllCall(
                    "gdi32\MoveToEx",
                    "Ptr", hDC,
                    "Int", rLeft,
                    "Int", rBottom - 1,
                    "Ptr", 0
                )

                DllCall(
                    "gdi32\LineTo",
                    "Ptr", hDC,
                    "Int", rRight,
                    "Int", rBottom - 1
                )

                DllCall(
                    "gdi32\SetTextColor",
                    "Ptr", hDC,
                    "UInt", HexToColorRef(CurrentThemeText)
                )

                DllCall(
                    "gdi32\SetBkColor",
                    "Ptr", hDC,
                    "UInt", HexToColorRef(CurrentThemeBg)
                )

                DllCall(
                    "gdi32\SetBkMode",
                    "Ptr", hDC,
                    "Int", 1
                )

                captionRect := Buffer(16, 0)
                NumPut("Int", textX,             captionRect, 0)
                NumPut("Int", rTop + 1,         captionRect, 4)
                NumPut("Int", textX + textWidth + 8, captionRect, 8)
                NumPut("Int", rTop + 20,        captionRect, 12)

                DllCall(
                    "user32\DrawTextW",
                    "Ptr", hDC,
                    "Str", groupText,
                    "Int", -1,
                    "Ptr", captionRect,
                    "UInt", 0x0000
                )

                if (oldFont)
                    DllCall(
                        "gdi32\SelectObject",
                        "Ptr", hDC,
                        "Ptr", oldFont
                    )

                if (oldBrush)
                    DllCall(
                        "gdi32\SelectObject",
                        "Ptr", hDC,
                        "Ptr", oldBrush
                    )

                if (oldPen)
                    DllCall(
                        "gdi32\SelectObject",
                        "Ptr", hDC,
                        "Ptr", oldPen
                    )

                DllCall("gdi32\DeleteObject", "Ptr", borderPen)
            }

            return 1
        }
    }

    if (ctlType != 101)
        return

    hwndItem  := NumGet(lParam, A_PtrSize = 8 ? 24 : 20, "Ptr")
    hDC       := NumGet(lParam, A_PtrSize = 8 ? 32 : 24, "Ptr")
    itemIdx   := NumGet(lParam, 8, "UInt")
    itemState := NumGet(lParam, 16, "UInt")

    offRC   := A_PtrSize = 8 ? 40 : 28
    rLeft   := NumGet(lParam, offRC, "Int")
    rTop    := NumGet(lParam, offRC + 4, "Int")
    rRight  := NumGet(lParam, offRC + 8, "Int")
    rBottom := NumGet(lParam, offRC + 12, "Int")

    isSelected := (itemState & 1)

    fillBrush := isSelected ? HBRUSH_BTN : HBRUSH_BG

    rect := Buffer(16, 0)
    NumPut("Int", rLeft, rect, 0)
    NumPut("Int", rTop + 2, rect, 4)
    NumPut("Int", rRight, rect, 8)
    NumPut("Int", rBottom - 2, rect, 12)

    DllCall("user32\FillRect", "Ptr", hDC, "Ptr", rect, "Ptr", fillBrush)

    if (isSelected)
    {
        sepHex := CurrentThemeIsDark ? "3A3A3A" : "CCCCCC"

        sepBrush := DllCall(
            "gdi32\CreateSolidBrush",
            "UInt", HexToColorRef(sepHex),
            "Ptr"
        )

        if (sepBrush)
        {
            DllCall(
                "user32\FrameRect",
                "Ptr", hDC,
                "Ptr", rect,
                "Ptr", sepBrush
            )

            DllCall("gdi32\DeleteObject", "Ptr", sepBrush)
        }
    }

    tcItem := Buffer(A_PtrSize = 8 ? 40 : 28, 0)
    textBuf := Buffer(256, 0)

    NumPut("UInt", 0x0001, tcItem, 0)
    NumPut("Ptr", textBuf.Ptr, tcItem, A_PtrSize = 8 ? 16 : 12)
    NumPut("Int", 256, tcItem, A_PtrSize = 8 ? 24 : 16)

    SendMessage(
        0x133C,
        itemIdx,
        tcItem.Ptr,
        ,
        "ahk_id " hwndItem
    )

    tabText := StrGet(textBuf)

    DllCall("gdi32\SetBkMode", "Ptr", hDC, "Int", 1)

    DllCall(
        "gdi32\SetTextColor",
        "Ptr", hDC,
        "UInt", HexToColorRef(CurrentThemeText)
    )

    hFont := SendMessage(0x0031, 0, 0,, "ahk_id " hwndItem)

    oldFont := (hFont != 0)
        ? DllCall(
            "gdi32\SelectObject",
            "Ptr", hDC,
            "Ptr", hFont,
            "Ptr"
        )
        : 0

    if InStr(tabText, "+")
    {
        yOffset := 3
        NumPut(
            "Int",
            NumGet(rect, 4, "Int") + yOffset,
            rect,
            4
        )
    }

    DllCall(
        "user32\DrawText",
        "Ptr", hDC,
        "Str", tabText,
        "Int", -1,
        "Ptr", rect,
        "UInt", 0x25
    )

    if (oldFont)
        DllCall(
            "gdi32\SelectObject",
            "Ptr", hDC,
            "Ptr", oldFont
        )

    return 1
}

WM_ERASEBKGND(wParam, lParam, msg, hwnd)
{
    global TabBar, HBRUSH_BG
    if (!HBRUSH_BG)
        return

    try cls := WinGetClass("ahk_id " . hwnd)
    catch
        return

    if (hwnd == (TabBar ? TabBar.Hwnd : 0) || cls = "SysTabControl32" || cls = "#32770")
    {
        rect := Buffer(16, 0)
        DllCall("user32\GetClientRect", "Ptr", hwnd, "Ptr", rect)
        DllCall("user32\FillRect", "Ptr", wParam, "Ptr", rect, "Ptr", HBRUSH_BG)
        return 1
    }
}

WM_NOTIFY(wParam, lParam, msg, hwnd)
{
    global CurrentThemeText, CurrentThemeCtrlBg, CurrentThemeBg

    code := NumGet(lParam, A_PtrSize = 8 ? 16 : 8, "Int")

    if (code = -12)
    {
        hwndFrom := NumGet(lParam, 0, "Ptr")
        cls := WinGetClass("ahk_id " . hwndFrom)

        if (cls = "SysListView32" || cls = "SysHeader32")
        {
            dwDrawStage := NumGet(lParam, A_PtrSize = 8 ? 24 : 12, "UInt")

            if (dwDrawStage = 1)
                return 0x20

            if (dwDrawStage = 0x00010001)
            {
                hDC := NumGet(lParam, A_PtrSize = 8 ? 32 : 16, "Ptr")
                bgColor := (cls = "SysHeader32") ? CurrentThemeBg : CurrentThemeCtrlBg

                DllCall("gdi32\SetTextColor", "Ptr", hDC, "UInt", HexToColorRef(CurrentThemeText))
                DllCall("gdi32\SetBkColor", "Ptr", hDC, "UInt", HexToColorRef(bgColor))
                DllCall("gdi32\SetBkMode", "Ptr", hDC, "Int", 1)

                if (cls = "SysListView32")
                {
                    offText := A_PtrSize = 8 ? 80 : 48
                    offTextBk := A_PtrSize = 8 ? 88 : 52
                    NumPut("UInt", HexToColorRef(CurrentThemeText), lParam, offText)
                    NumPut("UInt", HexToColorRef(CurrentThemeCtrlBg), lParam, offTextBk)
                }

                return 0x00000000
            }
        }
    }
}


WM_CTLCOLORDLG(wParam, lParam, msg, hwnd)
{
    global CurrentThemeBg, CurrentThemeText, HBRUSH_BG
    DllCall("SetTextColor", "Ptr", wParam, "UInt", HexToColorRef(CurrentThemeText))
    DllCall("SetBkColor", "Ptr", wParam, "UInt", HexToColorRef(CurrentThemeBg))
    return HBRUSH_BG
}

WM_CTLCOLOREDIT(wParam, lParam, msg, hwnd)
{
    global CurrentThemeCtrlBg, CurrentThemeText, HBRUSH_CTRL
    DllCall("SetTextColor", "Ptr", wParam, "UInt", HexToColorRef(CurrentThemeText))
    DllCall("SetBkColor", "Ptr", wParam, "UInt", HexToColorRef(CurrentThemeCtrlBg))
    return HBRUSH_CTRL
}

WM_CTLCOLORLISTBOX(wParam, lParam, msg, hwnd)
{
    global CurrentThemeCtrlBg, CurrentThemeText, HBRUSH_CTRL
    DllCall("SetTextColor", "Ptr", wParam, "UInt", HexToColorRef(CurrentThemeText))
    DllCall("SetBkColor", "Ptr", wParam, "UInt", HexToColorRef(CurrentThemeCtrlBg))
    return HBRUSH_CTRL
}

WM_CTLCOLORBTN(wParam, lParam, msg, hwnd)
{
    global CurrentThemeBtn, CurrentThemeBg, CurrentThemeText
    global HBRUSH_BTN, HBRUSH_BG

    style := 0

    try style := DllCall(
        "user32\GetWindowLongPtr",
        "Ptr", lParam,
        "Int", -16,
        "Ptr"
    )

    buttonType := style & 0xF

    if (buttonType = 2 || buttonType = 3 || buttonType = 4 || buttonType = 9)
    {
        checkboxTextColor := GetAutoTextColor(CurrentThemeBg)

        DllCall(
            "gdi32\SetTextColor",
            "Ptr", wParam,
            "UInt", HexToColorRef(checkboxTextColor)
        )

        DllCall(
            "gdi32\SetBkColor",
            "Ptr", wParam,
            "UInt", HexToColorRef(CurrentThemeBg)
        )

        DllCall(
            "gdi32\SetBkMode",
            "Ptr", wParam,
            "Int", 1
        )

        return HBRUSH_BG
    }

    DllCall(
        "gdi32\SetTextColor",
        "Ptr", wParam,
        "UInt", HexToColorRef(CurrentThemeText)
    )

    DllCall(
        "gdi32\SetBkColor",
        "Ptr", wParam,
        "UInt", HexToColorRef(CurrentThemeBtn)
    )

    DllCall(
        "gdi32\SetBkMode",
        "Ptr", wParam,
        "Int", 1
    )

    return HBRUSH_BTN
}

WM_CTLCOLORSTATIC(wParam, lParam, msg, hwnd)
{
    global CurrentThemeBg, CurrentThemeText, HBRUSH_BG, ActiveHoverHwnd, HBRUSH_HOVER, CurrentThemeIsDark

    if (ActiveHoverHwnd && hwnd == ActiveHoverHwnd && HBRUSH_HOVER)
    {
        DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", HexToColorRef(CurrentThemeText))
        DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", HexToColorRef(CurrentThemeIsDark ? "3A3A3A" : "E5E5E5"))
        DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", 2)
        return HBRUSH_HOVER
    }

    DllCall("SetTextColor", "Ptr", wParam, "UInt", HexToColorRef(CurrentThemeText))
    DllCall("SetBkMode", "Ptr", wParam, "Int", 1)
    return HBRUSH_BG
}

InitProcessDarkMode()
{
    static initialized := false
    if (initialized)
        return
    initialized := true
    try DllCall("uxtheme\SetPreferredAppMode", "Int", 2)
    catch
        try DllCall("uxtheme\" . 135, "Int", 2)
}

ApplyGuiTheme(guiObj, themeName := "")
{
    global AppTheme
    global CurrentThemeBg, CurrentThemeText, CurrentThemeBtn, CurrentThemeCtrlBg, CurrentThemeIsDark

    InitProcessDarkMode()

    if (themeName = "")
        themeName := AppTheme

	if (IsSet(TabSeparator) && TabSeparator)
		TabSeparator.Opt("Background" . (CurrentThemeIsDark ? "3A3A3A" : "CCCCCC"))

    colors := ComputeThemeColors(themeName)
    CurrentThemeBg     := colors.bg
    CurrentThemeText   := colors.text
    CurrentThemeBtn    := colors.btn
    CurrentThemeCtrlBg := colors.ctrlBg
    CurrentThemeIsDark := colors.isDark

    RebuildThemeBrushes()

    try DllCall("uxtheme\AllowDarkModeForWindow", "Ptr", guiObj.Hwnd, "Int", colors.isDark)
    catch
        try DllCall("uxtheme\" . 133, "Ptr", guiObj.Hwnd, "Int", colors.isDark)

    darkModeVal := Buffer(4, 0)
    NumPut("Int", colors.isDark ? 1 : 0, darkModeVal)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", guiObj.Hwnd, "Int", 20, "Ptr", darkModeVal, "Int", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", guiObj.Hwnd, "Int", 19, "Ptr", darkModeVal, "Int", 4)

    guiObj.BackColor := colors.bg
    guiObj.SetFont("c" . colors.text)

    ThemeAllControls(guiObj)

    try WinRedraw("ahk_id " . guiObj.Hwnd)
}

ApplyCustomTheme(bgHex, textHex, btnHex, ctrlBgHex, persist := false)
{
    global CurrentThemeBg, CurrentThemeText, CurrentThemeBtn, CurrentThemeCtrlBg, CurrentThemeIsDark
    global CustomThemeBg, CustomThemeText, CustomThemeBtn, CustomThemeCtrlBg
    global AppTheme, ConfigFile, MainGui

    CurrentThemeBg     := StrReplace(bgHex, "#", "")
    CurrentThemeText   := StrReplace(textHex, "#", "")
    CurrentThemeBtn    := StrReplace(btnHex, "#", "")
    CurrentThemeCtrlBg := StrReplace(ctrlBgHex, "#", "")
    CurrentThemeIsDark := IsHexDark(CurrentThemeBg)

    RebuildThemeBrushes()

    if (IsSet(MainGui))
    {
        try
        {
            darkModeVal := Buffer(4, 0)
            NumPut("Int", CurrentThemeIsDark ? 1 : 0, darkModeVal)
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", MainGui.Hwnd, "Int", 20, "Ptr", darkModeVal, "Int", 4)
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", MainGui.Hwnd, "Int", 19, "Ptr", darkModeVal, "Int", 4)
            MainGui.BackColor := CurrentThemeBg
            MainGui.SetFont("c" . CurrentThemeText)
            ThemeAllControls(MainGui)
            WinRedraw("ahk_id " . MainGui.Hwnd)
        }
    }

    if (persist)
    {
        CustomThemeBg     := CurrentThemeBg
        CustomThemeText   := CurrentThemeText
        CustomThemeBtn    := CurrentThemeBtn
        CustomThemeCtrlBg := CurrentThemeCtrlBg
        AppTheme          := "Custom"

        IniWrite("#" . CustomThemeBg,     ConfigFile, "Appearance", "CustomThemeBg")
        IniWrite("#" . CustomThemeText,   ConfigFile, "Appearance", "CustomThemeText")
        IniWrite("#" . CustomThemeBtn,    ConfigFile, "Appearance", "CustomThemeBtn")
        IniWrite("#" . CustomThemeCtrlBg, ConfigFile, "Appearance", "CustomThemeCtrlBg")
        IniWrite(AppTheme, ConfigFile, "Appearance", "Theme")
    }
}

RevertLiveTheme()
{
    global MainGui
    try ApplyGuiTheme(MainGui)
}

ApplyCustomFont(fontName, persist := false)
{
    global CurrentGuiFontName, CurrentGuiFontFile, ConfigFile, MainGui

    if (fontName = "")
        return

    CurrentGuiFontName := fontName

    if (IsSet(MainGui))
    {
        try
        {
            ThemeAllControls(MainGui)
            WinRedraw("ahk_id " . MainGui.Hwnd)
        }
    }

    if (persist)
    {
        IniWrite(CurrentGuiFontName, ConfigFile, "Appearance", "FontName")
        IniWrite(CurrentGuiFontFile, ConfigFile, "Appearance", "FontFile")
    }
}

ImportFontFile(tabObj)
{
    global CurrentGuiFontFile

    selectedFile := FileSelect(1, , "Select Font File", "Font Files (*.ttf; *.otf)")
    if (selectedFile = "")
        return

    added := DllCall("gdi32\AddFontResourceExW", "Str", selectedFile, "UInt", 0x10, "Ptr", 0)
    if (!added)
    {
        MsgBox("Failed to load that font file. It may be corrupted or unsupported.", "Font Load Error", "Iconx")
        return
    }

    SplitPath(selectedFile, , , , &fontName)

    CurrentGuiFontFile := selectedFile
    ApplyCustomFont(fontName, false)

    js := "if(window.setCustomFontLabel) setCustomFontLabel('" . EscapeJsString(fontName) . "');"
    try tabObj.WB.ExecuteScriptAsync(js)
}

RevertLiveFont()
{
    global MainGui
    try ApplyGuiTheme(MainGui)
}

ImportHtmlIntoEditor(tabObj)
{
    selectedFile := FileSelect(1, , "Import HTML File", "HTML Files (*.html; *.htm)")
    if (selectedFile = "")
        return

    try
    {
        importedHtml := FileRead(selectedFile, "UTF-8")

        escapedHtml := StrReplace(importedHtml, "\", "\\")
        escapedHtml := StrReplace(escapedHtml, "'", "\'")
        escapedHtml := StrReplace(escapedHtml, "`r`n", "\n")
        escapedHtml := StrReplace(escapedHtml, "`n", "\n")
        escapedHtml := StrReplace(escapedHtml, "`r", "\n")
        escapedHtml := StrReplace(escapedHtml, "</script", "<\/script")

        js := "(() => {"
        js .= "try {"
        js .= "  const aceEditor = ace.edit('editorTextarea');"
        js .= "  aceEditor.setValue('" . escapedHtml . "', -1);"
        js .= "  aceEditor.clearSelection();"
        js .= "  if (typeof updatePreview === 'function') updatePreview();"
        js .= "} catch (e) {"
        js .= "  console.error('HTML import failed:', e);"
        js .= "}"
        js .= "})();"

        tabObj.WB.ExecuteScriptAsync(js)
    }
    catch as err
    {
        MsgBox("Failed to import HTML file:`n" . err.Message, "Import Error", "Iconx")
    }
}

ChooseColorDialog(initialHex, ownerHwnd)
{
    static customColors := Buffer(4 * 16, 0)

    ccSize := (A_PtrSize = 8) ? 72 : 36
    cc := Buffer(ccSize, 0)

    offHwndOwner := (A_PtrSize = 8) ? 8  : 4
    offRgbResult := (A_PtrSize = 8) ? 24 : 12
    offCustColors := (A_PtrSize = 8) ? 32 : 16
    offFlags     := (A_PtrSize = 8) ? 40 : 20

    NumPut("UInt", ccSize, cc, 0)
    NumPut("Ptr", ownerHwnd, cc, offHwndOwner)
    NumPut("UInt", HexToColorRef(initialHex), cc, offRgbResult)
    NumPut("Ptr", customColors.Ptr, cc, offCustColors)
    NumPut("UInt", 0x1 | 0x2, cc, offFlags)

    try {
        if DllCall("comdlg32\ChooseColor", "Ptr", cc.Ptr, "Int")
        {
            colorRef := NumGet(cc, offRgbResult, "UInt")
            r := colorRef & 0xFF
            g := (colorRef >> 8) & 0xFF
            b := (colorRef >> 16) & 0xFF
            return Format("#{:02X}{:02X}{:02X}", r, g, b)
        }
    }
    return ""
}

WM_NCCALCSIZE(wParam, lParam, msg, hwnd)
{
    global MainGui
    if !(IsSet(MainGui) && hwnd = MainGui.Hwnd)
        return

    if (wParam = 0)
        return 0

    if DllCall("user32\IsZoomed", "Ptr", hwnd, "Int")
    {
        mon := DllCall("user32\MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr")
        mi := Buffer(40, 0)
        NumPut("UInt", 40, mi, 0)
        DllCall("user32\GetMonitorInfo", "Ptr", mon, "Ptr", mi)

        waLeft   := NumGet(mi, 20, "Int")
        waTop    := NumGet(mi, 24, "Int")
        waRight  := NumGet(mi, 28, "Int")
        waBottom := NumGet(mi, 32, "Int")

        NumPut("Int", waLeft,   lParam, 0)
        NumPut("Int", waTop,    lParam, 4)
        NumPut("Int", waRight,  lParam, 8)
        NumPut("Int", waBottom, lParam, 12)
    }

    return 0
}

OpenCustomizationPanel(*)
{
    global MainGui, AppTheme, NewTabBgType, NewTabBgVal, ColorPresetNames, ColorPresetMap

    CustGui := Gui("+Owner" . MainGui.Hwnd . " +ToolWindow", "Customization Panel")
    CustGui.MarginX := 15
    CustGui.MarginY := 15

    if ColorPresetMap.Has(AppTheme) {
        CustGui.BackColor := StrReplace(ColorPresetMap[AppTheme], "#", "")
    }

    CustomColorHex := (NewTabBgVal != "") ? NewTabBgVal : "#2B2B2B"
    StartColorChoice := "Custom..."
    for pName, pHex in ColorPresetMap
    {
        if (pHex = CustomColorHex)
        {
            StartColorChoice := pName
            break
        }
    }

    AddCustomGroupBox(CustGui, 15, 15, 330, 100, "New Tab Page Background")

    CustGui.Add("Text", "x25 y40 w80 h20", "Type:")
    TypeDDL := CustGui.Add("DropDownList", "x110 y37 w215", ["Color", "Image"])
    TypeDDL.Choose(NewTabBgType = "Image" ? "Image" : "Color")

    ValueLabel := CustGui.Add("Text", "x25 y70 w80 h20", "Value:")

    ColorDDL := CustGui.Add("DropDownList", "x110 y67 w215", ColorPresetNames)
    ColorDDL.Choose(StartColorChoice)

    ValEdit := CustGui.Add("Edit", "x110 y67 w140 h22 -Wrap", NewTabBgVal)
    BrowseBtn := CustGui.Add("Button", "x255 y67 w70 h22", "Browse")

    AddCustomGroupBox(CustGui, 15, 125, 330, 65, "Browser Window Theme")

    CustGui.Add("Text", "x25 y150 w80 h20", "Palette:")
    ThemeDDL := CustGui.Add("DropDownList", "x110 y147 w215", ["Light", "Dark", "Midnight Blue", "Gothic Dark", "Dracula", "Cyberpunk", "Emerald Forest", "Nord", "Custom"])
    try ThemeDDL.Choose(AppTheme)

    EditNewTabBtn := CustGui.Add("Button", "x110 y200 w110 h28", "GUI Editor")
    SaveCustBtn   := CustGui.Add("Button", "x225 y200 w110 h28 Default Disabled", "Apply")

    EditNewTabBtn.OnEvent("Click", (*) => (CustGui.Destroy(), OpenNewTabEditor()))
    SaveCustBtn.OnEvent("Click", (*) => SaveCustomization(TypeDDL.Text, ThemeDDL.Text, CustGui))
    BrowseBtn.OnEvent("Click", (*) => (ChooseImageFile(ValEdit), CheckForChanges()))
    ColorDDL.OnEvent("Change", (*) => (OnColorDDLChange(), CheckForChanges()))
    TypeDDL.OnEvent("Change", (*) => (UpdateFieldStates(), CheckForChanges()))
    ThemeDDL.OnEvent("Change", (*) => CheckForChanges())
    ValEdit.OnEvent("Change", (*) => CheckForChanges())

    UpdateFieldStates()
    ApplyGuiTheme(CustGui)
    CustGui.Show()

    UpdateFieldStates()
    {
        isColor := (TypeDDL.Text = "Color")
        ValueLabel.Text := isColor ? "Value:" : "Image Path:"
        ColorDDL.Visible := isColor
        ValEdit.Visible := !isColor
        BrowseBtn.Visible := !isColor
    }

    CheckForChanges(*)
    {
        currentType := TypeDDL.Text
        currentVal := (currentType = "Color") ? CustomColorHex : Trim(ValEdit.Text)
        currentTheme := ThemeDDL.Text

        hasChanged := (currentType != NewTabBgType)
                   || (currentVal != NewTabBgVal)
                   || (currentTheme != AppTheme)

        SaveCustBtn.Enabled := hasChanged
    }

    OnColorDDLChange()
    {
        if (ColorDDL.Text = "Custom...")
        {
            picked := ChooseColorDialog(CustomColorHex, CustGui.Hwnd)
            if (picked != "")
                CustomColorHex := picked
        }
        else if ColorPresetMap.Has(ColorDDL.Text)
        {
            CustomColorHex := ColorPresetMap[ColorDDL.Text]
        }
    }

    ChooseImageFile(editCtrl)
    {
        selectedFile := FileSelect(1, , "Select Background Image", "Image Files (*.jpg; *.jpeg; *.png; *.bmp)")
        if (selectedFile != "")
            editCtrl.Text := selectedFile
    }

    SaveCustomization(newType, newTheme, guiObj)
    {
        global NewTabBgType, NewTabBgVal, AppTheme, MainGui

        NewTabBgType := newType
        NewTabBgVal  := (newType = "Color") ? CustomColorHex : Trim(ValEdit.Text)
        AppTheme     := newTheme

        GenerateNewTabPage(true)
        SaveSettingsToIni()

        hwnds := WinGetList("ahk_pid " ProcessExist())
        for hwnd in hwnds
        {
            try
            {
                if (winGui := GuiFromHwnd(hwnd))
                {
                    ApplyGuiTheme(winGui)
                }
            }
        }

        guiObj.Destroy()
        GReload()
    }
}

OpenPerformancePanel(*)
{
    global ConfigFile
    global EnableSuspendTabs, ExtraCmdFlags
    global MainGui, AppTheme, ColorPresetMap
    global CurrentThemeBg, CurrentGuiFontName
    global SuspendChk, CmdFlagsChk, FlagsEdit, SavePerfBtn

    cleanTextColor := GetAutoTextColor(CurrentThemeBg)

    PerfGui := Gui("+Owner" . MainGui.Hwnd . " +ToolWindow", "Performance Settings")
    PerfGui.MarginX := 15
    PerfGui.MarginY := 15
    PerfGui.SetFont("c" . cleanTextColor)

    if ColorPresetMap.Has(AppTheme)
        PerfGui.BackColor := StrReplace(ColorPresetMap[AppTheme], "#", "")

    currSuspend := (
        IniRead(
            ConfigFile,
            "Performance",
            "SuspendTabs",
            EnableSuspendTabs ? "1" : "0"
        ) == "1"
    )

    currFlags := IniRead(
        ConfigFile,
        "Performance",
        "CmdFlags",
        ExtraCmdFlags
    )

    flagsActive := (
        IniRead(
            ConfigFile,
            "Performance",
            "UseCmdFlags",
            "1"
        ) == "1"
    )

    AddCustomGroupBox(
        PerfGui,
        15, 15, 320, 130,
        "Performance Options"
    )

	SuspendChk := AddThemedCheckbox(
		PerfGui,
		25, 38, 300,
		currSuspend,
		"Tab Suspension"
	)

	CmdFlagsChk := AddThemedCheckbox(
		PerfGui,
		25, 63, 300,
		flagsActive,
		"Chromium Flags"
	)

    FlagsEdit := PerfGui.Add(
        "Edit",
        "x25 y88 w300 h24 "
        . (flagsActive ? "" : "Disabled"),
        currFlags
    )

    SavePerfBtn := PerfGui.Add(
        "Button",
        "x115 y158 w120 h30 Default Disabled",
        "Apply"
    )

    CheckForChanges(*)
    {
        hasChanged := (SuspendChk.Value != Integer(currSuspend))
                   || (CmdFlagsChk.Value != Integer(flagsActive))
                   || (FlagsEdit.Text != currFlags)

        SavePerfBtn.Enabled := hasChanged
    }

    SuspendChk.OnEvent("Click", CheckForChanges)

    CmdFlagsChk.OnEvent(
        "Click",
        (chk, *) => (
            FlagsEdit.Enabled := chk.Value,
            CheckForChanges()
        )
    )

    FlagsEdit.OnEvent("Change", CheckForChanges)

    SavePerfBtn.OnEvent(
        "Click",
        (*) => SavePerformanceSettings()
    )

    SavePerformanceSettings()
    {
        global EnableSuspendTabs, ExtraCmdFlags

        EnableSuspendTabs := SuspendChk.Value

        useFlags := CmdFlagsChk.Value
        savedFlags := Trim(FlagsEdit.Text)

        ExtraCmdFlags := useFlags ? savedFlags : ""

        IniWrite(
            EnableSuspendTabs ? "1" : "0",
            ConfigFile,
            "Performance",
            "SuspendTabs"
        )

        IniWrite(
            useFlags ? "1" : "0",
            ConfigFile,
            "Performance",
            "UseCmdFlags"
        )

        IniWrite(
            savedFlags,
            ConfigFile,
            "Performance",
            "CmdFlags"
        )

        PerfGui.Destroy()
    }

    ApplyGuiTheme(PerfGui)
    PerfGui.Show("w350 h205")
}

CreateNewTabWebView(parentHwnd)
{
    newTab := CreateNewTab()

    return newTab.CoreWebView2
}

SetEditFormattingRect(hwnd, rightPadding := 32) {
    rectBuffer := Buffer(16, 0)

    DllCall("user32\GetClientRect", "Ptr", hwnd, "Ptr", rectBuffer)

    left   := NumGet(rectBuffer, 0, "Int")
    top    := NumGet(rectBuffer, 4, "Int")
    right  := NumGet(rectBuffer, 8, "Int") - rightPadding
    bottom := NumGet(rectBuffer, 12, "Int")

    NumPut("Int", left,   rectBuffer, 0)
    NumPut("Int", top,    rectBuffer, 4)
    NumPut("Int", right,  rectBuffer, 8)
    NumPut("Int", bottom, rectBuffer, 12)

    DllCall("user32\SendMessage", "Ptr", hwnd, "UInt", 0x00B5, "Ptr", 0, "Ptr", rectBuffer)
}

IsMainGuiActive() {
    global MainGui

    if !IsSet(MainGui) || !MainGui
        return false

    try {
        return WinActive("ahk_id " . MainGui.Hwnd)
    } catch {
        return false
    }
}


UrlBarHasFocus() {
    global URL_Input

    if !IsSet(URL_Input) || !URL_Input
        return false

    try {
        return (DllCall("GetFocus", "Ptr") = URL_Input.Hwnd)
    } catch {
        return false
    }
}



#HotIf IsMainGuiActive()

^h::ShowHistory()
^t::GuardedNewTab()
^w::GuardedCloseTab()
^r::ReloadPage()
^l::URL_Input.Focus()
^n::SpawnNewWindow()

#HotIf



SpawnNewWindow() {
    if A_IsCompiled
        Run('"' . A_ScriptFullPath . '"')
    else
        Run('"' . A_AhkPath . '" "' . A_ScriptFullPath . '"')
}



GuardedNewTab(*) {
    global EditorModeActive

    if !EditorModeActive
        CreateNewTab()
}


GuardedCloseTab(*) {
    global EditorModeActive, ActiveTabIdx

    if !EditorModeActive
        CloseTab(ActiveTabIdx)
}



#HotIf IsMainGuiActive() && UrlBarHasFocus()

Enter::Navigate()

#HotIf



#HotIf IsMainGuiActive() && UrlBarHasFocus() && IsSuggestionVisible()

Down::
{
    global SuggestionLB, CurrentSuggestions, URL_Input

    if (CurrentSuggestions.Length = 0)
        return

    if (SuggestionLB.Value < CurrentSuggestions.Length)
        SuggestionLB.Value++
    else
        SuggestionLB.Value := 1

    URL_Input.Text := CurrentSuggestions[SuggestionLB.Value]
}


Up::
{
    global SuggestionLB, CurrentSuggestions, URL_Input

    if (CurrentSuggestions.Length = 0)
        return

    if (SuggestionLB.Value > 1)
        SuggestionLB.Value--
    else
        SuggestionLB.Value := CurrentSuggestions.Length

    URL_Input.Text := CurrentSuggestions[SuggestionLB.Value]
}


Escape::HideSuggestions()

#HotIf
