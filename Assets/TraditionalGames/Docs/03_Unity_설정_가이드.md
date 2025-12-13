# Unity 설정 가이드 - 경복궁 시간의 놀이문

> 이 문서는 `01_설계서_경복궁_시간의_놀이문.md` 기반으로 Unity Inspector 설정 방법을 안내합니다.

---

## 1. 프로젝트 폴더 구조

```
Assets/TraditionalGames/
├── Scripts/
│   ├── Manager/              # 게임 매니저
│   │   ├── GameFlowManager.lua
│   │   ├── StageManager.lua
│   │   └── AudioManager.lua
│   ├── Objects/
│   │   ├── Common/           # 공통 오브젝트
│   │   │   ├── BottariTrigger.lua
│   │   │   ├── TimeleapManager.lua
│   │   │   └── EndingManager.lua
│   │   ├── Pandol/           # 판돌 건너기
│   │   │   ├── PandolManager.lua
│   │   │   ├── PlatformStep.lua
│   │   │   └── GoalZoneTrigger.lua
│   │   └── Biseok/           # 비석치기
│   │       ├── BiseokManager.lua
│   │       └── ThrowingStone.lua
│   ├── UI/
│   └── Utils/
├── Prefabs/
│   ├── Common/
│   ├── Pandol/
│   │   ├── SafePlatform.prefab
│   │   └── BreakingPlatform.prefab
│   └── Biseok/
│       └── ThrowingStone.prefab
├── Scenes/
│   └── TraditionalGames.unity
├── Models/
├── Materials/
├── Audio/
│   ├── BGM/
│   └── SFX/
└── UI/
```

---

## 2. 씬 Hierarchy 구조

```
TraditionalGames (Scene)
│
├── --- MANAGERS ---
│   ├── GameFlowManager
│   ├── StageManager
│   └── AudioManager
│
├── --- AREAS ---
│   ├── Area_00_Prologue/        [시작 영역]
│   │   ├── Environment/
│   │   │   ├── GyeongbokgungModern
│   │   │   └── Lighting
│   │   ├── Bottari/
│   │   │   ├── BottariMesh
│   │   │   ├── SparkleParticle
│   │   │   └── TriggerZone (Collider, Is Trigger)
│   │   ├── OpenUI (상호작용 UI)
│   │   ├── SpawnPoint
│   │   └── NarrationAudio
│   │
│   ├── Area_01_Timeleap/
│   │   ├── Environment/
│   │   │   └── DanchengEffect (단청 파티클)
│   │   ├── Goblin/
│   │   │   ├── GoblinModel
│   │   │   └── GoblinAudio
│   │   ├── SoundEffects/
│   │   │   ├── BellSound
│   │   │   └── WindSound
│   │   ├── SpawnPoint
│   │   └── SubtitleUI
│   │
│   ├── Area_02_Pandol/
│   │   ├── Environment/
│   │   │   ├── Sky
│   │   │   └── FallZone (Collider, Is Trigger)
│   │   ├── Platforms/
│   │   │   ├── StartPlatform
│   │   │   ├── StepPairs/ (동적 생성 영역)
│   │   │   └── GoalPlatform
│   │   ├── GoalZone (Collider, Is Trigger)
│   │   ├── Goblin (힌트 대사)
│   │   ├── SpawnPoint
│   │   └── HintUI
│   │
│   ├── Area_03_Biseok/
│   │   ├── Environment/
│   │   │   └── GeunjeongjeonSquare
│   │   ├── Biseok/
│   │   │   ├── Biseok_01
│   │   │   ├── Biseok_02
│   │   │   └── Biseok_03
│   │   ├── StoneSpawnPoint
│   │   ├── ThrowingLine
│   │   ├── Goblin (힌트 대사)
│   │   ├── SpawnPoint
│   │   └── AttemptCountUI
│   │
│   └── Area_04_Ending/
│       ├── Environment/
│       ├── LightPillarEffect
│       ├── TimeGate (애니메이터)
│       ├── Goblin/
│       │   ├── GoblinModel
│       │   └── GoblinAudio
│       ├── Badge/
│       │   ├── BadgeModel
│       │   └── BadgeAnimator
│       ├── SpawnPoint
│       └── SubtitleUI
│
├── --- CHARACTERS ---
│   └── Goblin (공유 도깨비 - 각 영역에서 참조)
│
├── --- UI ---
│   ├── DialogCanvas
│   ├── ResultCanvas
│   └── FadeCanvas
│
└── --- XR ---
    └── XR Origin (VIVEN 표준)
```

