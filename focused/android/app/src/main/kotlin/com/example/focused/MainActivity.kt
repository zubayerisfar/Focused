package com.example.focused

import android.Manifest
import android.content.Context
import android.content.pm.LauncherApps
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlin.math.min

class MainActivity : FlutterActivity() {
    companion object {
        private const val APP_METADATA_CHANNEL = "focused/app_metadata"
        private const val FOCUS_GUARD_CHANNEL = "focused/focus_guard"
        private const val NOTIFICATION_PERMISSION_REQUEST = 4401
        private const val DEFAULT_ICON_SIZE = 96
        private const val MAX_BATCH_SIZE = 200
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_METADATA_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppMetadataBatch" -> {
                    val packages =
                        call.argument<List<String>>("packageNames")
                            ?.map { it.trim() }
                            ?.filter { it.isNotEmpty() }
                            ?.distinct()
                            ?.take(MAX_BATCH_SIZE)
                            ?: emptyList()

                    val requestedSize =
                        call.argument<Int>("iconSize") ?: DEFAULT_ICON_SIZE
                    val iconSize = requestedSize.coerceIn(48, 192)

                    try {
                        val payload = packages.map { packageName ->
                            resolveAppMetadata(packageName, iconSize)
                        }
                        result.success(payload)
                    } catch (error: Throwable) {
                        result.error(
                            "APP_METADATA_FAILED",
                            error.message ?: "Could not resolve app metadata.",
                            null,
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FOCUS_GUARD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            val arguments = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()

            try {
                when (call.method) {
                    "startFocusGuard" -> {
                        requestNotificationPermissionIfNeeded()
                        FocusGuardRuntime.start(this, arguments)
                        result.success(null)
                    }

                    "pauseFocusGuard" -> {
                        FocusGuardRuntime.pause(this, arguments)
                        result.success(null)
                    }

                    "resumeFocusGuard" -> {
                        FocusGuardRuntime.resume(this, arguments)
                        result.success(null)
                    }

                    "syncFocusGuardPhase" -> {
                        FocusGuardRuntime.sync(this, arguments)
                        result.success(null)
                    }

                    "updateFocusGuardAllowedPackages" -> {
                        FocusGuardRuntime.updateAllowedPackages(
                            this,
                            arguments,
                            notifyService = true,
                        )
                        result.success(null)
                    }

                    "cacheFocusGuardAllowedPackages" -> {
                        FocusGuardRuntime.updateAllowedPackages(
                            this,
                            arguments,
                            notifyService = false,
                        )
                        result.success(null)
                    }

                    "stopFocusGuard" -> {
                        FocusGuardRuntime.stop(this)
                        result.success(null)
                    }

                    "getFocusGuardEvents" -> {
                        result.success(FocusGuardRuntime.getEvents(this))
                    }

                    "clearFocusGuardEvents" -> {
                        FocusGuardRuntime.clearEvents(this)
                        result.success(null)
                    }

                    "getFocusGuardSnapshot" -> {
                        result.success(FocusGuardRuntime.getSnapshot(this))
                    }

                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error(
                    "FOCUS_GUARD_FAILED",
                    error.message ?: "Focus Guard operation failed.",
                    null,
                )
            }
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST,
            )
        }
    }

    private fun resolveAppMetadata(
        packageName: String,
        iconSize: Int,
    ): Map<String, Any?> {
        val packageManager = packageManager
        val launcherApps =
            getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps

        var displayName = packageName
        var icon: Drawable? = null
        var installed = false

        try {
            val launcherActivity = launcherApps
                .getActivityList(packageName, Process.myUserHandle())
                .firstOrNull()

            if (launcherActivity != null) {
                installed = true

                val label = launcherActivity.label?.toString()?.trim()
                if (!label.isNullOrEmpty()) {
                    displayName = label
                }

                icon = launcherActivity.getIcon(resources.displayMetrics.densityDpi)
            }
        } catch (_: Throwable) {
            // Some OEMs are stricter around launcher metadata. Fall through
            // to PackageManager for the same specific package.
        }

        if (!installed || icon == null || displayName == packageName) {
            try {
                @Suppress("DEPRECATION")
                val applicationInfo =
                    packageManager.getApplicationInfo(packageName, 0)

                installed = true

                val label =
                    packageManager.getApplicationLabel(applicationInfo)
                        ?.toString()
                        ?.trim()

                if (!label.isNullOrEmpty()) {
                    displayName = label
                }

                if (icon == null) {
                    icon = packageManager.getApplicationIcon(applicationInfo)
                }
            } catch (_: PackageManager.NameNotFoundException) {
                // UsageStats can retain packages that are no longer installed.
                // Keep the package id as an honest historical fallback.
            } catch (_: Throwable) {
                // Package visibility/OEM restrictions should not break usage
                // analytics. The Dart layer will use a text fallback.
            }
        }

        val iconBytes = icon?.let { drawableToPng(it, iconSize) }

        return mapOf(
            "packageName" to packageName,
            "displayName" to displayName,
            "iconBytes" to iconBytes,
            "isInstalled" to installed,
        )
    }

    private fun drawableToPng(
        drawable: Drawable,
        targetSize: Int,
    ): ByteArray? {
        return try {
            val intrinsicWidth =
                drawable.intrinsicWidth.takeIf { it > 0 } ?: targetSize
            val intrinsicHeight =
                drawable.intrinsicHeight.takeIf { it > 0 } ?: targetSize

            val scale = min(
                targetSize.toFloat() / intrinsicWidth.toFloat(),
                targetSize.toFloat() / intrinsicHeight.toFloat(),
            )

            val drawWidth =
                (intrinsicWidth * scale).toInt().coerceAtLeast(1)
            val drawHeight =
                (intrinsicHeight * scale).toInt().coerceAtLeast(1)

            val bitmap = Bitmap.createBitmap(
                targetSize,
                targetSize,
                Bitmap.Config.ARGB_8888,
            )

            val canvas = Canvas(bitmap)
            val left = (targetSize - drawWidth) / 2
            val top = (targetSize - drawHeight) / 2

            drawable.setBounds(
                left,
                top,
                left + drawWidth,
                top + drawHeight,
            )
            drawable.draw(canvas)

            ByteArrayOutputStream().use { output ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
                bitmap.recycle()
                output.toByteArray()
            }
        } catch (_: Throwable) {
            null
        }
    }
}
