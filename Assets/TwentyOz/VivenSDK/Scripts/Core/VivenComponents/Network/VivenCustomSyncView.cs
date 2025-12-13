using System;
using TwentyOz.VivenSDK.Scripts.Core.Lua;
using TwentyOz.VivenSDK.Scripts.Core.VivenComponents.VivenFields;
using UnityEngine;

namespace TwentyOz.VivenSDK.Scripts.Core.VivenComponents.Network
{
    /// <summary>
    /// VivenSDK에서 사용하는 ObjSync Component
    /// </summary>
    /// <remarks>
    /// VivenBehaviour에서 선언된 변수들은 각 클라이언트에서만 사용됩니다.
    /// 모든 클라이언트에서 상태를 동기화하기 위해서는 <c>VivenCustomSyncView</c>를 사용해 데이터를 동기화해야 합니다.
    /// <br/>
    /// 다음과 같은 동기화를 지원합니다:
    /// <list type="number">
    /// <item>SyncVar 객체를 이용한 자동 변수 동기화 (권장)</item>
    /// <item>이벤트 함수를 이용한 수동 변수 동기화</item>
    /// <item>RPC를 활용한 이벤트성 함수 호출</item>
    /// </list>
    ///
    /// <para>
    /// 네트워크 이벤트는 다음 이벤트들을 기반으로 동작합니다.
    /// <list type="bullet">
    /// <item>
    ///     <term>onSyncViewInitialized</term>
    ///     <description>SyncView 초기화 시에 호출됩니다. 이 시점 이후부터 네트워크와 관련된 동작을 수행 할 수 있습니다.</description>
    /// </item>
    /// <item>
    ///     <term>sendSyncUpdate</term>
    ///     <description>데이터를 서버로 전송할때 호출됩니다. 해당 구현을 통해 동기화 할 데이터를 설정해 주세요.</description>
    /// </item>
    /// <item>
    ///     <term>receiveSyncUpdate</term>
    ///     <description>서버로부터 데이터를 받을때 호출됩니다. 해당 구현을 통해 동기화된 데이터를 처리해 주세요.</description>
    /// </item>
    /// <item>
    ///     <term>sendSyncFixedUpdate</term>
    ///     <description>데이터를 서버로 전송할때 호출됩니다. sendSyncUpdate와 다른 점은 Unity의 FixedUpdate 이벤트 위에서 작동합니다. Physic적인 동기화에 사용할 수 있습니다.</description>
    /// </item>
    /// <item>
    ///     <term>receiveSyncFixedUpdate</term>
    ///     <description>서버로부터 데이터를 받을때 호출됩니다. receiveSyncUpdate와 다른 점은 Unity의 FixedUpdate 이벤트 위에서 작동합니다. Physic적인 동기화에 사용할 수 있습니다.</description>
    /// </item>
    /// <item>
    ///     <term>onOwnerChanged</term>
    ///    <description>소유권이 변경되었을 때 호출됩니다. 소유권이 변경되면 해당 이벤트를 통해 소유권 변경에 대한 처리를 구현할 수 있습니다.</description>
    /// </item>
    /// </list>
    /// 각 이벤트 함수를 통해 데이터 동기화 시 행동을 구현할 수 있습니다.
    ///
    /// 
    /// <br/>
    /// 프로퍼티 동기화 예제는 다음과 같습니다.
    /// <code language="lua">
    /// -- 본 예제는 간단한 Transform Position 동기화 예제입니다.
    ///
    /// --@details SyncView가 초기화 되어 네트워크와 연결되었을때 호출됩니다.
    /// function onSyncViewInitialized()
    ///     -- 이 시점 이후 부터 네트워크와 관련된 동작을 수행 할 수 있습니다. 
    /// end
    /// ---@details 오브젝트의 소유권이 내것일 때 동기화 하고 싶은 Table을 리턴하면 됩니다.
    /// function sendSyncUpdate()
    ///     -- 현재 transform position을 동기화하기위하여 테이블 리턴 
    ///     local syncParam = {self.transform.position.x, self.transform.position.y, self.transform.position.z}
    ///     return syncParam
    /// end
    /// ---@details 오브젝트가 내것이 아니면 동기화 받은 데이터 처리 로직을 작성 하시면 됩니다.
    /// function receiveSyncUpdate(syncTable)
    ///     if (syncTable == nil or #syncTable &lt; 3) then 
    ///         return 
    ///     end
    ///     -- 동기화 받은 데이터로 transform 업데이트
    ///     self.transform.position = Vector3(syncTable[1], syncTable[2], syncTable[3])
    /// end
    /// ---@details 소유권을 요청함
    /// function requestOwnership()
    ///     -- SyncView는 숏컷입니다.
    ///     SyncView:RequestOwnership()
    /// end
    /// 
    /// ---@return boolean
    /// ---@details 소유권이 나에게 있는지를 반환함
    /// function getIsMine()
    ///     return SyncView.IsMine
    /// end
    /// </code>
    /// </para>
    /// RPC는 Remote Procedure Call(원격 프로시저 호출)의 약자로, 다른 유저의 네트워크 객체 내의 메소드 함수를 원격으로 호출 할 수 있는 기능을 제공합니다.
    /// View와 달리 연속적인 데이터 동기화가 아니라, 단방향의 이벤트성 동기화를 위해 사용합니다.
    ///
    /// 예제는 다음과 같습니다.
    /// 
    /// <para>
    /// <code language="lua">
    /// -- 나를 포함한 모든 방의 유저들에게 보내는 경우
    /// function rpc1()
    ///     local AllOption = RPCSendOption.All
    /// 
    ///     -- 필요한 parameter는 다음과 같습니다.
    ///       -- 1. 해당 rpc 코드를 작성하고 있는 스크립트 이름
    ///       -- 2. 실행하도록 하고   싶은 메소드   이름
    ///       -- 3. RPC option
    ///       -- 4. 실행하려는 메소드의 parameter. 사용 가능한 parameter 개수는 최대 5개입니다. 
    ///     SyncView:SendRPC("SendAll", AllOption, nil)
    /// end
    /// 
    /// function SendAll() 
    ///     -- 이 메소드는 나를 포함한 모든 유저들이 실행하게 됩니다.
    /// end
    /// -- 나를 제외한 모든 방의 유저들에게 보내는 경우
    /// function rpc2()
    ///     local OthersOption = RPCSendOption.Others
    ///     local table = {9, 1}
    /// 
    ///     SyncView:SendRPC("SendOthers", OthersOption, table)
    /// end
    /// 
    /// function SendOthers(a, b) 
    ///     -- 이       메소드는 나를 제외한 유저들이 실행하게 됩니다.
    ///     -- {9, 1}을 보냈으므로,  a = 9,   b = 1 입니다. 
    /// end
    /// </code>
    /// <b>SendTargetRPC</b>
    /// <br/>
    /// 유저의 id를 입력하여 해당 유저가 특정 메소드를 실행하도록 할 수 있습니다. 유저의 id는 Player.Other.GetPlayerID() 를 사용하여 알 수 있습니다.
    /// <code language="lua">
    /// function rpc3()
    ///     local players = {}
    ///     -- 닉네임이 "targetPlayerNickname"인 유저의 id를 받아옵니다.
    ///     players[1] = Player.Other.GetPlayerID("targetPlayerNickname")
    /// 
    ///     SyncView:SendTargetRPC("Test", "SendTarget", players, nil)
    /// end
    /// 
    ///     function SendTarget()
    ///     -- 닉네임이 "targetPlayerNickname"인 유저만 이 메소드를 실행하게 됩니다.
    /// end 
    /// </code>
    /// 
         /// <b>SyncVar 방식</b>
     /// <br/>
     /// SyncVar 객체를 이용하면 직관적으로 데이터를 동기화할 수 있습니다.
     /// <code language="lua">
     /// function awake()
     ///     -- SyncVar 객체 생성 (네트워크 동기화 전에 미리 생성)
     ///     self.playerScore = SyncView:CreateLuaSyncVar("score", 0)
     ///     self.playerName = SyncView:CreateLuaSyncVar("name", "Player")
     ///     self.playerScore:AddListener(function(oldValue, newValue)
     ///         print("점수 변경: " .. oldValue .. " → " .. newValue)
     ///     end)
     /// end
     /// 
     /// 
     /// function increaseScore(amount)
     ///     if SyncView.IsMine then
     ///         local currentScore = self.playerScore:Get()
     ///         self.playerScore:Set(currentScore + amount)
     ///     end
     /// end
     /// </code>
    /// 
    /// </para>
    /// </remarks>
    [AddComponentMenu("VivenSDK/Network/Viven Custom Sync View")]
    public class VivenCustomSyncView : MonoBehaviour
    {
        /// <summary>
        /// 동기화를 수행할 LuaBehaviour입니다.
        /// </summary>
        public VivenLuaBehaviour luaBehaviour;

