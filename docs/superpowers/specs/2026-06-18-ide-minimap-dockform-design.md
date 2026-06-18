# IDEScroll 패키지 확장 — 도킹 미니맵 설계서

작성일: 2026-06-18

## 1. 목적

IDE 패키지(`.bpl`) 플레이버에 **ToolsAPI 도킹 가능 폼**을 추가하고, 그 폼에 **폼 디자이너 미니맵**을 제공한다. 미니맵은 현재 디자인 중인 폼 전체를 축소해 보여주고, 마우스 드래그로 디자이너의 스크롤 위치를 이동시킨다. 디자이너에서 컨트롤을 추가·삭제·이동·크기변경하면 미니맵에도 반영된다.

> 범위: **IDE 패키지(`.bpl`) 전용**. 표준 EXE 플레이버(IDE 외부 프로세스)는 디자이너 내부 이벤트와 도킹 시스템에 접근할 수 없으므로 대상에서 제외한다. 기존 휠 훅 동작(`IDEScroll.WheelHook`)은 변경하지 않는다.

## 2. 배경

- 현재 패키지는 UI 없이 로드 시 `TWheelHook`를 자동 활성화하고, 민감도는 `%APPDATA%\IDEScroll\IDEScroll.ini`에서 읽는다.
- 패키지는 **IDE 프로세스 안에 로드**되므로 EXE와 달리 ToolsAPI/DesignIntf의 디자인 알림과 도킹 시스템을 직접 사용할 수 있다.
- 휠 훅은 `WH_MOUSE_LL` 전역 훅으로 `TFormContainerForm`(폼 디자이너 컨테이너)을 찾아 `WM_VSCROLL`/`WM_HSCROLL`을 보낸다.

## 3. 범위에서 제외 (명시적 비범위)

- 휠 켜기/끄기 UI — 추가하지 않는다. 휠 훅은 기존대로 패키지 로드 시 자동 활성화된다.
- 휠 민감도 조정 UI — 추가하지 않는다. 민감도는 기존 ini/기본값(시스템 휠 스크롤 라인 수)을 그대로 사용한다.
- EXE 플레이버 변경 — 없음.
- `IDEScroll.WheelHook.pas` 변경 — 없음.

## 4. 아키텍처

`IDEScrollPkg.dpk` 의 `requires` 절에 **`designide`** 를 추가한다(ToolsAPI/DesignIntf 사용). 신규/변경 유닛 구성:

| 유닛 | 역할 |
|---|---|
| `IDEScroll.WheelHook.pas` (공용, 기존) | **변경 없음** — 휠 훅은 종전대로 자동 동작 |
| `IDEScroll.DesignerIntrospect.pas` (신규) | 디자이너 컨테이너/디자인 폼 HWND 탐색, `GetScrollInfo`/스크롤 메시지 전송, PrintWindow 풀캡처 헬퍼 |
| `IDEScroll.MinimapControl.pas` (신규) | `TCustomControl` 파생 미니맵 컨트롤 — 캡처 비트맵+뷰포트 사각형 렌더, 마우스 드래그→스크롤 |
| `IDEScroll.DockFrame.pas` + `.dfm` (신규) | `TFrame` — 미니맵 컨트롤만 배치(`alClient`) |
| `IDEScroll.DockForm.pas` (신규) | `INTACustomDockableForm` 구현 — `GetFrameClass`로 위 프레임 반환, 데스크톱 상태 저장/복원 |
| `IDEScroll.IdeHook.pas` (기존, 확장) | 패키지 진입점. 기존 휠 자동 활성화 + ini 민감도 로드 **유지**, 여기에 View 메뉴 항목 등록 + 도킹 폼 등록 + `IDesignNotification` 등록/해제 추가 |

### 4.1 단위 경계

- **DesignerIntrospect**: 디자이너 창/스크롤/캡처에 관한 Win32·HWND 수준 로직만 담당. 입력은 HWND, 출력은 비트맵·사각형·스크롤 정보. UI를 모른다.
- **MinimapControl**: 순수 VCL 컨트롤. `DesignerIntrospect`를 호출해 캡처·뷰포트를 얻어 렌더하고, 드래그 입력을 스크롤 명령으로 변환한다. 도킹/ToolsAPI를 모른다.
- **DockFrame/DockForm**: ToolsAPI 도킹 통합과 프레임 호스팅만 담당. 미니맵 내부를 모른다.
- **IdeHook**: 패키지 생명주기 + IDE 통합 배선(메뉴/등록/알림)만 담당.

## 5. 미니맵 캡처 방식 (선택: A안)

`TFormContainerForm` 안의 **실제 디자인 폼 자식창 HWND**를 찾아 `PrintWindow`로 폼 전체(스크롤로 가려진 영역 포함)를 한 번에 캡처한다. 디자인 폼 창은 실제로 전체 크기이며 컨테이너가 스크롤로 클리핑할 뿐이므로, PrintWindow는 전체 폼을 얻는다.

