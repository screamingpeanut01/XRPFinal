---도깨비 NPC 시스템
---@description 수문도깨비의 등장, 대화, 애니메이션 관리
---@usage 도깨비 오브젝트에 VivenLuaBehaviour로 추가

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
---@details StageManager 스크립트 이름
stageManagerName = NullableInject(stageManagerName) or "StageManager"

---@type Animator
---@details 도깨비 애니메이터 컴포넌트
animator = NullableInject(animator)

---@type AudioSource
---@details 도깨비 음성 오디오 소스
voiceAudioSource = NullableInject(voiceAudioSource)

---@type ParticleSystem
---@details 등장 파티클 시스템
appearParticle = NullableInject(appearParticle)

---@type ParticleSystem
---@details 퇴장 파티클 시스템
disappearParticle = NullableInject(disappearParticle)

---@type GameObject
---@details 도깨비 메쉬/비주얼 오브젝트 (등장/퇴장 시 활성화/비활성화)
visualObject = NullableInject(visualObject)

---@type number
---@details 등장 연출 시간 (초)
appearDuration = NullableInject(appearDuration) or 1.5

---@type number
---@details 퇴장 연출 시간 (초)
disappearDuration = NullableInject(disappearDuration) or 1.0

---@type boolean
---@details 플레이어 바라보기 활성화 여부
lookAtPlayer = NullableInject(lookAtPlayer)
if lookAtPlayer == nil then lookAtPlayer = true end

---@type number
---@details 플레이어 바라보기 회전 속도
lookAtSpeed = NullableInject(lookAtSpeed) or 2.0

---@type GameObject
---@details 자막 캔버스 (도깨비 머리 위)
subtitleCanvas = NullableInject(subtitleCanvas)

---@type GameObject
---@details 자막 텍스트 오브젝트 (TMP_Text 포함)
subtitleTextObject = NullableInject(subtitleTextObject)

-- 대사별 오디오 클립 (Inspector에서 연결)
---@type AudioClip
---@details 타임리프 인트로 대사
timeleap_introClip = NullableInject(timeleap_introClip)

---@type AudioClip
---@details 판돌 인트로 대사
round1_introClip = NullableInject(round1_introClip)

---@type AudioClip
---@details 판돌 힌트 대사
round1_hintClip = NullableInject(round1_hintClip)

---@type AudioClip
---@details 판돌 성공 대사
round1_successClip = NullableInject(round1_successClip)

---@type AudioClip
---@details 판돌 실패 대사
round1_failClip = NullableInject(round1_failClip)

---@type AudioClip
---@details 비석 인트로 대사
round2_introClip = NullableInject(round2_introClip)

---@type AudioClip
---@details 비석 힌트 대사
round2_hintClip = NullableInject(round2_hintClip)

---@type AudioClip
---@details 비석 성공 대사
round2_successClip = NullableInject(round2_successClip)

---@type AudioClip
---@details 엔딩 진심 대사
ending_truthClip = NullableInject(ending_truthClip)

---@type AudioClip
---@details 엔딩 배지 대사
ending_badgeClip = NullableInject(ending_badgeClip)

---@type AudioClip
---@details 엔딩 작별 대사
ending_farewellClip = NullableInject(ending_farewellClip)
--endregion

--region Variables
local util = require 'xlua.util'

---@type table
local stageManager = nil

---@type TMP_Text
local subtitleTMP = nil

---@type boolean
local isAppeared = false

---@type boolean
local isSpeaking = false

---@type Coroutine
local currentCoroutine = nil

---@type Transform
local playerTransform = nil

-- 대사 데이터베이스 (start에서 오디오 클립 연결)
---@type table<string, DialogueData>
local dialogueDatabase = {}

