package com.example.focused

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

object AppUsageSummaryScheduler {
    private const val PREFS_NAME = "focused_usage_summary_prefs"
    private const val KEY_ENABLED = "summary_notifications_enabled"
    private const val REQUEST_CODE_5PM = 9101
    private const val REQUEST_CODE_11PM = 9102

    fun isEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_ENABLED, true) // Enabled by default
    }

    fun setEnabled(context: Context, enabled: Boolean) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_ENABLED, enabled).apply()

        if (enabled) {
            scheduleDailySummaries(context)
        } else {
            cancelDailySummaries(context)
        }
    }

    fun scheduleDailySummaries(context: Context) {
        scheduleNextSlot(context, targetHour = 17, targetMinute = 0, requestCode = REQUEST_CODE_5PM, slotName = "5PM")
        scheduleNextSlot(context, targetHour = 23, targetMinute = 0, requestCode = REQUEST_CODE_11PM, slotName = "11PM")
    }

    fun cancelDailySummaries(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        
        val intent5 = Intent(context, AppUsageSummaryNotificationReceiver::class.java).apply {
            action = AppUsageSummaryNotificationReceiver.ACTION_TRIGGER_5PM
        }
        val pi5 = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE_5PM,
            intent5,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.cancel(pi5)

        val intent11 = Intent(context, AppUsageSummaryNotificationReceiver::class.java).apply {
            action = AppUsageSummaryNotificationReceiver.ACTION_TRIGGER_11PM
        }
        val pi11 = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE_11PM,
            intent11,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.cancel(pi11)
    }

    private fun scheduleNextSlot(context: Context, targetHour: Int, targetMinute: Int, requestCode: Int, slotName: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return

        val now = Calendar.getInstance()
        val target = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, targetHour)
            set(Calendar.MINUTE, targetMinute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        // If time already passed today, schedule for tomorrow
        if (target.before(now)) {
            target.add(Calendar.DAY_OF_YEAR, 1)
        }

        val intent = Intent(context, AppUsageSummaryNotificationReceiver::class.java).apply {
            action = if (targetHour == 17) AppUsageSummaryNotificationReceiver.ACTION_TRIGGER_5PM else AppUsageSummaryNotificationReceiver.ACTION_TRIGGER_11PM
            putExtra("slotName", slotName)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    target.timeInMillis,
                    pendingIntent,
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    target.timeInMillis,
                    pendingIntent,
                )
            }
        } catch (e: SecurityException) {
            // Handle devices without exact alarm permission
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                target.timeInMillis,
                pendingIntent,
            )
        }
    }
}

