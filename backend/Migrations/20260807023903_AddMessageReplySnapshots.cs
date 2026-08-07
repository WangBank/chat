using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace VideoCallAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddMessageReplySnapshots : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "reply_to_content",
                table: "GroupChatMessages",
                type: "character varying(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "reply_to_file_path",
                table: "GroupChatMessages",
                type: "character varying(255)",
                maxLength: 255,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "reply_to_message_id",
                table: "GroupChatMessages",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "reply_to_sender_name",
                table: "GroupChatMessages",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "reply_to_type",
                table: "GroupChatMessages",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "reply_to_content",
                table: "ChatMessages",
                type: "character varying(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "reply_to_file_path",
                table: "ChatMessages",
                type: "character varying(255)",
                maxLength: 255,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "reply_to_message_id",
                table: "ChatMessages",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "reply_to_sender_name",
                table: "ChatMessages",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "reply_to_type",
                table: "ChatMessages",
                type: "integer",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_GroupChatMessages_reply_to_message_id",
                table: "GroupChatMessages",
                column: "reply_to_message_id");

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessages_reply_to_message_id",
                table: "ChatMessages",
                column: "reply_to_message_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_GroupChatMessages_reply_to_message_id",
                table: "GroupChatMessages");

            migrationBuilder.DropIndex(
                name: "IX_ChatMessages_reply_to_message_id",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "reply_to_content",
                table: "GroupChatMessages");

            migrationBuilder.DropColumn(
                name: "reply_to_file_path",
                table: "GroupChatMessages");

            migrationBuilder.DropColumn(
                name: "reply_to_message_id",
                table: "GroupChatMessages");

            migrationBuilder.DropColumn(
                name: "reply_to_sender_name",
                table: "GroupChatMessages");

            migrationBuilder.DropColumn(
                name: "reply_to_type",
                table: "GroupChatMessages");

            migrationBuilder.DropColumn(
                name: "reply_to_content",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "reply_to_file_path",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "reply_to_message_id",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "reply_to_sender_name",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "reply_to_type",
                table: "ChatMessages");
        }
    }
}
