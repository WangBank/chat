using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace VideoCallAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddQQAccountBinding : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "qq_avatar_url",
                table: "users",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "qq_bound_at",
                table: "users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "qq_nickname",
                table: "users",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "qq_open_id",
                table: "users",
                type: "character varying(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "qq_union_id",
                table: "users",
                type: "character varying(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_users_qq_open_id",
                table: "users",
                column: "qq_open_id",
                unique: true,
                filter: "\"qq_open_id\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_users_qq_union_id",
                table: "users",
                column: "qq_union_id",
                unique: true,
                filter: "\"qq_union_id\" IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_users_qq_open_id",
                table: "users");

            migrationBuilder.DropIndex(
                name: "IX_users_qq_union_id",
                table: "users");

            migrationBuilder.DropColumn(
                name: "qq_avatar_url",
                table: "users");

            migrationBuilder.DropColumn(
                name: "qq_bound_at",
                table: "users");

            migrationBuilder.DropColumn(
                name: "qq_nickname",
                table: "users");

            migrationBuilder.DropColumn(
                name: "qq_open_id",
                table: "users");

            migrationBuilder.DropColumn(
                name: "qq_union_id",
                table: "users");
        }
    }
}
