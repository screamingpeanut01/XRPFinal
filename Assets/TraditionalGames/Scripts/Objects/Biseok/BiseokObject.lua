---비석 오브젝트 스크립트
---@description 개별 비석의 상태 및 효과 관리
---@usage 각 비석 오브젝트에 VivenLuaBehaviour로 추가

--region Injection
local _INJECTED_ORDER = 0
local function NullableInject(OBJECT)
    _INJECTED_ORDER = _INJECTED_ORDER + 1
    if OBJECT == nil then
        Debug.Log(_INJECTED_ORDER .. "th object is missing (nullable)")
    end
    return OBJECT
end

---@type ParticleSystem
---@details 쓰러짐 효과 파티클
fallParticle = NullableInject(fallParticle)

---@type ParticleSystem
---@details 충돌 효과 파티클
hitParticle = NullableInject(hitParticle)

---@type AudioSource
---@details 충돌 사운드
hitSound = NullableInject(hitSound)

---@type number
---@details 비석 질량 (Rigidbody mass 설정)
biseokMass = NullableInject(biseokMass) or 10

---@type boolean
---@details 처음에 Kinematic 상태로 시작할지
startKinematic = NullableInject(startKinematic)
if startKinematic == nil then startKinematic = false end
--endregion

--region Variables
local manager = nil
local isFallen = false
local rb = nil
local initialPosition = nil
local initialRotation = nil
--endregion

--region Lifecycle
function awake()
    rb = self:GetComponent(typeof(CS.UnityEngine.Rigidbody))
    
    -- 초기 위치/회전 저장
    initialPosition = self.transform.position
    initialRotation = self.transform.rotation
    
    Debug.Log("[BiseokObject] Initialized: " .. self.gameObject.name)
end

function start()
    -- Rigidbody 설정
    if rb then
        rb.mass = biseokMass
        rb.isKinematic = startKinematic
    end
end
--endregion

--region Collision Events
function onCollisionEnter(collision)
    -- 돌과 충돌 체크
    local otherName = collision.gameObject.name:lower()
    if otherName:find("stone") or otherName:find("rock") or collision.gameObject.tag == "Throwable" then
        OnHitByStone(collision)
    end
end
--endregion

--region Hit/Fall Logic
---@param collision Collision
---@description 돌에 맞았을 때 처리
function OnHitByStone(collision)
    Debug.Log("[BiseokObject] Hit by stone: " .. self.gameObject.name)
    
    -- 충돌 사운드
    if hitSound then
        hitSound:Play()
    end
    
    -- 충돌 파티클
    if hitParticle then
        hitParticle:Play()
    end
    
    -- Kinematic 해제 (물리 반응 활성화)
    if rb and rb.isKinematic then
        rb.isKinematic = false
    end
end

---@description 비석 쓰러짐 시 호출 (BiseokManager에서 호출)
function OnFallen()
    if isFallen then return end
    
    isFallen = true
    Debug.Log("[BiseokObject] Fallen: " .. self.gameObject.name)
    
    -- 쓰러짐 파티클
    if fallParticle then
        fallParticle:Play()
    end
end
--endregion

--region Public API
---@param mgr table
---@description 매니저 설정 (BiseokManager에서 호출)
function SetManager(mgr)
    manager = mgr
end

---@return boolean
---@description 쓰러짐 여부
function IsFallen()
    return isFallen
end

---@description 비석 리셋
function ResetBiseok()
    isFallen = false
    
    -- 위치/회전 복구
    if initialPosition then
        self.transform.position = initialPosition
    end
    if initialRotation then
        self.transform.rotation = initialRotation
    end
    
    -- Rigidbody 리셋
    if rb then
        rb.velocity = Vector3.zero
        rb.angularVelocity = Vector3.zero
        rb.isKinematic = startKinematic
    end
    
    Debug.Log("[BiseokObject] Reset: " .. self.gameObject.name)
end

---@description Kinematic 상태 해제 (물리 반응 활성화)
function EnablePhysics()
    if rb then
        rb.isKinematic = false
    end
end

---@description Kinematic 상태 설정 (물리 반응 비활성화)
function DisablePhysics()
    if rb then
        rb.isKinematic = true
    end
end
--endregion
