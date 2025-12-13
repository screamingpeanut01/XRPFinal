# Lua 스크립트 가이드 - 경복궁 시간의 놀이문

## 1. 기본 스크립트 구조

### 1.1 표준 템플릿

```lua
--[[
    스크립트명: ScriptName.lua
    설명: 스크립트 설명
    작성일: YYYY-MM-DD
]]

--region Injection list
local _INJECTED_ORDER = 0
local function checkInject(OBJECT)
    _INJECTED_ORDER = _INJECTED_ORDER + 1
    assert(OBJECT, _INJECTED_ORDER .. "th object is missing")
    return OBJECT
end
local function NullableInject(OBJECT)
    _INJECTED_ORDER = _INJECTED_ORDER + 1
    if OBJECT == nil then
        Debug.Log(_INJECTED_ORDER .. "th object is missing")
    end
    return OBJECT
end

---@type GameObject
---@details 설명
TargetObject = checkInject(TargetObject)

---@type number
---@details 설정값 설명
ConfigValue = checkInject(ConfigValue)
--endregion

--region Local variables
local util = require 'xlua.util'
local component = nil
local isInitialized = false
--endregion

--region Lifecycle functions
function awake()
    -- 컴포넌트 캐싱
    component = self:GetComponent("ComponentName")
end

function start()
    -- 초기화 로직
    isInitialized = true
end

function onEnable()
    -- 이벤트 리스너 등록
end

function onDisable()
    -- 이벤트 리스너 해제
end

function update()
    -- 프레임 업데이트
end
--endregion

--region Public functions
function PublicFunction()
    -- 외부에서 호출 가능한 함수
end
--endregion

--region Private functions
local function privateFunction()
    -- 내부 전용 함수
end
--endregion
```

---

## 2. 매니저 스크립트 템플릿

### 2.1 GameFlowManager.lua

```lua
--[[
    GameFlowManager.lua
    전체 게임 흐름을 제어하는 매니저
]]

--region Injection list
local _INJECTED_ORDER = 0
local function checkInject(OBJECT)
    _INJECTED_ORDER = _INJECTED_ORDER + 1
    assert(OBJECT, _INJECTED_ORDER .. "th object is missing")
    return OBJECT
end

---@type GameObject
AreaManager = checkInject(AreaManager)

---@type GameObject
PandolManager = checkInject(PandolManager)

---@type GameObject
BiseokManager = checkInject(BiseokManager)
--endregion

--region Local variables
local util = require 'xlua.util'
local currentRound = 0
local gameState = "Loading" -- Loading, Prologue, Timeleap, Pandol, Biseok, Ending

local areaManagerScript = nil
local pandolManagerScript = nil
local biseokManagerScript = nil
--endregion

--region Lifecycle
function awake()
    areaManagerScript = AreaManager:GetLuaComponent("AreaManager")
    pandolManagerScript = PandolManager:GetLuaComponent("PandolManager")
    biseokManagerScript = BiseokManager:GetLuaComponent("BiseokManager")
end

function start()
    SetGameState("Loading")
end
--endregion

--region Game State
function SetGameState(newState)
    gameState = newState
    Debug.Log("[GameFlow] State: " .. gameState)

    if gameState == "Loading" then
        OnLoadingStart()
    elseif gameState == "Prologue" then
        OnPrologueStart()
    elseif gameState == "Timeleap" then
        OnTimeleapStart()
    elseif gameState == "Pandol" then
        OnPandolStart()
    elseif gameState == "Biseok" then
        OnBiseokStart()
    elseif gameState == "Ending" then
        OnEndingStart()
    end
end

function GetGameState()
    return gameState
end
--endregion

--region State Handlers
function OnLoadingStart()
    -- 로딩 화면 표시
    self:StartCoroutine(util.cs_generator(function()
        coroutine.yield(WaitForSeconds(2.0))
        SetGameState("Prologue")
    end))
end

function OnPrologueStart()
    currentRound = 0
    areaManagerScript.TransitionTo("Prologue")
end

function OnTimeleapStart()
    areaManagerScript.TransitionTo("Timeleap")
end

function OnPandolStart()
    currentRound = 1
    areaManagerScript.TransitionTo("Pandol")
    pandolManagerScript.StartGame()
end

function OnBiseokStart()
    currentRound = 2
    areaManagerScript.TransitionTo("Biseok")
    biseokManagerScript.StartGame()
end

function OnEndingStart()
    areaManagerScript.TransitionTo("Ending")
end
--endregion

--region Round Management
function OnRoundClear()
    Debug.Log("[GameFlow] Round " .. currentRound .. " Clear!")

    if currentRound == 1 then
        SetGameState("Biseok")
    elseif currentRound == 2 then
        SetGameState("Ending")
    end
end

function OnRoundFail()
    Debug.Log("[GameFlow] Round " .. currentRound .. " Failed!")
    -- 실패 처리 (재시도 또는 게임오버)
end
--endregion
```

