-- netsh QoL
-- Fixes annoyances of the netsh input field (TerminalInput : CodeEdit):
--   1. The game's own hint dropdown also works in the middle of a line: when
--      you type there (or press Ctrl+Space) the rest of the line is hidden while
--      the dropdown is open, so the game suggests for the word at the caret;
--      it comes back when the dropdown closes or the caret moves. Enter while
--      the tail is hidden runs the full command if the game rejected the cut
--      one, otherwise puts the full line back without running anything
--   2. Up inside the hint popup no longer throws you into command history
--   3. Browsing history with Up no longer loses the command you were typing:
--      Down from the newest history entry brings it back
--   4. Ctrl+V in the middle of a command lands at the caret, not at the end
--
-- How (learned with netsh-probe, TNI 0.13.3 / Godot 4.6.2):
--   * Tab, Up and Down never reach mods (the field swallows them, presses and
--     releases alike), so features 2 and 3 watch the field's text every tick
--     and react to what changed; the global Input singleton is not reachable
--   * mods get other keys only after the field handled them (Ctrl+Space has
--     already inserted a space when we see it)
--   * call setters and script methods with dot syntax (inp.set_text(s)); colon
--     syntax passes the object itself as the first argument
--   * keycodes are Variants: compare with ==, never use them as table keys
--   * os.clock() is sandbox CPU time: count on_game_tick calls (60/s) instead
--   * find the field through the viewport focus owner, not find_children

-- ===== MOD CONFIGURATION START =====
local config = {
    -- show the game's hint dropdown for the word at the caret, mid-line
    midline_hints = true,
    -- Up inside the hint popup stays in the popup
    popup_up_fix = true,
    -- Down from the newest history entry restores the unfinished command
    keep_history_draft = true,
    -- move text pasted with Ctrl+V back to the caret position
    paste_at_caret = true,
    -- log what the mod does to godot.log
    debug_logging = false
}
-- ===== MOD CONFIGURATION END =====

local KEY_CTRL  = 4194326
local KEY_HOME  = 4194317
local KEY_SPACE = 32

local input = nil
local ticks = 0

-- field state as of the previous tick
local prev = nil            -- { text, caret, cc_n, cc_sel }
local pending_sel = nil     -- popup selection to restore once the popup is back
local pending_until = 0
local pending_revert = nil  -- { text, caret } to re-apply as if typed
local pending_complete = nil -- Ctrl+Space: field state before the key
local injected_draft = nil  -- draft we appended to command_history
local paste_watch = nil     -- { text, caret, until_tick }
local home_tick = -1000      -- last tick Home reached the mod (it is not swallowed)
local trace_ticks = 0       -- debug: log the field for a few ticks after we edit it

local function log(msg) if config.debug_logging then print(msg) end end

-- While the world is being torn down (leaving to the menu) get_game_world()
-- returns a null object and the next call on it throws outside pcall's reach,
-- even while get_devices() still lists devices. The base UI lives above the
-- world and shares its viewport, so ask it for the focused control instead.
-- Never keep a node across ticks (a freed node faults the sandbox): look up the
-- focused control afresh each time and use it only if it is the netsh field.
local function find_input()
    input = nil
    pcall(function()
        local f = ModApiV1.get_base_ui():get_viewport():gui_get_focus_owner()
        if f ~= nil and tostring(f:get_path()):find("NetShell/TextInput", 1, true) then
            input = f
        end
    end)
    return input
end

local function has_focus(inp)
    local ok, v = pcall(function() return inp:has_focus(false) end)
    return ok and v == true
end

local function num(v) return tonumber(tostring(v)) or 0 end
local function get_text(inp) return tostring(inp:get_text()) end
local function get_caret(inp) return num(inp:get_caret_column(0)) end

local function set_text_caret(inp, text, caret)
    inp.set_text(text)
    inp.set_caret_column(caret, true, 0)
end

local function read_state(inp)
    return {
        text = get_text(inp),
        caret = get_caret(inp),
        cc_n = num(inp:get_code_completion_options():size()),
        cc_sel = num(inp:get_code_completion_selected_index()),
    }
end

