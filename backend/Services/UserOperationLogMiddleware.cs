using Microsoft.AspNetCore.Mvc.Controllers;

namespace VideoCallAPI.Services;

public sealed class UserOperationLogMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context, UserOperationLogService log)
    {
        var action = context.GetEndpoint()?.Metadata.GetMetadata<ControllerActionDescriptor>();
        var method = context.Request.Method;
        if (action is null || !(HttpMethods.IsPost(method) || HttpMethods.IsPut(method) ||
            HttpMethods.IsPatch(method) || HttpMethods.IsDelete(method)))
        {
            await next(context);
            return;
        }

        var operation = GetOperation(action.ControllerName, action.ActionName);
        var status = StatusCodes.Status500InternalServerError;
        try
        {
            await next(context);
            status = context.Response.StatusCode;
        }
        catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
        {
            status = 499;
            throw;
        }
        finally
        {
            var actor = context.Items[typeof(OperationActor)] as OperationActor ??
                OperationActor.FromClaims(context.User);
            await log.RecordAsync(actor, operation, "HTTP", status is >= 200 and < 300, status);
        }
    }

    // Labels come exclusively from server-owned action metadata. Bodies, query strings,
    // concrete request paths, tokens and uploaded filenames never enter the operation log.
    private static string GetOperation(string controller, string action) => (controller, action) switch
    {
        ("Auth", "Register") => "注册账号",
        ("Auth", "Login") => "账号登录",
        ("Auth", "QQLogin" or "QQDevLogin") => "QQ 登录",
        ("Auth", "BindQQ" or "QQDevBind") => "绑定 QQ",
        ("Auth", "ChangePassword") => "修改密码",
        ("Auth", "ForgotPassword") => "找回密码",
        ("Auth", "ResetPassword") => "重置密码",
        ("Auth", "ChangeEmail") => "修改邮箱",
        ("Auth", "VerifyEmail") => "验证邮箱",
        ("Auth", "UpdateProfile") => "更新个人资料",
        ("Auth", "UploadAvatar") => "更新头像",
        ("Auth", "CreateEmailCodeCaptcha") => "申请图案验证",
        ("Auth", "RequestRegistrationEmailCode" or "RequestEmailChangeCode" or
            "RequestEmailVerificationCode" or "RequestPasswordChangeCode") => "申请邮箱验证码",
        ("Chat", "SendMessage") => "发送私聊消息",
        ("Chat", "UploadChatFile") => "上传聊天文件",
        ("Chat", "MarkMessageAsRead") => "标记消息已读",
        ("Chat", "DeleteChatHistory") => "删除聊天记录",
        ("Groups", "CreateGroup") => "创建群聊",
        ("Groups", "SendMessage") => "发送群聊消息",
        ("Contacts", "AddContact" or "CreateFriendRequest") => "申请添加好友",
        ("Contacts", "RespondFriendRequest") => "处理好友申请",
        ("Contacts", "ClearHandledFriendRequests") => "清理好友申请",
        ("Contacts", "RemoveContact") => "移除联系人",
        ("Contacts", "BlockContact") => "更新联系人屏蔽状态",
        ("Contacts", "UpdateDisplayName") => "修改联系人备注",
        ("Favorites", "CreateFavorite") => "添加收藏",
        ("Favorites", "UpdateFavorite") => "修改收藏",
        ("Favorites", "DeleteFavorite") => "删除收藏",
        ("Calls", "CreateRoom") => "创建通话房间",
        ("Calls", "CreateLiveKitToken") => "申请通话令牌",
        ("Admin", "CreateUser") => "管理员创建用户",
        ("Admin", "UpdateUser") => "管理员编辑用户",
        ("Admin", "ChangeUserPassword") => "管理员修改用户密码",
        ("Announcements", "Publish") => "发布系统公告",
        ("Announcements", "MarkRead") => "标记公告已读",
        ("DatabaseBackups", "Create") => "创建数据库备份",
        ("DatabaseBackups", "Restore") => "还原数据库备份",
        _ => $"{controller}.{action}"
    };
}
