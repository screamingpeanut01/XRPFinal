---발판 스크립트
---@description 개별 발판의 동작 관리 (안전/깨지는 발판)

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

---@type ParticleSystem
---@details 깨지는 효과 파티클
breakParticle = NullableInject(breakParticle)

---@type AudioSource
---@details 깨지는 효과음 오디오 소스
breakSound = NullableInject(breakSound)

---@type MeshRenderer
---@details 발판 메쉬 렌더러
meshRenderer = NullableInject(meshRenderer)

---@type Collider
---@details 발판 콜라이더
platformCollider = NullableInject(platformCollider)

---@type number
---@details 발판이 깨지기까지 딜레이 (초)
breakDelay = NullableInject(breakDelay) or 0.3

---@type boolean
---@details 이 발판이 안전한지 여부 (Inspector에서 설정 가능)
isSafePlatform = NullableInject(isSafePlatform)
--endregion

--region Variables
local util = require 'xlua.util'

local managerObject = nil  -- PandolManager의 GameObject를 저장
local isSafe = true
local hasTriggered = false
local isBreaking = false

-- Rigidbody 관련
local platformRigidbody = nil
local originalPosition = nil
local originalRotation = nil
--endregion

--region Lifecycle
function awake()
    -- meshRenderer, collider 자동 획득
    if not meshRenderer then
        meshRenderer = self:GetComponent(typeof(CS.UnityEngine.MeshRenderer))
    end

    if not platformCollider then
        platformCollider = self:GetComponent(typeof(CS.UnityEngine.Collider))
    end

    -- Rigidbody 자동 획득
    platformRigidbody = self:GetComponent(typeof(CS.UnityEngine.Rigidbody))
    if platformRigidbody then
        -- 초기 위치/회전 저장 (리셋용)
        originalPosition = self.transform.position
        originalRotation = self.transform.rotation
        -- 초기에는 중력만 비활성화 (isKinematic은 Inspector 설정 유지)
        platformRigidbody.useGravity = false
    end

    -- Inspector에서 설정된 값 적용
    if isSafePlatform ~= nil then
        isSafe = isSafePlatform
    end
end

function start()
    -- 초기 상태 설정
    hasTriggered = false
    isBreaking = false
end
--endregion

--region Collision Events
function onCollisionEnter(collision)
    -- 공통 처리 함수 호출
    HandleHit(collision.gameObject)
end

function onTriggerEnter(other)
    if hasTriggered then return end
    
    -- 디버깅용 로그
    Debug.Log("[PlatformStep] Trigger with: " .. other.name .. " (Tag: " .. other.tag .. ")")
    
    HandleHit(other.gameObject)
end

---@param targetObj GameObject
function HandleHit(targetObj)
    if hasTriggered then return end

    -- 플레이어와 충돌 체크 (BottariTrigger 로직 참조)
    local objName = targetObj.name
    local isPlayer = false
    
    if targetObj.tag == "Player" then
        isPlayer = true
    elseif string.find(objName, "Player") or string.find(objName, "Avatar") then
        isPlayer = true
    elseif string.find(objName, "Grabber") or string.find(objName, "Placer") or string.find(objName, "Interactor") or string.find(objName, "Hand") or string.find(objName, "CharacterController") then
        isPlayer = true
    end
    
    -- [DEBUG] 리지드바디가 있으면 플레이어로 간주 (필요시 주석 해제)
    -- local rb = targetObj:GetComponent(typeof(CS.UnityEngine.Rigidbody))
    -- if rb then isPlayer = true end

    if isPlayer then
        hasTriggered = true
        Debug.Log("[PlatformStep] Player detected! Safe: " .. tostring(isSafe))

        if not isSafe then
            -- 깨지는 발판
            StartBreaking()
        end
    else
        Debug.Log("[PlatformStep] Ignored object: " .. objName)
    end
end
--endregion

--region Break Logic
---@description 발판 깨지기 시작
function StartBreaking()
    if isBreaking then return end

    isBreaking = true
    Debug.Log("[PlatformStep] Platform breaking...")

    self:StartCoroutine(util.cs_generator(function()
        -- 약간의 딜레이
        coroutine.yield(WaitForSeconds(breakDelay))

        -- 매니저에 알림
        if managerObject then
            local managerScript = managerObject:GetLuaComponent("PandolManager")
            if managerScript and managerScript.OnPlatformBreak then
                managerScript.OnPlatformBreak(self.gameObject)
            else
                Debug.Log("[PlatformStep] Warning: Could not call OnPlatformBreak")
            end
        end

        -- 깨지는 효과
        BreakPlatform()
    end))
end

---@description 발판 깨짐 처리
function BreakPlatform()
    -- 효과음 재생
    if breakSound then
        breakSound:Play()
    end

    -- 파티클 재생
    if breakParticle then
        breakParticle:Play()
    end

    -- Rigidbody가 있으면 중력으로 떨어지게
    if platformRigidbody then
        platformRigidbody.useGravity = true
        -- 약간의 랜덤 토크로 자연스럽게 회전하며 떨어지게
        local randomTorque = CS.UnityEngine.Vector3(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)
        platformRigidbody:AddTorque(randomTorque * 3, CS.UnityEngine.ForceMode.Impulse)
        Debug.Log("[PlatformStep] Platform falling with gravity!")
    else
        -- Rigidbody가 없으면 기존 방식 (메쉬 숨기기)
        if meshRenderer then
            meshRenderer.enabled = false
        end
        if platformCollider then
            platformCollider.enabled = false
        end
        Debug.Log("[PlatformStep] Platform hidden (no Rigidbody)")
    end

    -- 일정 시간 후 오브젝트 비활성화 (낙하 후 정리)
    self:StartCoroutine(util.cs_generator(function()
        coroutine.yield(WaitForSeconds(3.0))  -- 3초 후 비활성화
        if meshRenderer then
            meshRenderer.enabled = false
        end
        if platformCollider then
            platformCollider.enabled = false
        end
        if platformRigidbody then
            platformRigidbody.useGravity = false
        end
    end))

    Debug.Log("[PlatformStep] Platform broken!")
end
--endregion

--region Public API
---@param mgrGameObject GameObject
---@description 매니저 설정 (PandolManager에서 호출)
function SetManager(mgrGameObject)
    managerObject = mgrGameObject
end

---@param safe boolean
---@description 발판 안전 여부 설정
function SetIsSafe(safe)
    isSafe = safe
end

---@return boolean
---@description 발판이 안전한지 확인
function GetIsSafe()
    return isSafe
end

---@return boolean
---@description 이미 밟혔는지 확인
function IsTriggered()
    return hasTriggered
end

---@description 발판 리셋
function ResetPlatform()
    hasTriggered = false
    isBreaking = false

    -- 메쉬 다시 보이기
    if meshRenderer then
        meshRenderer.enabled = true
    end

    -- 콜라이더 활성화
    if platformCollider then
        platformCollider.enabled = true
    end

    -- Rigidbody 초기화 및 위치 복구
    if platformRigidbody then
        platformRigidbody.useGravity = false
        platformRigidbody.velocity = CS.UnityEngine.Vector3.zero
        platformRigidbody.angularVelocity = CS.UnityEngine.Vector3.zero
    end

    -- 원래 위치/회전으로 복구
    if originalPosition then
        self.transform.position = originalPosition
    end
    if originalRotation then
        self.transform.rotation = originalRotation
    end

    Debug.Log("[PlatformStep] Platform reset!")
end
--endregion
