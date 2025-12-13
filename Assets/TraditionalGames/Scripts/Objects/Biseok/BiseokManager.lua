---비석치기 게임 매니저
---@description Round 2 비석치기 전체 게임 로직 관리
---@usage Area_04_Biseok 영역에 VivenLuaBehaviour로 추가

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

---@type table
---@details 비석 오브젝트 목록 (배열)
biseokObjects = NullableInject(biseokObjects) or {}

---@type GameObject
---@details 돌 스폰 위치 (던질 돌이 생성되는 위치)
stoneSpawnPoint = NullableInject(stoneSpawnPoint)

---@type GameObject
---@details 돌 프리팹
stonePrefab = NullableInject(stonePrefab)

---@type AudioSource
---@details 성공 사운드
successSound = NullableInject(successSound)

---@type AudioSource
---@details 비석 쓰러짐 사운드
biseokFallSound = NullableInject(biseokFallSound)

---@type AudioSource
---@details 던지기 사운드
throwSound = NullableInject(throwSound)

---@type AudioSource
---@details 게임 시작 사운드
startSound = NullableInject(startSound)

---@type number
---@details 클리어에 필요한 쓰러진 비석 수
requiredFallenCount = NullableInject(requiredFallenCount) or 2

---@type number
---@details 비석 쓰러짐 판정 각도 (도)
fallenAngleThreshold = NullableInject(fallenAngleThreshold) or 45

---@type number
---@details 최대 돌 개수 (0 = 무제한)
maxStones = NullableInject(maxStones) or 0

---@type number
---@details 돌 리스폰 대기 시간 (초)
stoneRespawnDelay = NullableInject(stoneRespawnDelay) or 1.5
--endregion

--region Variables
local util = require 'xlua.util'

local gameFlowManager = nil
local stageManager = nil
local goblinNPC = nil

local isGameActive = false
local isGameCleared = false
local stonesThrown = 0
local fallenBiseokCount = 0
local currentCoroutine = nil

-- 비석 상태 추적
local biseokStates = {}  -- { [biseokObj] = { isFallen = bool, script = BiseokObject } }

-- 현재 활성화된 돌
local currentStone = nil
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
    
    Debug.Log("[BiseokManager] Initialized")
end

function start()
    -- 비석 정보 초기화
    InitializeBiseok()
end

function onEnable()
    -- 영역 활성화 시 게임 시작
    Debug.Log("[BiseokManager] Area enabled - Starting game")
    StartGame()
end

function onDisable()
    -- 영역 비활성화 시 게임 중지
    StopGame()
end

function update()
    -- 비석 쓰러짐 체크 (매 프레임)
    if isGameActive and not isGameCleared then
        CheckBiseokFallen()
    end
end
--endregion

--region Initialization
---@description 비석 정보 초기화
function InitializeBiseok()
    biseokStates = {}
    
    local count = biseokObjects and #biseokObjects or 0
    if count == 0 then
        Debug.Log("[BiseokManager] WARNING: No biseok objects configured")
        return
    end
    
    Debug.Log("[BiseokManager] Initializing " .. count .. " biseok objects")
    
    for i, biseokObj in ipairs(biseokObjects) do
        if biseokObj then
            local biseokScript = biseokObj:GetLuaComponent("BiseokObject")
            biseokStates[biseokObj] = {
                isFallen = false,
                script = biseokScript,
                initialRotation = biseokObj.transform.rotation
            }
            
            -- 매니저 설정
            if biseokScript then
                biseokScript.SetManager(self)
            end
        end
    end
end

---@description 모든 비석 리셋
function ResetAllBiseok()
    for biseokObj, state in pairs(biseokStates) do
        if biseokObj then
            state.isFallen = false
            
            -- 원래 회전으로 복구
            if state.initialRotation then
                biseokObj.transform.rotation = state.initialRotation
            end
            
            -- 스크립트 리셋
            if state.script then
                state.script.ResetBiseok()
            end
            
            -- Rigidbody 리셋
            local rb = biseokObj:GetComponent(typeof(CS.UnityEngine.Rigidbody))
            if rb then
                rb.velocity = Vector3.zero
                rb.angularVelocity = Vector3.zero
            end
        end
    end
    
    fallenBiseokCount = 0