        /// <summary>
        /// 동기화 방법에 대한 타입입니다.
        /// </summary>
        public SDKSyncType viewSyncType = SDKSyncType.Continuous;

        /// <summary>
        /// 해당 컴포넌트가 속한 VObject의 소유권을 요청합니다.
        /// </summary>
        /// <remarks>
        /// 소유권을 가진 클라이언트만이 SyncVar 값을 변경하고 다른 클라이언트에게 동기화할 수 있습니다.
        /// 소유권을 가진 클라이언트에서는 sendSyncUpdate, sendSyncFixedUpdate 이벤트가 호출됩니다.
        /// 소유권이 없는 클라이언트에서는 receiveSyncUpdate, receiveSyncFixedUpdate 이벤트가 호출됩니다.
        /// 소유권 변경 시 onOwnershipChanged 이벤트가 호출됩니다.
        /// </remarks>
        /// <example>
        /// <code language="lua">
        /// -- Lua에서 소유권 요청
        /// function requestOwnership()
        ///     SyncView:RequestOwnership()
        /// end
        /// 
        /// -- 소유권 변경 이벤트 처리
        /// function onOwnershipChanged(isMine)
        ///     if isMine then
        ///         print("이제 이 오브젝트의 소유자입니다!")
        ///     else
        ///         print("소유권을 잃었습니다.")
        ///     end
        /// end
        /// </code>
        /// </example>
        public void RequestOwnership()
        {
        }


