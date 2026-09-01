using System.Collections.Concurrent;
using System.Net;
using Microsoft.Extensions.Logging;
using SIPSorcery.Net;
using SIPSorcery.Sys;
using VideoCallAPI.Models;

namespace VideoCallAPI.Services;

/// <summary>
/// An SFU media plane. Each participant has one server-side
/// RTCPeerConnection. Packets are decrypted by SIPSorcery's DTLS-SRTP stack,
/// forwarded without decoding, and encrypted again for the other participants.
/// </summary>
public sealed class SfuMediaService : ISfuMediaService, IDisposable
{
    private readonly IWebRTCService _callSessions;
    private readonly IConfiguration _configuration;
    private readonly ILogger<SfuMediaService> _logger;
    private readonly ConcurrentDictionary<string, SfuCall> _calls = new();
    // Trickle ICE can arrive before the first SFU Offer reaches SignalR. Keep
    // those candidates briefly instead of dropping them when no SfuCall exists.
    private readonly ConcurrentDictionary<string, ConcurrentQueue<RTCIceCandidateInit>> _earlyCandidates = new();
    private long _forwardedRtpPackets;
    private int _missingPublicIpWarningLogged;

    public SfuMediaService(
        IWebRTCService callSessions,
        IConfiguration configuration,
        ILogger<SfuMediaService> logger)
    {
        _callSessions = callSessions;
        _configuration = configuration;
        _logger = logger;
    }

    public int ActivePeerConnectionCount => _calls.Values.Sum(x => x.PeerCount);
    public long ForwardedRtpPacketCount => Interlocked.Read(ref _forwardedRtpPackets);

    public async Task<SfuAnswer?> HandleOfferAsync(
        string callId,
        int userId,
        string sdp,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(callId) || string.IsNullOrWhiteSpace(sdp))
        {
            throw new ArgumentException("SFU offer 不能为空。");
        }

        var call = await _callSessions.GetSessionAsync(callId).ConfigureAwait(false);
        if (call == null || !IsParticipant(call, userId))
        {
            _logger.LogWarning("拒绝未授权的 SFU Offer: CallId={CallId}, UserId={UserId}", callId, userId);
            return null;
        }

        if (!RTCSessionDescriptionInit.TryParse(sdp, out var offer))
        {
            throw new ArgumentException("无法解析 SFU Offer SDP。");
        }