### 영역 초기 상태
| 영역 | 초기 Active | 설명 |
|------|-------------|------|
| Area_00_Prologue | ✅ Active | 시작 영역 (현대 경복궁) |
| Area_01_Timeleap | ❌ Inactive | 보따리 열기 후 전환 |
| Area_02_Pandol | ❌ Inactive | 타임리프 후 전환 |
| Area_03_Biseok | ❌ Inactive | 판돌 클리어 후 전환 |
| Area_04_Ending | ❌ Inactive | 비석치기 클리어 후 전환 |

---

## 3. VIVEN SDK 기본 설정

### 3.1 VObject 설정 (네트워크 동기화)

**적용 대상**: 모든 동기화 필요 오브젝트

1. **Add Component → VObject**
2. **설정값:**

| 속성 | 값 | 설명 |
|------|-----|------|
| Content Type | Prepared | 맵과 함께 로드 |
| Object Sync Type | Continuous | 지속적 동기화 |

### 3.2 Grabbable 오브젝트 설정

**적용 대상**: ThrowingStone (던지는 돌)

#### 필수 컴포넌트 (순서대로 추가)
```
1. VObject
2. VivenGrabbableModule
3. VivenRigidbodyControlModule
4. VivenGrabbableRigidView
5. Rigidbody
6. Collider (Sphere 권장)
7. VivenLuaBehaviour (ThrowingStone.lua)
```

#### Rigidbody 설정
| 속성 | 값 |
|------|-----|
| Mass | 0.3 ~ 0.5 |
| Drag | 0.5 |
| Angular Drag | 0.5 |
| Use Gravity | ✅ |
| Is Kinematic | ❌ |
| Collision Detection | **Continuous Dynamic** |

#### VivenGrabbableModule 설정
| 속성 | 값 |
|------|-----|
| Grab Type | Direct |
| Movement Type | Velocity Tracking |
| Throw On Detach | ✅ |
| Throw Smoothing Duration | 0.25 |
| Throw Velocity Scale | 1.5 |

---

## 4. 매니저 설정

### 4.1 GameFlowManager

**위치**: Managers/GameFlowManager

**컴포넌트:**
1. VObject
2. VivenLuaBehaviour

**Script Name**: `GameFlowManager`

**Inspector Injection 설정:**
| 변수명 | 타입 | 연결 대상 |
|--------|------|-----------|
| stageManager | GameObject | StageManager 오브젝트 |
| audioManager | GameObject | AudioManager 오브젝트 |
| prologueArea | GameObject | Area_00_Prologue |
| timeleapArea | GameObject | Area_01_Timeleap |
| pandolArea | GameObject | Area_02_Pandol |
| biseokArea | GameObject | Area_03_Biseok |
| endingArea | GameObject | Area_04_Ending |

### 4.2 StageManager

**위치**: Managers/StageManager

**컴포넌트:**
1. VivenLuaBehaviour

**Script Name**: `StageManager`

**Inspector Injection 설정:**
| 변수명 | 타입 | 연결 대상 |
|--------|------|-----------|
| fadeDuration | number | 1.0 |

### 4.3 AudioManager

**위치**: Managers/AudioManager

**컴포넌트:**
1. Audio Source (BGM용)
2. Audio Source (SFX용)
3. VivenLuaBehaviour

**Script Name**: `AudioManager`

**Inspector Injection 설정:**
| 변수명 | 타입 | 연결 대상 |
|--------|------|-----------|
| bgmSource | AudioSource | BGM Audio Source |
| sfxSource | AudioSource | SFX Audio Source |
| bgmAmbient | AudioClip | 야간 경복궁 앰비언트 |
| bgmTimeleap | AudioClip | 타임리프 BGM |
| bgmGame | AudioClip | 라운드 플레이 BGM |
| bgmEnding | AudioClip | 엔딩 BGM |
| sfxBell | AudioClip | 종소리 |
| sfxWind | AudioClip | 바람소리 |
| sfxGlassBreak | AudioClip | 유리 깨지는 소리 |
| sfxStoneHit | AudioClip | 돌 충돌음 |
| sfxSuccess | AudioClip | 성공 차임 |
| sfxFail | AudioClip | 실패 차임 |

