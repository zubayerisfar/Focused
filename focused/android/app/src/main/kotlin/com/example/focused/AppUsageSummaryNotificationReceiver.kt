package com.example.focused

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar
import kotlin.math.max

class AppUsageSummaryNotificationReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_TRIGGER_5PM = "com.example.focused.USAGE_SUMMARY_5PM"
        const val ACTION_TRIGGER_11PM = "com.example.focused.USAGE_SUMMARY_11PM"
        const val ACTION_TEST_TRIGGER = "com.example.focused.USAGE_SUMMARY_TEST"

        private const val CHANNEL_ID = "focused_usage_summary_channel"
        private const val NOTIFICATION_ID_5PM = 9201
        private const val NOTIFICATION_ID_11PM = 9202
        private const val NOTIFICATION_ID_TEST = 9203
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return

        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            if (AppUsageSummaryScheduler.isEnabled(context)) {
                AppUsageSummaryScheduler.scheduleDailySummaries(context)
            }
            return
        }

        val is5pm = action == ACTION_TRIGGER_5PM
        val is11pm = action == ACTION_TRIGGER_11PM
        val isTest = action == ACTION_TEST_TRIGGER

        if (!is5pm && !is11pm && !isTest) return

        showSummaryNotification(context, is5pm = is5pm, isTest = isTest)

        if (!isTest && AppUsageSummaryScheduler.isEnabled(context)) {
            AppUsageSummaryScheduler.scheduleDailySummaries(context)
        }
    }

    private fun showSummaryNotification(context: Context, is5pm: Boolean, isTest: Boolean) {
        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return

        createNotificationChannel(notificationManager)

        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startOfDayMs = calendar.timeInMillis
        val nowMs = System.currentTimeMillis()

        // 1. Gather app usage stats and count app opens today
        val appUsageMap = mutableMapOf<String, Long>()
        var totalAppOpens = 0

        if (usageStatsManager != null) {
            try {
                val statsList = usageStatsManager.queryUsageStats(
                    UsageStatsManager.INTERVAL_DAILY,
                    startOfDayMs,
                    nowMs,
                )
                for (stat in statsList) {
                    if (stat.totalTimeInForeground > 30_000) { // More than 30s
                        appUsageMap[stat.packageName] = (appUsageMap[stat.packageName] ?: 0L) + stat.totalTimeInForeground
                    }
                }

                val events = usageStatsManager.queryEvents(startOfDayMs, nowMs)
                val event = UsageEvents.Event()
                while (events.hasNextEvent()) {
                    events.getNextEvent(event)
                    val pkg = event.packageName ?: continue
                    if (isIgnoredPackage(context, pkg)) continue
                    if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED || event.eventType == 1) {
                        totalAppOpens++
                    }
                }
            } catch (_: Throwable) {
            }
        }

        // 2. Identify top 6 apps
        val sortedApps = appUsageMap.entries
            .filter { entry -> !isIgnoredPackage(context, entry.key) }
            .sortedByDescending { it.value }
            .take(6)

        val totalScreenTimeMs = appUsageMap.values.sum()
        val totalScreenTimeStr = formatDuration(totalScreenTimeMs)
        val statsSubtitle = "$totalScreenTimeStr screen time • $totalAppOpens app opens"

        // 3. Build Custom RemoteViews
        val bigViews = RemoteViews(context.packageName, R.layout.notification_app_usage_summary)
        val compactViews = RemoteViews(context.packageName, R.layout.notification_app_usage_summary_compact)

        // Set subtitles with total usage & app opens
        bigViews.setTextViewText(R.id.tv_summary_stats, statsSubtitle)
        compactViews.setTextViewText(R.id.tv_summary_stats_compact, statsSubtitle)

        val headerTitle = when {
            isTest -> "Apps today"
            is5pm -> "Apps today • 5:00 PM"
            else -> "Apps today • 11:00 PM"
        }
        bigViews.setTextViewText(R.id.tv_apps_today_header, headerTitle)
        compactViews.setTextViewText(R.id.tv_apps_today_header_compact, headerTitle)

        // Bind Top 6 Apps into Big View
        val bigChips = listOf(
            Triple(R.id.chip_app_1, R.id.iv_app_1, R.id.tv_app_1),
            Triple(R.id.chip_app_2, R.id.iv_app_2, R.id.tv_app_2),
            Triple(R.id.chip_app_3, R.id.iv_app_3, R.id.tv_app_3),
            Triple(R.id.chip_app_4, R.id.iv_app_4, R.id.tv_app_4),
            Triple(R.id.chip_app_5, R.id.iv_app_5, R.id.tv_app_5),
            Triple(R.id.chip_app_6, R.id.iv_app_6, R.id.tv_app_6),
        )

        for (i in bigChips.indices) {
            val (chipId, ivId, tvId) = bigChips[i]
            if (i < sortedApps.size) {
                val app = sortedApps[i]
                val timeStr = formatDuration(app.value)
                val icon = getAppIconBitmap(context, app.key, sizePx = 64)

                bigViews.setViewVisibility(chipId, View.VISIBLE)
                bigViews.setTextViewText(tvId, timeStr)
                if (icon != null) {
                    bigViews.setImageViewBitmap(ivId, icon)
                }
            } else {
                bigViews.setViewVisibility(chipId, View.GONE)
            }
        }

        // Hide Row 2 if 3 or fewer apps
        bigViews.setViewVisibility(
            R.id.layout_apps_row_2,
            if (sortedApps.size > 3) View.VISIBLE else View.GONE,
        )

        // Bind Top 3 Apps into Compact View
        val compactChips = listOf(
            Triple(R.id.chip_app_1_compact, R.id.iv_app_1_compact, R.id.tv_app_1_compact),
            Triple(R.id.chip_app_2_compact, R.id.iv_app_2_compact, R.id.tv_app_2_compact),
            Triple(R.id.chip_app_3_compact, R.id.iv_app_3_compact, R.id.tv_app_3_compact),
        )

        for (i in compactChips.indices) {
            val (cChipId, cIvId, cTvId) = compactChips[i]
            if (i < sortedApps.size) {
                val app = sortedApps[i]
                val timeStr = formatDuration(app.value)
                val icon = getAppIconBitmap(context, app.key, sizePx = 64)

                compactViews.setViewVisibility(cChipId, View.VISIBLE)
                compactViews.setTextViewText(cTvId, timeStr)
                if (icon != null) {
                    compactViews.setImageViewBitmap(cIvId, icon)
                }
            } else {
                compactViews.setViewVisibility(cChipId, View.GONE)
            }
        }

        val pendingIntent = openAppPendingIntent(context)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setCustomContentView(compactViews)
            .setCustomBigContentView(bigViews)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_STATUS)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            builder.setStyle(Notification.DecoratedCustomViewStyle())
        }

        val notificationId = when {
            isTest -> NOTIFICATION_ID_TEST
            is5pm -> NOTIFICATION_ID_5PM
            else -> NOTIFICATION_ID_11PM
        }

        notificationManager.notify(notificationId, builder.build())
    }

    private fun isIgnoredPackage(context: Context, packageName: String): Boolean {
        if (packageName == context.packageName) return true
        if (packageName.startsWith("com.android.systemui")) return true
        if (packageName.contains("launcher") || packageName.contains("nexuslauncher")) return true
        if (packageName == "com.google.android.googlequicksearchbox") return true
        return false
    }

    private fun getAppIconBitmap(context: Context, packageName: String, sizePx: Int): Bitmap? {
        return try {
            val drawable = context.packageManager.getApplicationIcon(packageName)
            drawableToBitmap(drawable, sizePx)
        } catch (_: Throwable) {
            null
        }
    }

    private fun drawableToBitmap(drawable: Drawable, sizePx: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    private fun formatDuration(ms: Long): String {
        val totalMinutes = max(1L, ms / 60_000L)
        val hours = totalMinutes / 60
        val mins = totalMinutes % 60
        return when {
            hours > 0 && mins > 0 -> "${hours}h ${mins}m"
            hours > 0 -> "${hours}h"
            else -> "${mins}m"
        }
    }

    private fun createNotificationChannel(notificationManager: NotificationManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Daily App Usage Summaries",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Daily snapshot of your app usage and app opens at 5:00 PM and 11:00 PM."
                enableVibration(true)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun openAppPendingIntent(context: Context): PendingIntent? {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: return null
        launchIntent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP

        return PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
