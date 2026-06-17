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

## 빌드

- 요구: Delphi 13 (RAD Studio 37.0) 권장, 타깃 **Win64**
- 명령줄 빌드:

  ```cmd
  build.cmd
  ```

  `build.cmd` 안의 `STUDIO` 경로를 설치된 RAD Studio 버전에 맞게 수정하면 다른 버전으로도 빌드할 수 있습니다.

- 또는 `src\IDEScroll.dpr` 를 IDE에서 열어 Win64 구성으로 빌드합니다.

## 프로젝트 구조

```
src/
  IDEScroll.dpr            진입점 (VCL 애플리케이션)
  IDEScroll.WheelHook.pas  WH_MOUSE_LL 훅 + 휠 → 스크롤 변환 로직
  Main.pas / Main.dfm      UI (후킹 토글 + 감도 설정)
  IDEScroll.rc / .RES      리소스
build.cmd                  Win64 빌드 스크립트
```

## 호환성

- 동작 대상: 폼 디자이너 컨테이너가 `TFormContainerForm` 인 모든 Delphi / C++Builder 버전
- 빌드/검증: Delphi 13 (RAD Studio 37.0), Windows 11 (Win64)

## 라이선스

[MIT](LICENSE) © 2026 civilian7
