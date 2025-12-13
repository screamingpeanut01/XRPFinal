---엔딩 시스템 매니저
---@description 엔딩 연출 전체 관리 (도깨비 진심, 배지 지급, 현대 복귀)
---@usage Area_05_Ending 영역에 VivenLuaBehaviour로 추가

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

---@type GameObject
---@details 빛 기둥 오브젝트 (파티클 또는 메쉬)
lightPillar = NullableInject(lightPillar)

---@type GameObject
---@details 시간문 오브젝트
timeGate = NullableInject(timeGate)

---@type GameObject
---@details 배지 오브젝트 (3D 모델)
badgeObject = NullableInject(badgeObject)

---@type GameObject
---@details 배지 스폰 위치 (플레이어 앞)
badgeSpawnPoint = NullableInject(badgeSpawnPoint)

---@type ParticleSystem
---@details 빛 기둥 파티클
lightPillarParticle = NullableInject(lightPillarParticle)

---@type ParticleSystem
---@details 시간문 파티클
timeGateParticle = NullableInject(timeGateParticle)

---@type ParticleSystem
---@details 배지 등장 파티클
badgeParticle = NullableInject(badgeParticle)

---@type ParticleSystem
---@details 단청 붕괴 파티클
danchengCollapseParticle = NullableInject(danchengCollapseParticle)

---@type AudioSource
---@details 클리어 음악 (웅장한)
clearMusic = NullableInject(clearMusic)

---@type AudioSource
---@details 배지 등장 사운드
badgeSound = NullableInject(badgeSound)

---@type AudioSource
---@details 시간문 사운드
timeGateSound = NullableInject(timeGateSound)

---@type AudioSource
---@details 해금 BGM (은은한)
haegumBGM = NullableInject(haegumBGM)

---@type Material
---@details 현대 스카이박스 머티리얼
modernSkybox = NullableInject(modernSkybox)

---@type number
---@details 빛 기둥 연출 시간 (초)
lightPillarDuration = NullableInject(lightPillarDuration) or 3.0

---@type number
---@details 시간문 열리는 시간 (초)
timeGateOpenDuration = NullableInject(timeGateOpenDuration) or 2.0

---@type number
---@details 배지 회전 속도 (도/초)
badgeRotationSpeed = NullableInject(badgeRotationSpeed) or 30

---@type number
---@details 현대 복귀 전 대기 시간 (초)
returnDelay = NullableInject(returnDelay) or 3.0
--endregion

--region Variables
local util = require 'xlua.util'

local gameFlowManager = nil
local stageManager = nil
local goblinNPC = nil

local isSequenceRunning = false
local isSequenceComplete = false
local currentCoroutine = nil
local badgeRotating = false
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
    
    Debug.Log("[EndingManager] Initialized")
end

function start()
    -- 초기 상태: 모든 연출 오브젝트 비활성화
    HideAllEffects()
end

function onEnable()
    -- 영역 활성화 시 엔딩 시퀀스 시작
    Debug.Log("[EndingManager] Area enabled - Starting ending sequence")
    StartEndingSequence()
end

function onDisable()
    -- 영역 비활성화 시 정리
    StopSequence()
end

function update()
    -- 배지 회전 애니메이션
    if badgeRotating and badgeObject then
        local rotation = badgeObject.transform.rotation.eulerAngles
        rotation.y = rotation.y + badgeRotationSpeed * Time.deltaTime
        badgeObject.transform.rotation = Quaternion.Euler(rotation.x, rotation.y, rotation.z)
    end
end
--endregion

--region Initialization
---@description 모든 연출 오브젝트 비활성화
function HideAllEffects()
    if lightPillar then lightPillar:SetActive(false) end
    if timeGate then timeGate:SetActive(false) end
    if badgeObject then badgeObject:SetActive(false) end
end
--endregion

--region Ending Sequence
---@description 전체 엔딩 시퀀스 시작
function StartEndingSequence()
    if isSequenceRunning then
        Debug.Log("[EndingManager] Sequence already running")
        return
    end
    
    isSequenceRunning = true
    isSequenceComplete = false
    
    Debug.Log("[EndingManager] Starting ending sequence")
    
    if currentCoroutine then
        self:StopCoroutine(currentCoroutine)
    end
    
    currentCoroutine = self:StartCoroutine(util.cs_generator(function()
        -- Phase 1: 클리어 연출 (빛 기둥)
        PlayLightPillarEffect()
        coroutine.yield(WaitForSeconds(lightPillarDuration))
        
        -- Phase 2: 시간문 열림
        PlayTimeGateEffect()
        coroutine.yield(WaitForSeconds(timeGateOpenDuration))
        
        -- Phase 3: 도깨비 등장 및 진심 전달
        if goblinNPC then
            local dialogueComplete = false
            goblinNPC.PlayEndingSequence(function()
                dialogueComplete = true
            end)
            
            while not dialogueComplete do
                coroutine.yield(nil)
            end
        else
            -- 도깨비 없으면 자막으로 대체
            PlayFallbackDialogue()
            coroutine.yield(WaitForSeconds(15.0))
        end
        
        -- Phase 4: 배지 지급
        ShowBadge()
        coroutine.yield(WaitForSeconds(4.0))
        
        -- Phase 5: 단청 붕괴 연출
        PlayDanchengCollapseEffect()
        coroutine.yield(WaitForSeconds(2.0))
        
        -- Phase 6: 현대 복귀
        ReturnToModern()
        
        isSequenceComplete = true
        isSequenceRunning = false
        currentCoroutine = nil
    end))
end

