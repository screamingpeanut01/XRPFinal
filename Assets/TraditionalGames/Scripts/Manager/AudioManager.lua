---오디오 매니저
---@description BGM 및 SFX 관리

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

---@type AudioSource
---@details BGM 오디오 소스
bgmSource = NullableInject(bgmSource)

---@type AudioSource
---@details SFX 오디오 소스 (2D 사운드)
sfxSource = NullableInject(sfxSource)

---@type AudioClip
---@details 프롤로그 BGM (현대 경복궁)
bgmPrologue = NullableInject(bgmPrologue)

---@type AudioClip
---@details 타임리프 BGM
bgmTimeleap = NullableInject(bgmTimeleap)

---@type AudioClip
---@details 게임 라운드 BGM (판돌, 비석)
bgmRound = NullableInject(bgmRound)

---@type AudioClip
---@details 엔딩 BGM
bgmEnding = NullableInject(bgmEnding)

---@type AudioClip
---@details 성공 효과음
sfxSuccess = NullableInject(sfxSuccess)

---@type AudioClip
---@details 실패 효과음
sfxFail = NullableInject(sfxFail)

---@type AudioClip
---@details 유리 깨지는 효과음 (판돌)
sfxGlassBreak = NullableInject(sfxGlassBreak)

---@type AudioClip
---@details 돌 충돌 효과음 (비석치기)
sfxStoneHit = NullableInject(sfxStoneHit)

---@type AudioClip
---@details 종소리 (타임리프)
sfxBell = NullableInject(sfxBell)

---@type AudioClip
---@details 바람소리 (타임리프)
sfxWind = NullableInject(sfxWind)

---@type number
---@details BGM 페이드 시간 (초)
bgmFadeTime = NullableInject(bgmFadeTime) or 1.0

---@type number
---@details BGM 기본 볼륨
bgmVolume = NullableInject(bgmVolume) or 0.5

---@type number
---@details SFX 기본 볼륨
sfxVolume = NullableInject(sfxVolume) or 1.0
--endregion

--region Variables
local util = require 'xlua.util'

---@type table<string, AudioClip>
local bgmClips = {}

local currentBGM = nil
local fadeCoroutine = nil
--endregion

--region Lifecycle
function awake()
    -- BGM 클립 테이블 초기화
    bgmClips = {
        Prologue = bgmPrologue,
        Timeleap = bgmTimeleap,
        Round1 = bgmRound,
        Round2 = bgmRound,
        Ending = bgmEnding
    }

    Debug.Log("[AudioManager] Initialized")
end

function start()
    -- 초기 볼륨 설정
    if bgmSource then
        bgmSource.volume = bgmVolume
        bgmSource.loop = true
    end

    if sfxSource then
        sfxSource.volume = sfxVolume
    end
end
--endregion

--region BGM Control
---@param stageName string
---@param fadeIn boolean|nil
---@description 스테이지에 맞는 BGM 재생
function PlayBGMForStage(stageName, fadeIn)
    local clip = bgmClips[stageName]
    if not clip then
        Debug.Log("[AudioManager] WARNING: No BGM for stage: " .. stageName)
        return
    end

    if fadeIn then
        FadeInBGM(clip)
    else
        PlayBGM(clip)
    end
end

---@param clip AudioClip
---@description BGM 즉시 재생
function PlayBGM(clip)
    if not bgmSource then return end

    bgmSource.clip = clip
    bgmSource.volume = bgmVolume
    bgmSource:Play()
    currentBGM = clip
    Debug.Log("[AudioManager] Playing BGM: " .. clip.name)
end

---@param clip AudioClip
---@description BGM 페이드 인 재생
function FadeInBGM(clip)
    if not bgmSource then return end

    if fadeCoroutine then
        self:StopCoroutine(fadeCoroutine)
    end

    fadeCoroutine = self:StartCoroutine(util.cs_generator(function()
        bgmSource.clip = clip
        bgmSource.volume = 0
        bgmSource:Play()
        currentBGM = clip

        local elapsed = 0
        while elapsed < bgmFadeTime do
            elapsed = elapsed + Time.deltaTime
            bgmSource.volume = (elapsed / bgmFadeTime) * bgmVolume
            coroutine.yield(nil)
        end
        bgmSource.volume = bgmVolume

        fadeCoroutine = nil
    end))
end

---@description BGM 페이드 아웃 정지
function FadeOutBGM()
    if not bgmSource then return end

    if fadeCoroutine then
        self:StopCoroutine(fadeCoroutine)
    end

    fadeCoroutine = self:StartCoroutine(util.cs_generator(function()
        local startVolume = bgmSource.volume
        local elapsed = 0

        while elapsed < bgmFadeTime do
            elapsed = elapsed + Time.deltaTime
            bgmSource.volume = startVolume * (1 - (elapsed / bgmFadeTime))
            coroutine.yield(nil)
        end

        bgmSource:Stop()
        bgmSource.volume = bgmVolume
        currentBGM = nil

        fadeCoroutine = nil
    end))
end

---@description BGM 즉시 정지
function StopBGM()
    if not bgmSource then return end

    if fadeCoroutine then
        self:StopCoroutine(fadeCoroutine)
        fadeCoroutine = nil
    end

    bgmSource:Stop()
    currentBGM = nil
end

---@param volume number
---@description BGM 볼륨 설정 (0.0 ~ 1.0)
function SetBGMVolume(volume)
    bgmVolume = math.max(0, math.min(1, volume))
    if bgmSource then
        bgmSource.volume = bgmVolume
    end
end
--endregion

--region SFX Control
---@param clip AudioClip
---@description SFX 재생 (2D)
function PlaySFX(clip)
    if not sfxSource or not clip then return end

    sfxSource:PlayOneShot(clip, sfxVolume)
end

---@param clip AudioClip
---@param position Vector3
---@description SFX 재생 (3D, 위치 지정)
function PlaySFXAtPoint(clip, position)
    if not clip then return end

    AudioSource.PlayClipAtPoint(clip, position, sfxVolume)
end

---@description 성공 효과음 재생
function PlaySuccessSFX()
    PlaySFX(sfxSuccess)
end

---@description 실패 효과음 재생
function PlayFailSFX()
    PlaySFX(sfxFail)
end

---@description 유리 깨지는 효과음 재생
function PlayGlassBreakSFX()
    PlaySFX(sfxGlassBreak)
end

---@param position Vector3
---@description 돌 충돌 효과음 재생 (3D)
function PlayStoneHitSFXAtPoint(position)
    PlaySFXAtPoint(sfxStoneHit, position)
end

---@description 종소리 재생
function PlayBellSFX()
    PlaySFX(sfxBell)
end

---@description 바람소리 재생
function PlayWindSFX()
    PlaySFX(sfxWind)
end

---@param volume number
---@description SFX 볼륨 설정 (0.0 ~ 1.0)
function SetSFXVolume(volume)
    sfxVolume = math.max(0, math.min(1, volume))
    if sfxSource then
        sfxSource.volume = sfxVolume
    end
end
--endregion