---@description 대사 데이터베이스 초기화 (오디오 클립 연결)
local function InitDialogueDatabase()
    dialogueDatabase = {
        -- 타임리프 등장 대사
        timeleap_intro = {
            text = "경복궁의 시간을 지키기 위해\n너에게 두 가지 시험을 내리겠다.\n이를 통과해야 네 시대로 돌아갈 수 있다.",
            duration = 6.0,
            animTrigger = "Talk",
            clip = timeleap_introClip
        },
        
        -- Round 1 (판돌 건너기) 대사
        round1_intro = {
            text = "첫 번째 시험이다.\n눈에 보이는 길만이 정답은 아니다.\n직감을 믿어 앞으로 나아가라.",
            duration = 5.0,
            animTrigger = "Talk",
            clip = round1_introClip
        },
        round1_hint = {
            text = "서두르지 마라. 발을 옮기기 전에 잘 생각해라.",
            duration = 3.0,
            animTrigger = "Hint",
            clip = round1_hintClip
        },
        round1_success = {
            text = "훌륭하다. 첫 번째 시험을 통과했다.",
            duration = 3.0,
            animTrigger = "Clap",
            clip = round1_successClip
        },
        round1_fail = {
            text = "아직 멀었구나. 다시 도전해보아라.",
            duration = 2.5,
            animTrigger = "Shake",
            clip = round1_failClip
        },
        
        -- Round 2 (비석치기) 대사
        round2_intro = {
            text = "마지막 시험이다.\n너의 손끝에서 결과가 갈린다.\n시간의 비석을 쓰러뜨려라!",
            duration = 5.0,
            animTrigger = "Talk",
            clip = round2_introClip
        },
        round2_hint = {
            text = "힘을 조절하라. 너무 세지도, 너무 약하지도 않게.",
            duration = 3.0,
            animTrigger = "Hint",
            clip = round2_hintClip
        },
        round2_success = {
            text = "해냈구나! 모든 시험을 통과했다.",
            duration = 3.0,
            animTrigger = "Celebrate",
            clip = round2_successClip
        },
        
        -- 엔딩 대사
        ending_truth = {
            text = "너를 시험한 이유는\n전통이 잊혀져 가는 것이 두려웠기 때문이다.\n놀이에는 우리의 시간과 마음이 이어져 있다.",
            duration = 7.0,
            animTrigger = "Sad",
            clip = ending_truthClip
        },
        ending_farewell = {
            text = "너의 시대에서도 이 놀이를 다시 피워내주길 바란다.\n안녕히 가거라.",
            duration = 5.0,
            animTrigger = "Wave",
            clip = ending_farewellClip
        },
        ending_badge = {
            text = "이 배지를 가져가라.\n너는 이제 전통놀이 계승자다.",
            duration = 4.0,
            animTrigger = "Give",
            clip = ending_badgeClip
        }
    }
    Debug.Log("[GoblinNPC] Dialogue database initialized with audio clips")
end
--endregion

--region Lifecycle
function awake()
    -- 컴포넌트 자동 획득
    if not animator then
        animator = self:GetComponent(typeof(CS.UnityEngine.Animator))
    end
    
    if not voiceAudioSource then
        voiceAudioSource = self:GetComponent(typeof(CS.UnityEngine.AudioSource))
    end
    
    -- 대사 데이터베이스 초기화 (오디오 클립 연결)
    InitDialogueDatabase()
    
    Debug.Log("[GoblinNPC] Initialized")
end

function start()
    -- 초기 상태: 비활성화
    if visualObject then
        visualObject:SetActive(false)
    end
    isAppeared = false
    
    -- StageManager 찾기
    local managerObj = GameObject.Find("MANAGERS")
    if managerObj then
        stageManager = managerObj:GetLuaComponentInChildren(stageManagerName)
    end
    
    -- 로컬 자막 TMP_Text 가져오기
    if subtitleTextObject then
        subtitleTMP = subtitleTextObject:GetComponent(typeof(CS.TMPro.TMP_Text))
    end
    
    -- 자막 초기 비활성화
    if subtitleCanvas then
        subtitleCanvas:SetActive(false)
    end
end

function update()
    -- 플레이어 바라보기
    if isAppeared and lookAtPlayer and playerTransform then
        LookAtPlayerSmooth()
    end
end
--endregion

--region Appearance System
---@description 도깨비 등장 연출
function Appear()
    if isAppeared then
        Debug.Log("[GoblinNPC] Already appeared")
        return
    end
    
    Debug.Log("[GoblinNPC] Appearing...")
    
    -- 등장 파티클
    if appearParticle then
        appearParticle:Play()
    end
    
    -- 비주얼 활성화
    if visualObject then
        visualObject:SetActive(true)
    end
    
    -- 등장 애니메이션
    if animator then
        animator:SetTrigger("Appear")
    end
    
    isAppeared = true
    
    -- 플레이어 Transform 찾기
    FindPlayerTransform()
end

---@param callback function|nil
---@description 등장 연출 (코루틴 버전, 콜백 지원)
function AppearWithCallback(callback)
    if currentCoroutine then
        self:StopCoroutine(currentCoroutine)
    end
    
    currentCoroutine = self:StartCoroutine(util.cs_generator(function()
        Appear()
        coroutine.yield(WaitForSeconds(appearDuration))
        
        if callback then
            callback()
        end
        currentCoroutine = nil
    end))
end

---@description 도깨비 퇴장 연출
function Disappear()
    if not isAppeared then
        Debug.Log("[GoblinNPC] Already disappeared")
        return
    end
    
    Debug.Log("[GoblinNPC] Disappearing...")
    
    -- 퇴장 애니메이션
    if animator then
        animator:SetTrigger("Disappear")
    end
    
    -- 퇴장 파티클
    if disappearParticle then
        disappearParticle:Play()
    end
    
    -- 일정 시간 후 비활성화
    self:StartCoroutine(util.cs_generator(function()
        coroutine.yield(WaitForSeconds(disappearDuration))
        
        if visualObject then
            visualObject:SetActive(false)
        end
        
        isAppeared = false
    end))
