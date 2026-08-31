using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace VideoCallAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddEmailCodeCaptchaChallenges : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "EmailCodeCaptchaChallenges",
                columns: table => new
                {
                    id = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    purpose = table.Column<int>(type: "integer", nullable: false),
                    answer_hash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    binding_hash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    expires_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    failed_attempts = table.Column<int>(type: "integer", nullable: false),
                    is_used = table.Column<bool>(type: "boolean", nullable: false),
                    used_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_EmailCodeCaptchaChallenges", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_EmailCodeCaptchaChallenges_is_used_expires_at",
                table: "EmailCodeCaptchaChallenges",
                columns: new[] { "is_used", "expires_at" });

            migrationBuilder.CreateIndex(
                name: "IX_EmailCodeCaptchaChallenges_purpose_binding_hash_created_at",
                table: "EmailCodeCaptchaChallenges",
                columns: new[] { "purpose", "binding_hash", "created_at" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "EmailCodeCaptchaChallenges");
        }
    }
}
