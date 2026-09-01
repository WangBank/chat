namespace VideoCallAPI.Services;

public sealed record SfuAnswer(string CallId, int UserId, string Sdp);

/// <summary>
/// Owns the media-plane peer connections for calls. SignalR remains the
/// signalling/control plane; this service is the component that terminates
/// DTLS-SRTP and forwards RTP between participants.
/// </summary>
public interface ISfuMediaService
{
    Task<SfuAnswer?> HandleOfferAsync(string callId, int userId, string sdp,
        CancellationToken cancellationToken = default);

    Task<bool> HandleIceCandidateAsync(string callId, int userId, string candidate,
        CancellationToken cancellationToken = default);

    Task<bool> RemovePeerAsync(string callId, int userId);

    Task RemoveCallAsync(string callId);

    int ActivePeerConnectionCount { get; }

    long ForwardedRtpPacketCount { get; }
}