        /// <summary>
        /// 해당 컴포넌트가 속한 VObject의 소유권이 내것인지 확인합니다.
        /// </summary>
        /// <value>
        /// 현재 클라이언트가 이 오브젝트의 소유자인 경우 true, 그렇지 않은 경우 false를 반환합니다.
        /// </value>
        /// <remarks>
        /// 소유권을 가진 클라이언트만이 다음 작업을 수행할 수 있습니다:
        /// <list type="bullet">
        /// <item>SyncVar 값 변경 및 동기화 (Set, SetValueImmediately 메서드)</item>
        /// <item>sendSyncUpdate/sendSyncFixedUpdate 이벤트 호출</item>
        /// <item>CreateLuaSyncVar로 생성된 객체를 통한 값 변경</item>
        /// </list>
        /// </remarks>
        /// <example>
        /// <code language="lua">
        /// -- Lua에서 소유권 확인
        /// function checkOwnership()
        ///     if SyncView.IsMine then
        ///         print("내가 소유자입니다 - 값을 변경할 수 있습니다")
        ///         -- 소유자만 실행되는 로직
        ///     else
        ///         print("다른 사람이 소유자입니다 - 변경 불가")
        ///         -- 비소유자는 수신만 가능
        ///     end
        /// end
        /// </code>
        /// </example>
        public bool IsMine { get; set; }

