# hermes.bat 실행 테스트

- **일시**: 2026-07-27
- **대상**: `d:\GitHub\AI\hermes-agent\hermes.bat`
- **실행**: `cmd /c "D:\GitHub\AI\hermes-agent\hermes.bat …"`

---

## 결과 요약

| 명령 | exit | 결과 |
|------|------|------|
| `--version` | 0 | ✅ Hermes Agent v0.19.0, Python 3.11.9, `.venv` 경로 |
| `status` | 0 | ✅ 상태 패널 출력 |
| `model --help` | 0 | ✅ argparse help 정상 |

`hermes.exe` 해석: `D:\GitHub\AI\hermes-agent\.venv\Scripts\hermes.exe` (존재함)

---

## `--version` 출력

```
Hermes Agent v0.19.0 (2026.7.20) · upstream f2992c1c · local 1da3278d (+1 carried commit)
Install directory: D:\GitHub\AI\hermes-agent
Install method: git
Python: 3.11.9
OpenAI SDK: 2.24.0
Up to date
```

---

## 주의: HERMES_HOME / .env

이 셸에 `HERMES_HOME=C:\Users\PM\AppData\Local\hermes`가 **이미 설정**되어 있음.

| 경로 | 상태 |
|------|------|
| `%HERMES_HOME%\config.yaml` | ✗ 없음 |
| `%HERMES_HOME%\.env` | ✗ 없음 |
| `hermes-agent\.env` | ✓ 있음 (`CURSOR_API_KEY` 등) |

`hermes.bat`은 `HERMES_HOME`이 **비어 있을 때만** `%LOCALAPPDATA%\hermes\config.yaml` 존재 여부로 기본값을 넣는다.  
이미 잘못된/빈 `HERMES_HOME`이 잡혀 있으면 덮어쓰지 않음 → `hermes status`에 `.env file: ✗ not found`, Model `(not set)`로 보임.

### 우회 (테스트 시)

```powershell
$env:HERMES_HOME = "D:\GitHub\AI\hermes-agent"   # 또는 실제 프로필 홈
.\hermes.bat status
```

또는 빈 홈을 지운 뒤 bat 기본 로직에 맡기기(해당 경로에 `config.yaml`이 있을 때만 자동 설정됨).

---

## 실행 팁

현재 디렉터리가 `hermes-agent`가 아니면 `hermes.bat`만으로는 PATH에 없음 → 절대경로로 호출:

```bat
D:\GitHub\AI\hermes-agent\hermes.bat --version
```
