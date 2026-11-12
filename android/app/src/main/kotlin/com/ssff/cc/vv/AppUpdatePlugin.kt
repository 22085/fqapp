package com.ssff.cc.vv

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * In-app self-update channel (`fqapp/app-update`).
 *
 * `getCurrentInfo` reports the installed build (PackageManager
 * versionCode / versionName plus `Build.SUPPORTED_ABIS`) so the Dart
 * side can compare against update.json without a package_info
 * dependency.
 *
 * `installApk` opens the system installer for a downloaded APK through
 * FileProvider (authority `<package>.fileprovider`, see
 * `res/xml/file_paths.xml`). On Android 8+ the app must be allowed to
 * install unknown apps first: when `canRequestPackageInstalls()` is
 * false the per-app settings page is opened instead and
 * `needsPermission` is returned so the Dart side can tell the user to
 * allow it and retry.
 */
class AppUpdatePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "fqapp/app-update")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCurrentInfo" -> getCurrentInfo(result)
            "installApk" -> installApk(call, result)
            else -> result.notImplemented()
        }
    }

    private fun getCurrentInfo(result: MethodChannel.Result) {
        val ctx = context
        if (ctx == null) {
            result.error("no_context", "更新通道未附着到引擎", null)
            return
        }
        try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ctx.packageManager.getPackageInfo(
                    ctx.packageName,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                ctx.packageManager.getPackageInfo(ctx.packageName, 0)
            }
            val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                packageInfo.versionCode.toLong()
            }
            result.success(
                mapOf(
                    "versionCode" to versionCode,
                    "versionName" to (packageInfo.versionName ?: ""),
                    "supportedAbis" to Build.SUPPORTED_ABIS.toList(),
                ),
            )
        } catch (error: Exception) {
            result.error("package_info_failed", "无法读取当前版本", error.message)
        }
    }

    private fun installApk(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context
        if (ctx == null) {
            result.error("no_context", "更新通道未附着到引擎", null)
            return
        }
        val path = call.argument<String>("path")
        val file = if (path.isNullOrBlank()) null else File(path)
        if (file == null || !file.exists()) {
            result.error("no_file", "安装包文件不存在", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !ctx.packageManager.canRequestPackageInstalls()
        ) {
            // First run: send the user to this app's "install unknown apps"
            // switch, then report back so the UI can ask for a retry.
            val settingsIntent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            ).apply {
                data = Uri.parse("package:${ctx.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            start(settingsIntent)
            result.success("needsPermission")
            return
        }
        val uri = try {
            FileProvider.getUriForFile(ctx, "${ctx.packageName}.fileprovider", file)
        } catch (error: Exception) {
            result.error("uri_failed", "无法为安装包生成分享链接", error.message)
            return
        }
        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            start(installIntent)
        } catch (error: Exception) {
            result.error("install_failed", "无法打开安装器", error.message)
            return
        }
        result.success("ok")
    }

    private fun start(intent: Intent) {
        val host = activity
        if (host != null) {
            host.startActivity(intent)
        } else {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context?.startActivity(intent)
        }
    }
}
