package com.example.focused

import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import kotlin.math.ceil

class FocusGuardService : Service() {
    companion object {
        const val ACTION_START = "com.example.focused.focusguard.START"
        const val ACTION_STATE_UPDATED = "com.example.focused.focusguard.STATE_UPDATED"
        const val ACTION_ALLOWED_PACKAGES_UPDATED =
            "com.example.focused.focusguard.ALLOWED_PACKAGES_UPDATED"
        const val ACTION_DEADLINE = "com.example.focused.focusguard.DEADLINE"
        const val ACTION_STOP = "com.example.focused.focusguard.STOP"

        private const val ONGOING_CHANNEL_ID = "focused_focus_guard_ongoing"
        private const val ALERT_CHANNEL_ID = "focused_focus_guard_alerts"
        private const val ONGOING_NOTIFICATION_ID = 8701
        private const val WARNING_NOTIFICATION_ID = 8702
        private const val TRANSITION_NOTIFICATION_BASE_ID = 8720
        private const val DEADLINE_REQUEST_CODE = 8801

        private const val POLL_INTERVAL_MS = 2_000L
        private const val FOREGROUND_QUERY_LOOKBACK_MS = 24L * 60L * 60L * 1000L
        private const val FOREGROUND_NOTIFICATION_REFRESH_MS = 10_000L
    }

    private lateinit var store: FocusGuardStateStore
    private lateinit var notificationManager: NotificationManager
    private lateinit var alarmManager: AlarmManager
    private lateinit var usageStatsManager: UsageStatsManager
    private lateinit var powerManager: PowerManager
    private lateinit var keyguardManager: KeyguardManager

