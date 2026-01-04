using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace VideoCallAPI.Migrations
{
    /// <inheritdoc />
    public partial class InitDB : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "users",
                columns: table => new
                {
                    id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    username = table.Column<string>(type: "TEXT", maxLength: 50, nullable: false),
                    email = table.Column<string>(type: "TEXT", maxLength: 100, nullable: false),
                    password_hash = table.Column<string>(type: "TEXT", nullable: false),
                    display_name = table.Column<string>(type: "TEXT", maxLength: 50, nullable: true),
                    avatar_path = table.Column<string>(type: "TEXT", maxLength: 255, nullable: true),
                    created_at = table.Column<DateTime>(type: "TEXT", nullable: false),
                    updated_at = table.Column<DateTime>(type: "TEXT", nullable: false),
                    last_login_at = table.Column<DateTime>(type: "TEXT", nullable: true),
                    is_online = table.Column<bool>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_users", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "CallHistories",
                columns: table => new
                {
                    id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    caller_id = table.Column<int>(type: "INTEGER", nullable: false),
                    receiver_id = table.Column<int>(type: "INTEGER", nullable: false),
                    call_type = table.Column<int>(type: "INTEGER", nullable: false),
                    status = table.Column<int>(type: "INTEGER", nullable: false),
                    start_time = table.Column<DateTime>(type: "TEXT", nullable: false),
                    end_time = table.Column<DateTime>(type: "TEXT", nullable: true),
                    duration = table.Column<int>(type: "INTEGER", nullable: true),
                    end_reason = table.Column<string>(type: "TEXT", maxLength: 255, nullable: true),
                    created_at = table.Column<DateTime>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CallHistories", x => x.id);
                    table.ForeignKey(
                        name: "FK_CallHistories_users_caller_id",
                        column: x => x.caller_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CallHistories_users_receiver_id",
                        column: x => x.receiver_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ChatMessages",
                columns: table => new
                {
                    id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    sender_id = table.Column<int>(type: "INTEGER", nullable: false),
                    receiver_id = table.Column<int>(type: "INTEGER", nullable: false),
                    content = table.Column<string>(type: "TEXT", maxLength: 1000, nullable: false),
                    type = table.Column<int>(type: "INTEGER", nullable: false),
                    timestamp = table.Column<DateTime>(type: "TEXT", nullable: false),
                    is_read = table.Column<bool>(type: "INTEGER", nullable: false),
                    file_path = table.Column<string>(type: "TEXT", maxLength: 255, nullable: true),
                    file_size = table.Column<int>(type: "INTEGER", nullable: true),
                    duration = table.Column<int>(type: "INTEGER", nullable: true),
                    created_at = table.Column<DateTime>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ChatMessages", x => x.id);
                    table.ForeignKey(
                        name: "FK_ChatMessages_users_receiver_id",
                        column: x => x.receiver_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ChatMessages_users_sender_id",
                        column: x => x.sender_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Contacts",
                columns: table => new
                {
                    id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    user_id = table.Column<int>(type: "INTEGER", nullable: false),
                    contact_user_id = table.Column<int>(type: "INTEGER", nullable: false),
                    display_name = table.Column<string>(type: "TEXT", maxLength: 50, nullable: true),
                    added_at = table.Column<DateTime>(type: "TEXT", nullable: false),
                    is_blocked = table.Column<bool>(type: "INTEGER", nullable: false),
                    last_message_at = table.Column<DateTime>(type: "TEXT", nullable: true),
                    unread_count = table.Column<int>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Contacts", x => x.id);
                    table.ForeignKey(
                        name: "FK_Contacts_users_contact_user_id",
                        column: x => x.contact_user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Contacts_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Rooms",
                columns: table => new
                {
                    id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    room_name = table.Column<string>(type: "TEXT", maxLength: 100, nullable: false),
                    room_code = table.Column<string>(type: "TEXT", nullable: false),
                    created_by = table.Column<int>(type: "INTEGER", nullable: false),
                    created_at = table.Column<DateTime>(type: "TEXT", nullable: false),
                    is_active = table.Column<bool>(type: "INTEGER", nullable: false),
                    max_participants = table.Column<int>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Rooms", x => x.id);
                    table.ForeignKey(
                        name: "FK_Rooms_users_created_by",
                        column: x => x.created_by,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "RoomParticipants",
                columns: table => new
                {
                    id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    room_id = table.Column<int>(type: "INTEGER", nullable: false),
                    user_id = table.Column<int>(type: "INTEGER", nullable: false),
                    joined_at = table.Column<DateTime>(type: "TEXT", nullable: false),
                    left_at = table.Column<DateTime>(type: "TEXT", nullable: true),
                    is_active = table.Column<bool>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RoomParticipants", x => x.id);
                    table.ForeignKey(
                        name: "FK_RoomParticipants_Rooms_room_id",
                        column: x => x.room_id,
                        principalTable: "Rooms",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_RoomParticipants_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CallHistories_caller_id",
                table: "CallHistories",
                column: "caller_id");

            migrationBuilder.CreateIndex(
                name: "IX_CallHistories_receiver_id",
                table: "CallHistories",
                column: "receiver_id");

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessages_receiver_id_sender_id_timestamp",
                table: "ChatMessages",
                columns: new[] { "receiver_id", "sender_id", "timestamp" });

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessages_sender_id_receiver_id_timestamp",
                table: "ChatMessages",
                columns: new[] { "sender_id", "receiver_id", "timestamp" });

            migrationBuilder.CreateIndex(
                name: "IX_Contacts_contact_user_id",
                table: "Contacts",
                column: "contact_user_id");

            migrationBuilder.CreateIndex(
                name: "IX_Contacts_user_id_contact_user_id",
                table: "Contacts",
                columns: new[] { "user_id", "contact_user_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RoomParticipants_room_id_user_id_is_active",
                table: "RoomParticipants",
                columns: new[] { "room_id", "user_id", "is_active" });

            migrationBuilder.CreateIndex(
                name: "IX_RoomParticipants_user_id",
                table: "RoomParticipants",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_Rooms_created_by",
                table: "Rooms",
                column: "created_by");

            migrationBuilder.CreateIndex(
                name: "IX_Rooms_room_code",
                table: "Rooms",
                column: "room_code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_users_email",
                table: "users",
                column: "email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_users_username",
                table: "users",
                column: "username",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CallHistories");

            migrationBuilder.DropTable(
                name: "ChatMessages");

            migrationBuilder.DropTable(
                name: "Contacts");

            migrationBuilder.DropTable(
                name: "RoomParticipants");

            migrationBuilder.DropTable(
                name: "Rooms");

            migrationBuilder.DropTable(
                name: "users");
        }
    }
}