        var sfuCall = _calls.GetOrAdd(callId, _ => new SfuCall(callId, this, _logger));
        if (_earlyCandidates.TryRemove(PendingCandidateKey(callId, userId), out var earlyCandidates))
        {
            foreach (var candidate in earlyCandidates)
            {
                await sfuCall.AddIceCandidateAsync(userId, candidate, cancellationToken).ConfigureAwait(false);
            }
        }
        return await sfuCall.SetOfferAsync(userId, offer, cancellationToken).ConfigureAwait(false);
    }

    public async Task<bool> HandleIceCandidateAsync(
        string callId,
        int userId,
        string candidate,
        CancellationToken cancellationToken = default)
    {
        if (!RTCIceCandidateInit.TryParse(candidate, out var candidateInit))
        {
            throw new ArgumentException("无法解析 SFU ICE candidate。");
        }

        var session = await _callSessions.GetSessionAsync(callId).ConfigureAwait(false);
        if (session == null || !IsParticipant(session, userId))
        {
            return false;
        }

        if (!_calls.TryGetValue(callId, out var call))
        {
            var queue = _earlyCandidates.GetOrAdd(PendingCandidateKey(callId, userId),
                _ => new ConcurrentQueue<RTCIceCandidateInit>());
            queue.Enqueue(candidateInit);
            return true;
        }

        await call.AddIceCandidateAsync(userId, candidateInit, cancellationToken).ConfigureAwait(false);
        return true;
    }

    public async Task<bool> RemovePeerAsync(string callId, int userId)
    {
        if (!_calls.TryGetValue(callId, out var call))
        {
            return false;
        }

        var removed = await call.RemovePeerAsync(userId).ConfigureAwait(false);
        if (call.PeerCount == 0)
        {
            RemoveEmptyCall(callId, call);
        }
        return removed;
    }

    public Task RemoveCallAsync(string callId)
    {
        if (_calls.TryRemove(callId, out var call))
        {
            call.Dispose();
        }
        foreach (var key in _earlyCandidates.Keys.Where(key => key.StartsWith(callId + ":", StringComparison.Ordinal)))
        {
            _earlyCandidates.TryRemove(key, out _);
        }
        return Task.CompletedTask;
    }

    private static string PendingCandidateKey(string callId, int userId) => $"{callId}:{userId}";

    internal RTCPeerConnection CreatePeerConnection(string callId, int userId, SDP offerSdp)
    {
        var config = new RTCConfiguration
        {
            X_UseRtpFeedbackProfile = true,
            X_BindAddress = ParseBindAddress(),
            iceServers = new List<RTCIceServer>()
        };

        var portRange = ParsePortRange();
        var pc = new RTCPeerConnection(config, portRange: portRange);

        // Add local send tracks with exactly the codecs offered by the client.
        // This causes SIPSorcery to generate a reciprocal send/recv answer while
        // preserving the client's payload type and fmtp values.
        foreach (var announcement in offerSdp.Media.Where(x =>
                     x.Port != 0 &&
                     (x.Media == SDPMediaTypesEnum.audio || x.Media == SDPMediaTypesEnum.video)))
        {
            var capabilities = announcement.MediaFormats.Values.ToList();
            if (capabilities.Count > 0)
            {
                pc.addTrack(new MediaStreamTrack(announcement.Media, false, capabilities));
            }
        }

        var publicIp = _configuration["WebRtc:SfuPublicIp"]?.Trim();
        if (IPAddress.TryParse(publicIp, out var publicAddress) && pc.GetRtpChannel().RTPPort > 0)
        {
            // Docker/NAT deployments can advertise the host's public address
            // explicitly. When empty, SIPSorcery advertises its normal host ICE
            // candidates and deployments may use TURN instead.
            pc.addLocalIceCandidate(new RTCIceCandidate(
                RTCIceProtocol.udp,
                publicAddress,
                (ushort)pc.GetRtpChannel().RTPPort,
                RTCIceCandidateType.host));
        }
        else if (Interlocked.Exchange(ref _missingPublicIpWarningLogged, 1) == 0)
        {
            _logger.LogWarning(
                "SFU 未配置有效的 WebRtc:SfuPublicIp；Docker 或 NAT 外的手机无法访问私有 ICE 地址。" +
                "请配置服务器公网 IPv4 并放行 WebRtc:SfuPortMin-WebRtc:SfuPortMax UDP 端口。" +
                "当前 RtpPort={RtpPort}",
                pc.GetRtpChannel().RTPPort);
        }

        _logger.LogInformation(
            "创建 SFU PeerConnection: CallId={CallId}, UserId={UserId}, RtpPort={RtpPort}",
            callId, userId, pc.GetRtpChannel().RTPPort);
        return pc;
    }

    private IPAddress? ParseBindAddress()
    {
        var value = _configuration["WebRtc:SfuBindAddress"]?.Trim();
        return IPAddress.TryParse(value, out var address) ? address : null;
    }

    private PortRange? ParsePortRange()
    {
        var min = _configuration.GetValue<int?>("WebRtc:SfuPortMin");
        var max = _configuration.GetValue<int?>("WebRtc:SfuPortMax");
        return min is > 0 && max is > 0 && max >= min + 2 ? new PortRange(min.Value, max.Value) : null;
    }

    private static bool IsParticipant(WebRTCSession call, int userId) =>
        call.caller_id == userId || call.receiver_id == userId;

    internal void CountForwardedPacket() => Interlocked.Increment(ref _forwardedRtpPackets);

    private async Task RemovePeerAfterTransportClosedAsync(
        string callId,
        int userId,
        RTCPeerConnection peer)
    {
        if (!_calls.TryGetValue(callId, out var call))
        {
            return;
        }

        var removed = await call.RemovePeerAsync(userId, peer).ConfigureAwait(false);
        if (removed && call.PeerCount == 0)
        {
            RemoveEmptyCall(callId, call);
        }
    }

    private void RemoveEmptyCall(string callId, SfuCall call)
    {
        var pair = new KeyValuePair<string, SfuCall>(callId, call);
        if (((ICollection<KeyValuePair<string, SfuCall>>)_calls).Remove(pair))
        {
            call.Dispose();
        }
    }

    public void Dispose()
    {
        foreach (var call in _calls.Values)
        {
            call.Dispose();
        }
        _calls.Clear();
        _earlyCandidates.Clear();
    }

    private sealed class SfuCall : IDisposable
    {
        private readonly string _callId;
        private readonly SfuMediaService _owner;
        private readonly ILogger _logger;
        private readonly object _sync = new();
        private readonly Dictionary<int, RTCPeerConnection> _peers = new();
        private readonly Dictionary<int, SemaphoreSlim> _peerLocks = new();
        private readonly Dictionary<int, List<RTCIceCandidateInit>> _pendingCandidates = new();

        public SfuCall(string callId, SfuMediaService owner, ILogger logger)
        {
            _callId = callId;
            _owner = owner;
            _logger = logger;
        }

        public int PeerCount
        {
            get { lock (_sync) return _peers.Count; }
        }

        public async Task<SfuAnswer> SetOfferAsync(
            int userId,
            RTCSessionDescriptionInit offer,
            CancellationToken cancellationToken)
        {
            var gate = GetPeerLock(userId);
            await gate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                RTCPeerConnection? pc;
                lock (_sync)
                {
                    if (!_peers.TryGetValue(userId, out pc))
                    {
                        var parsedOffer = SDP.ParseSDPDescription(offer.sdp);
                        pc = _owner.CreatePeerConnection(_callId, userId, parsedOffer);
                        _peers[userId] = pc;
                        pc.OnRtpPacketReceived += (remoteEndPoint, media, packet) =>
                            ForwardPacket(userId, pc, media, packet);
                        pc.onconnectionstatechange += state =>
                        {
                            _logger.LogInformation(
                                "SFU PeerConnection 状态: CallId={CallId}, UserId={UserId}, State={State}",
                                _callId, userId, state);
                            if (state is RTCPeerConnectionState.failed or RTCPeerConnectionState.closed)
                            {
                                // A delayed state change from a previous PeerConnection must
                                // never tear down a newly negotiated replacement for this user.
                                _ = _owner.RemovePeerAfterTransportClosedAsync(_callId, userId, pc);
                            }
                        };
                    }
                }

                        var result = pc.setRemoteDescription(offer);
                if (result != SetDescriptionResultEnum.OK)
                {
                        throw new InvalidOperationException($"SFU Offer 协商失败: {result}");
                }

                List<RTCIceCandidateInit>? pending;
                lock (_sync)
                {
                    _pendingCandidates.Remove(userId, out pending);
                }
                if (pending != null)
                {
                    foreach (var candidate in pending)
                    {
                        pc.addIceCandidate(candidate);
                    }
                }

                var answer = pc.createAnswer(new RTCAnswerOptions
                {
                    X_WaitForIceGatheringToComplete = true
                });
                await pc.setLocalDescription(answer).ConfigureAwait(false);
                var localSdp = pc.localDescription?.sdp?.ToString();
                if (string.IsNullOrWhiteSpace(localSdp))
                {
                    throw new InvalidOperationException("SFU 未生成有效 Answer SDP。");
                }

                _logger.LogInformation("SFU Answer 已生成: CallId={CallId}, UserId={UserId}", _callId, userId);
                return new SfuAnswer(_callId, userId, localSdp);
            }
            finally
            {
                gate.Release();
            }
        }

        public async Task AddIceCandidateAsync(
            int userId,
            RTCIceCandidateInit candidate,
            CancellationToken cancellationToken)
        {
            var gate = GetPeerLock(userId);
            await gate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                lock (_sync)
                {
                    if (_peers.TryGetValue(userId, out var pc))
                    {
                        pc.addIceCandidate(candidate);
                    }
                    else
                    {
                        if (!_pendingCandidates.TryGetValue(userId, out var pending))
                        {
                            pending = new List<RTCIceCandidateInit>();
                            _pendingCandidates[userId] = pending;
                        }
                        pending.Add(candidate);
                    }
                }
            }
            finally
            {
                gate.Release();
            }
        }

        public Task<bool> RemovePeerAsync(int userId, RTCPeerConnection? expectedPeer = null)
        {
            RTCPeerConnection? pc = null;
            lock (_sync)
            {
                if (_peers.TryGetValue(userId, out var current) &&
                    (expectedPeer == null || ReferenceEquals(current, expectedPeer)))
                {
                    _peers.Remove(userId, out pc);
                    // Do not dispose the per-peer gate here. A connection-state
                    // callback can race with an in-flight Offer/ICE operation;
                    // its short-lived gate can be collected after the callers exit.
                    _peerLocks.Remove(userId);
                    _pendingCandidates.Remove(userId);
                }
            }
            if (pc != null)
            {
                pc.Close("participant left");
                pc.Dispose();
            }
            return Task.FromResult(pc != null);
        }

        private SemaphoreSlim GetPeerLock(int userId)
        {
            lock (_sync)
            {
                if (!_peerLocks.TryGetValue(userId, out var gate))
                {
                    gate = new SemaphoreSlim(1, 1);
                    _peerLocks[userId] = gate;
                }
                return gate;
            }
        }

        private void ForwardPacket(int sourceUserId, RTCPeerConnection source, SDPMediaTypesEnum media, RTPPacket packet)
        {
            if (media is not (SDPMediaTypesEnum.audio or SDPMediaTypesEnum.video))
            {
                return;
            }

            // A true SFU fan-outs each inbound RTP packet to every other
            // participant. No decode/mix step is performed; each target's
            // negotiated payload type is resolved independently.
            RTCPeerConnection[] targets;
            lock (_sync)
            {
                targets = _peers
                    .Where(pair => pair.Key != sourceUserId)
                    .Select(pair => pair.Value)
                    .ToArray();
            }

            foreach (var target in targets)
            {
                var payloadType = ResolveTargetPayloadType(source, target, media, packet.Header.PayloadType);
                target.SendRtpRaw(
                    media,
                    packet.Payload,
                    packet.Header.Timestamp,
                    packet.Header.MarkerBit,
                    payloadType);
                _owner.CountForwardedPacket();
            }
        }

        private static int ResolveTargetPayloadType(
            RTCPeerConnection source,
            RTCPeerConnection target,
            SDPMediaTypesEnum media,
            int sourcePayloadType)
        {
            var sourceTrack = media == SDPMediaTypesEnum.audio
                ? source.AudioStream?.RemoteTrack
                : source.VideoStream?.RemoteTrack;
            var targetTrack = media == SDPMediaTypesEnum.audio
                ? target.AudioStream?.LocalTrack
                : target.VideoStream?.LocalTrack;

            var sourceFormat = sourceTrack?.GetFormatForPayloadID(sourcePayloadType);
            if (sourceFormat.HasValue && !sourceFormat.Value.IsEmpty() && targetTrack?.Capabilities != null)
            {
                var matching = targetTrack.Capabilities.FirstOrDefault(
                    format => SDPAudioVideoMediaFormat.AreMatch(sourceFormat.Value, format));
                if (!matching.IsEmpty())
                {
                    return matching.ID;
                }
            }
            return sourcePayloadType;
        }

        public void Dispose()
        {
            List<RTCPeerConnection> peers;
            List<SemaphoreSlim> locks;
            lock (_sync)
            {
                peers = _peers.Values.ToList();
                locks = _peerLocks.Values.ToList();
                _peers.Clear();
                _peerLocks.Clear();
                _pendingCandidates.Clear();
            }

            foreach (var pc in peers)
            {
                try
                {
                    pc.Close("call ended");
                    pc.Dispose();
                }
                catch (Exception ex)
                {
                    _logger.LogDebug(ex, "释放 SFU PeerConnection 失败: CallId={CallId}", _callId);
                }
            }
            foreach (var gate in locks) gate.Dispose();
        }
    }
}