**BGM Audio Source 설정:**
| 속성 | 값 |
|------|-----|
| Play On Awake | ❌ |
| Loop | ✅ |
| Volume | 0.5 |

---

## 5. Area_00_Prologue 설정

### 5.1 Hierarchy 구조
```
Area_00_Prologue/
├── Environment/
│   ├── GyeongbokgungModern
│   └── Lighting
├── Bottari/
│   ├── BottariMesh
│   ├── SparkleParticle
│   └── TriggerZone
├── OpenUI
├── SpawnPoint
└── NarrationAudio
```

### 5.2 Bottari (보따리) 설정

**위치**: Area_00_Prologue/Bottari

**컴포넌트:**
1. VObject
2. VivenLuaBehaviour

**Script Name**: `BottariTrigger`

**Inspector Injection 설정:**
| 변수명 | 타입 | 연결 대상 |
|--------|------|-----------|
| gameFlowManagerName | string | "GameFlowManager" |
| openUIObject | GameObject | Area_00_Prologue/OpenUI |
| narrationAudio | AudioSource | Area_00_Prologue/NarrationAudio |

### 5.3 TriggerZone 설정

**위치**: Bottari/TriggerZone

**컴포넌트:**
1. Box Collider (Is Trigger ✅)

| 속성 | 값 |
|------|-----|
| Is Trigger | ✅ |
| Size | (1.5, 1.5, 1.5) |

---

## 6. Area_01_Timeleap 설정

### 6.1 Hierarchy 구조
```
Area_01_Timeleap/
├── Environment/
│   └── DanchengEffect
├── Goblin/
│   ├── GoblinModel
│   └── GoblinAudio
├── SoundEffects/
│   ├── BellSound
│   └── WindSound
├── SpawnPoint
└── SubtitleUI
```

### 6.2 TimeleapManager 설정

**위치**: Area_01_Timeleap

**컴포넌트:**
1. VivenLuaBehaviour

**Script Name**: `TimeleapManager`

**Inspector Injection 설정:**
| 변수명 | 타입 | 연결 대상 |
|--------|------|-----------|
| gameFlowManagerName | string | "GameFlowManager" |
| danchengEffect | GameObject | Environment/DanchengEffect |
| goblinObject | GameObject | Goblin |
| goblinVoice | AudioSource | Goblin/GoblinAudio |
| bellSound | AudioSource | SoundEffects/BellSound |
| windSound | AudioSource | SoundEffects/WindSound |
| subtitleUI | GameObject | SubtitleUI |

### 6.3 도깨비 대사 설정

| 대사 인덱스 | 내용 |
|-------------|------|
| 0 | "경복궁의 시간을 지키기 위해 너에게 두 가지 시험을 내리겠다." |

---

## 7. Area_02_Pandol (판돌 건너기) 설정

### 7.1 Hierarchy 구조
```
Area_02_Pandol/
├── Environment/
│   ├── Sky
│   └── FallZone
├── Platforms/
│   ├── StartPlatform
│   ├── StepPairs/ (동적 생성)
│   └── GoalPlatform
├── GoalZone
├── Goblin
├── SpawnPoint
└── HintUI
```

### 7.2 PandolManager 설정

**위치**: Area_02_Pandol

**컴포넌트:**
1. VObject
2. VivenLuaBehaviour

**Script Name**: `PandolManager`

**Inspector Injection 설정:**
| 변수명 | 타입 | 연결 대상 | 기본값 |
|--------|------|-----------|--------|
| safePlatformPrefab | GameObject | Prefabs/Pandol/SafePlatform | - |
| breakingPlatformPrefab | GameObject | Prefabs/Pandol/BreakingPlatform | - |
| platformStartPoint | Transform | Platforms/StartPlatform | - |
| spawnPoint | Transform | SpawnPoint | - |
| goalZone | GameObject | GoalZone | - |
| stepCount | number | - | 10 |
| stepDistance | number | - | 1.5 |
| pairWidth | number | - | 1.0 |
| fallThreshold | number | - | -10 |
| glassBreakSound | AudioClip | (SFX) | - |
| gameFlowManagerName | string | - | "GameFlowManager" |

### 7.3 SafePlatform Prefab 설정

**컴포넌트:**
1. VObject
2. Box Collider
3. MeshRenderer
4. VivenLuaBehaviour