### 2.2 AreaManager.lua

```lua
--[[
    AreaManager.lua
    영역 전환 및 텔레포트 관리
]]

--region Injection list
local _INJECTED_ORDER = 0
local function checkInject(OBJECT)
    _INJECTED_ORDER = _INJECTED_ORDER + 1
    assert(OBJECT, _INJECTED_ORDER .. "th object is missing")
    return OBJECT
end

---@type GameObject
Area_Loading = checkInject(Area_Loading)

---@type GameObject
Area_Prologue = checkInject(Area_Prologue)

---@type GameObject
Area_Timeleap = checkInject(Area_Timeleap)

---@type GameObject
Area_Pandol = checkInject(Area_Pandol)

---@type GameObject
Area_Biseok = checkInject(Area_Biseok)

---@type GameObject
Area_Ending = checkInject(Area_Ending)

---@type number
FadeDuration = checkInject(FadeDuration) or 1.0
--endregion

--region Local variables
local util = require 'xlua.util'
local areas = {}
local currentArea = nil
local isTransitioning = false
--endregion

--region Lifecycle
function awake()
    areas = {
        Loading = Area_Loading,
        Prologue = Area_Prologue,
        Timeleap = Area_Timeleap,
        Pandol = Area_Pandol,
        Biseok = Area_Biseok,
        Ending = Area_Ending
    }
end

function start()
    -- 모든 영역 비활성화 후 로딩만 활성화
    for name, area in pairs(areas) do
        area:SetActive(name == "Loading")
    end
    currentArea = "Loading"
end
--endregion

--region Public Functions
function TransitionTo(areaName)
    if isTransitioning then
        Debug.LogWarning("[AreaManager] Already transitioning!")
        return
    end

    if areas[areaName] == nil then
        Debug.LogError("[AreaManager] Area not found: " .. areaName)
        return
    end

    self:StartCoroutine(util.cs_generator(function()
        isTransitioning = true

        -- 페이드 아웃
        UI.FadeOut(FadeDuration)
        coroutine.yield(WaitForSeconds(FadeDuration))

        -- 영역 전환
        if currentArea and areas[currentArea] then
            areas[currentArea]:SetActive(false)
        end
        areas[areaName]:SetActive(true)

        -- 텔레포트
        local spawnPoint = areas[areaName].transform:Find("PlayerSpawnPoint")
        if spawnPoint then
            Player.Mine.TeleportPlayer(spawnPoint.position, spawnPoint.rotation)
        end

        currentArea = areaName

        -- 페이드 인
        UI.FadeIn(FadeDuration)
        coroutine.yield(WaitForSeconds(FadeDuration))

        isTransitioning = false
        Debug.Log("[AreaManager] Transitioned to: " .. areaName)
    end))
end

function GetCurrentArea()
    return currentArea
end
--endregion
```

---

## 3. 게임 오브젝트 스크립트 템플릿

### 3.1 PlatformStep.lua (판돌)

