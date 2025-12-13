# 도깨비 NPC 시스템 설정 가이드

> **문서 버전:** 1.0  
> **최종 수정일:** 2024-12-10  
> **관련 스크립트:** `GoblinNPC.lua`, `TimeleapManager.lua`

---

## 1. 개요

도깨비 NPC 시스템은 수문도깨비의 등장, 대화, 애니메이션을 관리하는 시스템입니다.

### 주요 기능

- **등장/퇴장 연출**: 파티클 효과와 애니메이션
- **대사 시스템**: 사전 정의된 대사 + 자막 표시
- **애니메이션 제어**: 상황별 애니메이션 트리거
- **플레이어 바라보기**: 부드러운 회전으로 플레이어를 바라봄
- **씬별 시퀀스**: 타임리프, 라운드별, 엔딩 전용 시퀀스

---

## 2. Unity 설정

### 2.1 도깨비 오브젝트 구조

```
Goblin (GameObject)
├── VivenLuaBehaviour (GoblinNPC.lua)
├── Animator (Optional)
├── AudioSource (음성)
├── GoblinVisual (자식 오브젝트)
│   └── 3D Model / MeshRenderer
├── AppearParticle (ParticleSystem)
└── DisappearParticle (ParticleSystem)
```

### 2.2 VivenLuaBehaviour 설정

도깨비 오브젝트에 `VivenLuaBehaviour` 컴포넌트를 추가하고 다음을 설정합니다:

| 속성 | 타입 | 설명 | 필수 여부 |
|------|------|------|----------|
| **luaScript** | TextAsset | `GoblinNPC.lua` 스크립트 | ✅ 필수 |

### 2.3 Inspector 주입 변수

| 변수명 | 타입 | 설명 | 기본값 |
|--------|------|------|--------|
| `stageManagerName` | string | StageManager 스크립트 이름 | "StageManager" |
| `animator` | Animator | 도깨비 애니메이터 | 자동 획득 |
| `voiceAudioSource` | AudioSource | 음성 오디오 소스 | 자동 획득 |
| `appearParticle` | ParticleSystem | 등장 파티클 | (선택) |
| `disappearParticle` | ParticleSystem | 퇴장 파티클 | (선택) |
| `visualObject` | GameObject | 도깨비 비주얼 오브젝트 | (선택) |
| `appearDuration` | number | 등장 연출 시간 (초) | 1.5 |
| `disappearDuration` | number | 퇴장 연출 시간 (초) | 1.0 |
| `lookAtPlayer` | boolean | 플레이어 바라보기 활성화 | true |
| `lookAtSpeed` | number | 바라보기 회전 속도 | 2.0 |

### 2.4 TimeleapManager 연동

`TimeleapManager.lua`에서 도깨비를 사용하려면:

| 변수명 | 타입 | 설명 |
|--------|------|------|
| `goblinNPCName` | string | GoblinNPC 스크립트 이름 (기본: "GoblinNPC") |
| `goblinObject` | GameObject | 도깨비 오브젝트 (GoblinNPC 스크립트 포함) |

---

## 3. 애니메이터 설정

### 3.1 필수 트리거 (Animator Triggers)

| 트리거 이름 | 설명 | 사용 시점 |
|-------------|------|-----------|
| `Appear` | 등장 애니메이션 | 도깨비 등장 시 |
| `Disappear` | 퇴장 애니메이션 | 도깨비 퇴장 시 |
| `Talk` | 말하기 애니메이션 | 대사 재생 시 |
| `Hint` | 힌트 제스처 | 힌트 대사 시 |
| `Clap` | 박수 | 성공 축하 시 |
| `Shake` | 고개 젓기 | 실패 반응 시 |
| `Celebrate` | 축하 | 게임 클리어 시 |
| `Sad` | 슬픔 | 엔딩 진심 전달 시 |
| `Wave` | 손 흔들기 | 작별 인사 시 |
| `Give` | 주기 | 배지 지급 시 |

### 3.2 Animator Controller 예시 구조

```
Idle (기본)
  ├── Appear → Idle
  ├── Talk → Idle
  ├── Hint → Idle
  ├── Clap → Idle
  ├── Shake → Idle
  ├── Celebrate → Idle
  ├── Sad → Idle
  ├── Wave → Idle
  ├── Give → Idle
  └── Disappear → (비활성화)
```

---

## 4. 대사 데이터베이스

### 4.1 사전 정의된 대사 키

