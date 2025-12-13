---스테이지 매니저
---@description 각 스테이지의 상태 및 진행 관리

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
---@details GameFlowManager 스크립트 이름 [선택 - 기본값: "GameFlowManager"]
gameFlowManagerName = NullableInject(gameFlowManagerName) or "GameFlowManager"

---@type GameObject
---@details 자막 UI 캔버스
subtitleCanvas = NullableInject(subtitleCanvas)

---@type UnityEngine.UI.Text
---@details 자막 텍스트 컴포넌트
subtitleText = NullableInject(subtitleText)

---@type number
---@details 자막 표시 시간 (초)
subtitleDuration = NullableInject(subtitleDuration) or 3.0
--endregion

--region Variables
local util = require 'xlua.util'

local gameFlowManager = nil
local subtitleCoroutine = nil

---@type table
---@details 스테이지별 클리어 상태
local stageProgress = {
    Prologue = false,
    Timeleap = false,
    Round1 = false,
    Round2 = false,
    Ending = false
}
--endregion

--region Lifecycle
function awake()
    gameFlowManager = self:GetLuaComponentInParent(gameFlowManagerName)
    Debug.Log("[StageManager] Initialized")
end

function start()
    -- 자막 UI 초기 비활성화
    if subtitleCanvas then
        subtitleCanvas:SetActive(false)
    end
end
--endregion

--region Subtitle System
---@param text string
---@param duration number|nil
---@description 자막 표시 (duration 미지정 시 기본값 사용)
function ShowSubtitle(text, duration)
    if not subtitleCanvas or not subtitleText then
        Debug.Log("[StageManager] WARNING: Subtitle UI not configured")
        return
    end

    -- 기존 자막 코루틴 중지
    if subtitleCoroutine then
        self:StopCoroutine(subtitleCoroutine)
        subtitleCoroutine = nil
    end

    local displayDuration = duration or subtitleDuration

    subtitleCoroutine = self:StartCoroutine(util.cs_generator(function()
        -- 텍스트 설정 및 표시
        subtitleText.text = text
        subtitleCanvas:SetActive(true)

        -- 대기
        coroutine.yield(WaitForSeconds(displayDuration))

        -- 숨기기
        subtitleCanvas:SetActive(false)
        subtitleCoroutine = nil
    end))
end

---@description 자막 즉시 숨기기
function HideSubtitle()
    if subtitleCoroutine then
        self:StopCoroutine(subtitleCoroutine)
        subtitleCoroutine = nil
    end

    if subtitleCanvas then
        subtitleCanvas:SetActive(false)
    end
end
--endregion

--region Stage Progress
---@param stageName string
---@description 스테이지 클리어 상태 설정
function SetStageCleared(stageName)
    stageProgress[stageName] = true
    Debug.Log("[StageManager] Stage cleared: " .. stageName)
end

---@param stageName string
---@return boolean
---@description 스테이지 클리어 여부 확인
function IsStageClear(stageName)
    return stageProgress[stageName] or false
end

---@description 전체 스테이지 클리어 상태 초기화
function ResetAllProgress()
    for key, _ in pairs(stageProgress) do
        stageProgress[key] = false
    end
    Debug.Log("[StageManager] All progress reset")
end

---@return number
---@description 클리어한 스테이지 수 반환
function GetClearedStageCount()
    local count = 0
    for _, cleared in pairs(stageProgress) do
        if cleared then
            count = count + 1
        end
    end
    return count
end
--endregion

--region Toast Messages
---@param message string
---@description 토스트 메시지 표시 (VIVEN SDK)
function ShowToast(message)
    UI.ToastMessage(message)
end

---@param message string
---@param duration number
---@description 성공 메시지 표시
function ShowSuccessMessage(message, duration)
    ShowSubtitle(message, duration or 2.0)
    -- 추가 성공 효과 (사운드 등) 여기에 구현
end

---@param message string
---@param duration number
---@description 실패 메시지 표시
function ShowFailMessage(message, duration)
    ShowSubtitle(message, duration or 2.0)
    -- 추가 실패 효과 (사운드 등) 여기에 구현
end
--endregion

--region Public API
---@return table
---@description GameFlowManager 참조 반환
function GetGameFlowManager()
    return gameFlowManager
end
--endregion