**Script Name**: `PlatformStep`

**Collider 설정:**
| 속성 | 값 |
|------|-----|
| Is Trigger | ❌ |

### 7.4 BreakingPlatform Prefab 설정

**컴포넌트:**
1. VObject
2. Box Collider
3. MeshRenderer
4. ParticleSystem (깨지는 효과)
5. VivenLuaBehaviour

**Script Name**: `PlatformStep`

### 7.5 FallZone 설정

**컴포넌트:**
1. Box Collider (Is Trigger ✅)

| 속성 | 값 |
|------|-----|
| Is Trigger | ✅ |
| Size | 영역 전체 (예: 50, 5, 50) |
| Position Y | fallThreshold 보다 약간 위 |

### 7.6 GoalZone 설정

**위치**: Area_02_Pandol/GoalZone

**컴포넌트:**
1. Box Collider (Is Trigger ✅)
2. VivenLuaBehaviour

**Script Name**: `GoalZoneTrigger`

**Inspector Injection 설정:**
| 변수명 | 타입 | 연결 대상 |
|--------|------|-----------|
| managerName | string | "PandolManager" |

---

## 8. Area_03_Biseok (비석치기) 설정

### 8.1 Hierarchy 구조
```
Area_03_Biseok/
├── Environment/
│   └── GeunjeongjeonSquare
├── Biseok/
│   ├── Biseok_01
│   ├── Biseok_02
│   └── Biseok_03
├── StoneSpawnPoint
├── ThrowingLine
├── Goblin
├── SpawnPoint
└── AttemptCountUI
```

### 8.2 BiseokManager 설정

**위치**: Area_03_Biseok

**컴포넌트:**
1. VObject
2. VivenLuaBehaviour

**Script Name**: `BiseokManager`

**Inspector Injection 설정:**
| 변수명 | 타입 | 연결 대상 | 기본값 |
|--------|------|-----------|--------|
| stonePrefab | GameObject | Prefabs/Biseok/ThrowingStone | - |
| stoneSpawnPoint | Transform | StoneSpawnPoint | - |
| biseokObjects | GameObject[] | [Biseok_01, Biseok_02, Biseok_03] | - |
| requiredKnockdown | number | - | 2 |
| knockdownAngle | number | - | 60 |
| maxAttempts | number | - | 5 |
| gameFlowManagerName | string | - | "GameFlowManager" |

### 8.3 비석 (Biseok) 설정

**각 Biseok_01, Biseok_02, Biseok_03에 적용**

**컴포넌트:**
1. VObject
2. Rigidbody
3. Box Collider
4. MeshRenderer

**Rigidbody 설정:**
| 속성 | 값 |
|------|-----|
| Mass | 2.0 |
| Drag | 0.5 |
| Angular Drag | 0.5 |
| Use Gravity | ✅ |
| Is Kinematic | ❌ |
| Collision Detection | **Continuous Dynamic** |

**Tag**: `Biseok`

### 8.4 ThrowingStone Prefab 설정

**컴포넌트:**
1. VObject
2. VivenGrabbableModule
3. VivenRigidbodyControlModule
4. VivenGrabbableRigidView
5. Rigidbody
6. Sphere Collider
7. VivenLuaBehaviour

**Script Name**: `ThrowingStone`

**Inspector Injection 설정:**
| 변수명 | 타입 | 연결 대상 |
|--------|------|-----------|
| gameManagerName | string | "BiseokManager" |

**Rigidbody 설정:**
| 속성 | 값 |
|------|-----|
| Mass | 0.3 |
| Collision Detection | **Continuous Dynamic** |

**VivenGrabbableModule 설정:**
| 속성 | 값 |
|------|-----|
| Throw On Detach | ✅ |
| Throw Velocity Scale | 1.5 |

---

## 9. Area_04_Ending 설정

### 9.1 Hierarchy 구조
```
Area_04_Ending/
├── Environment/
├── LightPillarEffect
├── TimeGate
├── Goblin/
│   ├── GoblinModel
│   └── GoblinAudio
├── Badge/
│   ├── BadgeModel
│   └── BadgeAnimator
├── SpawnPoint
└── SubtitleUI
```

### 9.2 EndingManager 설정

**위치**: Area_04_Ending

**컴포넌트:**
1. VivenLuaBehaviour

**Script Name**: `EndingManager`

