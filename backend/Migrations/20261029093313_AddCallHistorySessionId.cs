using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace VideoCallAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddCallHistorySessionId : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "call_id",
                table: "CallHistories",
                type: "character varying(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_CallHistories_call_id",
                table: "CallHistories",
                column: "call_id",
                unique: true,
                filter: "\"call_id\" IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_CallHistories_call_id",
                table: "CallHistories");

            migrationBuilder.DropColumn(
                name: "call_id",
                table: "CallHistories");
        }
    }
}