        /// <summary>
        /// 새로운 LuaSyncVar 객체를 생성하여 네트워크를 통해 자동 동기화되도록 설정합니다.
        /// </summary>
        /// <param name="varId">SyncVar의 고유 식별자 (네트워크 동기화에 사용)</param>
        /// <param name="initialValue">초기값</param>
        /// <param name="alwaysInvokeOnChange">소유자도 값 변경 콜백을 받을지 여부 (기본값: true)</param>
        /// <param name="onChanged">값이 변경될 때 호출될 콜백 함수 (선택사항)</param>
        /// <returns>생성된 LuaSyncVar 객체</returns>
        /// <remarks>
        /// <para>SyncVar는 소유자가 값을 변경하면 자동으로 모든 클라이언트에게 동기화됩니다.</para>
        /// <para>지원되는 타입: primitive types (int, float, bool 등), string, Vector3, Quaternion</para>
        /// <para>기본적으로 onChanged 콜백은 비소유자에서만 호출되며, alwaysInvokeOnChange=true로 설정시 소유자도 콜백을 받습니다.</para>
        /// <para>varId는 모든 클라이언트에서 동일해야 하며, 고유해야 합니다.</para>
        /// </remarks>
        /// <example>
        /// <code language="lua">
        /// -- Lua 스크립트에서 SyncVar 생성 및 사용 예제
        /// function awake()
        ///     -- SyncVar 객체 생성 (네트워크 동기화 전에 미리 생성)
        ///     self.healthVar = SyncView:CreateLuaSyncVar("health", 100)
        ///     self.positionVar = SyncView:CreateLuaSyncVar("position", Vector3(0, 0, 0))
        ///     self.healthVar:AddListener(onHealthChanged)
        ///     self.positionVar:AddListener(onPositionChanged)
        /// end
        /// 
        /// 
        /// -- 값 변경 콜백
        /// function onHealthChanged(oldValue, newValue)
        ///     print("체력 변경: " .. tostring(oldValue) .. " -> " .. tostring(newValue))
        ///     updateHealthBar(newValue)
        /// end
        /// 
        /// function onPositionChanged(oldPos, newPos)
        ///     print("위치 변경: " .. tostring(newPos))
        ///     self.transform.position = newPos
        /// end
        /// 
        /// -- 값 변경 예제
        /// function increaseHealth()
        ///     if SyncView.IsMine then
        ///         local currentHealth = self.healthVar:Get()
        ///         self.healthVar:Set(currentHealth + 10)
        ///         print("체력 증가: " .. self.healthVar:Get())
        ///     else
        ///         print("소유권이 없어 체력을 변경할 수 없습니다")
        ///     end
        /// end
        /// 
        /// -- 즉시 동기화가 필요한 경우
        /// function teleportPlayer(newPosition)
        ///     if SyncView.IsMine then
        ///         self.positionVar:SetValueImmediately(newPosition)
        ///         print("즉시 텔레포트: " .. tostring(newPosition))
        ///     end
        /// end
        /// </code>
        /// </example>
        /// <exception cref="System.ArgumentException">지원되지 않는 타입의 값을 초기값으로 설정할 때 발생</exception>
        public LuaSyncVar CreateLuaSyncVar(string varId, object initialValue, bool alwaysInvokeOnChange = true, Action<object, object> onChanged = null)
        {
            return new LuaSyncVar();
        }