end

---@param callback function|nil
---@description 퇴장 연출 (코루틴 버전, 콜백 지원)
function DisappearWithCallback(callback)
    if currentCoroutine then
        self:StopCoroutine(currentCoroutine)
    end
    
    currentCoroutine = self:StartCoroutine(util.cs_generator(function()
        Disappear()
        coroutine.yield(WaitForSeconds(disappearDuration + 0.5))
        
        if callback then
            callback()
        end
        currentCoroutine = nil
    end))
end
--endregion

--region Dialogue System
---@param dialogueKey string
---@param audioClip AudioClip|nil
---@description 특정 대사 재생
function Speak(dialogueKey, audioClipOverride)
    local dialogue = dialogueDatabase[dialogueKey]
    if not dialogue then
        Debug.Log("[GoblinNPC] Unknown dialogue key: " .. tostring(dialogueKey))
        return
    end
    
    -- 오디오 클립: 외부 전달 > 데이터베이스 클립
    local audioClip = audioClipOverride or dialogue.clip
    SpeakCustom(dialogue.text, dialogue.duration, dialogue.animTrigger, audioClip)
end

---@param text string
---@param duration number
---@param animTrigger string|nil
---@param audioClip AudioClip|nil
---@description 커스텀 대사 재생
function SpeakCustom(text, duration, animTrigger, audioClip)
    if isSpeaking then
        Debug.Log("[GoblinNPC] Already speaking, queuing...")
    end
    
    isSpeaking = true
    Debug.Log("[GoblinNPC] Speaking: " .. string.sub(text, 1, 30) .. "...")
    
    -- 애니메이션 트리거
    if animator and animTrigger then
        animator:SetTrigger(animTrigger)
    end
    
    -- 음성 재생
    if voiceAudioSource and audioClip then
        voiceAudioSource.clip = audioClip
        voiceAudioSource:Play()
    end
    
    -- 자막 표시 (로컬 자막 우선, 없으면 StageManager)
    if subtitleTMP and subtitleCanvas then
        subtitleTMP.text = text
        subtitleCanvas:SetActive(true)
        
        -- 자막 숨기기 코루틴
        self:StartCoroutine(util.cs_generator(function()
            coroutine.yield(WaitForSeconds(duration))
            if subtitleCanvas then
                subtitleCanvas:SetActive(false)
            end
        end))
    elseif stageManager then
        stageManager.ShowSubtitle(text, duration)
    end
    
    -- 말하기 완료 처리
    self:StartCoroutine(util.cs_generator(function()
        coroutine.yield(WaitForSeconds(duration))
        isSpeaking = false
    end))
end

---@param dialogueKey string
---@param audioClip AudioClip|nil
---@param callback function|nil
---@description 대사 재생 후 콜백 호출
function SpeakWithCallback(dialogueKey, audioClip, callback)
    local dialogue = dialogueDatabase[dialogueKey]
    if not dialogue then
        Debug.Log("[GoblinNPC] Unknown dialogue key: " .. tostring(dialogueKey))
        if callback then callback() end
        return
    end
    
    if currentCoroutine then
        self:StopCoroutine(currentCoroutine)
    end
    
    currentCoroutine = self:StartCoroutine(util.cs_generator(function()
        Speak(dialogueKey, audioClip)
        coroutine.yield(WaitForSeconds(dialogue.duration + 0.5))
        
        if callback then
            callback()
        end
        currentCoroutine = nil
    end))
end

---@param dialogueKeys table<number, string>
---@param audioClips table<number, AudioClip>|nil
---@param callback function|nil
---@description 연속 대사 재생
function SpeakSequence(dialogueKeys, audioClips, callback)
    if currentCoroutine then
        self:StopCoroutine(currentCoroutine)
    end
    
    currentCoroutine = self:StartCoroutine(util.cs_generator(function()
        for i, key in ipairs(dialogueKeys) do
            local audioClip = audioClips and audioClips[i] or nil
            local dialogue = dialogueDatabase[key]
            
            if dialogue then
                Speak(key, audioClip)
                coroutine.yield(WaitForSeconds(dialogue.duration + 1.0))
            end
        end
        
        if callback then
            callback()
        end
        currentCoroutine = nil
    end))
end
--endregion

--region Animation Control
---@param triggerName string
---@description 애니메이션 트리거 설정
function PlayAnimation(triggerName)
    if animator then
        animator:SetTrigger(triggerName)
        Debug.Log("[GoblinNPC] Animation trigger: " .. triggerName)
    end
