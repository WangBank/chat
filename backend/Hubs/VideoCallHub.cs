using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.Authorization;
using VideoCallAPI.Models.DTOs;
using VideoCallAPI.Services;
using System.Security.Claims;

namespace VideoCallAPI.Hubs
{
    [Authorize]
    public class VideoCallHub : Hub
    {
        private readonly ICallService _callService;
        private readonly ILogger<VideoCallHub> _logger;

        public VideoCallHub(ICallService callService, ILogger<VideoCallHub> logger)
        {
            _callService = callService;
            _logger = logger;
        }

        public override async Task OnConnectedAsync()
        {
            var userId = GetUserId();
            if (userId.HasValue)
            {
                await Groups.AddToGroupAsync(Context.ConnectionId, $"User_{userId}");
                await _callService.UpdateUserOnlineStatus(userId.Value, true);
                _logger.LogInformation($"User {userId} connected with connectionId {Context.ConnectionId}");
            }
            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var userId = GetUserId();
            if (userId.HasValue)
            {
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"User_{userId}");
                await _callService.UpdateUserOnlineStatus(userId.Value, false);
                _logger.LogInformation($"User {userId} disconnected");
            }
            await base.OnDisconnectedAsync(exception);
        }

        // 发起通话
        public async Task InitiateCall(InitiateCallDto callDto)
        {
            var callerId = GetUserId();
            if (!callerId.HasValue) return;

            try
            {
                var call = await _callService.InitiateCallAsync(callerId.Value, callDto.ReceiverId, callDto.CallType);
                
                // 通知被叫用户
                await Clients.Group($"User_{callDto.ReceiverId}")
                    .SendAsync("IncomingCall", new
                    {
                        CallId = call.CallId,
                        Caller = call.Caller,
                        CallType = call.CallType
                    });

                // 通知主叫用户
                await Clients.Caller.SendAsync("CallInitiated", call);
            }
            catch (Exception ex)
            {
                await Clients.Caller.SendAsync("CallError", ex.Message);
            }
        }

        // 应答通话
        public async Task AnswerCall(AnswerCallDto answerDto)
        {
            var userId = GetUserId();
            if (!userId.HasValue) return;

            try
            {
                var result = await _callService.AnswerCallAsync(answerDto.CallId, userId.Value, answerDto.Accept);
                
                if (answerDto.Accept)
                {
                    // 加入通话房间
                    await Groups.AddToGroupAsync(Context.ConnectionId, $"Call_{answerDto.CallId}");
                    
                    // 通知主叫用户通话被接受
                    await Clients.Group($"User_{result.Caller.Id}")
                        .SendAsync("CallAccepted", new { CallId = answerDto.CallId });
                }
                else
                {
                    // 通知主叫用户通话被拒绝
                    await Clients.Group($"User_{result.Caller.Id}")
                        .SendAsync("CallRejected", new { CallId = answerDto.CallId });
                }
            }
            catch (Exception ex)
            {
                await Clients.Caller.SendAsync("CallError", ex.Message);
            }
        }

        // 结束通话
        public async Task EndCall(string callId)
        {
            var userId = GetUserId();
            if (!userId.HasValue) return;

            try
            {
                await _callService.EndCallAsync(callId, userId.Value);
                
                // 通知通话房间内的所有用户
                await Clients.Group($"Call_{callId}").SendAsync("CallEnded", new { CallId = callId });
                
                // 移除用户从通话房间
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"Call_{callId}");
            }
            catch (Exception ex)
            {
                await Clients.Caller.SendAsync("CallError", ex.Message);
            }
        }

        // WebRTC 信令 - 发送 Offer
        public async Task SendOffer(WebRTCOfferDto offerDto)
        {
            await Clients.Group($"Call_{offerDto.CallId}")
                .SendAsync("ReceiveOffer", new
                {
                    CallId = offerDto.CallId,
                    Offer = offerDto.Offer,
                    SenderId = GetUserId()
                });
        }

        // WebRTC 信令 - 发送 Answer
        public async Task SendAnswer(WebRTCAnswerDto answerDto)
        {
            await Clients.Group($"Call_{answerDto.CallId}")
                .SendAsync("ReceiveAnswer", new
                {
                    CallId = answerDto.CallId,
                    Answer = answerDto.Answer,
                    SenderId = GetUserId()
                });
        }

        // WebRTC 信令 - 发送 ICE Candidate
        public async Task SendIceCandidate(WebRTCCandidateDto candidateDto)
        {
            await Clients.Group($"Call_{candidateDto.CallId}")
                .SendAsync("ReceiveIceCandidate", new
                {
                    CallId = candidateDto.CallId,
                    Candidate = candidateDto.Candidate,
                    SenderId = GetUserId()
                });
        }

        // 加入房间
        public async Task JoinRoom(string roomCode)
        {
            var userId = GetUserId();
            if (!userId.HasValue) return;

            try
            {
                var room = await _callService.JoinRoomAsync(roomCode, userId.Value);
                
                // 加入房间群组
                await Groups.AddToGroupAsync(Context.ConnectionId, $"Room_{room.Id}");
                
                // 通知房间内其他用户
                await Clients.Group($"Room_{room.Id}")
                    .SendAsync("UserJoinedRoom", new
                    {
                        RoomId = room.Id,
                        UserId = userId.Value,
                        Username = Context.User?.Identity?.Name
                    });

                // 通知用户加入成功
                await Clients.Caller.SendAsync("RoomJoined", room);
            }
            catch (Exception ex)
            {
                await Clients.Caller.SendAsync("RoomError", ex.Message);
            }
        }

        // 离开房间
        public async Task LeaveRoom(int roomId)
        {
            var userId = GetUserId();
            if (!userId.HasValue) return;

            try
            {
                await _callService.LeaveRoomAsync(roomId, userId.Value);
                
                // 离开房间群组
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"Room_{roomId}");
                
                // 通知房间内其他用户
                await Clients.Group($"Room_{roomId}")
                    .SendAsync("UserLeftRoom", new
                    {
                        RoomId = roomId,
                        UserId = userId.Value,
                        Username = Context.User?.Identity?.Name
                    });
            }
            catch (Exception ex)
            {
                await Clients.Caller.SendAsync("RoomError", ex.Message);
            }
        }

        // 房间内发送 WebRTC 信令
        public async Task SendRoomOffer(int roomId, string offer, int targetUserId)
        {
            await Clients.Group($"User_{targetUserId}")
                .SendAsync("ReceiveRoomOffer", new
                {
                    RoomId = roomId,
                    Offer = offer,
                    SenderId = GetUserId()
                });
        }

        public async Task SendRoomAnswer(int roomId, string answer, int targetUserId)
        {
            await Clients.Group($"User_{targetUserId}")
                .SendAsync("ReceiveRoomAnswer", new
                {
                    RoomId = roomId,
                    Answer = answer,
                    SenderId = GetUserId()
                });
        }

        public async Task SendRoomIceCandidate(int roomId, string candidate, int targetUserId)
        {
            await Clients.Group($"User_{targetUserId}")
                .SendAsync("ReceiveRoomIceCandidate", new
                {
                    RoomId = roomId,
                    Candidate = candidate,
                    SenderId = GetUserId()
                });
        }

        private int? GetUserId()
        {
            var userIdClaim = Context.User?.FindFirst(ClaimTypes.NameIdentifier);
            if (userIdClaim != null && int.TryParse(userIdClaim.Value, out int userId))
            {
                return userId;
            }
            return null;
        }
    }
}
