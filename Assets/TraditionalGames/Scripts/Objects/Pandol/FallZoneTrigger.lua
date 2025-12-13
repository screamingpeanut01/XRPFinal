---판돌 낙하 존 트리거
---@description 플레이어가 낙하 존에 떨어졌을 때 감지
---@usage FallZone 오브젝트에 VivenLuaBehaviour로 추가

--region Injection
local _INJECTED_ORDER = 0
local function NullableInject(OBJECT)
    _INJECTED_ORDER = _INJECTED_ORDER + 1
    if OBJECT == nil then
        Debug.Log(_INJECTED_ORDER .. "th object is missing (nullable)")
    end
    return OBJECT
end

---@type string
---@details PandolManager 스크립트 이름
pandolManagerName = NullableInject(pandolManagerName) or "PandolManager"

---@type GameObject
---@details PandolManager가 있는 오브젝트
pandolManagerObject = NullableInject(pandolManagerObject)

---@type number
---@details 쿨다운 시간 (리스폰 중 중복 감지 방지)
cooldownTime = NullableInject(cooldownTime) or 1.0
--endregion

--region Variables
local pandolManager = nil
local lastTriggerTime = 0
--endregion

--region Lifecycle
function start()
    -- PandolManager 찾기
    if pandolManagerObject then
        pandolManager = pandolManagerObject:GetLuaComponent(pandolManagerName)
    end
    
    if not pandolManager then
        -- 부모에서 찾기
        pandolManager = self:GetLuaComponentInParent(pandolManagerName)
    end
    
    if pandolManager then
        Debug.Log("[FallZoneTrigger] PandolManager found")
    else
        Debug.Log("[FallZoneTrigger] WARNING: PandolManager not found")
    end
end
--endregion

--region Helper
local function IsPlayerController(gameObject)
    if not gameObject then return false end
    
    local name = gameObject.name:lower()
    
    -- VR 플레이어 관련 이름 패턴들
    if name:find("player") or name:find("controller") or name:find("hand") then
        return true
    end
    
    -- RIIO VR 관련
    if name:find("riio") or name:find("avatar") or name:find("interactor") then
        return true
    end
    
    -- CharacterController 관련
    if name:find("character") or name:find("grabber") or name:find("placer") then
        return true
    end
    
    if gameObject.tag == "Player" then
        return true
    end
    
    return false
end
--endregion

--region Trigger Events
function onTriggerEnter(other)
    -- [DEBUG] 모든 트리거 충돌 로깅
    Debug.Log("[FallZoneTrigger] Trigger with: " .. other.name .. " (Tag: " .. other.tag .. ")")
    
    -- 쿨다운 체크
    local currentTime = Time.time
    if currentTime - lastTriggerTime < cooldownTime then
        Debug.Log("[FallZoneTrigger] Cooldown active, ignoring")
        return
    end
    
    local isPlayer = IsPlayerController(other.gameObject)
    Debug.Log("[FallZoneTrigger] IsPlayer: " .. tostring(isPlayer))
    
    if isPlayer then
        lastTriggerTime = currentTime
        Debug.Log("[FallZoneTrigger] Player fell! Calling OnPlayerFall...")
        
        if pandolManager then
            pandolManager.OnPlayerFall()
            Debug.Log("[FallZoneTrigger] OnPlayerFall called successfully")
        else
            Debug.Log("[FallZoneTrigger] ERROR: pandolManager is nil!")
        end
    end
end
--endregion
