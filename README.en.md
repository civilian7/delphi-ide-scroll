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

## Build

- Requires: Delphi 13 (RAD Studio 37.0) recommended, target **Win64**
- Command-line build:

  ```cmd
  build.cmd
  ```

  Edit the `STUDIO` path inside `build.cmd` to match your installed RAD Studio version to build with other versions.

- Or open `src\IDEScroll.dpr` in the IDE and build the Win64 configuration.

## Project layout

```
src/
  IDEScroll.dpr            Entry point (VCL application)
  IDEScroll.WheelHook.pas  WH_MOUSE_LL hook + wheel → scroll translation
  Main.pas / Main.dfm      UI (hook toggle + sensitivity settings)
  IDEScroll.rc / .RES      Resources
build.cmd                  Win64 build script
```

## Compatibility

- Targets any Delphi / C++Builder version whose form designer container is `TFormContainerForm`
- Built / verified with Delphi 13 (RAD Studio 37.0), Windows 11 (Win64)

## License

[MIT](LICENSE) © 2026 civilian7
