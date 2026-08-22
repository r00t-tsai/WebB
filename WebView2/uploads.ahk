; ============================================================================
; uploads.ahk -- automated "attach a file" logic for Ask Box
; ============================================================================
; This file is #Include'd directly into AskBox.ahk, so it shares the same
; script/global namespace (it can freely call JoinJsLines(), DecodeJSONString(),
; etc. that already exist in AskBox.ahk). It is kept in its own file only to
; keep the upload automation separate and easy to find/maintain.
;
; ENTRY POINT
; -----------
;   result := AskBox_AttachFile(WB, aiName, filePath)
;
;   WB       - the CoreWebView2 object already navigated to the AI's chat page
;              (the same "WB" AskBox.ahk uses for SendScript()/PollScript()).
;   aiName   - "DuckDuckGo", "Gemini", or "ChatGPT"
;   filePath - full path to the file the user picked via FileSelect()
;
;   Returns one of:
;     "OK"                - file was handed off to the site successfully
;     "LOGIN_REQUIRED"    - the site says you must log in to attach files
;     "UNSUPPORTED"       - this AI doesn't support attachments at all
;     "ERROR::<reason>"   - something else went wrong
; ============================================================================

AskBox_AttachFile(WB, aiName, filePath)
{
    if (aiName = "Gemini")
        return "UNSUPPORTED"

    ; --- Step 1: find + click the site's attach control -------------------
    try
    {
        clickRes := WB.ExecuteScriptAsync(AskBox_FindAttachScript(aiName)).await()
    }
    catch as err
    {
        return "ERROR::click_failed:" . err.Message
    }

    clickText := DecodeJSONString(clickRes)

    if (InStr(clickText, "LOGIN::") = 1)
        return "LOGIN_REQUIRED"

    if (InStr(clickText, "NOTFOUND::") = 1)
        return "ERROR::upload_control_not_found"

    if (InStr(clickText, "ERROR::") = 1)
        return "ERROR::" . SubStr(clickText, 8)

    ; --- Step 2: give the site a moment to react ---------------------------
    ; It will either open a native file dialog, or (if it's going to refuse)
    ; show a login prompt instead of a dialog.
    Sleep(700)

    if (AskBox_CheckLoginPrompt(WB))
        return "LOGIN_REQUIRED"

    ; --- Step 3: wait for the native Windows "Open" dialog -----------------
    if !WinWait("ahk_class #32770",, 5)
    {
        ; Nothing opened. Give the login-prompt check one more chance --
        ; some sites take a beat longer to render the message.
        Sleep(500)
        if (AskBox_CheckLoginPrompt(WB))
            return "LOGIN_REQUIRED"
        return "ERROR::no_file_dialog_appeared"
    }

    dlg := WinExist("ahk_class #32770")

    try
    {
        WinActivate(dlg)
        WinWaitActive(dlg,, 2)
        ControlSetText(filePath, "Edit1", dlg)
        ControlSend("{Enter}", "Edit1", dlg)
    }
    catch as err
    {
        try WinClose(dlg)
        return "ERROR::dialog_automation_failed:" . err.Message
    }

    ; If the path was rejected (typo, unsupported file type for that site,
    ; etc.) the dialog usually stays open with an error of its own -- treat
    ; "didn't close" as a failure rather than guessing it worked.
    if !WinWaitClose(dlg,, 5)
    {
        try WinClose(dlg)
        return "ERROR::dialog_did_not_close"
    }

    ; --- Step 4: one last check in case the site rejects post-selection ----
    ; (e.g. it accepted the click, opened the dialog, but only *after* you
    ; pick a file does it tell you uploads need an account).
    Sleep(500)
    if (AskBox_CheckLoginPrompt(WB))
        return "LOGIN_REQUIRED"

    return "OK"
}

; Runs the login-prompt-detector script and returns true/false. Swallows
; errors -- if we can't check, we simply don't report a login wall.
AskBox_CheckLoginPrompt(WB)
{
    try
    {
        res := WB.ExecuteScriptAsync(AskBox_LoginPromptScript()).await()
        return (DecodeJSONString(res) = "LOGIN::1")
    }
    catch
    {
        return false
    }
}

; Finds and clicks whatever control starts the attach flow for the given AI.
AskBox_FindAttachScript(aiName)
{
    lines := [
        "(function(){",
        "  try {",
        "    function visible(el){",
        "      if (!el) return false;",
        "      var cs = window.getComputedStyle(el);",
        "      if (!cs) return false;",
        "      if (cs.display === 'none' || cs.visibility === 'hidden') return false;",
        "      var r = el.getBoundingClientRect();",
        "      return r.width > 0 && r.height > 0;",
        "    }",
        "",
        "    var loginRe = /\b(log in|log-in|sign in|sign-in|sign up|create a free account)\b/i;",
        "    var bodyText = document.body.innerText || '';",
        "",
        "    // --- 1) A directly usable native file input -----------------------",
        "",
        "    var inputs = Array.prototype.slice.call(document.querySelectorAll('input[type=file]'));",
        "    if (inputs.length) {",
        "      inputs[inputs.length - 1].click();",
        "      return 'CLICKED::1';",
        "    }",
        "",
        "    // --- 2) A visible button whose label/aria-label/title says attach --",
        "",
        "    var attachRe = /attach|upload|add photo|add file|add image|photo|image|file|clip/i;",
        "    var btns = Array.prototype.slice.call(document.querySelectorAll('button, [role=button]'));",
        "    var candidates = btns.filter(function(b){",
        "      if (!visible(b)) return false;",
        "      var label = ((b.getAttribute('aria-label')||'') + ' ' + (b.getAttribute('title')||'') + ' ' + (b.innerText||'')).trim();",
        "      return attachRe.test(label);",
        "    });",
        "",
        "    // --- 3) Fallback: an icon-only button (svg child, no text) that ----",
        "    //        lives in the same form/container as the message box --",
        "    //        (covers ChatGPT-style unlabeled '+' attach buttons).",
        "    if (!candidates.length) {",
        "      var box = Array.prototype.slice.call(document.querySelectorAll('textarea, [contenteditable]')).filter(function(el){",
        "        var r = el.getBoundingClientRect();",
        "        return el.offsetParent !== null && r.width > 100 && r.height > 0;",
        "      }).pop();",
        "      if (box) {",
        "        var container = box.closest('form') || box.parentElement;",
        "        for (var depth = 0; depth < 6 && container; depth++) {",
        "          var iconBtns = Array.prototype.slice.call(container.querySelectorAll('button, [role=button]')).filter(function(b){",
        "            return visible(b) && !b.disabled && b.querySelector('svg') && !(b.innerText||'').trim();",
        "          });",
        "          if (iconBtns.length) { candidates = [iconBtns[0]]; break; }",
        "          container = container.parentElement;",
        "        }",
        "      }",
        "    }",
        "",
        "    if (!candidates.length) return 'NOTFOUND::';",
        "",
        "    candidates[0].click();",
        "",
        "    // Give any dropdown menu a moment, then look again for either a menu",
        "    // item that actually starts the upload, or a freshly-revealed input.",
        "    return new Promise(function(resolve){",
        "      setTimeout(function(){",
        "        if (loginRe.test(document.body.innerText || '')) { resolve('LOGIN::1'); return; }",
        "",
        "        var inputs2 = Array.prototype.slice.call(document.querySelectorAll('input[type=file]'));",
        "        if (inputs2.length) {",
        "          inputs2[inputs2.length - 1].click();",
        "          resolve('CLICKED::1');",
        "          return;",
        "        }",
        "",
        "        var menuRe = /upload|photo|file|computer|image/i;",
        "        var items = Array.prototype.slice.call(document.querySelectorAll('[role=menuitem], button, [role=button]'));",
        "        var menuItem = null;",
        "        for (var i = 0; i < items.length; i++) {",
        "          var it = items[i];",
        "          if (!visible(it)) continue;",
        "          var lbl = ((it.innerText||'') + ' ' + (it.getAttribute('aria-label')||'')).trim();",
        "          if (menuRe.test(lbl)) { menuItem = it; break; }",
        "        }",
        "        if (menuItem) {",
        "          menuItem.click();",
        "          resolve('CLICKED::1');",
        "          return;",
        "        }",
        "",
        "        // We clicked *something* -- let the native-dialog wait on the AHK",
        "        // side make the final call (dialog appears = good, times out = error).",
        "        resolve('CLICKED::1');",
        "      }, 400);",
        "    });",
        "  } catch (e) {",
        "    return 'ERROR::' + (e && e.message ? e.message : 'unknown');",
        "  }",
        "})()"
    ]

    return JoinJsLines(lines)
}

; Returns 'LOGIN::1' if a visible dialog/modal/toast on the page currently
; contains login-wall wording, 'LOGIN::0' otherwise.
AskBox_LoginPromptScript()
{
    lines := [
        "(function(){",
        "  try {",
        "    var re = /\b(log in|log-in|sign in|sign-in|sign up|create a free account|you.?ll need to (log|sign) in|please (log|sign) in|logging in)\b/i;",
        "    var els = Array.prototype.slice.call(document.querySelectorAll('[role=dialog], [role=alertdialog], [class*=modal i], [class*=toast i], [class*=popup i]'));",
        "    for (var i = 0; i < els.length; i++) {",
        "      var cs = window.getComputedStyle(els[i]);",
        "      if (!cs || cs.display === 'none' || cs.visibility === 'hidden') continue;",
        "      if (re.test(els[i].innerText || '')) return 'LOGIN::1';",
        "    }",
        "    return 'LOGIN::0';",
        "  } catch (e) {",
        "    return 'LOGIN::0';",
        "  }",
        "})()"
    ]

    return JoinJsLines(lines)
}