```lua
--[[
    PlatformStep.lua
    판돌 건너기의 개별 발판 스크립트
]]

--region Injection list
local _INJECTED_ORDER = 0
local function checkInject(OBJECT)
    _INJECTED_ORDER = _INJECTED_ORDER + 1
    assert(OBJECT, _INJECTED_ORDER .. "th object is missing")
    return OBJECT
end

---@type number
PlatformIndex = checkInject(PlatformIndex)

---@type boolean
IsSafe = checkInject(IsSafe)

---@type number
ShakeDuration = checkInject(ShakeDuration) or 0.5

---@type number
FallDelay = checkInject(FallDelay) or 1.0
--endregion

--region Local variables
local util = require 'xlua.util'
local manager = nil
local rigidbody = nil
local collider = nil
local originalPosition = nil
local isActivated = false
local isFalling = false
--endregion

--region Lifecycle
function awake()
    rigidbody = self:GetComponent("Rigidbody")
    collider = self:GetComponent("Collider")
    originalPosition = self.transform.position
end

function start()
    -- PandolManager 찾기
    local managerObj = GameObject.Find("PandolManager")
    if managerObj then
        manager = managerObj:GetLuaComponent("PandolManager")
    end
end
--endregion

--region Trigger Events
function onTriggerEnter(other)
    if isActivated or isFalling then return end

    -- 플레이어 감지
    if other.tag == "Player" then
        isActivated = true
        OnPlayerStep()
    end
end
--endregion

--region Platform Logic
function OnPlayerStep()
    Debug.Log("[Platform " .. PlatformIndex .. "] Stepped! Safe: " .. tostring(IsSafe))

    if IsSafe then
        -- 안전한 발판: 약간 흔들림
        self:StartCoroutine(util.cs_generator(function()
            ShakePlatform(0.02, ShakeDuration * 0.5)
        end))
    else
        -- 위험한 발판: 흔들리다가 떨어짐
        self:StartCoroutine(util.cs_generator(function()
            ShakePlatform(0.05, ShakeDuration)
            coroutine.yield(WaitForSeconds(FallDelay))
            FallPlatform()
        end))
    end

    -- 매니저에 알림
    if manager then
        manager.OnPlatformStepped(PlatformIndex, IsSafe)
    end
end

function ShakePlatform(intensity, duration)
    local elapsed = 0
    while elapsed < duration do
        local offsetX = (math.random() - 0.5) * intensity
        local offsetZ = (math.random() - 0.5) * intensity
        self.transform.position = Vector3(
            originalPosition.x + offsetX,
            originalPosition.y,
            originalPosition.z + offsetZ
        )
        elapsed = elapsed + Time.deltaTime
        coroutine.yield(nil)
    end
    self.transform.position = originalPosition
end

function FallPlatform()
    isFalling = true

    -- 물리 활성화
    if rigidbody then
        rigidbody.isKinematic = false
        rigidbody.useGravity = true
    end

    -- 콜라이더 비활성화 (플레이어 통과)
    if collider then
        collider.enabled = false
    end

    Debug.Log("[Platform " .. PlatformIndex .. "] Falling!")
end
--endregion

--region Public Functions
function ResetPlatform()
    isActivated = false
    isFalling = false

    self.transform.position = originalPosition

    if rigidbody then
        rigidbody.isKinematic = true
        rigidbody.useGravity = false
        rigidbody.velocity = Vector3.zero
        rigidbody.angularVelocity = Vector3.zero
    end

    if collider then
        collider.enabled = true
    end
end
--endregion
```

### 3.2 ThrowingStone.lua (비석치기 돌)

