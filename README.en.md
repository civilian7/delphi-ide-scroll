# IDEScroll

> [한국어](README.md) | English

A small utility that **changes the mouse-wheel scroll direction** in the Delphi IDE form designer.
When designing large forms, scroll vertically with the wheel and horizontally with `Ctrl+Wheel`.

## Features

- **Wheel** → vertical scroll
- **Ctrl + Wheel** → horizontal scroll
- Independent **scroll sensitivity** for vertical / horizontal (lines per wheel notch)
- Sensitivity settings are saved to / restored from `IDEScroll.ini` next to the executable

## How it works

- Uses a Windows low-level mouse hook (`WH_MOUSE_LL`). It does **not inject** into the IDE process, so it works **regardless of the Delphi / C++Builder version or bitness**.
- It walks up from the window under the cursor to find the form designer container window (`TFormContainerForm`), then translates the wheel event into `WM_VSCROLL` / `WM_HSCROLL` messages.
- When the cursor is not over the designer, it does not interfere with normal wheel behavior at all.

## Download

Grab `IDEScroll.exe` from [Releases](../../releases). It is a single executable with no installation required.

## Usage

1. Run `IDEScroll.exe`
2. Click **Start hooking** (or press `Enter`)
3. Adjust the vertical / horizontal sensitivity as you like
4. In the Delphi IDE form designer, use the **wheel** (vertical) / **Ctrl+wheel** (horizontal)
5. Click the button again to stop hooking. Settings are saved on exit.

> To keep it active in the background, just leave the program running with hooking enabled.

## Two flavors

| Flavor | Description | Target |
|---|---|---|
| **Standalone EXE** | Separate executable with a toggle UI + sensitivity settings | Win64 |
| **IDE package (.bpl)** | Install into the IDE; hooks automatically. No UI | Win32 (the IDE is a 32-bit process) |

> The package flavor reads its sensitivity from `%APPDATA%\IDEScroll\IDEScroll.ini` (created with defaults on first run).

### Installing the package

1. Build with `build-bpl.cmd` → produces `bin\IDEScrollPkg370.bpl` (for Delphi 13.0; building in the 13.1 IDE yields `...371.bpl`)
2. In the IDE, go to **Component → Install Packages → Add** and select the `.bpl`
3. After installation, use the wheel / Ctrl+wheel in the form designer (no separate program needed)

## Build

- Requires: Delphi 13 (RAD Studio 37.0) recommended
- EXE (Win64): `build.cmd`
- Package (Win32): `build-bpl.cmd`

  Edit the `STUDIO` path in each script to match your installed RAD Studio version to build with others.
  Or open `src\exe\IDEScroll.dpr` / `src\bpl\IDEScrollPkg.dpk` in the IDE and build.

## Project layout

```
src/
  exe/                       Standalone executable (Win64)
    IDEScroll.dpr            Entry point (VCL application)
    IDEScroll.WheelHook.pas  WH_MOUSE_LL hook + wheel → scroll translation
    Main.pas / Main.dfm      UI (hook toggle + sensitivity settings)
    IDEScroll.rc / .RES      Resources
  bpl/                       IDE package (Win32, Delphi 13)
    IDEScrollPkg.dpk         design-time package
    IDEScroll.IdeHook.pas    activates the hook on load
build.cmd                    EXE build (Win64)
build-bpl.cmd                Package build (Win32)
```

> The EXE and the package share the same `IDEScroll.WheelHook.pas` hook logic.

## Compatibility

- Targets any Delphi / C++Builder version whose form designer container is `TFormContainerForm`
- Built / verified with Delphi 13 (RAD Studio 37.0), Windows 11 (Win64)

## License

[MIT](LICENSE) © 2026 civilian7
