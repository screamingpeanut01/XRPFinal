---판돌 건너기 게임 매니저
---@description Round 1 판돌 건너기 전체 게임 로직 관리
---@usage Area_03_Pandol 영역에 VivenLuaBehaviour로 추가

--region Injection
local _INJECTED_ORDER = 0
local function checkInject(OBJECT)
    _INJECTED_ORDER = _INJECTED_ORDER + 1
    assert(OBJECT, _INJECTED_ORDER .. "th object is missing")
    return OBJECT
end
local function NullableInject(OBJECT)
    _INJECTED_ORDER = _INJECTED_ORDER + 1
    if OBJECT == nil then
        Debug.Log(_INJECTED_ORDER .. "th object is missing (nullable)")
    end
    return OBJECT
end

---@type string
---@details GameFlowManager 스크립트 이름
gameFlowManagerName = NullableInject(gameFlowManagerName) or "GameFlowManager"

---@type string
---@details StageManager 스크립트 이름
stageManagerName = NullableInject(stageManagerName) or "StageManager"

---@type string
---@details GoblinNPC 스크립트 이름
goblinNPCName = NullableInject(goblinNPCName) or "GoblinNPC"

---@type GameObject
---@details 도깨비 오브젝트 (GoblinNPC 스크립트 포함)
goblinObject = NullableInject(goblinObject)

---@type GameObject
---@details 골 영역 (트리거 존)
goalZone = NullableInject(goalZone)

---@type GameObject
---@details 낙하 감지 영역 (트리거 존)
fallZone = NullableInject(fallZone)

---@type GameObject
---@details 스폰 포인트 (리스폰 위치)
spawnPoint = NullableInject(spawnPoint)

---@type GameObject
---@details 발판들이 모여있는 부모 오브젝트 (Platforms)
platformsRoot = NullableInject(platformsRoot)

-- 기존 리스트 방식 제거 (Inspector 지원 안함)
-- leftPlatforms = NullableInject(leftPlatforms) or {}
-- rightPlatforms = NullableInject(rightPlatforms) or {}

---@type AudioSource
---@details 성공 사운드
successSound = NullableInject(successSound)

---@type AudioSource
---@details 실패 사운드
failSound = NullableInject(failSound)

---@type AudioSource
---@details 게임 시작 사운드
startSound = NullableInject(startSound)

---@type number
---@details 리스폰 대기 시간 (초)
respawnDelay = NullableInject(respawnDelay) or 2.0

---@type number
---@details 최대 시도 횟수 (0 = 무제한)
maxAttempts = NullableInject(maxAttempts) or 0

---@type boolean
---@details 발판 배치 랜덤화 여부
randomizePlatforms = NullableInject(randomizePlatforms)
if randomizePlatforms == nil then randomizePlatforms = false end  -- 테스트용: 왼쪽이 항상 안전
--endregion

--region Variables
local util = require 'xlua.util'

local gameFlowManager = nil
local stageManager = nil
local goblinNPC = nil

local isGameActive = false
local isGameCleared = false
local attemptCount = 0
local currentCoroutine = nil

-- 발판 데이터
local platformSteps = {}  -- { {left = platform, right = platform, safeIsLeft = bool}, ... }
local stepCount = 0
--endregion

--region Lifecycle
function awake()
    -- 매니저 찾기
    local managerObj = GameObject.Find("MANAGERS")
    if managerObj then
        gameFlowManager = managerObj:GetLuaComponentInChildren(gameFlowManagerName)
        stageManager = managerObj:GetLuaComponentInChildren(stageManagerName)
    end
    
    -- GoblinNPC 찾기
    if goblinObject then
        goblinNPC = goblinObject:GetLuaComponent(goblinNPCName)
    end
    
    Debug.Log("[PandolManager] Initialized")
end

function start()
    -- 발판 정보 초기화
    InitializePlatforms()
end

function onEnable()
    -- 영역 활성화 시 게임 시작
    Debug.Log("[PandolManager] Area enabled - Starting game")
    StartGame()
end

function onDisable()
    -- 영역 비활성화 시 게임 중지
    StopGame()
end
--endregion

