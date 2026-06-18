# IDEScroll

> 한국어 | [English](README.en.md)

델파이 IDE 폼 디자이너의 **마우스 휠 스크롤 방향을 바꿔주는** 작은 유틸리티입니다.
큰 폼을 디자인할 때 휠로 세로, `Ctrl+휠`로 가로로 빠르게 스크롤할 수 있습니다.

## 기능

- **휠** → 세로 스크롤
- **Ctrl + 휠** → 가로 스크롤
- 세로 / 가로 **스크롤 감도** 개별 조정 (휠 1노치당 스크롤할 줄 수)
- 감도 설정은 실행 파일 옆 `IDEScroll.ini` 에 자동 저장 / 복원

## 작동 원리

- Windows 저수준 마우스 훅(`WH_MOUSE_LL`)을 사용합니다. IDE 프로세스에 **인젝션하지 않으므로** Delphi / C++Builder **버전·비트수와 무관**하게 동작합니다.
- 커서 아래 창에서 부모를 거슬러 올라가 폼 디자이너 컨테이너 창(`TFormContainerForm`)을 찾고, 휠 이벤트를 `WM_VSCROLL` / `WM_HSCROLL` 메시지로 변환해 전달합니다.
- 디자이너 위가 아닐 때는 휠 동작에 전혀 개입하지 않습니다.

## 다운로드

[Releases](../../releases) 에서 `IDEScroll.exe` 를 받으세요. 별도 설치가 필요 없는 단일 실행 파일입니다.

## 사용법

1. `IDEScroll.exe` 실행
2. **후킹 시작** 버튼 클릭 (또는 `Enter`)
3. 세로 / 가로 감도를 원하는 값으로 조정
4. Delphi IDE 폼 디자이너에서 **휠**(세로) / **Ctrl+휠**(가로) 사용
5. 다시 버튼을 누르면 후킹이 중지됩니다. 종료 시 감도 설정이 저장됩니다.

> 백그라운드에서 계속 동작하도록 두려면 프로그램을 띄워둔 채로 후킹을 켜 두면 됩니다.

## 두 가지 형태

| 형태 | 설명 | 타깃 |
|---|---|---|
| **스탠드얼론 EXE** | 별도 실행 파일. 켜고 끄는 UI + 감도 설정 제공 | Win64 |
| **IDE 패키지 (.bpl)** | IDE에 설치하면 자동 후킹 + **도킹형 미니맵** 제공 | Win32 (IDE가 32비트 프로세스) |

> 패키지 버전의 감도는 `%APPDATA%\IDEScroll\IDEScroll.ini` 에서 조정합니다(첫 실행 시 기본값으로 생성).

### 패키지 설치

1. `build-bpl.cmd` 로 빌드 → `bin\IDEScrollPkg370.bpl` 생성 (Delphi 13.0 기준; 13.1 IDE에서 빌드하면 `...371.bpl`)
2. IDE 메뉴 **Component → Install Packages → Add** 에서 해당 `.bpl` 선택
3. 설치 후 IDE 디자이너에서 휠 / Ctrl+휠 사용 (별도 실행 불필요)

자세한 빌드·설치 절차는 [패키지 빌드 가이드](docs/build-package.md) 를 참고하세요.

### 미니맵 (IDE 패키지 전용)

IDE 패키지를 설치하면 **View 메뉴 → IDEScroll Minimap** 으로 도킹 가능한 미니맵 창을 열 수 있습니다. ToolsAPI 도킹 폼(`INTACustomDockableForm`)으로 구현되어 다른 IDE 창처럼 자유롭게 도킹/플로팅할 수 있습니다.

- 폼 디자이너의 **전체 스크롤 영역**을 축소해 폼 콘텐츠와 함께 보여주고, **현재 보이는 영역**을 반투명 강조 박스로 표시합니다.
- 강조 박스를 **드래그/드롭**하거나, 미니맵 위에서 **마우스 휠**(세로) / **Ctrl+휠**(가로)을 굴리면 디자이너가 그 위치로 스크롤됩니다. 박스 바깥을 클릭하면 그 지점으로 즉시 이동합니다.
- 폼에서 컨트롤을 추가/이동/삭제하면 미니맵이 자동 갱신됩니다(디자인 알림 기반, 디바운스 재캡처).
- **IDE 테마**(라이트/다크)에 맞춰 색이 적용됩니다.
- 마지막 **도킹/플로팅 위치를 기억**해 다음에 같은 자리에 표시됩니다.

> 미니맵은 패키지가 IDE 프로세스 안에서 동작하기에 가능한 기능으로, EXE 버전에는 제공되지 않습니다.

## 빌드

- 요구: Delphi 13 (RAD Studio 37.0) 권장
- EXE (Win64): `build.cmd`
- 패키지 (Win32): `build-bpl.cmd`

  각 스크립트의 `STUDIO` 경로를 설치된 RAD Studio 버전에 맞게 수정하면 다른 버전으로도 빌드할 수 있습니다.
  또는 `src\exe\IDEScroll.dpr` / `src\bpl\IDEScrollPkg.dpk` 를 IDE에서 열어 빌드합니다.

## 프로젝트 구조

```
src/
  common/                    공유 코드
    IDEScroll.WheelHook.pas  WH_MOUSE_LL 훅 + 휠 → 스크롤 변환 로직 (EXE/패키지 공용)
  exe/                       스탠드얼론 실행 파일 (Win64)
    IDEScroll.dpr            진입점 (VCL 애플리케이션)
    Main.pas / Main.dfm      UI (후킹 토글 + 감도 설정)
    IDEScroll.rc / .RES      리소스
  bpl/                       IDE 패키지 (Win32, Delphi 13)
    IDEScrollPkg.dpk         design-time 패키지 (requires: rtl, vcl, designide)
    IDEScroll.IdeHook.pas    훅 자동 활성화 + View 메뉴/도킹 폼 등록
    IDEScroll.DockForm.pas   ToolsAPI 도킹 폼 (INTACustomDockableForm)
    IDEScroll.DockFrame.pas  미니맵 호스트 프레임 (+ .dfm)
    IDEScroll.MinimapControl.pas      미니맵 컨트롤 (렌더 + 드래그/휠 스크롤)
    IDEScroll.DesignerIntrospect.pas  디자이너/스크롤 조회 + 폼 캡처
    IDEScroll.DesignNotifier.pas      디자인 변경 통지 → 미니맵 갱신
    IDEScroll.Theming.pas    IDE 테마 색 + 변경 통지
build.cmd                    EXE 빌드 (Win64)
build-bpl.cmd                패키지 빌드 (Win32)
```

> EXE와 패키지는 `src/common/IDEScroll.WheelHook.pas` 훅 로직을 공유합니다.

## 호환성

- 동작 대상: 폼 디자이너 컨테이너가 `TFormContainerForm` 인 모든 Delphi / C++Builder 버전
- 빌드/검증: Delphi 13 (RAD Studio 37.0), Windows 11 (Win64)

## 라이선스

[MIT](LICENSE) © 2026 civilian7