    private val handler = Handler(Looper.getMainLooper())
    private var polling = false
    private var lastForegroundPackage: String? = null
    private var lastUsageQueryAtMs: Long = 0L
    private var lastForegroundNotificationAtMs: Long = 0L
    private var transitionNotificationCounter = 0

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!polling) return

            try {
                tick()
            } catch (_: Throwable) {
                // Focus Guard must not crash the whole app because one OEM has
                // unusual UsageStats behavior. The next poll can recover.
            }

            if (polling) {
                handler.postDelayed(this, POLL_INTERVAL_MS)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        store = FocusGuardStateStore(this)
        notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        keyguardManager =
            getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager

        createNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START

        when (action) {
            ACTION_STOP -> {
                cancelDeadlineAlarm()
                stopPolling()
                stopForegroundCompat()
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_START,
            ACTION_STATE_UPDATED,
            ACTION_ALLOWED_PACKAGES_UPDATED,
            ACTION_DEADLINE -> {
                val state = store.readState()
                if (state?.active != true) {
                    stopPolling()
                    stopForegroundCompat()
                    stopSelf()
                    return START_NOT_STICKY
                }

                ensureForeground(state)

                if (action == ACTION_DEADLINE) {
                    advanceExpiredPhases(System.currentTimeMillis())
                }

                val updated = store.readState()
                if (updated?.active == true) {
                    scheduleDeadlineAlarm(updated)
                    startPolling()
                    updateOngoingNotification(updated, force = true)
                }
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopPolling()
        super.onDestroy()
    }

    private fun startPolling() {
        if (polling) return
        polling = true
        lastUsageQueryAtMs = System.currentTimeMillis() - FOREGROUND_QUERY_LOOKBACK_MS
        handler.post(pollRunnable)
    }

    private fun stopPolling() {
        polling = false
        handler.removeCallbacks(pollRunnable)
    }

    private fun tick() {
        val now = System.currentTimeMillis()
        advanceExpiredPhases(now)

        var state = store.readState() ?: return
        if (!state.active) {
            stopPolling()
            stopForegroundCompat()
            stopSelf()
            return
        }

        if (!state.paused && state.deadlineEpochMs != null) {
            val remaining = secondsUntil(state.deadlineEpochMs, now)
            if (remaining != state.remainingSeconds) {
                state = state.copy(remainingSeconds = remaining)
                store.saveState(state)
            }
        }

        updateOngoingNotification(state)

        if (state.paused || state.phase != "focus") {
            resetExcursion(state)
            return
        }

        if (!powerManager.isInteractive || keyguardManager.isKeyguardLocked) {
            resetExcursion(state)
            return
        }

        if (!FocusGuardRuntime.hasUsageAccess(this)) {
            resetExcursion(state)
            return
        }

        val foregroundPackage = readForegroundPackage(now)
        if (foregroundPackage.isNullOrBlank()) {
            return
        }

        state = store.readState() ?: return
        if (!state.active || state.paused || state.phase != "focus") {
            return
        }

        val allowedPackages = store.getAllowedPackages()
        val isAllowed = foregroundPackage == packageName ||
            foregroundPackage == "com.android.systemui" ||
            allowedPackages.contains(foregroundPackage)

        if (isAllowed) {
            resetExcursion(
                state.copy(currentPackage = foregroundPackage),
            )
            return
        }

        val attention = FocusGuardAttentionRule.evaluate(
            nowMs = now,
            monitoringEnabled = true,
            isAllowedWorkspace = false,
            previousOutsideStartedAtMs = state.outsideWorkspaceStartedAtMs,
            previouslyWarned = state.warnedForCurrentExcursion,
            warningThresholdSeconds = state.warningThresholdSeconds,
        )

        val updated = state.copy(
            currentPackage = foregroundPackage,
            outsideWorkspaceStartedAtMs = attention.outsideWorkspaceStartedAtMs,
            warnedForCurrentExcursion = attention.warnedForCurrentExcursion,
        )

        if (attention.shouldWarnNow) {
            val label = resolveAppLabel(foregroundPackage)
            val message =
                "$label has been outside your focus workspace for " +
                    "${state.warningThresholdSeconds} seconds. Return to ${state.taskName}."

            showWarningNotification(message)
            store.appendEvent(
                sessionId = state.sessionId,
                type = "workspaceWarning",
                occurredAtMs = now,
                packageName = foregroundPackage,
                appLabel = label,
                outsideWorkspaceSeconds = state.warningThresholdSeconds,
                message = message,
            )

        }

        store.saveState(updated)
    }

    private fun advanceExpiredPhases(now: Long) {
        var state = store.readState() ?: return
        if (!state.active || state.paused || state.deadlineEpochMs == null) return

        var deadline = state.deadlineEpochMs

        while (state.active && !state.paused && deadline != null && now >= deadline) {
            val oldIndex = state.currentBlockIndex
            val oldBlock = state.plan.getOrNull(oldIndex)

            if (oldBlock == null || oldIndex >= state.plan.lastIndex) {
                val message = "${state.taskName} is finished. Open Focused to view your summary."
                store.appendEvent(
                    sessionId = state.sessionId,
                    type = "sessionComplete",
                    occurredAtMs = deadline,
                    message = message,
                )
                showTransitionNotification(
                    title = "Focus session complete",
                    message = message,
                )

                store.saveState(
                    state.copy(
                        active = false,
                        phase = "inactive",
                        deadlineEpochMs = null,
                        remainingSeconds = 0,
                        outsideWorkspaceStartedAtMs = null,
                        warnedForCurrentExcursion = false,
                    ),
                )
                cancelDeadlineAlarm()
                stopPolling()
                stopForegroundCompat()
                stopSelf()
                return
            }

            val nextIndex = oldIndex + 1
            val nextBlock = state.plan[nextIndex]
            val nextDeadline = deadline + nextBlock.durationSeconds * 1000L

            if (oldBlock.isBreak) {
                val focusNumber = state.plan
                    .take(nextIndex + 1)
                    .count { !it.isBreak }
                val totalFocusBlocks = state.plan.count { !it.isBreak }
                val message = "Focus block $focusNumber of $totalFocusBlocks starts now."

                store.appendEvent(
                    sessionId = state.sessionId,
                    type = "breakComplete",
                    occurredAtMs = deadline,
                    message = message,
                )
                showTransitionNotification(
                    title = "Break finished",
                    message = message,
                )
            } else if (nextBlock.isBreak) {
                val breakMinutes = ceil(nextBlock.durationSeconds / 60.0).toInt()
                val message = "Your $breakMinutes-minute break starts now."

                store.appendEvent(
                    sessionId = state.sessionId,
                    type = "focusBlockComplete",
                    occurredAtMs = deadline,
                    message = message,
                )
                showTransitionNotification(
                    title = "Focus block complete",
                    message = message,
                )
            }

            state = state.copy(
                currentBlockIndex = nextIndex,
                phase = nextBlock.type,
                deadlineEpochMs = nextDeadline,
                remainingSeconds = secondsUntil(nextDeadline, now),
                currentPackage = null,
                outsideWorkspaceStartedAtMs = null,
                warnedForCurrentExcursion = false,
            )
            store.saveState(state)
            deadline = nextDeadline
        }
    }

    private fun resetExcursion(state: FocusGuardNativeState) {
        if (
            state.outsideWorkspaceStartedAtMs == null &&
            !state.warnedForCurrentExcursion
        ) {
            return
        }

        store.saveState(
            state.copy(
                outsideWorkspaceStartedAtMs = null,
                warnedForCurrentExcursion = false,
            ),
        )
    }

    private fun readForegroundPackage(now: Long): String? {
        val queryStart = lastUsageQueryAtMs
            .coerceAtMost(now)
            .coerceAtLeast(now - FOREGROUND_QUERY_LOOKBACK_MS)
        val events = usageStatsManager.queryEvents(queryStart, now)
        val event = UsageEvents.Event()
        var latestPackage: String? = null
        var latestTimestamp = Long.MIN_VALUE

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (
                event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND
            ) {
                if (event.timeStamp >= latestTimestamp) {
                    latestTimestamp = event.timeStamp
                    latestPackage = event.packageName
                }
            }
        }

        lastUsageQueryAtMs = now + 1L
        if (!latestPackage.isNullOrBlank()) {
            lastForegroundPackage = latestPackage
        }
        return lastForegroundPackage
    }

    private fun ensureForeground(state: FocusGuardNativeState) {
        val notification = buildOngoingNotification(state)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                ONGOING_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(ONGOING_NOTIFICATION_ID, notification)
        }
    }

    private fun updateOngoingNotification(
        state: FocusGuardNativeState,
        force: Boolean = false,
    ) {
        val now = System.currentTimeMillis()
        if (!force && now - lastForegroundNotificationAtMs < FOREGROUND_NOTIFICATION_REFRESH_MS) {
            return
        }

        lastForegroundNotificationAtMs = now
        notificationManager.notify(
            ONGOING_NOTIFICATION_ID,
            buildOngoingNotification(state),
        )
    }

    private fun buildOngoingNotification(state: FocusGuardNativeState): Notification {
        val title = when {
            state.paused -> "Focused • Paused"
            state.phase == "break" -> "Focused • Break"
            else -> "Focused • ${state.taskName}"
        }

        val remainingMinutes = ceil(state.remainingSeconds / 60.0).toInt().coerceAtLeast(0)
        val body = when {
            state.paused -> "Focus Guard is paused."
            state.phase == "break" -> "$remainingMinutes min break remaining"
            state.originDevice == "windows" ->
                "Running on Windows • Phone Focus Guard active • $remainingMinutes min remaining"
            !FocusGuardRuntime.hasUsageAccess(this) ->
                "$remainingMinutes min remaining • Usage Access needed for app warnings"
            else -> "$remainingMinutes min remaining • Focus Guard active"
        }

        return notificationBuilder(ONGOING_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(openAppPendingIntent())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .build()
    }

    private fun showWarningNotification(message: String) {
        val notification = notificationBuilder(ALERT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Focus warning")
            .setContentText(message)
            .setStyle(Notification.BigTextStyle().bigText(message))
            .setContentIntent(openAppPendingIntent())
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .build()

        notificationManager.notify(WARNING_NOTIFICATION_ID, notification)
    }

    private fun showTransitionNotification(title: String, message: String) {
        transitionNotificationCounter = (transitionNotificationCounter + 1) % 100
        val notification = notificationBuilder(ALERT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(Notification.BigTextStyle().bigText(message))
            .setContentIntent(openAppPendingIntent())
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .build()

        notificationManager.notify(
            TRANSITION_NOTIFICATION_BASE_ID + transitionNotificationCounter,
            notification,
        )
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        notificationManager.createNotificationChannel(
            NotificationChannel(
                ONGOING_CHANNEL_ID,
                "Focus Guard session",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shows the active Focused session and Focus Guard state."
                setShowBadge(false)
            },
        )

        notificationManager.createNotificationChannel(
            NotificationChannel(
                ALERT_CHANNEL_ID,
                "Focus Guard alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description =
                    "Distraction warnings and focus/break transition reminders."
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            },
        )
    }

    private fun openAppPendingIntent(): PendingIntent? {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: return null
        launchIntent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP

        return PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun notificationBuilder(channelId: String): Notification.Builder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun scheduleDeadlineAlarm(state: FocusGuardNativeState) {
        val deadline = state.deadlineEpochMs
        if (!state.active || state.paused || deadline == null) {
            cancelDeadlineAlarm()
            return
        }

        val pendingIntent = deadlinePendingIntent()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                alarmManager.canScheduleExactAlarms()
            } else {
                true
            }

            if (canExact) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    deadline,
                    pendingIntent,
                )
            } else {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    deadline,
                    pendingIntent,
                )
            }
        } else {
            @Suppress("DEPRECATION")
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                deadline,
                pendingIntent,
            )
        }
    }

    private fun cancelDeadlineAlarm() {
        alarmManager.cancel(deadlinePendingIntent())
    }

    private fun deadlinePendingIntent(): PendingIntent {
        val intent = Intent(this, FocusGuardAlarmReceiver::class.java)
            .setAction(ACTION_DEADLINE)

        return PendingIntent.getBroadcast(
            this,
            DEADLINE_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun resolveAppLabel(packageName: String): String {
        return try {
            @Suppress("DEPRECATION")
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString().ifBlank { packageName }
        } catch (_: Throwable) {
            packageName
        }
    }

    private fun secondsUntil(deadlineMs: Long, nowMs: Long): Int {
        if (deadlineMs <= nowMs) return 0
        return ((deadlineMs - nowMs + 999L) / 1000L).toInt()
    }
}