--region Initialization
---@description 발판 정보 초기화
---@description 발판 정보 초기화 (Auto Discovery)
function InitializePlatforms()
    platformSteps = {}
    
    if not platformsRoot then
        Debug.Log("[PandolManager] ERROR: platformsRoot is missing!")
        return
    end
    
    Debug.Log("[PandolManager] Auto-discovering platforms from " .. platformsRoot.name)
    
    local rootTransform = platformsRoot.transform
    local childCount = rootTransform.childCount
    local tempSteps = {}
    local maxIndex = 0
    
    -- 자식 오브젝트 순회하며 이름 파싱
    for i = 0, childCount - 1 do
        local child = rootTransform:GetChild(i).gameObject
        local name = child.name
        
        -- 이름 패턴 매칭: "left_platform" + 숫자, "right_platform" + 숫자
        -- 예: left_platform1, right_platform3
        
        -- Lua 패턴 매칭
        -- (%d+)는 숫자를 캡처
        local leftIndex = string.match(name, "left_platform(%d+)")
        local rightIndex = string.match(name, "right_platform(%d+)")
        
        if leftIndex then
            local idx = tonumber(leftIndex)
            if not tempSteps[idx] then tempSteps[idx] = {} end
            tempSteps[idx].left = child
            if idx > maxIndex then maxIndex = idx end
            Debug.Log("Found Left Step " .. idx .. ": " .. name)
        elseif rightIndex then
            local idx = tonumber(rightIndex)
            if not tempSteps[idx] then tempSteps[idx] = {} end
            tempSteps[idx].right = child
            if idx > maxIndex then maxIndex = idx end
            Debug.Log("Found Right Step " .. idx .. ": " .. name)
        end
    end
    
    stepCount = maxIndex
    
    if stepCount == 0 then
        Debug.Log("[PandolManager] WARNING: No matching platforms found (pattern: left/right_platform#)")
        return
    end
    
    -- 인덱스 순서대로 platformSteps 배열 구성
    for i = 1, stepCount do
        local stepData = tempSteps[i]
        if stepData and stepData.left and stepData.right then
            local step = {
                left = stepData.left,
                right = stepData.right,
                safeIsLeft = true
            }
            table.insert(platformSteps, step)
        else
            Debug.Log("[PandolManager] WARNING: Step " .. i .. " is incomplete or missing")
        end
    end
    
    Debug.Log("[PandolManager] Initialized " .. #platformSteps .. " platform steps")
end

---@description 안전한 발판 배치 (랜덤 또는 고정)
function RandomizeSafePlatforms()
    if randomizePlatforms then
        math.randomseed(os.time())
    end
    
    for i, step in ipairs(platformSteps) do
        if randomizePlatforms then
            -- 랜덤: 50% 확률로 좌측 또는 우측
            step.safeIsLeft = math.random() > 0.5
        else
            -- 고정: 왼쪽이 항상 안전
            step.safeIsLeft = true
        end
        
        -- 발판에 안전 여부 설정
        SetPlatformSafety(step.left, step.safeIsLeft)
        SetPlatformSafety(step.right, not step.safeIsLeft)
        
        local safeText = step.safeIsLeft and "LEFT" or "RIGHT"
        Debug.Log("[PandolManager] Step " .. i .. " safe: " .. safeText)
    end
end

---@param platformObj GameObject
---@param isSafe boolean
---@description 발판의 안전 여부 설정
function SetPlatformSafety(platformObj, isSafe)
    if not platformObj then return end
    
    local platformStep = platformObj:GetLuaComponent("PlatformStep")
    if platformStep then
        platformStep.SetIsSafe(isSafe)
        platformStep.SetManager(self.gameObject)
    else
        Debug.Log("[PandolManager] WARNING: PlatformStep not found on " .. platformObj.name)
    end
end

---@description 모든 발판 리셋
function ResetAllPlatforms()
    for _, step in ipairs(platformSteps) do
        if step.left then
            local leftStep = step.left:GetLuaComponent("PlatformStep")
            if leftStep then leftStep.ResetPlatform() end
        end
        if step.right then
            local rightStep = step.right:GetLuaComponent("PlatformStep")
            if rightStep then rightStep.ResetPlatform() end
        end
    end
end
--endregion

--region Game Flow
---@description 게임 시작
function StartGame()
    if isGameActive then return end
    
    isGameActive = true
    isGameCleared = false
    attemptCount = 0
    
    Debug.Log("[PandolManager] Starting Pandol game")
    
    -- 발판 리셋 및 랜덤 배치
    ResetAllPlatforms()
    RandomizeSafePlatforms()
    
    -- 시작 연출
    if currentCoroutine then
        self:StopCoroutine(currentCoroutine)
    end
    
    currentCoroutine = self:StartCoroutine(util.cs_generator(function()
        -- 시작 사운드
        if startSound then
            startSound:Play()
        end
        
        -- 도깨비 인트로 대사
        if goblinNPC then
            local introComplete = false
            goblinNPC.PlayRound1IntroSequence(function()
                introComplete = true
            end)
            
            while not introComplete do
                coroutine.yield(nil)
            end
        else
            -- 도깨비 없으면 자막으로 대체
            if stageManager then
                stageManager.ShowSubtitle("첫 번째 시험: 직감을 믿어 앞으로 나아가라.", 3.0)
            end
            coroutine.yield(WaitForSeconds(3.0))
        end
        
        -- 게임 시작 안내 (도깨비 자막으로 표시)
        -- TODO: SpeakCustom 500 에러 임시 조치 (오디오 클립 문제로 추정)
        -- if goblinNPC then
        --    goblinNPC.SpeakCustom("발판을 선택하여 건너세요!", 2.0, nil, nil)
        -- end
        
        if stageManager then
             stageManager.ShowSubtitle("발판을 선택하여 건너세요!", 2.0)
        end
        
        currentCoroutine = nil
    end))
end

---@description 게임 중지
function StopGame()
    isGameActive = false
    
    if currentCoroutine then
        self:StopCoroutine(currentCoroutine)
        currentCoroutine = nil
    end
    
    Debug.Log("[PandolManager] Game stopped")
end

---@description 게임 클리어 처리
function OnGameClear()
    if isGameCleared then return end
    
    isGameCleared = true
    isGameActive = false
    
    Debug.Log("[PandolManager] Game cleared!")
    
    if currentCoroutine then
        self:StopCoroutine(currentCoroutine)
    end
    
    currentCoroutine = self:StartCoroutine(util.cs_generator(function()
        -- 성공 사운드
        if successSound then
            successSound:Play()
        end
        
        -- 햅틱 피드백
        XR.StartControllerVibration(false, 0.5, 0.3)
        XR.StartControllerVibration(true, 0.5, 0.3)
        
        -- 도깨비 성공 대사
        if goblinNPC then
            goblinNPC.Speak("round1_success", nil)
            coroutine.yield(WaitForSeconds(3.5))
        else
            if stageManager then
                stageManager.ShowSubtitle("첫 번째 시험 통과!", 3.0)
            end
            coroutine.yield(WaitForSeconds(3.0))
        end
        
        -- 다음 라운드로 전환
        if gameFlowManager then
            gameFlowManager.TransitionToRound2()
        end
        
        currentCoroutine = nil
    end))
end

---@param platformObj GameObject
---@description 발판 깨짐 이벤트 (PlatformStep에서 호출)
function OnPlatformBreak(platformObj)
    Debug.Log("[PandolManager] Platform break: " .. platformObj.name)
    -- 플레이어 낙하 처리는 FallZone에서 감지
end

---@description 플레이어 낙하 처리
function OnPlayerFall()
    if not isGameActive or isGameCleared then return end
    
    attemptCount = attemptCount + 1
    Debug.Log("[PandolManager] Player fell! Attempt: " .. attemptCount)
    
    if currentCoroutine then
        self:StopCoroutine(currentCoroutine)
    end
    
    currentCoroutine = self:StartCoroutine(util.cs_generator(function()
        -- 실패 사운드
        if failSound then
            failSound:Play()
        end
        
        -- 햅틱 피드백
        XR.StartControllerVibration(false, 0.8, 0.2)
        XR.StartControllerVibration(true, 0.8, 0.2)
        
        -- 실패 메시지
        if maxAttempts > 0 and attemptCount >= maxAttempts then
            -- 최대 시도 횟수 초과 - 게임 오버
            if stageManager then
                stageManager.ShowSubtitle("시험 실패...", 2.0)
            end
            coroutine.yield(WaitForSeconds(2.0))
            
            -- 게임 오버 처리 (프롤로그로 돌아가기 등)
            if gameFlowManager then
                gameFlowManager.TransitionToPrologue()
            end
        else
            -- 리스폰
            if goblinNPC then
                goblinNPC.Speak("round1_fail", nil)
            else
                if stageManager then
                    stageManager.ShowSubtitle("다시 도전하세요!", 2.0)
                end
            end
            
            coroutine.yield(WaitForSeconds(respawnDelay))
            
            -- 리스폰
            RespawnPlayer()
        end
        
        currentCoroutine = nil
    end))
end

---@description 플레이어 리스폰
function RespawnPlayer()
    if spawnPoint then
        local spawnTransform = spawnPoint.transform
        Player.Mine.TeleportPlayer(spawnTransform.position, spawnTransform.rotation)
        Debug.Log("[PandolManager] Player respawned")
    end
    
    -- 발판 리셋 및 재배치
    ResetAllPlatforms()
    RandomizeSafePlatforms()
end

---@description 골 존 도달 처리
function OnGoalReached()
    Debug.Log("[PandolManager] Goal reached!")
    OnGameClear()
end
--endregion

--region Trigger Events
---@param other Collider
function onTriggerEnter(other)
    -- 이 스크립트가 FallZone이나 GoalZone에 직접 붙어있을 때 사용
    -- 또는 별도의 트리거 스크립트에서 호출
end
--endregion

--region Public API
---@return boolean
---@description 게임 활성화 여부
function IsGameActive()
    return isGameActive
end

---@return boolean
---@description 게임 클리어 여부
function IsGameCleared()
    return isGameCleared
end

---@return number
---@description 현재 시도 횟수
function GetAttemptCount()
    return attemptCount
end

---@return number
---@description 발판 단계 수
function GetStepCount()
    return stepCount
end

---@description 외부에서 게임 재시작
function RestartGame()
    StopGame()
    StartGame()
end
--endregion
