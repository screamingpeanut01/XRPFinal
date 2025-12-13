---던지는 돌 스크립트
---@description VR 손으로 잡아서 던지는 돌 관리
---@usage 돌 프리팹에 VivenLuaBehaviour로 추가 (VivenGrabbableModule과 함께)

--region Injection
local _INJECTED_ORDER = 0
local function NullableInject(OBJECT)
    _INJECTED_ORDER = _INJECTED_ORDER + 1
    if OBJECT == nil then
        Debug.Log(_INJECTED_ORDER .. "th object is missing (nullable)")
    end
    return OBJECT
end

---@type number
---@details 최소 던지기 속도 (이 속도 이상이어야 던진 것으로 판정)
minThrowVelocity = NullableInject(minThrowVelocity) or 2.0

---@type number
---@details 던지기 힘 배율
throwForceMultiplier = NullableInject(throwForceMultiplier) or 1.5

---@type number
---@details 생존 시간 (초) - 이 시간 후 자동 제거
lifeTime = NullableInject(lifeTime) or 10.0

---@type ParticleSystem
---@details 잡았을 때 파티클
grabParticle = NullableInject(grabParticle)

---@type AudioSource
---@details 잡았을 때 사운드
grabSound = NullableInject(grabSound)
--endregion

--region Variables
local util = require 'xlua.util'

local manager = nil
local rb = nil
local grabbable = nil

local isGrabbed = false
local hasBeenThrown = false
local grabHand = nil  -- "left" or "right"
--endregion

--region Lifecycle
function awake()
    rb = self:GetComponent(typeof(CS.UnityEngine.Rigidbody))
    grabbable = self:GetComponent("VivenGrabbableModule")
    
    Debug.Log("[ThrowingStone] Initialized")
end

function start()
    -- 생존 시간 설정
    if lifeTime > 0 then
        self:StartCoroutine(util.cs_generator(function()
            coroutine.yield(WaitForSeconds(lifeTime))
            if self.gameObject then
                Debug.Log("[ThrowingStone] Lifetime expired, destroying")
                GameObject.Destroy(self.gameObject)
            end
        end))
    end
end
--endregion

--region Grab Events (VivenGrabbableModule에서 호출)
---@description 잡았을 때 호출
function onGrab()
    isGrabbed = true
    Debug.Log("[ThrowingStone] Grabbed")
    
    -- 잡기 효과
    if grabSound then
        grabSound:Play()
    end
    if grabParticle then
        grabParticle:Play()
    end
    
    -- 햅틱 피드백
    XR.StartControllerVibration(false, 0.3, 0.1)
    XR.StartControllerVibration(true, 0.3, 0.1)
end

---@description 놓았을 때 호출
function onRelease()
    if not isGrabbed then return end
    
    isGrabbed = false
    Debug.Log("[ThrowingStone] Released")
    
    -- 속도 체크하여 던진 것으로 판정
    if rb then
        local velocity = rb.velocity
        local speed = velocity.magnitude
        
        Debug.Log("[ThrowingStone] Release velocity: " .. tostring(speed))
        
        if speed >= minThrowVelocity then
            OnThrown(velocity)
        end
    end
end
--endregion

--region Throw Logic
---@param velocity Vector3
---@description 던졌을 때 처리
function OnThrown(velocity)
    if hasBeenThrown then return end
    
    hasBeenThrown = true
    Debug.Log("[ThrowingStone] Thrown with velocity: " .. tostring(velocity.magnitude))
    
    -- 추가 힘 적용 (선택적)
    if rb and throwForceMultiplier > 1.0 then
        local additionalForce = velocity * (throwForceMultiplier - 1.0)
        rb:AddForce(additionalForce, CS.UnityEngine.ForceMode.VelocityChange)
    end
    
    -- 햅틱 피드백
    XR.StartControllerVibration(false, 0.5, 0.15)
    XR.StartControllerVibration(true, 0.5, 0.15)
    
    -- 매니저에 알림
    if manager then
        manager.OnStoneThrown(self.gameObject)
    end
end
--endregion

--region Collision Events
function onCollisionEnter(collision)
    -- 비석과 충돌 시 효과
    local otherName = collision.gameObject.name:lower()
    if otherName:find("biseok") or otherName:find("pillar") or collision.gameObject.tag == "Biseok" then
        OnHitBiseok(collision)
    end
end

---@param collision Collision
---@description 비석에 맞았을 때
function OnHitBiseok(collision)
    Debug.Log("[ThrowingStone] Hit biseok: " .. collision.gameObject.name)
    
    -- 충돌 햅틱
    XR.StartControllerVibration(false, 0.4, 0.1)
    XR.StartControllerVibration(true, 0.4, 0.1)
end
--endregion

--region Public API
---@param mgr table
---@description 매니저 설정 (BiseokManager에서 호출)
function SetManager(mgr)
    manager = mgr
end

---@return boolean
---@description 잡혀있는지 여부
function IsGrabbed()
    return isGrabbed
end

---@return boolean
---@description 던져졌는지 여부
function HasBeenThrown()
    return hasBeenThrown
end

---@description 수동으로 던지기 처리 (테스트용)
function ForceThrow(direction, force)
    if rb then
        rb:AddForce(direction * force, CS.UnityEngine.ForceMode.Impulse)
    end
    OnThrown(direction * force)
end
--endregion