- 디자인 폼 HWND 탐색: 컨테이너(`TFormContainerForm`)의 자식 창을 열거해 디자인 폼 창을 찾는다. (가능하면 ToolsAPI `IOTAFormEditor`로 루트 컴포넌트의 `TWinControl.Handle`을 얻는 경로도 병행 고려.)
- 뷰포트 사각형: 컨테이너에 `GetScrollInfo(SB_HORZ/SB_VERT)`로 `nPos`/`nPage`/`nMax`를 얻어, 전체 콘텐츠 대비 현재 가시 영역을 비례 계산해 미니맵 위에 오버레이로 그린다.

대안 비교(기록용):
- (B) 컨테이너 가시영역만 BitBlt + 외삽 — 가려진 영역이 비어 미니맵 의미 반감. 기각.
- (C) ToolsAPI 컴포넌트 트리 벡터 렌더 — 모든 컨트롤 종류를 직접 그려야 해 구현량 과다. 기각.

## 6. 데이터 흐름

1. **패키지 로드**: 기존 `LoadConfig` + 휠 훅 자동 활성화 유지 → View 메뉴에 "IDEScroll" 항목 추가(`INTAServices`) → 도킹 폼 등록(`RegisterFieldAddress`/`INTAServices.CreateDockableForm`) → `IDesignNotification` 등록(`RegisterDesignNotification`).
2. **메뉴 클릭**: 도킹 폼 표시/포커스. 이미 떠 있으면 앞으로.
3. **미니맵 갱신**: `IDesignNotification` 통지(`ItemInserted`/`ItemDeleted`/`ItemsModified`/`SelectionChanged`/`DesignerOpened`/`DesignerClosed`) 수신 → dirty 플래그 설정 → 디바운스 타이머(≈150ms) 만료 시 디자인 폼 재캡처 후 미니맵 무효화. 컨테이너 스크롤 위치 변화는 뷰포트 사각형만 갱신(저비용).
4. **미니맵 드래그**: 마우스 위치 → 미니맵 좌표를 콘텐츠 좌표로 비례 환산 → 컨테이너에 `WM_VSCROLL`/`WM_HSCROLL`의 `SB_THUMBPOSITION`(필요 시 `SB_THUMBTRACK`)으로 절대 스크롤 위치 전송.

## 7. 에러 처리 / 안전

- 디자이너/디자인 폼을 찾지 못하면(코드 편집 중 등) 미니맵은 "디자이너 없음" 빈 상태를 표시하고 드래그를 무시한다.
- `PrintWindow` 실패 시 직전 캡처 비트맵을 유지해 깜빡임을 방지한다.
- 패키지 finalization에서 **메뉴 항목·도킹 폼 등록·`IDesignNotification`·디바운스 타이머·캡처 비트맵을 모두 해제**한다(IDE 언로드 시 누수/AV 방지).
- 디자인 알림·메뉴 콜백·드래그 모두 IDE 메인 스레드 컨텍스트이므로 별도 스레드 동기화는 불필요.

## 8. 코딩 규약

- **인라인 변수 미사용** — 이 프로젝트는 구형 Delphi 호환을 위해 인라인 변수를 금지한다(전역 CLAUDE.md를 오버라이드). 모든 신규 코드는 `var` 블록 선언.
- `TFrame`은 `.dfm` 동반(전역 GUI 규약). `.pas`/`.dfm`는 UTF-8 BOM + CRLF(PostToolUse hook이 자동 보정).
- `uses` 절은 네임스페이스 정규화 + tier 순서 정렬, `{$REGION 'uses'}`로 묶음.
- 빌드: dcc32(32비트, IDE가 32비트 프로세스). `build-bpl.cmd`로 컴파일.

## 9. 테스트 / 검증

자동화가 어려운 IDE 통합 기능이므로 수동 검증을 기준으로 한다.

1. dcc32로 패키지 컴파일 통과(`build-bpl.cmd`).
2. IDE에 패키지 설치 후:
   - View 메뉴에 "IDEScroll" 항목 노출, 클릭 시 도킹 폼 표시.
   - 폼을 도킹/플로팅/재도킹해도 정상, IDE 재시작 후 데스크톱 상태 복원.
   - 폼 디자이너를 열면 미니맵에 현재 폼이 축소되어 표시.
   - 디자이너에서 컨트롤 추가/이동/삭제/크기변경 시 미니맵이 (디바운스 후) 갱신.
   - 미니맵 뷰포트를 드래그하면 디자이너가 해당 위치로 스크롤.
   - 코드 편집기로 전환 등 디자이너가 없을 때 미니맵이 빈 상태로 안전하게 표시.
   - 패키지 언로드/IDE 종료 시 오류 없음.

## 10. 향후 과제 (이번 범위 밖)

- 미니맵 클릭 즉시 이동(드래그 외 단일 클릭 점프).
- 선택된 컴포넌트 하이라이트 오버레이.