local function history_list(inp)
    local t = {}
    local h = inp.command_history
    for i = 0, num(h:size()) - 1 do t[#t + 1] = tostring(h:get(i)) end
    return t
end

local function contains(list, s)
    for _, v in ipairs(list) do if v == s then return true end end
    return false
end

-- 1. mid-line hints: hide the tail so the game hints for the caret word -----

local split = nil -- { tail, last, until_tick } while the tail is hidden

-- set the text so that the game sees the last character typed: set_text()
-- alone does not run the game's suggestions
local function retype(inp, text)
    local head = string.sub(text, 1, #text - 1)
    set_text_caret(inp, head, #head)
    pcall(function() inp.insert_text_at_caret(string.sub(text, -1), -1) end)
end

local function enter_split(inp, text, caret)
    if caret == 0 then return end
    split = { tail = string.sub(text, caret + 1), last = string.sub(text, 1, caret), until_tick = ticks + 6 }
    retype(inp, split.last)
    log("split: prefix=[" .. split.last .. "] tail=[" .. split.tail .. "]")
end

local function words(s)
    local t = {}
    for w in string.gmatch(s, "%S+") do t[#t + 1] = w end
    return t
end

local function exit_split(inp, cur)
    local prefix, tail = cur.text, split.tail
    local completed = prefix ~= split.last
    split = nil
    if completed then
        -- the dropdown replaced the word at the caret: drop what was left of
        -- the old word, then any words the completion already brought along
        -- (templates insert "route show on", the tail still has " on @r1")
        tail = string.gsub(tail, "^%S+", "")
        local pw, tw = words(prefix), words(tail)
        for k = math.min(#pw, #tw), 1, -1 do
            local same = true
            for i = 1, k do
                if pw[#pw - k + i] ~= tw[i] then same = false; break end
            end
            if same then
                local skip = 0
                for _ = 1, k do
                    local _, e = string.find(tail, "^%s*%S+", skip + 1)
                    skip = e
                end
                tail = string.sub(tail, skip + 1)
                break
            end
        end
    end
    if string.sub(prefix, -1) == " " and string.sub(tail, 1, 1) == " " then tail = string.sub(tail, 2) end
    local caret = math.min(cur.caret, #prefix)
    set_text_caret(inp, prefix .. tail, caret)
    -- the game's dropdown still lists hints for the old caret word: close it
    pcall(function() inp.cancel_code_completion() end)
    log("split end (" .. (completed and "completed" or "kept") .. "): [" .. prefix .. tail .. "]")
end

-- Enter while the tail was hidden: Enter never reaches mods and the game runs
-- the field at once, so the cut line has already been executed. If the game
-- rejected it (it prints an error before returning), run the full command the
-- player meant; if the cut line was itself a valid command, don't run anything
-- else on their behalf - put the full line back for them to check.
local function display_of(inp)
    local shell = inp:get_parent()
    local kids = shell:get_children(false)
    for i = 0, num(kids:size()) - 1 do
        local k = kids:get(i)
        if tostring(k:get_name()) == "TextDisplay" then return shell, k end
    end
    return shell, nil
end

local function output_after(display, cut)
    -- plain text of the display from the last echo of the cut command on
    local txt = tostring(display:get_parsed_text())
    local echo = "> " .. cut
    local last = nil
    local from = 1
    while true do
        local a = string.find(txt, echo, from, true)
        if a == nil then break end
        last = a
        from = a + 1
    end
    if last == nil then return nil end
    return string.sub(txt, last + #echo)
end

local function replace_history_tail(inp, cut, full)
    local h = inp.command_history
    local n = num(h:size())
    if n > 0 and tostring(h:get(n - 1)) == cut then h:remove_at(n - 1) end
    h:append(full)
end

function on_cut_enter(inp, cut, full)
    local shell, display = display_of(inp)
    local out = display and output_after(display, cut)
    log("cut Enter: cut=[" .. cut .. "] full=[" .. full .. "] output=[" .. tostring(out) .. "]")
    -- the game echoes "> cmd" and errors right away; a valid remote command
    -- prints nothing yet (its reply arrives later through the debugger)
    local failed = out ~= nil and string.find(out, "%S") ~= nil
    if failed and display ~= nil then
        replace_history_tail(inp, cut, full)
        pcall(function() display.print_line("> " .. full) end)
        local ok, err = pcall(function() shell.exec_command(full, display) end)
        log("cut command failed; ran the full command (ok=" .. tostring(ok) .. " " .. tostring(err) .. ")")
    else
        set_text_caret(inp, full, #full)
        log("cut command looked valid; full command put back, not run")
    end
end

-- typing one character in the middle of the line?
local function typed_midline(p, c)
    if c.caret >= #c.text or #c.text ~= #p.text + 1 or c.caret == 0 then return false end
    local ch = string.sub(c.text, c.caret, c.caret)
    if ch == " " then return false end
    return string.sub(c.text, 1, c.caret - 1) .. string.sub(c.text, c.caret + 1) == p.text
end

-- deleting one character in the middle of the line (Backspace or Delete),
-- leaving part of a word before the caret?
local function deleted_midline(p, c)
    if c.caret >= #c.text or #c.text ~= #p.text - 1 or c.caret == 0 then return false end
    if string.sub(c.text, c.caret, c.caret) == " " then return false end
    local head, tail = string.sub(c.text, 1, c.caret), string.sub(c.text, c.caret + 1)
    return string.sub(p.text, 1, #head) == head and string.sub(p.text, -#tail) == tail
end

local pending_del = nil -- { text, caret, at_tick }: open hints after a mid-line deletion

local function update_split(inp, cur)
    if cur.text == "" then
        local cut, full = split.last, split.last .. split.tail
        split = nil
        on_cut_enter(inp, cut, full)
        return
    end
    if cur.caret ~= #cur.text then
        log(string.format("split exit: caret %d ~= len %d", cur.caret, #cur.text))
        exit_split(inp, cur); return
    end
    if cur.cc_n == 0 and ticks > split.until_tick then
        log("split exit: no dropdown")
        exit_split(inp, cur); return
    end
    if cur.cc_n > 0 then split.until_tick = ticks + 6 end
    -- plain typing / deleting keeps refining the word
    if string.sub(cur.text, 1, #split.last) == split.last or string.sub(split.last, 1, #cur.text) == cur.text then
        if #cur.text - #split.last <= 1 then split.last = cur.text end
    end
end

-- 4. paste fix ---------------------------------------------------------------

local caret_hold = nil -- { text, caret, until_tick }: keep the caret after a paste

-- The game either appends the clipboard at the end of the line or inserts it
-- at the caret, and in both cases leaves the caret at the end (sometimes a
-- frame later). Put the text where the caret was and the caret right after it.
local function fix_paste(inp, now_text)
    local w = paste_watch
    if ticks > w.until_tick then paste_watch = nil; return end
    if now_text == w.text then return end
    local old, at = w.text, w.caret
    -- one character is typing, not a paste: keep watching from the new state
    if #now_text == #old + 1 then
        w.text, w.caret = now_text, get_caret(inp)
        return
    end
    paste_watch = nil
    if #now_text <= #old then return end
    local head, tail = string.sub(old, 1, at), string.sub(old, at + 1)
    local new_text, caret
    if string.sub(now_text, 1, #head) == head
       and (tail == "" or string.sub(now_text, -#tail) == tail) then
        -- inserted at the caret: only the caret is wrong
        new_text, caret = now_text, #now_text - #tail
    elseif string.sub(now_text, 1, #old) == old then
        -- appended at the end: move it to the caret
        local inserted = string.sub(now_text, #old + 1)
        -- the game separates the paste with a space; drop it when inserting mid-line
        if string.sub(inserted, 1, 1) == " " then inserted = string.sub(inserted, 2) end
        new_text, caret = head .. inserted .. tail, at + #inserted
    else
        return
    end
    set_text_caret(inp, new_text, caret)
    caret_hold = { text = new_text, caret = caret, until_tick = ticks + 10 }
    -- Ctrl may still be held for another V, which mods never see: keep watching
    paste_watch = { text = new_text, caret = caret, until_tick = ticks + 120 }
    log("paste at caret " .. at .. ": [" .. new_text .. "] caret=" .. caret)
end

-- 2 + 3. react to history jumps ------------------------------------------------

-- Tab with the game's own dropdown open in the middle of the line: the game
-- puts the pick in place of the LAST word of the line. Move it to the word
-- under the caret and give the last word back.
local function fix_midline_tab(inp, cur)
    -- (the game's hint list after a deletion is not a CodeEdit popup, so
    -- cc_n can't be trusted here; the pick must extend the caret word instead)
    if prev.caret >= #prev.text then return false end
    local a, b = prev.text, cur.text
    local lw = #a
    while lw > 0 and string.sub(a, lw, lw) ~= " " do lw = lw - 1 end
    if prev.caret >= lw or string.sub(b, 1, lw) ~= string.sub(a, 1, lw) then return false end
    local pick = string.gsub(string.sub(b, lw + 1), "%s+$", "")
    if pick == "" or pick == string.sub(a, lw + 1) then return false end
    local ws = prev.caret
    while ws > 0 and string.sub(a, ws, ws) ~= " " do ws = ws - 1 end
    local partial = string.sub(a, ws + 1, prev.caret)
    if partial == "" or string.sub(pick, 1, #partial) ~= partial then return false end
    local we = prev.caret
    while we < #a and string.sub(a, we + 1, we + 1) ~= " " do we = we + 1 end
    local fixed = string.sub(a, 1, ws) .. pick .. string.sub(a, we + 1)
    set_text_caret(inp, fixed, ws + #pick)
    pcall(function() inp.cancel_code_completion() end)
    log("mid-line Tab: [" .. b .. "] -> [" .. fixed .. "]")
    return true
end

local function on_text_changed(inp, cur)
    if config.midline_hints and split == nil and fix_midline_tab(inp, cur) then return true end
    -- typing or deleting changes the text by growing/shrinking it at the end;
    -- a history jump replaces it wholesale
    local a, b = prev.text, cur.text
    if string.sub(b, 1, #a) == a or string.sub(a, 1, #b) == b then
        if cur.text == "" then a = nil else return false end
    end
    local hist = history_list(inp)
    local now_hist = contains(hist, cur.text)
    local prev_hist = contains(hist, prev.text)

    -- 2. Up pressed while the hint popup was open: the game jumped into
    --    history instead of moving the selection. Undo the jump.
    if config.popup_up_fix and a ~= nil and prev.cc_n > 0 and now_hist and not prev_hist then
        -- the game moves the caret after this tick and set_text() does not
        -- re-run its suggestions, so finish the undo on the next tick
        pending_revert = { text = prev.text, caret = prev.caret }
        pending_sel = math.max(prev.cc_sel - 1, 0)
        pending_until = ticks + 30
        set_text_caret(inp, prev.text, prev.caret)
        log("popup Up: undid history jump, selection -> " .. pending_sel)
        return true
    end

    -- 3. first jump from typed text into history: keep the draft as the
    --    newest history entry so Down from the real newest brings it back
    if config.keep_history_draft and a ~= nil and now_hist and not prev_hist
       and prev.text ~= "" and injected_draft == nil then
        inp.command_history:append(prev.text)
        injected_draft = prev.text
        log("draft kept in history: [" .. prev.text .. "] size=" .. num(inp.command_history:size()))
    end

    -- command executed (field cleared): take our draft entry back out
    if cur.text == "" and injected_draft ~= nil then
        local h = inp.command_history
        for i = num(h:size()) - 1, 0, -1 do
            if tostring(h:get(i)) == injected_draft then h:remove_at(i); break end
        end
        log("draft removed from history")
        injected_draft = nil
    end
    return false
end

function on_mod_load()
    print("netsh QoL loaded")
end

function on_player_input(event)
    pcall(function()
        if event:get_class() ~= "InputEventKey" then return end
        if not event:is_pressed() then return end
        local inp = find_input()
        if inp == nil or not has_focus(inp) then return end
        local key = event:get_keycode()
        if key == KEY_HOME then home_tick = ticks end
        if key == KEY_SPACE and event:is_ctrl_pressed() and config.midline_hints then
            -- the field inserts a space for Ctrl+Space, sometimes before and
            -- sometimes after this hook runs: complete on the next tick from
            -- the state recorded before the key
            if prev ~= nil then pending_complete = { text = prev.text, caret = prev.caret } end
        elseif key == KEY_CTRL and config.paste_at_caret and not event:is_echo() and prev ~= nil then
            paste_watch = { text = prev.text, caret = prev.caret, until_tick = ticks + 120 }
        end
    end)
end

function on_game_tick(delta)
    ticks = ticks + 1
    pcall(function()
        local inp = find_input()
        if inp == nil then prev = nil; return end
        local cur = read_state(inp)
        if trace_ticks > 0 then
            trace_ticks = trace_ticks - 1
            log(string.format("trace text=[%s] caret=%d cc_n=%d", cur.text, cur.caret, cur.cc_n))
        end
        if pending_revert ~= nil then
            local r = pending_revert
            pending_revert = nil
            -- retype the last character so the game rebuilds and shows its hints
            retype(inp, r.text)
            inp.set_caret_column(r.caret, true, 0)
            cur = read_state(inp)
            log("popup reopened: cc_n=" .. cur.cc_n)
        end
        if pending_complete ~= nil then
            local base = pending_complete
            pending_complete = nil
            -- base is the state before the key, whenever the field inserted its space
            if split ~= nil then
                set_text_caret(inp, base.text, base.caret)
            elseif base.caret < #base.text then
                enter_split(inp, base.text, base.caret)
            elseif base.text ~= "" then
                retype(inp, base.text)
            end
            cur = read_state(inp)
            trace_ticks = 3
        end
        if pending_sel ~= nil then
            if cur.cc_n > 0 then
                inp.set_code_completion_selected_index(math.min(pending_sel, cur.cc_n - 1))
                pending_sel = nil
                cur = read_state(inp)
            elseif ticks > pending_until then
                pending_sel = nil -- popup did not come back
            end
        end
        if paste_watch ~= nil then fix_paste(inp, cur.text); cur = read_state(inp) end
        if caret_hold ~= nil then
            if ticks > caret_hold.until_tick or cur.text ~= caret_hold.text then
                caret_hold = nil
            elseif cur.caret ~= caret_hold.caret then
                inp.set_caret_column(caret_hold.caret, true, 0)
                cur = read_state(inp)
            end
        end
        -- history jumps first: undoing an Up inside the dropdown must win over
        -- the hidden-tail bookkeeping below
        local reverted = false
        if prev ~= nil and cur.text ~= prev.text then
            reverted = on_text_changed(inp, cur)
            if reverted then cur = read_state(inp) end
        end
        -- Up inside the dropdown with nothing (older) in history: the game keeps
        -- the text but throws the caret to the line start and closes the
        -- dropdown. Put the caret back and reopen the dropdown one entry up.
        if config.popup_up_fix and not reverted and prev ~= nil and prev.cc_n > 0
           and cur.text == prev.text and cur.caret == 0 and prev.caret > 0
           and ticks - home_tick > 2 then
            pending_revert = { text = prev.text, caret = prev.caret }
            pending_sel = math.max(prev.cc_sel - 1, 0)
            pending_until = ticks + 30
            set_text_caret(inp, prev.text, prev.caret)
            cur = read_state(inp)
            reverted = true
            log("popup Up at line start: caret restored, selection -> " .. pending_sel)
        end
        if reverted or pending_revert ~= nil then
            -- the dropdown is being restored; leave the hidden tail alone
        elseif split ~= nil then
            update_split(inp, cur)
            cur = read_state(inp)
        elseif config.midline_hints and prev ~= nil and caret_hold == nil
               and typed_midline(prev, cur) then
            enter_split(inp, cur.text, cur.caret)
            cur = read_state(inp)
        elseif config.midline_hints and prev ~= nil and caret_hold == nil and deleted_midline(prev, cur) then
            -- the game is still busy with the Backspace for a few frames; open
            -- the hints like Ctrl+Space does once the field has settled
            pending_del = { text = cur.text, caret = cur.caret, at_tick = ticks + 15 }
        elseif pending_del ~= nil then
            if cur.text ~= pending_del.text or cur.caret ~= pending_del.caret then
                pending_del = nil
            elseif ticks >= pending_del.at_tick then
                pending_del = nil
                enter_split(inp, cur.text, cur.caret)
                cur = read_state(inp)
            end
        end
        prev = cur
    end)
end
