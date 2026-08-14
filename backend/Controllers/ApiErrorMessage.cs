using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using VideoCallAPI.Models.DTOs;
using VideoCallAPI.Services;
using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using VideoCallAPI.Models;
using VideoCallAPI.Data;
using Microsoft.EntityFrameworkCore;
using VideoCallAPI.Hubs;
using BCrypt.Net;

namespace VideoCallAPI.Controllers
{
    internal static class ApiErrorMessage
    {
        public static string ForClient(Exception exception, string fallback)
        {
            return exception is ArgumentException or InvalidOperationException or UnauthorizedAccessException
                ? exception.Message
                : fallback;
        }
    }
}