end

---@param paramName string
---@param value boolean
---@description 애니메이션 파라미터 설정 (Bool)
function SetAnimBool(paramName, value)
    if animator then
        animator:SetBool(paramName, value)
    end
end

---@param paramName string
---@param value number
---@description 애니메이션 파라미터 설정 (Float)
function SetAnimFloat(paramName, value)
    if animator then
        animator:SetFloat(paramName, value)
    end
end
--endregion

--region Look At System
---@description 플레이어 Transform 찾기
function FindPlayerTransform()
    -- VIVEN SDK에서 플레이어 카메라 찾기
    local mainCamera = Camera.main
    if mainCamera then
        playerTransform = mainCamera.transform
        Debug.Log("[GoblinNPC] Player transform found")
    end
end

---@description 플레이어를 부드럽게 바라보기 (Y축만 회전)
function LookAtPlayerSmooth()
    if not playerTransform then return end
    
    local myTransform = self.transform
    local targetPos = playerTransform.position
    
    -- Y축 회전만 적용 (수평 바라보기)
    local direction = targetPos - myTransform.position
    direction.y = 0  -- Y 방향 무시
    
    if direction.sqrMagnitude > 0.01 then
        local targetRotation = Quaternion.LookRotation(direction)
        
        -- Y축만 추출해서 회전 (X, Z는 0 유지)
        local targetEuler = targetRotation.eulerAngles
        local currentEuler = myTransform.rotation.eulerAngles
        
        -- Y축만 부드럽게 보간
        local newY = Mathf.LerpAngle(currentEuler.y, targetEuler.y, Time.deltaTime * lookAtSpeed)
        myTransform.rotation = Quaternion.Euler(0, newY, 0)
    end
end

---@description 즉시 플레이어 바라보기
function LookAtPlayerImmediate()
    if not playerTransform then
        FindPlayerTransform()
    end
    
    if playerTransform then
        local myTransform = self.transform
        local direction = playerTransform.position - myTransform.position
        direction.y = 0
        
        if direction.sqrMagnitude > 0.01 then
            myTransform.rotation = Quaternion.LookRotation(direction)
        end
    end
end
--endregion

--region Scene-Specific Sequences
---@param callback function|nil
---@description 타임리프 씬용 등장 시퀀스
function PlayTimeleapSequence(callback)
    Debug.Log("[GoblinNPC] Starting Timeleap sequence")
    
    AppearWithCallback(function()
        LookAtPlayerImmediate()
        SpeakWithCallback("timeleap_intro", nil, callback)
    end)
end

---@param callback function|nil
---@description 라운드 1 인트로 시퀀스
function PlayRound1IntroSequence(callback)
    Debug.Log("[GoblinNPC] Starting Round1 intro sequence")
    
    if isAppeared then
        SpeakWithCallback("round1_intro", nil, callback)
    else
        AppearWithCallback(function()
            SpeakWithCallback("round1_intro", nil, callback)
        end)
    end
end

---@param callback function|nil
---@description 라운드 2 인트로 시퀀스
function PlayRound2IntroSequence(callback)
    Debug.Log("[GoblinNPC] Starting Round2 intro sequence")
    
    if isAppeared then
        SpeakWithCallback("round2_intro", nil, callback)
    else
        AppearWithCallback(function()
            SpeakWithCallback("round2_intro", nil, callback)
        end)
    end
end

---@param callback function|nil
---@description 엔딩 전체 시퀀스
function PlayEndingSequence(callback)
    Debug.Log("[GoblinNPC] Starting Ending sequence")
    
    local endingDialogues = { "ending_truth", "ending_badge", "ending_farewell" }
    
    if isAppeared then
        SpeakSequence(endingDialogues, nil, function()
            DisappearWithCallback(callback)
        end)
    else
        AppearWithCallback(function()
            SpeakSequence(endingDialogues, nil, function()
                DisappearWithCallback(callback)
            end)
        end)
    end
end
--endregion

--region Public API
---@return boolean
---@description 도깨비 등장 여부
function IsAppeared()
    return isAppeared
end

---@return boolean
---@description 도깨비가 말하고 있는지 여부
function IsSpeaking()
    return isSpeaking
end

---@param key string
---@param dialogueData table
---@description 대사 데이터베이스에 새 대사 추가
function AddDialogue(key, dialogueData)
    dialogueDatabase[key] = dialogueData
end

---@param key string
---@return table|nil
---@description 대사 데이터 조회
function GetDialogue(key)
    return dialogueDatabase[key]
end

---@description 현재 진행 중인 시퀀스 중지
function StopCurrentSequence()
    if currentCoroutine then
        self:StopCoroutine(currentCoroutine)
        currentCoroutine = nil
    end
    isSpeaking = false
end
--endregion