---@description 시퀀스 중지
function StopSequence()
    if currentCoroutine then
        self:StopCoroutine(currentCoroutine)
        currentCoroutine = nil
    end
    
    isSequenceRunning = false
    badgeRotating = false
    
    -- GoblinNPC 시퀀스도 중지
    if goblinNPC then
        goblinNPC.StopCurrentSequence()
    end
end
--endregion

--region Effects
---@description 빛 기둥 연출
function PlayLightPillarEffect()
    Debug.Log("[EndingManager] Playing light pillar effect")
    
    -- 클리어 음악
    if clearMusic then
        clearMusic:Play()
    end
    
    -- 빛 기둥 활성화
    if lightPillar then
        lightPillar:SetActive(true)
    end
    
    -- 빛 기둥 파티클
    if lightPillarParticle then
        lightPillarParticle:Play()
    end
    
    -- 햅틱 피드백
    XR.StartControllerVibration(false, 0.4, 1.0)
    XR.StartControllerVibration(true, 0.4, 1.0)
end

---@description 시간문 열림 연출
function PlayTimeGateEffect()
    Debug.Log("[EndingManager] Playing time gate effect")
    
    -- 시간문 활성화
    if timeGate then
        timeGate:SetActive(true)
    end
    
    -- 시간문 파티클
    if timeGateParticle then
        timeGateParticle:Play()
    end
    
    -- 시간문 사운드
    if timeGateSound then
        timeGateSound:Play()
    end
end

---@description 배지 지급 연출
function ShowBadge()
    Debug.Log("[EndingManager] Showing badge")
    
    -- 배지 위치 설정 (플레이어 앞)
    if badgeObject and badgeSpawnPoint then
        badgeObject.transform.position = badgeSpawnPoint.transform.position
        badgeObject.transform.rotation = badgeSpawnPoint.transform.rotation
    end
    
    -- 배지 활성화
    if badgeObject then
        badgeObject:SetActive(true)
    end
    
    -- 배지 파티클
    if badgeParticle then
        badgeParticle:Play()
    end
    
    -- 배지 사운드
    if badgeSound then
        badgeSound:Play()
    end
    
    -- 배지 회전 시작
    badgeRotating = true
    
    -- 자막
    if stageManager then
        stageManager.ShowSubtitle("전통놀이 계승자 배지를 획득했습니다!", 3.0)
    end
    
    -- 햅틱 피드백
    XR.StartControllerVibration(false, 0.6, 0.5)
    XR.StartControllerVibration(true, 0.6, 0.5)
end

---@description 단청 붕괴 연출 (현대로 전환 전)
function PlayDanchengCollapseEffect()
    Debug.Log("[EndingManager] Playing dancheng collapse effect")
    
    -- 단청 붕괴 파티클
    if danchengCollapseParticle then
        danchengCollapseParticle:Play()
    end
    
    -- 해금 BGM 시작
    if haegumBGM then
        haegumBGM:Play()
    end
    
    -- 클리어 음악 페이드 아웃 (선택적)
    if clearMusic and clearMusic.isPlaying then
        -- 볼륨 페이드 아웃은 별도 구현 필요
    end
end

---@description 현대 경복궁으로 복귀
function ReturnToModern()
    Debug.Log("[EndingManager] Returning to modern Gyeongbokgung")
    
    -- 배지 회전 중지
    badgeRotating = false
    
    -- 자막
    if stageManager then
        stageManager.ShowSubtitle("당신의 시간, 돌아왔습니다.", 3.0)
    end
    
    self:StartCoroutine(util.cs_generator(function()
        coroutine.yield(WaitForSeconds(returnDelay))
        
        -- 스카이박스 변경 (현대)
        if modernSkybox then
            RenderSettings.skybox = modernSkybox
        end
        
        -- 프롤로그로 전환 (보따리 상호작용 불가 상태로)
        if gameFlowManager then
            gameFlowManager.TransitionToPrologueEnding()
        end
    end))
end

---@description 도깨비 없을 때 대체 대사
function PlayFallbackDialogue()
    Debug.Log("[EndingManager] Playing fallback dialogue")
    
    if not stageManager then return end
    
    self:StartCoroutine(util.cs_generator(function()
        stageManager.ShowSubtitle("너를 시험한 이유는\n전통이 잊혀져 가는 것이 두려웠기 때문이다.", 5.0)
        coroutine.yield(WaitForSeconds(6.0))
        
        stageManager.ShowSubtitle("놀이에는 우리의 시간과 마음이 이어져 있다.", 4.0)
        coroutine.yield(WaitForSeconds(5.0))
        
        stageManager.ShowSubtitle("너의 시대에서도 이 놀이를 다시 피워내주길 바란다.", 4.0)
    end))
end
--endregion

--region Public API
---@return boolean
---@description 시퀀스 진행 중 여부
function IsSequenceRunning()
    return isSequenceRunning
end

---@return boolean
---@description 시퀀스 완료 여부
function IsSequenceComplete()
    return isSequenceComplete
end

---@description 배지 회전 중지
function StopBadgeRotation()
    badgeRotating = false
end

---@description 배지 회전 시작
function StartBadgeRotation()
    badgeRotating = true
end

---@description 수동으로 특정 단계 실행 (디버그용)
function DebugPlayPhase(phase)
    if phase == "lightPillar" then
        PlayLightPillarEffect()
    elseif phase == "timeGate" then
        PlayTimeGateEffect()
    elseif phase == "badge" then
        ShowBadge()
    elseif phase == "collapse" then
        PlayDanchengCollapseEffect()
    elseif phase == "return" then
        ReturnToModern()
    end
end

---@description 엔딩 재시작 (디버그용)
function RestartEnding()
    StopSequence()
    HideAllEffects()
    StartEndingSequence()
end
--endregion