end
--endregion

--region Game Flow
---@description 게임 시작
function StartGame()
    if isGameActive then return end
    
    isGameActive = true
    isGameCleared = false
    stonesThrown = 0
    fallenBiseokCount = 0
    
    Debug.Log("[BiseokManager] Starting Biseok game")
    
    -- 비석 리셋
    ResetAllBiseok()
    
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
            goblinNPC.PlayRound2IntroSequence(function()
                introComplete = true
            end)
            
            while not introComplete do
                coroutine.yield(nil)
            end
        else
            -- 도깨비 없으면 자막으로 대체
            if stageManager then
                stageManager.ShowSubtitle("마지막 시험: 비석을 쓰러뜨려라!", 3.0)
            end
            coroutine.yield(WaitForSeconds(3.0))
        end
        
        -- 게임 시작 안내
        if stageManager then
            local totalCount = 0
            for _ in pairs(biseokStates) do totalCount = totalCount + 1 end
            stageManager.ShowSubtitle(totalCount .. "개의 비석 중 " .. requiredFallenCount .. "개를 쓰러뜨리세요!", 2.0)
        end
        
        coroutine.yield(WaitForSeconds(1.0))
        
        -- 첫 번째 돌 생성
        SpawnStone()
        
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
    
    -- 현재 돌 제거
    if currentStone then
        GameObject.Destroy(currentStone)
        currentStone = nil
    end
    
    Debug.Log("[BiseokManager] Game stopped")
end

---@description 게임 클리어 처리
function OnGameClear()
    if isGameCleared then return end
    
    isGameCleared = true
    isGameActive = false
    
    Debug.Log("[BiseokManager] Game cleared! Fallen: " .. fallenBiseokCount)
    
    if currentCoroutine then
        self:StopCoroutine(currentCoroutine)
    end
    
    currentCoroutine = self:StartCoroutine(util.cs_generator(function()
        -- 성공 사운드
        if successSound then
            successSound:Play()
        end
        
        -- 햅틱 피드백
        XR.StartControllerVibration(false, 0.6, 0.5)
        XR.StartControllerVibration(true, 0.6, 0.5)
        
        -- 도깨비 성공 대사
        if goblinNPC then
            goblinNPC.Speak("round2_success", nil)
            coroutine.yield(WaitForSeconds(4.0))
        else
            if stageManager then
                stageManager.ShowSubtitle("모든 시험 통과! 축하합니다!", 3.0)
            end
            coroutine.yield(WaitForSeconds(3.0))
        end
        
        -- 엔딩으로 전환
        if gameFlowManager then
            gameFlowManager.TransitionToEnding()
        end
        
        currentCoroutine = nil
    end))
end
--endregion

--region Stone Management
---@description 돌 생성
function SpawnStone()
    if not isGameActive or isGameCleared then return end
    
    -- 최대 돌 개수 체크
    if maxStones > 0 and stonesThrown >= maxStones then
        OnOutOfStones()
        return
    end
    
    if not stonePrefab then
        Debug.Log("[BiseokManager] WARNING: Stone prefab not set")
        return
    end
    
    local spawnPos = Vector3.zero
    local spawnRot = Quaternion.identity
    
    if stoneSpawnPoint then
        spawnPos = stoneSpawnPoint.transform.position
        spawnRot = stoneSpawnPoint.transform.rotation
    end
    
    -- 돌 생성
    currentStone = GameObject.Instantiate(stonePrefab, spawnPos, spawnRot)
    
    -- ThrowingStone 스크립트에 매니저 설정
    local throwingStone = currentStone:GetLuaComponent("ThrowingStone")
    if throwingStone then
        throwingStone.SetManager(self)
    end
    
    Debug.Log("[BiseokManager] Stone spawned")
end