```lua
--[[
    ThrowingStone.lua
    비석치기에서 던지는 돌
]]

--region Injection list
local _INJECTED_ORDER = 0
local function checkInject(OBJECT)
    _INJECTED_ORDER = _INJECTED_ORDER + 1
    assert(OBJECT, _INJECTED_ORDER .. "th object is missing")
    return OBJECT
end

---@type GameObject
SpawnPoint = checkInject(SpawnPoint)

---@type number
RespawnDelay = checkInject(RespawnDelay) or 2.0
--endregion

--region Local variables
local util = require 'xlua.util'
local grabbable = nil
local rigidbody = nil
local manager = nil
local isThrown = false
local originalPosition = nil
local originalRotation = nil
--endregion

--region Lifecycle
function awake()
    grabbable = self:GetComponent("VivenGrabbableModule")
    rigidbody = self:GetComponent("Rigidbody")

    if SpawnPoint then
        originalPosition = SpawnPoint.transform.position
        originalRotation = SpawnPoint.transform.rotation
    else
        originalPosition = self.transform.position
        originalRotation = self.transform.rotation
    end
end

function start()
    local managerObj = GameObject.Find("BiseokManager")
    if managerObj then
        manager = managerObj:GetLuaComponent("BiseokManager")
    end
end

function onEnable()
    if grabbable then
        grabbable.onGrabEvent:AddListener(OnGrab)
        grabbable.onReleaseEvent:AddListener(OnRelease)
    end
end

function onDisable()
    if grabbable then
        grabbable.onGrabEvent:RemoveListener(OnGrab)
        grabbable.onReleaseEvent:RemoveListener(OnRelease)
    end
end
--endregion

--region Grab Events
function OnGrab()
    Debug.Log("[ThrowingStone] Grabbed")
    isThrown = false

    -- 햅틱 피드백
    XR.StartControllerVibration(false, 0.3, 0.1)
end

function OnRelease()
    Debug.Log("[ThrowingStone] Released (Thrown)")
    isThrown = true

    -- 일정 시간 후 리스폰
    self:StartCoroutine(util.cs_generator(function()
        coroutine.yield(WaitForSeconds(RespawnDelay))
        RespawnStone()
    end))
end
--endregion

--region Collision
function onCollisionEnter(collision)
    if not isThrown then return end

    -- 비석과 충돌
    if collision.gameObject.tag == "TargetStone" then
        Debug.Log("[ThrowingStone] Hit target stone!")

        -- 충돌 사운드 및 햅틱
        XR.StartControllerVibration(false, 0.5, 0.2)

        -- 매니저에 알림
        if manager then
            manager.OnStoneHit(collision.gameObject)
        end
    end
end
--endregion

--region Public Functions
function RespawnStone()
    isThrown = false

    -- 위치 초기화
    self.transform.position = originalPosition
    self.transform.rotation = originalRotation

    -- 물리 초기화
    if rigidbody then
        rigidbody.velocity = Vector3.zero
        rigidbody.angularVelocity = Vector3.zero
    end

    Debug.Log("[ThrowingStone] Respawned")
end
--endregion
```

### 3.3 TargetStone.lua (목표 비석)

```lua
--[[
    TargetStone.lua
    비석치기의 목표 비석
]]

--region Injection list
local _INJECTED_ORDER = 0
local function checkInject(OBJECT)
    _INJECTED_ORDER = _INJECTED_ORDER + 1
    assert(OBJECT, _INJECTED_ORDER .. "th object is missing")
    return OBJECT
end

---@type number
KnockAngleThreshold = checkInject(KnockAngleThreshold) or 45
--endregion

--region Local variables
local util = require 'xlua.util'
local rigidbody = nil
local manager = nil
local isKnockedDown = false
local originalPosition = nil
local originalRotation = nil
local checkRoutine = nil
--endregion

--region Lifecycle
function awake()
    rigidbody = self:GetComponent("Rigidbody")
    originalPosition = self.transform.position
    originalRotation = self.transform.rotation
end

function start()
    local managerObj = GameObject.Find("BiseokManager")
    if managerObj then
        manager = managerObj:GetLuaComponent("BiseokManager")
    end
end

function onEnable()
    -- 쓰러짐 체크 시작
    checkRoutine = self:StartCoroutine(util.cs_generator(CheckKnockDown))
end

function onDisable()
    if checkRoutine then
        self:StopCoroutine(checkRoutine)
        checkRoutine = nil
    end
end
--endregion

--region Knock Down Check
function CheckKnockDown()
    while true do
        coroutine.yield(WaitForSeconds(0.1))

        if isKnockedDown then
            goto continue
        end

        -- 비석의 기울기 확인
        local upVector = self.transform.up
        local angle = Vector3.Angle(upVector, Vector3.up)

        if angle > KnockAngleThreshold then
            OnKnockedDown()
        end

        ::continue::
    end
end

function OnKnockedDown()
    isKnockedDown = true
    Debug.Log("[TargetStone] Knocked down! Angle exceeded " .. KnockAngleThreshold)

    -- 매니저에 알림
    if manager then
        manager.OnTargetKnockedDown(self.gameObject)
    end
end
--endregion

--region Public Functions
function ResetStone()
    isKnockedDown = false

    -- 위치/회전 초기화
    self.transform.position = originalPosition
    self.transform.rotation = originalRotation

    -- 물리 초기화
    if rigidbody then
        rigidbody.velocity = Vector3.zero
        rigidbody.angularVelocity = Vector3.zero
    end

    Debug.Log("[TargetStone] Reset")
end

function IsKnockedDown()
    return isKnockedDown
end
--endregion
```

---

