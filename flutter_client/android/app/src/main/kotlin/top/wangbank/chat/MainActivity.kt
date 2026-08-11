package top.wangbank.chat

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val updateChannelName = "top.wangbank.chat/update"
    private val qqChannelName = "top.wangbank.chat/qq"
    private val qqPackages = listOf(
        "com.tencent.mobileqq",
        "com.tencent.tim",
        "com.tencent.qqlite",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPackageInfo" -> result.success(getPackageInfoMap())
                    "canInstallApks" -> result.success(canInstallApks())
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("invalid_apk_path", "APK path is empty.", null)
                            return@setMethodCallHandler
                        }
                        installApk(path, result)
                    }
                    "openInstallPermissionSettings" -> {
                        openInstallPermissionSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, qqChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openQQAuthUrl" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank()) {
                            result.error("invalid_qq_auth_url", "QQ auth URL is empty.", null)
                            return@setMethodCallHandler
                        }
                        result.success(openQQAuthUrl(url))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getPackageInfoMap(): Map<String, Any> {
        val packageInfo = packageManager.getPackageInfo(packageName, 0)
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            packageInfo.versionCode.toLong()
        }

        return mapOf(
            "versionName" to (packageInfo.versionName ?: "unknown"),
            "versionCode" to versionCode,
        )
    }

    private fun installApk(path: String, result: MethodChannel.Result) {
        if (!canInstallApks()) {
            result.error(
                "unknown_sources_disabled",
                "Install permission for unknown apps is disabled.",
                null,
            )
            return
        }

        val apkFile = File(path)
        if (!apkFile.exists()) {
            result.error("apk_not_found", "APK file does not exist.", null)
            return
        }

        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.update_file_provider",
            apkFile,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            clipData = ClipData.newUri(contentResolver, "Love Chat update", uri)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        try {
            startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            result.error("install_intent_failed", error.message, null)
        }
    }

    private fun canInstallApks(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        }
    }

    private fun openQQAuthUrl(url: String): Boolean {
        val uri = Uri.parse(url)
        for (qqPackage in qqPackages) {
            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                setPackage(qqPackage)
                addCategory(Intent.CATEGORY_BROWSABLE)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            if (intent.resolveActivity(packageManager) == null) {
                continue
            }

            try {
                startActivity(intent)
                return true
            } catch (_: Exception) {
                continue
            }
        }

        return false
    }
}