        /// <summary>
        /// 다른 클라이언트의 Lua 함수를 원격으로 호출합니다. SendOption이 Target일 경우, SendTargetRPC를 사용해주세요.
        /// </summary>
        /// <param name="functionName">호출할 Lua 함수의 이름</param>
        /// <param name="option">RPC 전송 옵션 (All, Others 중 선택)</param>
        /// <param name="args">전달할 인자 (최대 10개까지 지원)</param>
        /// <remarks>
        /// <para>RPC는 연속적인 데이터 동기화가 아닌 이벤트성 호출에 사용됩니다.</para>
        /// <para>인자가 2개 이상인 경우 Lua Table로 전달하면 자동으로 Array로 변환됩니다.</para>
        /// <para>지원되는 인자 타입: primitive types, string, Vector3, Quaternion 등</para>
        /// <para>함수가 존재하지 않으면 에러가 발생하니 주의하세요.</para>
        /// </remarks>
        /// <example>
        /// <code language="lua">
        /// -- 모든 클라이언트에게 RPC 전송
        /// function notifyAllPlayers()
        ///     local AllOption = RPCSendOption.All
        ///     SyncView:SendRPC("onPlayerJoined", AllOption, "새로운 플레이어가 입장했습니다!")
        /// end
        /// 
        /// -- 나를 제외한 모든 클라이언트에게 RPC 전송
        /// function notifyOthers()
        ///     local OthersOption = RPCSendOption.Others
        ///     local data = {score = 100, level = 5}
        ///     SyncView:SendRPC("onScoreUpdate", OthersOption, data)
        /// end
        /// 
        /// -- RPC 수신 함수들
        /// function onPlayerJoined(message)
        ///     print("알림: " .. message)
        /// end
        /// 
        /// function onScoreUpdate(score, level)
        ///     print("점수 업데이트: " .. score .. ", 레벨: " .. level)
        /// end
        /// </code>
        /// </example>
        /// <exception cref="System.ArgumentException">지원되지 않는 인자 타입을 전달할 때 발생</exception>
        public void SendRPC(string functionName, SDKRPCSendOption option, params object[] args)
        {
        }

        /// <summary>
        /// 특정 플레이어들을 대상으로 Lua 함수를 원격 호출합니다.
        /// </summary>
        /// <param name="functionName">호출할 Lua 함수의 이름</param>
        /// <param name="playerIds">RPC를 받을 플레이어들의 ID 배열</param>
        /// <param name="args">전달할 인자 (최대 10개까지 지원)</param>
        /// <remarks>
        /// <para>Target RPC는 특정 플레이어에게만 메시지를 전송할 때 사용합니다.</para>
        /// <para>Player ID는 Player.Other.GetPlayerID(nickname) 또는 Player.Other.GetPlayerIDByIndex(index)로 획득할 수 있습니다.</para>
        /// <para>존재하지 않는 플레이어 ID는 자동으로 무시됩니다.</para>
        /// <para>인자가 2개 이상인 경우 Lua Table로 전달하면 자동으로 Array로 변환됩니다.</para>
        /// </remarks>
        /// <example>
        /// <code language="lua">
        /// -- 특정 플레이어에게만 RPC 전송
        /// function sendPrivateMessage()
        ///     local targetPlayers = {}
        ///     
        ///     -- 닉네임으로 플레이어 ID 찾기
        ///     local playerId = Player.Other.GetPlayerID("TargetPlayerNickname")
        ///     if playerId ~= nil then
        ///         targetPlayers[1] = playerId
        ///         
        ///         local message = "당신만을 위한 특별한 메시지입니다!"
        ///         SyncView:SendTargetRPC("onPrivateMessage", targetPlayers, message)
        ///     end
        /// end
        /// 
        /// -- 여러 플레이어에게 동시 전송
        /// function sendToMultiplePlayers()
        ///     local targetPlayers = {}
        ///     targetPlayers[1] = Player.Other.GetPlayerID("Player1")
        ///     targetPlayers[2] = Player.Other.GetPlayerID("Player2")
        ///     
        ///     local gameData = {event = "specialEvent", reward = 100}
        ///     SyncView:SendTargetRPC("onSpecialEvent", targetPlayers, gameData)
        /// end
        /// 
        /// -- Target RPC 수신 함수들
        /// function onPrivateMessage(message)
        ///     print("개인 메시지: " .. message)
        /// end
        /// 
        /// function onSpecialEvent(event, reward)
        ///     print("특별 이벤트: " .. event .. ", 보상: " .. reward)
        /// end
        /// </code>
        /// </example>
        /// <exception cref="System.ArgumentException">지원되지 않는 인자 타입을 전달할 때 발생</exception>
        /// <exception cref="System.ArgumentNullException">playerIds가 null이거나 빈 배열일 때 발생</exception>
        public void SendTargetRPC(string functionName, string[] playerIds, params object[] args)
        {
        }
    }
}