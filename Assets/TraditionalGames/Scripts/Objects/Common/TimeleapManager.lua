---타임리프 매니저
---@description 타임리프 연출 시퀀스 관리

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

---@type AudioSource
---@details 종소리
bellSound = NullableInject(bellSound)

---@type AudioSource
---@details 바람소리
windSound = NullableInject(windSound)

---@type ParticleSystem
---@details 단청 파편 파티클
danchengParticle = NullableInject(danchengParticle)

---@type Material
---@details 변경할 스카이박스 머티리얼 (조선시대)
joseonSkybox = NullableInject(joseonSkybox)

---@type number
---@details 단청 연출 시간 (초)
danchengDuration = NullableInject(danchengDuration) or 2.0

---@type number
---@details 도깨비 등장 전 대기 시간 (초)
goblinAppearDelay = NullableInject(goblinAppearDelay) or 1.5
--endregion

--region Variables
local util = require 'xlua.util'

local gameFlowManager = nil
local stageManager = nil
local goblinNPC = nil
local isSequenceRunning = false
local sequenceCoroutine = nil
--endregion

--region Lifecycle
function awake()
    gameFlowManager = self:GetLuaComponentInParent(gameFlowManagerName)

    if not gameFlowManager then
        local managerObj = GameObject.Find("MANAGERS")
        if managerObj then
            gameFlowManager = managerObj:GetLuaComponentInChildren(gameFlowManagerName)
            stageManager = managerObj:GetLuaComponentInChildren(stageManagerName)
        end
    end

    -- GoblinNPC 스크립트 참조 가져오기
    if goblinObject then
        goblinNPC = goblinObject:GetLuaComponent(goblinNPCName)
        if not goblinNPC then
            Debug.Log("[TimeleapManager] WARNING: GoblinNPC script not found on goblinObject")
        end
    end

    Debug.Log("[TimeleapManager] Initialized")
end

function start()
    -- 도깨비 오브젝트는 GoblinNPC가 자체적으로 비활성화 상태 관리
    -- 별도 처리 불필요
end
--endregion

--region Sequence
---@description 타임리프 시퀀스 시작
function StartTimeleapSequence()
    if isSequenceRunning then
        Debug.Log("[TimeleapManager] WARNING: Sequence already running")
        return
    end

    isSequenceRunning = true
    Debug.Log("[TimeleapManager] Starting timeleap sequence")

    sequenceCoroutine = self:StartCoroutine(util.cs_generator(function()
        -- 1. 환경 연출 (단청 파티클, 스카이박스 변경)
        PlayDanchengEffect()
        coroutine.yield(WaitForSeconds(danchengDuration))

        -- 2. 사운드 연출 (종소리, 바람소리)
        PlayTimeleapSounds()
        coroutine.yield(WaitForSeconds(goblinAppearDelay))

        -- 3. 도깨비 등장 및 대사 재생 (GoblinNPC 시스템 사용)
        if goblinNPC then
            -- GoblinNPC의 타임리프 시퀀스 호출
            local dialogueComplete = false
            goblinNPC.PlayTimeleapSequence(function()
                dialogueComplete = true
            end)
            
            -- 대사 완료 대기
            while not dialogueComplete do
                coroutine.yield(nil)
            end
        else
            -- GoblinNPC가 없으면 기존 방식으로 처리
            ShowGoblin()
            coroutine.yield(WaitForSeconds(1.0))
            PlayGoblinDialogue()
            coroutine.yield(WaitForSeconds(6.0)) -- 기본 대사 시간
        end

        -- 4. Round 1 (판돌 건너기)로 전환
        if gameFlowManager then
            gameFlowManager.TransitionToRound1()
        end

        isSequenceRunning = false
        sequenceCoroutine = nil
    end))
end

---@description 타임리프 시퀀스 중지
function StopSequence()
    if sequenceCoroutine then
        self:StopCoroutine(sequenceCoroutine)
        sequenceCoroutine = nil
    end
    
    -- GoblinNPC 시퀀스도 중지
    if goblinNPC then
        goblinNPC.StopCurrentSequence()
    end
    
    isSequenceRunning = false
end
--endregion

--region Effects
---@description 단청 파편 연출
function PlayDanchengEffect()
    Debug.Log("[TimeleapManager] Playing Dancheng effect")

    -- 스카이박스 변경
    if joseonSkybox then
        RenderSettings.skybox = joseonSkybox
    end

    -- 단청 파티클 재생
    if danchengParticle then
        danchengParticle:Play()
    end
end

---@description 타임리프 사운드 재생
function PlayTimeleapSounds()
    Debug.Log("[TimeleapManager] Playing timeleap sounds")

    if bellSound then
        bellSound:Play()
    end

    if windSound then
        windSound:Play()
    end
end

---@description 도깨비 등장 (GoblinNPC 연동)
function ShowGoblin()
    Debug.Log("[TimeleapManager] Showing Goblin")

    if goblinNPC then
        goblinNPC.Appear()
    elseif goblinObject then
        -- 폴백: GoblinNPC 없으면 단순 활성화
        goblinObject:SetActive(true)
    end
end

---@description 도깨비 대사 재생 (GoblinNPC 연동)
function PlayGoblinDialogue()
    Debug.Log("[TimeleapManager] Playing Goblin dialogue")

    if goblinNPC then
        goblinNPC.Speak("timeleap_intro", nil)
    elseif stageManager then
        -- 폴백: GoblinNPC 없으면 StageManager로 직접 자막
        stageManager.ShowSubtitle("경복궁의 시간을 지키기 위해\n너에게 두 가지 시험을 내리겠다.", 6.0)
    end
end

---@description 도깨비 숨기기 (GoblinNPC 연동)
function HideGoblin()
    if goblinNPC then
        goblinNPC.Disappear()
    elseif goblinObject then
        goblinObject:SetActive(false)
    end
end
--endregion

--region Public API
---@return boolean
---@description 시퀀스 실행 중 여부
function IsSequenceRunning()
    return isSequenceRunning
end

---@return table|nil
---@description GoblinNPC 스크립트 참조 반환
function GetGoblinNPC()
    return goblinNPC
end

---@param dialogueKey string
---@description 도깨비 대사 재생 (외부에서 호출 가능)
function PlayGoblinDialogueByKey(dialogueKey)
    if goblinNPC then
        goblinNPC.Speak(dialogueKey, nil)
    end
end
--endregion

