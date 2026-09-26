package com.focused.focused_android

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val NOTIFICATION_EVENTS_CHANNEL = "focused/notification_events"
        private const val INSTALLATION_INFO_CHANNEL = "focused/installation_info"
        private const val HOME_WIDGET_CHANNEL = "focused/home_widget"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INSTALLATION_INFO_CHANNEL,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getFirstInstallTimeMillis" -> {
                        @Suppress("DEPRECATION")
                        val packageInfo = packageManager.getPackageInfo(packageName, 0)
                        result.success(packageInfo.firstInstallTime)
                    }

                    "getDeviceIdentity" -> {
                        result.success(
                            mapOf(
                                "manufacturer" to Build.MANUFACTURER,
                                "brand" to Build.BRAND,
                                "model" to Build.MODEL,
                            ),
                        )
                    }

                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error(
                    "INSTALLATION_INFO_FAILED",
                    error.message ?: "Could not read Android installation information.",
                    null,
                )
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_EVENTS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "openAppNotificationSettings" -> {
                        openAppNotificationSettings()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error(
                    "NOTIFICATION_ACCESS_FAILED",
                    error.message ?: "Notification access operation failed.",
                    null,
                )
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            HOME_WIDGET_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgetData" -> {
                    val arguments = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
                    try {
                        val prefs = getSharedPreferences(
                            FocusedLifestyleWidgetProvider.PREFS_NAME,
                            Context.MODE_PRIVATE,
                        )
                        val editor = prefs.edit()

                        (arguments["streak"] as? String)?.let { editor.putString("streak", it) }
                        (arguments["focusHours"] as? String)?.let { editor.putString("focus_hours", it) }

                        val tasks = arguments["tasks"] as? List<*>
                        if (tasks != null) {
                            editor.putInt("tasks_count", tasks.size)
                            tasks.take(3).forEachIndexed { index, item ->
                                val taskMap = item as? Map<*, *>
                                val slot = index + 1
                                editor.putString("task_${slot}_id", taskMap?.get("id") as? String)
                                editor.putString("task_${slot}_title", taskMap?.get("title") as? String)
                                editor.putBoolean("task_${slot}_done", taskMap?.get("isDone") as? Boolean ?: false)
                            }
                        }

                        editor.apply()
                        FocusedLifestyleWidgetProvider.updateAllWidgets(applicationContext)
                        result.success(true)
                    } catch (error: Throwable) {
                        result.error(
                            "WIDGET_UPDATE_FAILED",
                            error.message ?: "Failed to update home widget.",
                            null,
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun openAppNotificationSettings() {
        val candidates = mutableListOf<Intent>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            candidates += Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        }

        candidates += Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        }
        candidates += Intent(Settings.ACTION_SETTINGS)

        startFirstResolvableSettingsIntent(candidates)
    }

    private fun startFirstResolvableSettingsIntent(candidates: List<Intent>) {
        var lastError: Throwable? = null
        for (candidate in candidates) {
            if (candidate.resolveActivity(packageManager) == null) continue
            try {
                candidate.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(candidate)
                return
            } catch (error: Throwable) {
                lastError = error
            }
        }

        throw IllegalStateException(
            "Android Settings could not be opened on this device.",
            lastError,
        )
    }
}
