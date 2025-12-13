---게임 흐름 관리자
---@description 전체 게임 상태 머신 및 영역 전환 관리

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

---@type GameObject
---@details Area_00_Loading 영역 (로딩)
area00Loading = NullableInject(area00Loading)

---@type GameObject
---@details Area_01_Prologue 영역 (현대 경복궁) - 시작 영역
area01Prologue = NullableInject(area01Prologue)

---@type GameObject
---@details Area_02_Timeleap 영역 (타임리프 연출)
area02Timeleap = NullableInject(area02Timeleap)

---@type GameObject
---@details Area_03_Pandol 영역 (판돌 건너기)
area03Pandol = NullableInject(area03Pandol)

---@type GameObject
---@details Area_04_Biseok 영역 (비석치기)
area04Biseok = NullableInject(area04Biseok)

---@type GameObject
---@details Area_05_Ending 영역 (엔딩)
area05Ending = NullableInject(area05Ending)

---@type GameObject
---@details 프롤로그 스폰 포인트 오브젝트
prologueSpawnPointObject = NullableInject(prologueSpawnPointObject)

---@type GameObject
---@details 타임리프 스폰 포인트 오브젝트
timeleapSpawnPointObject = NullableInject(timeleapSpawnPointObject)

---@type GameObject
---@details 판돌 건너기 스폰 포인트 오브젝트
pandolSpawnPointObject = NullableInject(pandolSpawnPointObject)

---@type GameObject
---@details 비석치기 스폰 포인트 오브젝트
biseokSpawnPointObject = NullableInject(biseokSpawnPointObject)

---@type GameObject
---@details 엔딩 스폰 포인트 오브젝트
endingSpawnPointObject = NullableInject(endingSpawnPointObject)

---@type number
---@details 페이드 전환 시간 (초)
fadeTransitionTime = NullableInject(fadeTransitionTime) or 1.0
--endregion

--region Variables
local util = require 'xlua.util'

---@alias GameState "Prologue" | "Timeleap" | "Round1" | "Round2" | "Ending"

---@type GameState
local currentState = "Prologue"

---@type GameObject
local currentArea = nil

---@type table<string, GameObject>
local areas = {}

---@type table<string, Transform>
local spawnPoints = {}

---@type Coroutine
local transitionCoroutine = nil

---@type boolean
local isGameCompleted = false
--endregion

--region Lifecycle
function awake()
    -- 영역 테이블 초기화
    areas = {
        Loading = area00Loading,
        Prologue = area01Prologue,
        Timeleap = area02Timeleap,
        Round1 = area03Pandol,
        Round2 = area04Biseok,
        Ending = area05Ending
    }

    -- 스폰 포인트 테이블 초기화 (GameObject에서 Transform 추출)
    spawnPoints = {}
    if prologueSpawnPointObject then
        spawnPoints.Prologue = prologueSpawnPointObject.transform
    end
    if timeleapSpawnPointObject then
        spawnPoints.Timeleap = timeleapSpawnPointObject.transform
    end
    if pandolSpawnPointObject then
        spawnPoints.Round1 = pandolSpawnPointObject.transform
    end
    if biseokSpawnPointObject then
        spawnPoints.Round2 = biseokSpawnPointObject.transform
    end
    if endingSpawnPointObject then
        spawnPoints.Ending = endingSpawnPointObject.transform
    end

    Debug.Log("[GameFlowManager] Initialized")
end

function start()
    -- 시작 시 프롤로그 영역만 활성화
    SetActiveArea("Prologue")
    currentState = "Prologue"

    -- 플레이어를 프롤로그 스폰 포인트로 즉시 텔레포트
    local spawnPoint = spawnPoints["Prologue"]
    Debug.Log("[GameFlowManager] spawnPoints.Prologue = " .. tostring(spawnPoint))

    if spawnPoint then
        Debug.Log("[GameFlowManager] SpawnPoint position: " .. tostring(spawnPoint.position))
        Debug.Log("[GameFlowManager] SpawnPoint rotation: " .. tostring(spawnPoint.rotation))
        Player.Mine.TeleportPlayer(spawnPoint.position, spawnPoint.rotation)
        Debug.Log("[GameFlowManager] Player teleported to Prologue spawn point")
    else
        Debug.Log("[GameFlowManager] WARNING: Prologue spawn point not set, skipping teleport")
    end

    -- 프롤로그 시작 로직 호출
    OnEnterPrologue()
end
--endregion

--region Area Management
---@param areaName string
---@description 해당 영역만 활성화하고 나머지는 비활성화
function SetActiveArea(areaName)
    for name, area in pairs(areas) do
        if area then
            local shouldActive = (name == areaName)
            area:SetActive(shouldActive)
            if shouldActive then
                currentArea = area
            end
        end
    end
    Debug.Log("[GameFlowManager] Active area: " .. areaName)
end

