---보따리 트리거 스크립트
---@description 프롤로그에서 보따리 상호작용 처리

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
---@details "열기" 안내 UI 오브젝트 [선택 - 나중에 추가]
openUIObject = NullableInject(openUIObject)

---@type AudioSource
---@details 나레이션 오디오 소스 ("뭐지... 왜 이런 데 보따리가 있지?")
narrationAudio = NullableInject(narrationAudio)

---@type ParticleSystem
---@details 보따리 주변 파티클 이펙트
sparkleParticle = NullableInject(sparkleParticle)

---@type AudioSource
---@details 보따리 열기 효과음
openSound = NullableInject(openSound)

---@type number
---@details 나레이션 재생 지연 시간 (초)
narrationDelay = NullableInject(narrationDelay) or 1.0

---@type Animator
---@details 보따리 애니메이터 (열기 애니메이션)
bottariAnimator = NullableInject(bottariAnimator)


---@type number
---@details 카운트다운 시작 숫자 (기본값: 5)
countdownStart = NullableInject(countdownStart) or 5
--endregion

--region Variables
local util = require 'xlua.util'
local TMP_Text = typeof(CS.TMPro.TMP_Text)

local gameFlowManager = nil
local isPlayerNear = false
local hasTriggered = false

---@type TMP_Text
local countdownText = nil
--endregion

--region Lifecycle
function awake()
    gameFlowManager = self:GetLuaComponentInParent(gameFlowManagerName)

    if not gameFlowManager then
        -- 부모에서 못 찾으면 전역에서 찾기
        local managerObj = GameObject.Find("MANAGERS")
        if managerObj then
            gameFlowManager = managerObj:GetLuaComponentInChildren(gameFlowManagerName)
        end
    end

    -- openUIObject에서 TMP_Text 컴포넌트 가져오기
    if openUIObject then
        countdownText = openUIObject:GetComponentInChildren(TMP_Text)
    end

    Debug.Log("[BottariTrigger] Initialized")
end

function start()
    -- UI 초기 비활성화
    if openUIObject then
        openUIObject:SetActive(false)
    end


    -- 파티클 재생
    if sparkleParticle then
        sparkleParticle:Play()
    end

    -- 나레이션 지연 재생
    if narrationAudio then
        self:StartCoroutine(util.cs_generator(function()
            coroutine.yield(WaitForSeconds(narrationDelay))
            if not hasTriggered then
                narrationAudio:Play()
            end
        end))
    end
end
--endregion

--region Trigger Events
function onTriggerEnter(other)
    if hasTriggered then return end

    -- VR 컨트롤러/손 감지 (GrabberPC, PlacerPC, Left Grabber, Interactor 등)
    local isPlayerHand = string.find(other.name, "Grabber") ~= nil
        or string.find(other.name, "Placer") ~= nil
        or string.find(other.name, "Interactor") ~= nil
        or string.find(other.name, "Hand") ~= nil
        or other.name == "CharacterController"
        or other.tag == "Player"

    if isPlayerHand then
        isPlayerNear = true
        Debug.Log("[BottariTrigger] Player entered trigger zone: " .. other.name)

        -- 자동으로 카운트다운 시작
        StartCountdown()
    end
end

function onTriggerExit(other)
    if hasTriggered then return end

    -- VR 컨트롤러/손 감지
    local isPlayerHand = string.find(other.name, "Grabber") ~= nil
        or string.find(other.name, "Placer") ~= nil
        or string.find(other.name, "Interactor") ~= nil
        or string.find(other.name, "Hand") ~= nil
        or other.name == "CharacterController"
        or other.tag == "Player"

    if isPlayerHand then
        isPlayerNear = false

        -- 안내 UI 숨김
        if openUIObject then
            openUIObject:SetActive(false)
        end

        Debug.Log("[BottariTrigger] Player exited trigger zone: " .. other.name)
    end
end
--endregion

--region Countdown
---@description 카운트다운 시작
function StartCountdown()
    if hasTriggered then return end

    hasTriggered = true
    Debug.Log("[BottariTrigger] Starting countdown...")

    self:StartCoroutine(util.cs_generator(function()
        -- openUI 활성화 (카운트다운 표시)
        if openUIObject then
            openUIObject:SetActive(true)
        end

        -- 카운트다운 표시
        for i = countdownStart, 1, -1 do
            if countdownText then
                countdownText.text = tostring(i)
            end
            Debug.Log("[BottariTrigger] Countdown: " .. i)
            coroutine.yield(WaitForSeconds(1.0))
        end

        -- openUI 비활성화
        if openUIObject then
            openUIObject:SetActive(false)
        end

        -- 카운트다운 완료
        if countdownText then
            countdownText.text = ""
        end

        Debug.Log("[BottariTrigger] Countdown complete! Opening bottari...")

        -- 보따리 열기 실행
        OnOpenBottari()
    end))
end
--endregion

--region Public API
---@description 보따리 열기 (카운트다운 완료 후 호출)
function OnOpenBottari()
    Debug.Log("[BottariTrigger] Bottari opened!")

    -- UI 숨김
    if openUIObject then
        openUIObject:SetActive(false)
    end

    -- 파티클 정지
    if sparkleParticle then
        sparkleParticle:Stop()
    end

    -- 열기 효과음
    if openSound then
        openSound:Play()
    end

    -- 열기 애니메이션
    if bottariAnimator then
        bottariAnimator:SetTrigger("Open")
    end

    -- 타임리프로 전환
    self:StartCoroutine(util.cs_generator(function()
        -- 애니메이션/효과 대기
        coroutine.yield(WaitForSeconds(1.0))

        if gameFlowManager then
            gameFlowManager.TransitionToTimeleap()
        else
            Debug.Log("[BottariTrigger] ERROR: GameFlowManager not found!")
        end
    end))
end

---@return boolean
---@description 보따리가 이미 열렸는지 확인
function IsTriggered()
    return hasTriggered
end

---@description 보따리 상태 리셋 (엔딩 후 현대 복귀 시 사용)
function ResetBottari()
    hasTriggered = false
    isPlayerNear = false

    if openUIObject then
        openUIObject:SetActive(false)
    end

    if sparkleParticle then
        sparkleParticle:Play()
    end

    if bottariAnimator then
        bottariAnimator:SetTrigger("Reset")
    end

    Debug.Log("[BottariTrigger] Bottari reset")
end

---@description 보따리 트리거 비활성화 (엔딩 후 재상호작용 방지)
function DisableTrigger()
    hasTriggered = true
    isPlayerNear = false

    if openUIObject then
        openUIObject:SetActive(false)
    end

    -- 파티클 정지 (닫힌 상태 유지)
    if sparkleParticle then
        sparkleParticle:Stop()
    end

    Debug.Log("[BottariTrigger] Trigger disabled (game completed)")
end

---@return boolean
---@description 트리거 활성화 여부
function IsTriggerEnabled()
    return not hasTriggered
end
--endregion
