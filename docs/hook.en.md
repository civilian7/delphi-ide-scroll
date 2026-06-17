# Hooking, and the Story of Building IDEScroll

> [한국어](hook.md) | English

This document covers two things:

1. **What hooking is** — the concept and kinds of Windows message hooks
2. **How IDEScroll was built** — from requirements through design decisions, implementation, and the bumps along the way

---

## 1. What is hooking?

### 1.1 The idea

**Hooking** is a technique for **intercepting events, messages, or function calls** that flow between the operating system and programs. The name comes from the image of hanging a "hook" into a stream and catching what passes by.

At the intercept point, we can typically do three things:

- **Observe**: look at which event happened (e.g. key logging, debugging)
- **Modify**: change the content or outcome of the event (e.g. turn a wheel event into a scroll in a different direction)
- **Suppress**: prevent the event from reaching its original destination

IDEScroll uses all three. It **observes** wheel events, **modifies** them into scrolls when over the designer, and **suppresses** the original wheel message.

### 1.2 Windows message hooks

Windows GUIs are **message** driven. Key presses, mouse moves, wheel rotations — all become messages delivered to a window's queue.

Windows offers an official API, **`SetWindowsHookEx`**, to step into this message flow.

```pascal
FHookHandle := SetWindowsHookEx(WH_MOUSE_LL, @LowLevelMouseProc, HInstance, 0);
```

- The first argument `WH_MOUSE_LL` is the **hook type**.
- The second is the **callback** invoked on each event.
- Hooks of the same type are linked into a **chain**; each callback either forwards to the next via `CallNextHookEx`, or returns a non-zero value to **consume (suppress)** the event.

### 1.3 Kinds of hooks — and the key fork in the road

Hooks fall into two broad families.

| | Global hook (injection) | Low-level hook (`WH_*_LL`) |
|---|---|---|
| Examples | `WH_MOUSE`, `WH_CBT`, `WH_GETMESSAGE` | `WH_MOUSE_LL`, `WH_KEYBOARD_LL` |
| Runs where | A **DLL is injected** into the target process and runs inside it | Runs **inside the installing process** (no injection) |
| Constraints | Must match the target's **bitness (32/64)** and needs a DLL | Bitness-independent, no DLL |
| Downside | Complex distribution / compatibility | Callback must finish quickly (system timeout) |

This single distinction shaped the entire design of IDEScroll, as we'll see below.

---

## 2. The development process

### 2.1 Starting point: the requirement

> "In the Delphi IDE form designer, large forms get scrollbars. I'd like to control horizontal/vertical scrolling with the wheel and Ctrl+wheel. Is hooking possible?"

The initial goal was **wheel = horizontal, Ctrl+wheel = vertical**, which later changed to **wheel = vertical, Ctrl+wheel = horizontal** (keeping the plain wheel vertical felt more natural).

### 2.2 First fork: how to step into the IDE

To change the designer's wheel behavior, our code must reach the IDE's message flow. Two candidates:

**(A) IDE extension (Open Tools API, a `.bpl` package)**
- The official way to run inside the IDE
- But a **`.bpl` must be recompiled for every IDE version**. Delphi has many versions, so build/maintenance grows with the number of supported versions.
- The OTA also has no interface for intercepting designer scrolling.

**(B) External program + low-level mouse hook (`WH_MOUSE_LL`)**
- A small separate executable installs a `WH_MOUSE_LL` hook
- Because there is **no injection**, a single executable covers all versions regardless of bitness
- No dependency on the OTA

The moment the user pinned down "must support **many versions**," the answer was clearly **(B)**. The injection-vs-low-level distinction from sections 1.2–1.3 became the deciding factor.

### 2.3 Second challenge: *where* to scroll

Even after intercepting the wheel, we must know **which window** to send scroll messages to. What window is the designer surface?

- Using a spy tool (Spy++ etc.) over the form designer revealed the window class **`TFormContainerForm`**.
- This class has been the **designer container across many Delphi/C++Builder versions for a long time**, which is great for multi-version support.
- The window also descends from `TCustomForm`/`TForm`, so it likely responds to VCL's standard scroll handling (`WM_HSCROLL`/`WM_VSCROLL`) provided by `TScrollingWinControl`.

So the strategy was set:

```
wheel event
 → find the window under the cursor (WindowFromPoint)
 → walk up the parent chain looking for class name TFormContainerForm
 → if found, PostMessage WM_VSCROLL / WM_HSCROLL
 → consume (suppress) the original wheel message
```

The core translation logic (essence):

```pascal
// plain wheel → vertical, Ctrl+wheel → horizontal
LVertical := not ACtrl;

// wheel up (delta>0) → up/left, down → down/right
LBackward := ADelta > 0;
```

### 2.4 Third: the message loop and callback safety

A `WH_MOUSE_LL` callback runs in the context of the **message pump of the thread that installed the hook**. Therefore:

- The callback does **no heavy work** (the system enforces a timeout). Scrolls are dispatched with asynchronous `PostMessage`, not synchronous `SendMessage`.
- The Ctrl state is read immediately as a physical state via `GetAsyncKeyState(VK_CONTROL)`.
- Because the VCL app's message loop runs the callback safely on the main thread, UI updates (the log memo) are also safe without extra synchronization.

### 2.5 Polishing: iterative user feedback

The requirements shifted several times during development, and each was incorporated:

- **Direction flip**: changed to wheel = vertical, Ctrl+wheel = horizontal
- **Sensitivity control added**: configure "lines per wheel notch" for vertical and horizontal separately; values persisted in `IDEScroll.ini`
- **UI**: a checkbox didn't respond to `Enter`, so it became a **Default button** that toggles on `Enter` per Windows convention
- **Lower-version compatibility**: inline variables (`var x := ...`, `for var i`) are newer syntax, so the code was switched to **traditional `var` blocks** to compile on older Delphi versions
- **Code-style cleanup**: removed `{$REGION}` directives and `///` XML doc comments; moved sources into `src\` and build output into `bin\`/`dcu\`

### 2.6 Small traps hit during the build

Things encountered and solved while actually compiling:

- **`PMSLLHOOKSTRUCT` undeclared**: `Winapi.Windows` lacks this pointer type, so the struct the callback receives was declared directly.
- **Missing UTF-8 BOM → Korean literals misread as ANSI (W1057 warning)**: fixed by ensuring a UTF-8 BOM on `.pas` files.
- **No `.res`**: generated by compiling an empty resource script with `brcc32`.
- **Output file locked (F2039)**: a running `IDEScroll.exe` from testing held the file; killed the process and rebuilt.

### 2.7 Remaining verification point

Whether `TFormContainerForm` actually responds to standard `WM_HSCROLL`/`WM_VSCROLL` is the final item to confirm in the runtime environment. As a `TForm` descendant it likely does, but if it uses custom-drawn scrollbars, the design leaves room to fall back to **manipulating the scrollbar position directly (`GetScrollInfo`/`SetScrollInfo`)**.

---

## 3. Wrap-up

IDEScroll is a "small convenience," but there is clear engineering behind it:

- It chose **low-level hooking over injection**, sidestepping multi-version and bitness problems entirely,
- It found the designer by relying on a stable identifier — the **window class name**,
- And it kept the **callback light and messages asynchronous**, respecting the safety rules of system hooks.

Hooking is powerful but fragile. The principle of "intercept only the bare minimum, and leave everything else untouched" is what kept this small tool simple and robust.
