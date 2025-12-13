---판돌 골 존 트리거
---@description 플레이어가 골 존에 도달했을 때 감지
---@usage GoalZone 오브젝트에 VivenLuaBehaviour로 추가

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
--endregion

--region Variables
local pandolManager = nil
local hasTriggered = false
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
        Debug.Log("[GoalZoneTrigger] PandolManager found")
    else
        Debug.Log("[GoalZoneTrigger] WARNING: PandolManager not found")
    end
end

function onEnable()
    hasTriggered = false
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
    Debug.Log("[GoalZoneTrigger] Trigger with: " .. other.name .. " (Tag: " .. other.tag .. ")")
    
    if hasTriggered then 
        Debug.Log("[GoalZoneTrigger] Already triggered, ignoring")
        return 
    end
    
    local isPlayer = IsPlayerController(other.gameObject)
    Debug.Log("[GoalZoneTrigger] IsPlayer: " .. tostring(isPlayer))
    
    if isPlayer then
        hasTriggered = true
        Debug.Log("[GoalZoneTrigger] Player reached goal! Calling OnGoalReached...")
        
        if pandolManager then
            pandolManager.OnGoalReached()
            Debug.Log("[GoalZoneTrigger] OnGoalReached called successfully")
        else
            Debug.Log("[GoalZoneTrigger] ERROR: pandolManager is nil!")
        end
    end
end
--endregion