---@param stoneObj GameObject
---@description 돌이 던져졌을 때 (ThrowingStone에서 호출)
function OnStoneThrown(stoneObj)
    stonesThrown = stonesThrown + 1
    Debug.Log("[BiseokManager] Stone thrown! Total: " .. stonesThrown)
    
    -- 던지기 사운드
    if throwSound then
        throwSound:Play()
    end
    
    -- 일정 시간 후 새 돌 생성
    self:StartCoroutine(util.cs_generator(function()
        coroutine.yield(WaitForSeconds(stoneRespawnDelay))
        
        -- 이전 돌 제거 (아직 존재하면)
        if stoneObj then
            GameObject.Destroy(stoneObj)
        end
        
        -- 게임이 아직 진행 중이면 새 돌 생성
        if isGameActive and not isGameCleared then
            SpawnStone()
        end
    end))
end

---@description 돌 소진 시
function OnOutOfStones()
    Debug.Log("[BiseokManager] Out of stones!")
    
    if stageManager then
        stageManager.ShowSubtitle("돌을 모두 사용했습니다...", 2.0)
    end
    
    -- 실패 처리 또는 재시작 옵션
    self:StartCoroutine(util.cs_generator(function()
        coroutine.yield(WaitForSeconds(2.0))
        
        if fallenBiseokCount < requiredFallenCount then
            -- 실패
            if stageManager then
                stageManager.ShowSubtitle("다시 도전하세요!", 2.0)
            end
            coroutine.yield(WaitForSeconds(2.0))
            RestartGame()
        end
    end))
end
--endregion

--region Biseok State Check
---@description 비석 쓰러짐 체크 (매 프레임)
function CheckBiseokFallen()
    for biseokObj, state in pairs(biseokStates) do
        if biseokObj and not state.isFallen then
            -- 비석의 현재 기울기 확인
            local rotation = biseokObj.transform.rotation.eulerAngles
            
            -- X 또는 Z 축 기울기 체크
            local xTilt = math.abs(rotation.x)
            local zTilt = math.abs(rotation.z)
            
            -- 180도 이상인 경우 보정
            if xTilt > 180 then xTilt = 360 - xTilt end
            if zTilt > 180 then zTilt = 360 - zTilt end
            
            if xTilt >= fallenAngleThreshold or zTilt >= fallenAngleThreshold then
                OnBiseokFallen(biseokObj)
            end
        end
    end
end

---@param biseokObj GameObject
---@description 비석 쓰러짐 처리
function OnBiseokFallen(biseokObj)
    local state = biseokStates[biseokObj]
    if not state or state.isFallen then return end
    
    state.isFallen = true
    fallenBiseokCount = fallenBiseokCount + 1
    
    Debug.Log("[BiseokManager] Biseok fallen! Count: " .. fallenBiseokCount .. "/" .. requiredFallenCount)
    
    -- 쓰러짐 사운드
    if biseokFallSound then
        biseokFallSound:Play()
    end
    
    -- 햅틱 피드백
    XR.StartControllerVibration(false, 0.4, 0.2)
    XR.StartControllerVibration(true, 0.4, 0.2)
    
    -- 스크립트 알림
    if state.script then
        state.script.OnFallen()
    end
    
    -- 자막
    if stageManager then
        local totalCount = 0
        for _ in pairs(biseokStates) do totalCount = totalCount + 1 end
        local remaining = requiredFallenCount - fallenBiseokCount
        
        if remaining > 0 then
            stageManager.ShowSubtitle(remaining .. "개 더!", 1.5)
        end
    end
    
    -- 클리어 체크
    if fallenBiseokCount >= requiredFallenCount then
        OnGameClear()
    end
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
---@description 던진 돌 개수
function GetStonesThrown()
    return stonesThrown
end

---@return number
---@description 쓰러진 비석 수
function GetFallenCount()
    return fallenBiseokCount
end

---@return number
---@description 클리어에 필요한 비석 수
function GetRequiredCount()
    return requiredFallenCount
end

---@description 외부에서 게임 재시작
function RestartGame()
    StopGame()
    StartGame()
end
--endregion