| 대사 키 | 내용 | 시간 | 애니메이션 |
|---------|------|------|------------|
| `timeleap_intro` | 타임리프 등장 대사 | 6.0초 | Talk |
| `round1_intro` | 판돌 건너기 소개 | 5.0초 | Talk |
| `round1_hint` | 판돌 힌트 | 3.0초 | Hint |
| `round1_success` | 판돌 성공 | 3.0초 | Clap |
| `round1_fail` | 판돌 실패 | 2.5초 | Shake |
| `round2_intro` | 비석치기 소개 | 5.0초 | Talk |
| `round2_hint` | 비석 힌트 | 3.0초 | Hint |
| `round2_success` | 비석 성공 | 3.0초 | Celebrate |
| `ending_truth` | 엔딩 진심 | 7.0초 | Sad |
| `ending_badge` | 배지 지급 | 4.0초 | Give |
| `ending_farewell` | 작별 인사 | 5.0초 | Wave |

### 4.2 커스텀 대사 추가

```lua
-- 새 대사 추가
goblinNPC.AddDialogue("custom_key", {
    text = "커스텀 대사 내용",
    duration = 3.0,
    animTrigger = "Talk"
})

-- 사용
goblinNPC.Speak("custom_key", audioClip)
```

---

## 5. API 사용법

### 5.1 기본 사용

```lua
-- GoblinNPC 참조 가져오기
local goblinNPC = goblinObject:GetLuaComponent("GoblinNPC")

-- 도깨비 등장
goblinNPC.Appear()

-- 도깨비 대사
goblinNPC.Speak("round1_intro", audioClip)

-- 도깨비 퇴장
goblinNPC.Disappear()
```

### 5.2 콜백과 함께 사용

```lua
-- 등장 후 콜백
goblinNPC.AppearWithCallback(function()
    Debug.Log("도깨비 등장 완료!")
end)

-- 대사 후 콜백
goblinNPC.SpeakWithCallback("round1_intro", nil, function()
    Debug.Log("대사 완료!")
    -- 다음 작업 수행
end)
```

### 5.3 씬별 시퀀스 사용

```lua
-- 타임리프 시퀀스 (등장 + 인트로 대사)
goblinNPC.PlayTimeleapSequence(function()
    -- 시퀀스 완료 후 처리
end)

-- 라운드 1 인트로
goblinNPC.PlayRound1IntroSequence(onComplete)

-- 라운드 2 인트로
goblinNPC.PlayRound2IntroSequence(onComplete)

-- 엔딩 시퀀스 (진심 + 배지 + 작별)
goblinNPC.PlayEndingSequence(function()
    -- 현대로 복귀
end)
```

### 5.4 연속 대사

```lua
-- 여러 대사 연속 재생
local dialogues = { "ending_truth", "ending_badge", "ending_farewell" }
goblinNPC.SpeakSequence(dialogues, nil, function()
    Debug.Log("모든 대사 완료!")
end)
```

### 5.5 상태 확인

```lua
-- 등장 여부
if goblinNPC.IsAppeared() then
    -- 이미 등장한 상태
end

-- 말하고 있는지
if goblinNPC.IsSpeaking() then
    -- 현재 대사 중
end
```

---

## 6. 디버깅

### 6.1 로그 확인

GoblinNPC는 모든 주요 동작에 대해 `[GoblinNPC]` 접두어로 로그를 출력합니다:

```
[GoblinNPC] Initialized
[GoblinNPC] Appearing...
[GoblinNPC] Speaking: 경복궁의 시간을 지키기 위해...
[GoblinNPC] Disappearing...
```

### 6.2 일반적인 문제

| 문제 | 원인 | 해결 방법 |
|------|------|----------|
| 도깨비가 보이지 않음 | visualObject 미설정 | Inspector에서 visualObject 설정 |
| 대사가 나오지 않음 | StageManager 미연결 | Managers 오브젝트에 StageManager 있는지 확인 |
| 애니메이션이 작동 안 함 | Animator 트리거 미설정 | Animator Controller에 트리거 추가 |
| 플레이어를 안 바라봄 | lookAtPlayer = false | true로 변경 |

---

## 7. 향후 확장

### 7.1 추가 가능한 기능

- [ ] 립싱크 (음성에 맞춘 입 움직임)
- [ ] 감정 표현 시스템
- [ ] 랜덤 idle 애니메이션
- [ ] 이동 시스템 (특정 위치로 걸어가기)
- [ ] 다중 도깨비 지원

### 7.2 확장 예시

```lua
-- 감정 표현 추가
function SetEmotion(emotion)
    if animator then
        animator:SetInteger("Emotion", emotion)
    end
end

-- 위치 이동
function MoveToPosition(targetPos, callback)
    -- NavMesh 또는 간단한 Lerp 이동 구현
end
```