---@param targetState GameState
---@description 지정된 스테이지로 전환 (페이드 + 텔레포트)
function TransitionToStage(targetState)
    if transitionCoroutine ~= nil then
        Debug.Log("[GameFlowManager] WARNING: Transition already in progress")
        return
    end

    transitionCoroutine = self:StartCoroutine(util.cs_generator(function()
        Debug.Log("[GameFlowManager] Transitioning to: " .. targetState)

        -- 페이드 아웃
        UI.FadeOut(fadeTransitionTime, nil)
        coroutine.yield(WaitForSeconds(fadeTransitionTime))

        -- 현재 영역 비활성화, 타겟 영역 활성화
        SetActiveArea(targetState)

        -- 플레이어 텔레포트
        local spawnPoint = spawnPoints[targetState]
        if spawnPoint then
            Player.Mine.TeleportPlayer(spawnPoint.position, spawnPoint.rotation)
        else
            Debug.Log("[GameFlowManager] WARNING: Spawn point not set for: " .. targetState)
        end

        -- 상태 업데이트
        currentState = targetState

        -- 페이드 인
        UI.FadeIn(fadeTransitionTime, nil)
        coroutine.yield(WaitForSeconds(fadeTransitionTime))

        -- 스테이지별 시작 로직 호출
        OnStageEnter(targetState)

        transitionCoroutine = nil
    end))
end
--endregion

--region Stage Callbacks
---@param state GameState
---@description 스테이지 진입 시 호출되는 콜백
function OnStageEnter(state)
    Debug.Log("[GameFlowManager] Entered stage: " .. state)

    if state == "Prologue" then
        OnEnterPrologue()
    elseif state == "Timeleap" then
        OnEnterTimeleap()
    elseif state == "Round1" then
        OnEnterRound1()
    elseif state == "Round2" then
        OnEnterRound2()
    elseif state == "Ending" then
        OnEnterEnding()
    end
end

function OnEnterPrologue()
    -- 프롤로그 진입: 보따리 트리거 대기
    Debug.Log("[GameFlowManager] Prologue started - waiting for bottari trigger")
end

function OnEnterTimeleap()
    -- 타임리프 매니저 시작 호출
    if area02Timeleap then
        local timeleapManager = area02Timeleap:GetLuaComponentInChildren("TimeleapManager")
        if timeleapManager then
            timeleapManager.StartTimeleapSequence()
        end
    end
end

function OnEnterRound1()
    -- 판돌 건너기 게임 시작
    if area03Pandol then
        local pandolManager = area03Pandol:GetLuaComponentInChildren("PandolManager")
        if pandolManager then
            pandolManager.StartGame()
        end
    end
end

function OnEnterRound2()
    -- 비석치기 게임 시작
    if area04Biseok then
        local biseokManager = area04Biseok:GetLuaComponentInChildren("BiseokManager")
        if biseokManager then
            biseokManager.StartGame()
        end
    end
end

function OnEnterEnding()
    -- 엔딩 매니저 시작 호출
    if area05Ending then
        local endingManager = area05Ending:GetLuaComponentInChildren("EndingManager")
        if endingManager then
            endingManager.StartEndingSequence()
        end
    end
end
--endregion

--region Public API (다른 스크립트에서 호출)
---@description 타임리프로 전환 (보따리 트리거에서 호출)
function TransitionToTimeleap()
    TransitionToStage("Timeleap")
end

---@description Round 1 (판돌 건너기)로 전환
function TransitionToRound1()
    TransitionToStage("Round1")
end

---@description Round 2 (비석치기)로 전환
function TransitionToRound2()
    TransitionToStage("Round2")
end

---@description 엔딩으로 전환
function TransitionToEnding()
    TransitionToStage("Ending")
end

---@description 현대 경복궁으로 복귀 (엔딩 후)
function TransitionToModernGyeongbokgung()
    TransitionToStage("Prologue")
end

---@description 엔딩 후 프롤로그로 전환 (보따리 비활성화 상태)
function TransitionToPrologueEnding()
    Debug.Log("[GameFlowManager] Transitioning to Prologue (ending state)")
    
    TransitionToStage("Prologue")
    
    -- 보따리 트리거 비활성화
    if area01Prologue then
        local bottariTrigger = area01Prologue:GetLuaComponentInChildren("BottariTrigger")
        if bottariTrigger and bottariTrigger.DisableTrigger then
            bottariTrigger.DisableTrigger()
        end
    end
    
    isGameCompleted = true
end

---@description 프롤로그로 전환 (게임 오버 시)
function TransitionToPrologue()
    TransitionToStage("Prologue")
end

---@return GameState
---@description 현재 게임 상태 반환
function GetCurrentState()
    return currentState
end

---@return boolean
---@description 게임 완료 여부 (엔딩을 본 적이 있는지)
function IsGameCompleted()
    return currentState == "Prologue" and isGameCompleted
end
--endregion
