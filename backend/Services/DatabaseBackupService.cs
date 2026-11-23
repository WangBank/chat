using System.Diagnostics;
using System.Data;
using System.Security.Cryptography;
using System.Text;
using Npgsql;

namespace VideoCallAPI.Services;

public sealed record DatabaseBackupInfo(string Id, DateTime CreatedAt, long SizeBytes, string Kind);

public sealed class BackupInProgressException() : Exception("已有备份或还原正在执行，请稍后重试。");
public sealed class IncompatibleBackupException() : Exception("备份与当前数据库的迁移版本不同，无法在线还原。");

public sealed class DatabaseBackupService(IConfiguration configuration)
{
    private const string Manual = "manual";
    private const string BeforeRestore = "before-restore";
    private readonly NpgsqlConnectionStringBuilder _database = new(
        configuration.GetConnectionString("DefaultConnection"));
    private readonly string _directory = Path.GetFullPath(configuration["DatabaseBackup:Directory"]
        ?? Path.Combine(AppContext.BaseDirectory, "private-backups"));

    public IReadOnlyList<DatabaseBackupInfo> List()
    {
        if (!Directory.Exists(_directory)) return [];
        return new DirectoryInfo(_directory).EnumerateFiles("*.dump")
            .Where(file => file.LinkTarget is null)
            .Select(ReadInfo)
            .OfType<DatabaseBackupInfo>()
            .OrderByDescending(backup => backup.CreatedAt)
            .ToList();
    }

    public async Task<DatabaseBackupInfo> CreateAsync(CancellationToken cancellationToken)
    {
        await using var lease = await AcquireLeaseAsync(cancellationToken);
        return await DumpAsync(lease, Manual, cancellationToken);
    }

    public async Task<DatabaseBackupInfo> RestoreAsync(Guid id, CancellationToken cancellationToken)
    {
        await using var lease = await AcquireLeaseAsync(cancellationToken);
        var directory = new DirectoryInfo(_directory);
        var source = (directory.Exists ? directory.EnumerateFiles($"*-{id:N}.dump") : [])
            .FirstOrDefault(file => file.LinkTarget is null && ReadInfo(file) is not null)
            ?? throw new FileNotFoundException("备份不存在。");
        var expectedSchema = source.Name.Split('-')[^2];
        var safety = await DumpAsync(lease, BeforeRestore, cancellationToken, expectedSchema);
        await RunAsync("pg_restore", ["--clean", "--if-exists", "--single-transaction",
            "--exit-on-error", "--dbname", _database.Database!, source.FullName],
            cancellationToken);
        return safety;
    }

    private async Task<NpgsqlConnection> AcquireLeaseAsync(CancellationToken cancellationToken)
    {
        // A dedicated session releases the database-wide lock even on process termination.
        var options = new NpgsqlConnectionStringBuilder(_database.ConnectionString) { Pooling = false };
        var lease = new NpgsqlConnection(options.ConnectionString);
        try
        {
            await lease.OpenAsync(cancellationToken);
            await using var command = new NpgsqlCommand(
                "SELECT pg_try_advisory_lock(1326255941, 1111576651)", lease);
            if (await command.ExecuteScalarAsync(cancellationToken) is not true)
                throw new BackupInProgressException();
            return lease;
        }
        catch
        {
            await lease.DisposeAsync();
            throw;
        }
    }

    private static DatabaseBackupInfo? ReadInfo(FileInfo file)
    {
        var name = Path.GetFileNameWithoutExtension(file.Name);
        var parts = name.Split('-');
        if (parts.Length < 3 || parts[^2].Length != 64 || !parts[^2].All(char.IsAsciiHexDigit)
            || !Guid.TryParseExact(parts[^1], "N", out var id))
            return null;
        var kind = string.Join("-", parts[..^2]);
        return kind is Manual or BeforeRestore
            ? new(id.ToString("N"), file.LastWriteTimeUtc, file.Length, kind) : null;
    }

    private async Task<DatabaseBackupInfo> DumpAsync(NpgsqlConnection lease, string kind,
        CancellationToken cancellationToken, string? expectedSchema = null)
    {
        // pg_dump imports the snapshot used to fingerprint EF migrations. A concurrent deployment
        // cannot accidentally stamp an old dump with the new migration list.
        await using var transaction = await lease.BeginTransactionAsync(IsolationLevel.RepeatableRead, cancellationToken);
        await using var query = new NpgsqlCommand("""
            SELECT pg_export_snapshot(), coalesce(string_agg("MigrationId", chr(10) ORDER BY "MigrationId"), '')
            FROM public."__EFMigrationsHistory"
            """, lease, transaction);
        string snapshot, schema;
        await using (var reader = await query.ExecuteReaderAsync(cancellationToken))
        {
            await reader.ReadAsync(cancellationToken);
            snapshot = reader.GetString(0);
            schema = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(reader.GetString(1))));
        }
        if (expectedSchema is not null && schema != expectedSchema)
            throw new IncompatibleBackupException();
        if (OperatingSystem.IsWindows()) Directory.CreateDirectory(_directory);
        else Directory.CreateDirectory(_directory, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);

        var path = Path.Combine(_directory, $"{kind}-{schema}-{Guid.NewGuid():N}.dump");
        var pending = path + ".partial";
        try
        {
            var options = new FileStreamOptions { Mode = FileMode.CreateNew, Access = FileAccess.Write };
            if (!OperatingSystem.IsWindows()) options.UnixCreateMode = UnixFileMode.UserRead | UnixFileMode.UserWrite;
            using (new FileStream(pending, options)) { }
            await RunAsync("pg_dump", ["--format=custom", "--snapshot", snapshot, "--file", pending], cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            File.Move(pending, path);
            return ReadInfo(new FileInfo(path))!;
        }
        finally
        {
            File.Delete(pending);
        }
    }

    private async Task RunAsync(string executable, string[] arguments, CancellationToken cancellationToken)
    {
        var settings = new ProcessStartInfo(executable)
        {
            UseShellExecute = false,
            RedirectStandardError = true
        };
        foreach (var argument in arguments) settings.ArgumentList.Add(argument);
        settings.ArgumentList.Add("--no-password");
        settings.Environment["PGHOST"] = _database.Host;
        settings.Environment["PGPORT"] = _database.Port.ToString(System.Globalization.CultureInfo.InvariantCulture);
        settings.Environment["PGDATABASE"] = _database.Database;
        settings.Environment["PGUSER"] = _database.Username;
        if (_database.Password is not null) settings.Environment["PGPASSWORD"] = _database.Password;
        settings.Environment["PGSSLMODE"] = _database.SslMode switch
        {
            SslMode.VerifyCA => "verify-ca",
            SslMode.VerifyFull => "verify-full",
            _ => _database.SslMode.ToString().ToLowerInvariant()
        };
        if (_database.RootCertificate is not null) settings.Environment["PGSSLROOTCERT"] = _database.RootCertificate;
        using var process = Process.Start(settings) ?? throw new InvalidOperationException("无法启动 PostgreSQL 客户端。");
        // Diagnostics can contain row values. Keep them out of HTTP responses and application logs.
        var drain = process.StandardError.BaseStream.CopyToAsync(Stream.Null);
        try
        {
            await process.WaitForExitAsync(cancellationToken);
        }
        catch (OperationCanceledException)
        {
            if (!process.HasExited) process.Kill();
            await process.WaitForExitAsync(CancellationToken.None);
            throw;
        }
        finally
        {
            await drain;
        }
        if (process.ExitCode != 0)
            throw new InvalidOperationException($"{executable} exited with status {process.ExitCode}.");
    }
}