## 4. 트리거 스크립트 템플릿

### 4.1 GoalZoneTrigger.lua

```lua
--[[
    GoalZoneTrigger.lua
    판돌 건너기 골인 영역
]]

--region Local variables
local manager = nil
local hasTriggered = false
--endregion

--region Lifecycle
function start()
    local managerObj = GameObject.Find("PandolManager")
    if managerObj then
        manager = managerObj:GetLuaComponent("PandolManager")
    end
end
--endregion

--region Trigger
function onTriggerEnter(other)
    if hasTriggered then return end

    if other.tag == "Player" then
        hasTriggered = true
        Debug.Log("[GoalZone] Player reached goal!")

        if manager then
            manager.OnGoalReached()
        end
    end
end

function ResetTrigger()
    hasTriggered = false
end
--endregion
```

### 4.2 FallZoneTrigger.lua

```lua
--[[
    FallZoneTrigger.lua
    판돌 건너기 낙하 감지 영역
]]

--region Local variables
local manager = nil
--endregion

--region Lifecycle
function start()
    local managerObj = GameObject.Find("PandolManager")
    if managerObj then
        manager = managerObj:GetLuaComponent("PandolManager")
    end
end
--endregion

--region Trigger
function onTriggerEnter(other)
    if other.tag == "Player" then
        Debug.Log("[FallZone] Player fell!")

        if manager then
            manager.OnPlayerFall()
        end
    end
end
--endregion
```

---

## 5. 자주 사용하는 API

### 5.1 플레이어 API

```lua
-- 현재 플레이어 ID
local playerId = Player.Mine.UserID

-- 플레이어 닉네임
local nickname = Player.Mine.Nickname

-- 이동 잠금
Player.Mine.CharacterMoveLock = true

-- 텔레포트
Player.Mine.TeleportPlayer(position, rotation)
```

### 5.2 UI API

```lua
-- 페이드 효과
UI.FadeIn(duration, callback)
UI.FadeOut(duration, callback)

-- 토스트 메시지
UI.ToastMessage("메시지 내용")
```

### 5.3 오브젝트 접근

```lua
-- 컴포넌트 가져오기
local comp = self:GetComponent("ComponentName")

-- Lua 스크립트 가져오기
local script = targetObj:GetLuaComponent("ScriptName")

-- 자식에서 찾기
local child = self.transform:Find("ChildName")
local childComp = self:GetComponentInChildren(typeof(CS.UnityEngine.MeshRenderer))
```

### 5.4 물리 관련

```lua
-- Rigidbody 접근
local rb = self:GetComponent("Rigidbody")
rb.velocity = Vector3.zero
rb.isKinematic = true
rb.useGravity = false

-- 힘 적용
rb:AddForce(Vector3(0, 10, 0), ForceMode.Impulse)
```

### 5.5 코루틴

```lua
local util = require 'xlua.util'

-- 코루틴 시작
local routine = self:StartCoroutine(util.cs_generator(function()
    coroutine.yield(WaitForSeconds(1.0))
    -- 1초 후 실행
end))

-- 코루틴 중지
self:StopCoroutine(routine)
```

### 5.6 햅틱 피드백

```lua
-- 컨트롤러 진동 (isLeftHand, intensity, duration)
XR.StartControllerVibration(false, 0.5, 0.2)  -- 오른손
XR.StartControllerVibration(true, 0.3, 0.1)   -- 왼손
```

---

## 6. 디버깅

### 6.1 로그 출력

```lua
Debug.Log("일반 메시지")
Debug.LogWarning("경고 메시지")
Debug.LogError("에러 메시지")
```

### 6.2 네이밍 컨벤션

| 항목 | 형식 | 예시 |
|------|------|------|
| 스크립트 파일 | PascalCase | `PandolManager.lua` |
| 함수 | PascalCase | `OnPlayerFall()` |
| 지역 변수 | camelCase | `isActivated` |
| 상수 | UPPER_SNAKE | `MAX_ATTEMPTS` |
| Injection 변수 | PascalCase | `TargetObject` |

### 6.3 주석 규칙

```lua
-- 한 줄 주석

--[[
    여러 줄 주석
    설명 내용
]]

---@type GameObject
---@details Inspector에서 연결할 대상 설명
TargetObject = checkInject(TargetObject)
```
