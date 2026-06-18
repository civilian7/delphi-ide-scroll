# 패키지(.bpl) 빌드 가이드

> 한국어 | [English](build-package.en.md)

IDE 패키지 버전(`IDEScrollPkg`)을 빌드하고 설치하는 방법입니다. 스탠드얼론 EXE 빌드는 [README](../README.md) 를 참고하세요.

## 핵심 전제: 반드시 Win32

**RAD Studio IDE(`bds.exe`)는 32비트 프로세스**입니다. 디자인타임 패키지는 IDE 프로세스 안에 로드되므로, 패키지는 **반드시 Win32로 빌드**해야 합니다. Win64 `.bpl` 은 IDE에 설치되지 않습니다.

## 사전 준비

- RAD Studio (Delphi 13 / Studio 37.0 기준, 다른 버전도 가능)
- 패키지는 `rtl`, `vcl`, `designide` 를 require 합니다(모두 RAD Studio 기본 제공 — 추가 서드파티 컴포넌트 불필요). `designide` 는 미니맵의 ToolsAPI 도킹 폼·테마 연동에 필요합니다.

## 방법 1 — 명령줄 빌드 (`build-bpl.cmd`)

저장소 루트에서:

```cmd
build-bpl.cmd
```

내부적으로 다음을 수행합니다.

- `dcc32.exe` (Win32 컴파일러) 사용
- `-U` 에 `lib\Win32\release` 지정 (Win32용 `rtl.dcp`/`vcl.dcp` 참조)
- `src\bpl` 로 이동 후 컴파일 → `.dpk` 안의 `..\common\...` 상대경로가 올바르게 해석됨
- 산출물: `bin\IDEScrollPkg370.bpl`, `dcu\IDEScrollPkg.dcp`

다른 RAD Studio 버전이면 `build-bpl.cmd` 상단의 `STUDIO` 경로를 수정하세요.

## 방법 2 — IDE에서 빌드

1. `src\bpl\IDEScrollPkg.dpk` 를 IDE에서 엽니다.
2. 플랫폼을 **Win32** 로 설정합니다 (중요).
3. Project Manager 에서 패키지를 우클릭 → **Build** (또는 **Compile**).

## 설치

1. IDE 메뉴 **Component → Install Packages → Add...**
2. 빌드된 `IDEScrollPkg370.bpl` 선택 → **OK**
3. 설치되면 즉시 후킹이 활성화됩니다. IDE 폼 디자이너에서 **휠**(세로) / **Ctrl+휠**(가로) 로 스크롤하세요.
4. **View 메뉴 → IDEScroll Minimap** 으로 도킹형 미니맵을 열 수 있습니다(폼 위치 표시 + 드래그/휠 스크롤). 자세한 내용은 [README](../README.md#미니맵-ide-패키지-전용) 참고.
5. 제거하려면 같은 화면에서 패키지를 선택 후 **Remove**.

## 감도 설정

패키지 버전은 UI가 없으므로 감도는 INI 파일로 조정합니다.

- 위치: `%APPDATA%\IDEScroll\IDEScroll.ini` (최초 로드 시 기본값으로 자동 생성)
- 내용:

  ```ini
  [Scroll]
  VerticalLines=3
  HorizontalLines=3
  ```

- `VerticalLines` / `HorizontalLines` 는 휠 1노치당 스크롤할 줄 수입니다. 값을 수정한 뒤에는 IDE를 재시작(또는 패키지 재로드)하면 반영됩니다.

## 버전별 `.bpl` 이름 (LIBSUFFIX AUTO)

패키지는 `{$LIBSUFFIX AUTO}` 를 사용해 RAD Studio 버전에 맞는 접미어를 자동으로 붙입니다.

| Delphi 버전 | Studio | 산출 파일 |
|---|---|---|
| 13.0 | 37.0 | `IDEScrollPkg370.bpl` |
| 13.1 | 37.1 | `IDEScrollPkg371.bpl` |

`.bpl` 은 버전마다 다르므로 **릴리스 자산으로 배포하지 않습니다.** 사용하는 RAD Studio 버전에서 직접 빌드하세요.

## 문제 해결

- **`F1026 File not found: '..\common\...'`** — `.dpk` 디렉터리에서 빌드하지 않은 경우. `build-bpl.cmd` 는 `pushd` 로 처리하며, IDE에서 열면 자동으로 올바르게 해석됩니다.
- **IDE에 설치되지 않음 / 로드 실패** — Win64 로 빌드했을 가능성. **Win32** 로 다시 빌드하세요.
- **"does not contain any registered components" 경고** — 정상입니다. 이 패키지는 비주얼 컴포넌트를 등록하지 않고, 로드 시 훅 활성화 + View 메뉴/도킹 미니맵만 등록합니다.
