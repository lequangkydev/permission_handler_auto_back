package com.leky.permission_handler_auto_back

import android.app.Activity
import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native side of `permission_handler_auto_back`.
 *
 * Opens the appropriate system Settings page for "special" Android permissions
 * (or for runtime permissions that have been permanently denied), polls the
 * granted state on the main thread, and brings the host app back to the
 * foreground automatically when the permission is granted.
 *
 * Polling pattern is intentionally identical to the well-tested implementation
 * shipped with `app823-pdf-launcher` (`PermissionHelper.kt`): a single
 * [Handler] on the main looper running a [Runnable] every 500 ms.
 */
class PermissionHandlerAutoBackPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware {

    private companion object {
        const val POLL_INTERVAL_MS = 500L
        const val POLL_TIMEOUT_MS = 5L * 60L * 1000L // 5 minutes
    }

    private lateinit var channel: MethodChannel
    private var appContext: Context? = null
    private var activity: Activity? = null

    private val handler = Handler(Looper.getMainLooper())
    private var pollingRunnable: Runnable? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "permission_handler_auto_back")
        channel.setMethodCallHandler(this)
        appContext = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        finishPolling(false)
        appContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openSettingsAndAutoReturn" -> {
                val permission = call.argument<String>("permission")
                if (permission.isNullOrEmpty()) {
                    result.error("ARG_ERR", "permission argument is required", null)
                    return
                }
                openSettingsAndAutoReturn(permission, result)
            }

            "pollPermissionAndAutoReturn" -> {
                val permission = call.argument<String>("permission")
                if (permission.isNullOrEmpty()) {
                    result.error("ARG_ERR", "permission argument is required", null)
                    return
                }
                pollPermissionAndAutoReturn(permission, result)
            }

            "cancel" -> {
                finishPolling(false)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Start polling for [permission] and bring the app back to the foreground
     * once it is granted, **without** opening any Settings page.
     *
     * Used when something else (typically `permission_handler`'s runtime API)
     * has already navigated the user to the right system page — for example
     * when requesting `ACCESS_BACKGROUND_LOCATION` on Android 11+, where the OS
     * itself redirects to the app's location-permission page.
     */
    private fun pollPermissionAndAutoReturn(permission: String, result: MethodChannel.Result) {
        val ctx = appContext ?: run {
            result.error("NO_CONTEXT", "Plugin not attached", null)
            return
        }
        if (isPermissionGranted(ctx, permission)) {
            result.success(true)
            return
        }
        finishPolling(false)
        pendingResult = result
        startPolling(permission)
    }

    private fun openSettingsAndAutoReturn(permission: String, result: MethodChannel.Result) {
        val ctx = appContext ?: run {
            result.error("NO_CONTEXT", "Plugin not attached", null)
            return
        }

        // Already granted — return immediately, no Settings trip needed.
        if (isPermissionGranted(ctx, permission)) {
            result.success(true)
            return
        }

        // Replace any previous pending request.
        finishPolling(false)
        pendingResult = result

        val intent = settingsIntentFor(permission, ctx)
        val launcher = activity ?: ctx
        val launchIntent = if (launcher === ctx) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        } else {
            intent
        }
        try {
            launcher.startActivity(launchIntent)
        } catch (e: Exception) {
            // Try the generic app details page as a last resort.
            val fallback = appDetailsIntent(ctx)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                launcher.startActivity(fallback)
            } catch (e2: Exception) {
                pendingResult = null
                result.error("OPEN_FAILED", e2.message, null)
                return
            }
        }
        startPolling(permission)
    }

    private fun startPolling(permission: String) {
        val startedAt = System.currentTimeMillis()
        val runnable = object : Runnable {
            override fun run() {
                val ctx = appContext ?: run {
                    finishPolling(false)
                    return
                }
                if (isPermissionGranted(ctx, permission)) {
                    bringAppToFront(ctx)
                    finishPolling(true)
                    return
                }
                if (System.currentTimeMillis() - startedAt > POLL_TIMEOUT_MS) {
                    finishPolling(false)
                    return
                }
                handler.postDelayed(this, POLL_INTERVAL_MS)
            }
        }
        pollingRunnable = runnable
        handler.postDelayed(runnable, POLL_INTERVAL_MS)
    }

    private fun finishPolling(granted: Boolean) {
        pollingRunnable?.let { handler.removeCallbacks(it) }
        pollingRunnable = null
        val r = pendingResult
        pendingResult = null
        r?.success(granted)
    }

    private fun bringAppToFront(ctx: Context) {
        val launchIntent = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: return
        launchIntent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS,
        )
        ctx.startActivity(launchIntent)
    }

    private fun settingsIntentFor(permission: String, ctx: Context): Intent {
        val pkgUri = Uri.parse("package:${ctx.packageName}")
        return when (permission) {
            "manageExternalStorage" ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, pkgUri)
                } else {
                    appDetailsIntent(ctx)
                }

            "systemAlertWindow" ->
                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, pkgUri)

            "requestInstallPackages" ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, pkgUri)
                } else {
                    appDetailsIntent(ctx)
                }

            "scheduleExactAlarm" ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pkgUri)
                } else {
                    appDetailsIntent(ctx)
                }

            "ignoreBatteryOptimizations" ->
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, pkgUri)

            "accessNotificationPolicy" ->
                Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)

            "notification" ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                        putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)
                    }
                } else {
                    appDetailsIntent(ctx)
                }

            // Runtime permissions that landed here are permanently denied; the
            // user must toggle them on in the app's details page.
            else -> appDetailsIntent(ctx)
        }
    }

    private fun appDetailsIntent(ctx: Context): Intent =
        Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:${ctx.packageName}"),
        )

    private fun isPermissionGranted(ctx: Context, permission: String): Boolean {
        return when (permission) {
            "manageExternalStorage" ->
                Build.VERSION.SDK_INT < Build.VERSION_CODES.R ||
                    Environment.isExternalStorageManager()

            "systemAlertWindow" -> Settings.canDrawOverlays(ctx)

            "requestInstallPackages" ->
                Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                    ctx.packageManager.canRequestPackageInstalls()

            "scheduleExactAlarm" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
                val am = ctx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                am?.canScheduleExactAlarms() == true
            }

            "ignoreBatteryOptimizations" -> {
                val pm = ctx.getSystemService(Context.POWER_SERVICE) as? PowerManager
                pm?.isIgnoringBatteryOptimizations(ctx.packageName) == true
            }

            "accessNotificationPolicy" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
                val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE)
                    as? android.app.NotificationManager
                nm?.isNotificationPolicyAccessGranted == true
            }

            "notification" -> NotificationManagerCompat.from(ctx).areNotificationsEnabled()

            "locationAlways" ->
                Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
                    hasRuntime(ctx, "android.permission.ACCESS_BACKGROUND_LOCATION")

            else -> mapToAndroidPermission(permission)?.let { hasRuntime(ctx, it) } ?: false
        }
    }

    private fun hasRuntime(ctx: Context, androidPerm: String): Boolean =
        ContextCompat.checkSelfPermission(ctx, androidPerm) == PackageManager.PERMISSION_GRANTED

    private fun mapToAndroidPermission(permission: String): String? = when (permission) {
        "camera" -> "android.permission.CAMERA"
        "microphone" -> "android.permission.RECORD_AUDIO"
        "location", "locationWhenInUse" -> "android.permission.ACCESS_FINE_LOCATION"
        "contacts" -> "android.permission.READ_CONTACTS"
        "phone" -> "android.permission.CALL_PHONE"
        "sms" -> "android.permission.SEND_SMS"
        "storage" -> "android.permission.READ_EXTERNAL_STORAGE"
        "photos" ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
                "android.permission.READ_MEDIA_IMAGES"
            else "android.permission.READ_EXTERNAL_STORAGE"

        "videos" ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
                "android.permission.READ_MEDIA_VIDEO"
            else "android.permission.READ_EXTERNAL_STORAGE"

        "audio" ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
                "android.permission.READ_MEDIA_AUDIO"
            else "android.permission.READ_EXTERNAL_STORAGE"

        "calendar", "calendarFullAccess" -> "android.permission.READ_CALENDAR"
        "calendarWriteOnly" -> "android.permission.WRITE_CALENDAR"
        "sensors" -> "android.permission.BODY_SENSORS"
        "sensorsAlways" ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
                "android.permission.BODY_SENSORS_BACKGROUND"
            else "android.permission.BODY_SENSORS"

        "bluetooth" -> "android.permission.BLUETOOTH"
        "bluetoothScan" -> "android.permission.BLUETOOTH_SCAN"
        "bluetoothConnect" -> "android.permission.BLUETOOTH_CONNECT"
        "bluetoothAdvertise" -> "android.permission.BLUETOOTH_ADVERTISE"
        "nearbyWifiDevices" -> "android.permission.NEARBY_WIFI_DEVICES"
        "activityRecognition" -> "android.permission.ACTIVITY_RECOGNITION"
        "accessMediaLocation" -> "android.permission.ACCESS_MEDIA_LOCATION"
        else -> null
    }
}
