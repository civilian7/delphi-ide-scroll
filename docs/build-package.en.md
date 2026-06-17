# Building the package (.bpl)

> [한국어](build-package.md) | English

How to build and install the IDE package (`IDEScrollPkg`). For the standalone EXE, see the [README](../README.en.md).

## Key requirement: Win32 only

**The RAD Studio IDE (`bds.exe`) is a 32-bit process.** A design-time package is loaded into the IDE process, so the package **must be built for Win32**. A Win64 `.bpl` cannot be installed into the IDE.

## Prerequisites

- RAD Studio (Delphi 13 / Studio 37.0 used here; other versions work too)
- The package only requires `rtl` and `vcl` — no extra components needed

## Option 1 — Command-line build (`build-bpl.cmd`)

From the repository root:

```cmd
build-bpl.cmd
```

It does the following:

- Uses `dcc32.exe` (the Win32 compiler)
- Points `-U` at `lib\Win32\release` (to reference the Win32 `rtl.dcp` / `vcl.dcp`)
- `cd`s into `src\bpl` before compiling so the `..\common\...` relative path inside the `.dpk` resolves correctly
- Output: `bin\IDEScrollPkg370.bpl`, `dcu\IDEScrollPkg.dcp`

For another RAD Studio version, edit the `STUDIO` path at the top of `build-bpl.cmd`.

## Option 2 — Build in the IDE

1. Open `src\bpl\IDEScrollPkg.dpk` in the IDE.
2. Set the platform to **Win32** (important).
3. Right-click the package in the Project Manager → **Build** (or **Compile**).

## Installation

1. IDE menu **Component → Install Packages → Add...**
2. Select the built `IDEScrollPkg370.bpl` → **OK**
3. Once installed, hooking is active immediately. In the form designer, use the **wheel** (vertical) / **Ctrl+wheel** (horizontal).
4. To remove it, select the package on the same dialog and click **Remove**.

## Sensitivity settings

The package flavor has no UI, so sensitivity is configured via an INI file.

- Location: `%APPDATA%\IDEScroll\IDEScroll.ini` (created with defaults on first load)
- Content:

  ```ini
  [Scroll]
  VerticalLines=3
  HorizontalLines=3
  ```

- `VerticalLines` / `HorizontalLines` are the number of lines scrolled per wheel notch. After editing, restart the IDE (or reload the package) to apply.

## Version-specific `.bpl` name (LIBSUFFIX AUTO)

The package uses `{$LIBSUFFIX AUTO}`, which appends the suffix matching the RAD Studio version automatically.

| Delphi version | Studio | Output file |
|---|---|---|
| 13.0 | 37.0 | `IDEScrollPkg370.bpl` |
| 13.1 | 37.1 | `IDEScrollPkg371.bpl` |

Because the `.bpl` differs per version, it is **not distributed as a release asset** — build it yourself with your RAD Studio version.

## Troubleshooting

- **`F1026 File not found: '..\common\...'`** — you built outside the `.dpk` directory. `build-bpl.cmd` handles this with `pushd`, and opening it in the IDE resolves it automatically.
- **Not installable / fails to load** — likely built for Win64. Rebuild for **Win32**.
- **"does not contain any registered components" warning** — expected. This package registers no components; it only activates the hook on load.
