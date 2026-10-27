# netsh QoL

Quality-of-life fixes for the **netsh** terminal in Tower Networking Inc.

*Українською — нижче.*

## Features

- **Hints in the middle of a line.** Put the caret anywhere in a command and start typing (or press **Ctrl+Space**): the game's own hint dropdown opens for the word at the caret — addresses, keywords, everything the game normally suggests at the end of a line. Pick with ↓/↑ and **Tab**; the rest of the line stays intact.
- **Up in the hint dropdown stays in the dropdown.** It no longer throws you into command history or jumps the caret to the start of the line.
- **Your unfinished command survives history browsing.** Type something, press ↑ to look at older commands, press ↓ back past the newest one — your draft is back.
- **Ctrl+V pastes at the caret**, not at the end of the line.

### How mid-line hints work (and one caveat)

While the dropdown is open the mod temporarily hides the part of the line after the caret, so the game suggests for the word you are editing. The rest comes back as soon as the dropdown closes or the caret moves.

If you press **Enter** while the dropdown is still open, the game runs the visible (cut) part right away — mods can't intercept Enter. The mod then:

- runs the **full** command for you if the game rejected the cut part (the usual case: a half-typed command is invalid);
- otherwise does **not** run anything else and just puts the full line back in the field, so you can check it and press Enter again.

Picking a hint with Tab (or closing the dropdown) before Enter avoids this entirely.

## Install

1. Install [LuaJIT Support](https://github.com/CJFWeatherhead/TNI-Mods/releases) (`luajit-support`) — required for Lua mods.
2. Copy the `netsh-qol` folder into the game's mods folder:
   - Windows: `%APPDATA%\Godot\app_userdata\Tower Networking Inc\mods\`
   - Linux: `~/.local/share/godot/app_userdata/Tower Networking Inc/mods/`

   so that `mods/netsh-qol/entry.lua` exists.
3. Start the game, open the **Mod manager** from the main menu and enable **netsh QoL**.

## Settings

Each feature can be switched off at the top of `entry.lua` (between the `MOD CONFIGURATION` markers): `midline_hints`, `popup_up_fix`, `keep_history_draft`, `paste_at_caret`. `debug_logging = true` writes what the mod does to `logs/godot.log`.

## Compatibility

Tested on Tower Networking Inc **0.13.3** (Godot 4.6.2) with luajit-support 0.2.0. It reads the netsh field's state each tick and changes nothing outside netsh; saves are not touched.

---

# netsh QoL (українською)

Покращення для терміналу **netsh** у Tower Networking Inc.

## Можливості

- **Підказки посередині рядка.** Постав курсор будь-де в команді й почни друкувати (або натисни **Ctrl+Space**) — відкриється звичайний ігровий список підказок для слова під курсором: адреси, ключові слова — все, що гра підказує в кінці рядка. Вибір — ↓/↑ і **Tab**, решта рядка лишається на місці.
- **↑ у списку підказок лишається в списку** — більше не перекидає в історію команд і не кидає курсор на початок рядка.
- **Недописана команда не губиться** при перегляді історії: ↑ подивився старі команди, ↓ повернувся — чернетка на місці.
- **Ctrl+V вставляє в місце курсора**, а не в кінець рядка.

### Як працюють підказки посередині (і одне застереження)

Поки список відкритий, мод тимчасово ховає частину рядка після курсора — так гра підказує саме для слова, яке ти редагуєш. Щойно список закривається або курсор зсувається, все повертається.

Якщо натиснути **Enter**, поки список ще відкритий, гра одразу виконає видиму (обрізану) частину — моди не можуть перехопити Enter. Тоді мод:

- сам запускає **повну** команду, якщо гра відхилила обрізану (звичайний випадок — недописана команда некоректна);
- інакше нічого більше не запускає, а повертає повний рядок у поле, щоб ти перевірив і натиснув Enter ще раз.

Щоб цього взагалі не траплялося — вибирай підказку Tab'ом (або закривай список) перед Enter.

## Встановлення

1. Встанови [LuaJIT Support](https://github.com/CJFWeatherhead/TNI-Mods/releases) (`luajit-support`) — потрібен для Lua-модів.
2. Скопіюй папку `netsh-qol` у папку модів гри:
   - Windows: `%APPDATA%\Godot\app_userdata\Tower Networking Inc\mods\`
   - Linux: `~/.local/share/godot/app_userdata/Tower Networking Inc/mods/`

   щоб існував файл `mods/netsh-qol/entry.lua`.
3. Запусти гру, відкрий **Менеджер модів** у головному меню й увімкни **netsh QoL**.

## Налаштування

Кожну функцію можна вимкнути вгорі `entry.lua` (між мітками `MOD CONFIGURATION`): `midline_hints`, `popup_up_fix`, `keep_history_draft`, `paste_at_caret`. `debug_logging = true` пише дії мода в `logs/godot.log`.

## Сумісність

Перевірено на Tower Networking Inc **0.13.3** (Godot 4.6.2) з luajit-support 0.2.0. Мод лише читає стан поля netsh і нічого не змінює поза ним; збереження не зачіпає.