**Inspector Injection 설정:**
| 변수명 | 타입 | 연결 대상 |
|--------|------|-----------|
| gameFlowManagerName | string | "GameFlowManager" |
| lightPillarEffect | GameObject | LightPillarEffect |
| timeGateAnimator | Animator | TimeGate |
| goblinObject | GameObject | Goblin |
| goblinVoice | AudioSource | Goblin/GoblinAudio |
| badgeObject | GameObject | Badge |
| badgeAnimator | Animator | Badge/BadgeAnimator |
| subtitleUI | GameObject | SubtitleUI |
| modernSpawnPoint | Transform | Area_00_Prologue/SpawnPoint |

### 9.3 도깨비 엔딩 대사

| 대사 인덱스 | 내용 |
|-------------|------|
| 0 | "전통이 잊혀져 가는 것이 두려웠기 때문이다..." |
| 1 | "놀이에는 우리의 시간과 마음이 이어져 있다." |

---

## 10. UI 캔버스 설정

### 10.1 FadeCanvas

```
FadeCanvas
└── FadeImage
```

**Canvas 설정:**
| 속성 | 값 |
|------|-----|
| Render Mode | Screen Space - Overlay |
| Sort Order | 999 |

**FadeImage 설정:**
| 속성 | 값 |
|------|-----|
| Color | Black (0, 0, 0, 0) |
| Raycast Target | ❌ |

### 10.2 DialogCanvas (자막)

```
DialogCanvas
└── SubtitleText
```

**Canvas 설정:**
| 속성 | 값 |
|------|-----|
| Render Mode | World Space |
| Event Camera | XR Camera |

---

## 11. 태그 및 레이어 설정

### Tags (Edit → Project Settings → Tags and Layers)
- `Player`
- `Biseok`
- `ThrowingStone`
- `Platform`
- `GoalZone`

### Layers
- `Grabbable`
- `Trigger`
- `Environment`
- `UI`

---

## 12. 설정 완료 체크리스트

### 매니저
- [ ] GameFlowManager 설정 완료
- [ ] StageManager 설정 완료
- [ ] AudioManager 설정 완료

### Area_00_Prologue
- [ ] 현대 경복궁 환경 배치 완료
- [ ] Bottari + TriggerZone 설정 완료
- [ ] BottariTrigger 스크립트 연결 완료

### Area_01_Timeleap
- [ ] 타임리프 환경 배치 완료
- [ ] 도깨비 모델 배치 완료
- [ ] TimeleapManager 설정 완료
- [ ] 사운드 효과 연결 완료

### Area_02_Pandol
- [ ] 판돌 환경 배치 완료
- [ ] SafePlatform/BreakingPlatform 프리팹 생성 완료
- [ ] PandolManager 설정 완료
- [ ] FallZone 설정 완료
- [ ] GoalZone + GoalZoneTrigger 설정 완료

### Area_03_Biseok
- [ ] 비석치기 환경 배치 완료
- [ ] 비석 3개 배치 및 Rigidbody 설정 완료
- [ ] ThrowingStone 프리팹 생성 완료 (Grabbable)
- [ ] BiseokManager 설정 완료

### Area_04_Ending
- [ ] 엔딩 환경 배치 완료
- [ ] 빛 기둥/시간문 효과 배치 완료
- [ ] 배지 오브젝트 배치 완료
- [ ] EndingManager 설정 완료

### UI
- [ ] FadeCanvas 설정 완료
- [ ] DialogCanvas 설정 완료

### 전체
- [ ] 모든 영역 전환 테스트 완료
- [ ] 전체 게임 플로우 테스트 완료
- [ ] 빌드 설정 확인 완료

---

## 13. 빌드 설정

### Build Settings
1. **File → Build Settings**
2. **Platform**: Android (Quest) 또는 Windows (PC VR)
3. **씬 추가**: TraditionalGames

### XR Plugin Management
1. **Edit → Project Settings → XR Plug-in Management**
2. Android: Oculus 활성화
3. Windows: OpenXR 활성화

### Quality Settings
| 속성 | 값 |
|------|-----|
| V Sync Count | Don't Sync |
| Anti Aliasing | 4x Multi Sampling |
| Texture Quality | Full Res |

### 성능 목표
- 프레임레이트: 72fps 이상
- 로딩 시간: 5초 이내
- 메모리: 2GB 이하
