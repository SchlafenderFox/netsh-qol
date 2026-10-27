# netsh QoL

Quality-of-life fixes for the **netsh** terminal in Tower Networking Inc.

> This mod is meant as a **temporary** solution. We'd be really happy to see these improvements become part of the game itself — until the developers get a chance to consider them, this mod makes working in the terminal a lot more comfortable.

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

1. Install the official **LuaJIT Support** mod: download `luajit-support.zip` from [Continuous (gnu) - beta](https://github.com/treefarmer741/Tower-Networking-Inc-modding-kit/releases/tag/continuous-gnu-beta) and extract it so that `mods/luajit-support/entry.elf` exists.
2. Copy the `netsh-qol` folder into the game's mods folder:
   - Windows: `%APPDATA%\Godot\app_userdata\Tower Networking Inc\mods\`
   - Linux: `~/.local/share/godot/app_userdata/Tower Networking Inc/mods/`

   so that `mods/netsh-qol/entry.lua` exists.
3. Start the game, open the **Mod manager** from the main menu and enable **netsh QoL**.

## Settings

Each feature can be switched off at the top of `entry.lua` (between the `MOD CONFIGURATION` markers): `midline_hints`, `popup_up_fix`, `keep_history_draft`, `paste_at_caret`. `debug_logging = true` writes what the mod does to `logs/godot.log`.

## Compatibility

Tested on Tower Networking Inc **0.13.3** (Godot 4.6.2) with the official luajit-support 0.2.1 (`continuous-gnu-beta`). It reads the netsh field's state each tick and changes nothing outside netsh; saves are not touched.

## Bug reports & testing

Any testing and bug reports are very welcome! Please [open an issue](https://github.com/SchlafenderFox/netsh-qol/issues) and include:

1. **Game version** (shown in the main menu, e.g. `0.13.3`) and mod version.
2. **What you typed** — the command, where the caret was, which keys you pressed.
3. **What happened vs. what you expected.** A screenshot of the netsh window helps.
4. **The mod's log**, if you can: set `debug_logging = true` at the top of `entry.lua`, reproduce the problem, **quit the game** (the log is only fully written on exit) and copy the lines starting with `[netsh-qol]` from `logs/godot.log` (next to the `mods` folder).

### Known limitations

- Mods can't see **Enter**, **Tab**, **↑** or **↓** — the input field swallows them — so the mod reacts to what changed in the field instead. A very fast key sequence may occasionally slip through.
- **Enter while the hint dropdown is open mid-line** runs the visible part first (see above).
- **Ctrl+Space** inserts a space before the mod removes it; on a slow frame you may see it flash.
- Tested only on **0.13.3**; a game update that changes netsh may break the mod.

---

# netsh QoL (українською)

Покращення для терміналу **netsh** у Tower Networking Inc.

> Цей мод, можливо, **тимчасовий**. Ми були б дуже раді, якби ці покращення з'явилися в самій грі, — а поки розробники розглядають цей варіант, мод допомагає зручніше працювати з терміналом.

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

1. Встанови офіційний мод **LuaJIT Support**: завантаж `luajit-support.zip` з [Continuous (gnu) - beta](https://github.com/treefarmer741/Tower-Networking-Inc-modding-kit/releases/tag/continuous-gnu-beta) і розпакуй так, щоб існував файл `mods/luajit-support/entry.elf`.
2. Скопіюй папку `netsh-qol` у папку модів гри:
   - Windows: `%APPDATA%\Godot\app_userdata\Tower Networking Inc\mods\`
   - Linux: `~/.local/share/godot/app_userdata/Tower Networking Inc/mods/`

   щоб існував файл `mods/netsh-qol/entry.lua`.
3. Запусти гру, відкрий **Менеджер модів** у головному меню й увімкни **netsh QoL**.

## Налаштування

Кожну функцію можна вимкнути вгорі `entry.lua` (між мітками `MOD CONFIGURATION`): `midline_hints`, `popup_up_fix`, `keep_history_draft`, `paste_at_caret`. `debug_logging = true` пише дії мода в `logs/godot.log`.

## Баг-репорти та тестування

Будь-яке тестування й повідомлення про баги дуже вітаються! [Створи issue](https://github.com/SchlafenderFox/netsh-qol/issues) і додай:

1. **Версію гри** (видно в головному меню, напр. `0.13.3`) і версію мода.
2. **Що ти вводив** — команду, де стояв курсор, які клавіші натискав.
3. **Що сталося і що мало статися.** Скріншот вікна netsh дуже допоможе.
4. **Лог мода**, якщо можеш: постав `debug_logging = true` вгорі `entry.lua`, повтори проблему, **вийди з гри** (лог повністю записується лише при виході) і скопіюй рядки `[netsh-qol]` з `logs/godot.log` (поруч із папкою `mods`).

### Відомі обмеження

- Моди не бачать **Enter**, **Tab**, **↑** і **↓** — їх забирає поле вводу, — тож мод реагує на зміни в полі. Дуже швидка послідовність клавіш зрідка може проскочити.
- **Enter при відкритому списку посередині рядка** спершу виконує видиму частину (див. вище).
- **Ctrl+Space** спершу вставляє пробіл, який мод потім прибирає; на повільному кадрі він може блимнути.
- Перевірено лише на **0.13.3**; оновлення гри, що змінить netsh, може зламати мод.

## Сумісність

Перевірено на Tower Networking Inc **0.13.3** (Godot 4.6.2) з офіційним luajit-support 0.2.1 (`continuous-gnu-beta`). Мод лише читає стан поля netsh і нічого не змінює поза ним; збереження не зачіпає.
