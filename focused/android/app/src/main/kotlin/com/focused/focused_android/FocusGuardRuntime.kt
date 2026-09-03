package com.focused.focused_android

import android.Manifest
import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process

internal object FocusGuardRuntime {
    fun start(context: Context, arguments: Map<*, *>) {
        val plan = parsePlan(arguments["plan"])
        if (plan.isEmpty()) {
            throw IllegalArgumentException("Focus Guard plan cannot be empty.")
        }

        val sessionId = arguments.string("sessionId")
            ?: throw IllegalArgumentException("sessionId is required.")
        val taskName = arguments.string("taskName")?.ifBlank { "Focus" } ?: "Focus"
        val originDevice = arguments.string("originDevice")?.ifBlank { "android" }
            ?: "android"
        val currentBlockIndex = arguments.int("currentBlockIndex").coerceIn(
            0,
            plan.lastIndex,
        )
        val remainingSeconds = arguments.int("remainingSeconds")
            .coerceAtLeast(1)
        val threshold = arguments.int("warningThresholdSeconds")
            .takeIf { it > 0 }
            ?: 30
        val phase = plan[currentBlockIndex].type
        val now = System.currentTimeMillis()

        FocusGuardStateStore(context).saveState(
            FocusGuardNativeState(
                active = true,
                sessionId = sessionId,
                taskName = taskName,
                originDevice = originDevice,
                plan = plan,
                currentBlockIndex = currentBlockIndex,
                phase = phase,
                deadlineEpochMs = now + remainingSeconds * 1000L,
                remainingSeconds = remainingSeconds,
                paused = false,
                warningThresholdSeconds = threshold,
                currentPackage = null,
                outsideWorkspaceStartedAtMs = null,
                warnedForCurrentExcursion = false,
            ),
        )

        startService(context, FocusGuardService.ACTION_START)
    }

    fun pause(context: Context, arguments: Map<*, *>) {
        val store = FocusGuardStateStore(context)
        val state = store.readState() ?: return
        if (!state.active) return

        store.saveState(
            state.copy(
                currentBlockIndex = arguments.int("currentBlockIndex")
                    .coerceIn(0, state.plan.lastIndex.coerceAtLeast(0)),
                phase = "paused",
                deadlineEpochMs = null,
                remainingSeconds = arguments.int("remainingSeconds")
                    .coerceAtLeast(0),
                paused = true,
                outsideWorkspaceStartedAtMs = null,
                warnedForCurrentExcursion = false,
            ),
        )
        startService(context, FocusGuardService.ACTION_STATE_UPDATED)
    }

    fun resume(context: Context, arguments: Map<*, *>) {
        sync(context, arguments)
    }

    fun sync(context: Context, arguments: Map<*, *>) {
        val store = FocusGuardStateStore(context)
        val state = store.readState() ?: return
        if (!state.active || state.plan.isEmpty()) return

        val index = arguments.int("currentBlockIndex")
            .coerceIn(0, state.plan.lastIndex)
        val phase = arguments.string("phase") ?: state.plan[index].type
        val remainingSeconds = arguments.int("remainingSeconds").coerceAtLeast(1)
        val now = System.currentTimeMillis()

        store.saveState(
            state.copy(
                currentBlockIndex = index,
                phase = phase,
                deadlineEpochMs = now + remainingSeconds * 1000L,
                remainingSeconds = remainingSeconds,
                paused = false,
                outsideWorkspaceStartedAtMs = null,
                warnedForCurrentExcursion = false,
            ),
        )
        startService(context, FocusGuardService.ACTION_STATE_UPDATED)
    }

    fun updateAllowedPackages(
        context: Context,
        arguments: Map<*, *>,
        notifyService: Boolean,
    ) {
        val packages = (arguments["packageNames"] as? List<*>)
            ?.mapNotNull { it as? String }
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            ?.toSet()
            ?: emptySet()

        FocusGuardStateStore(context).setAllowedPackages(packages)

        if (notifyService) {
            val state = FocusGuardStateStore(context).readState()
            if (state?.active == true) {
                startService(context, FocusGuardService.ACTION_ALLOWED_PACKAGES_UPDATED)
            }
        }
    }

    fun stop(context: Context) {
        FocusGuardStateStore(context).clearActiveState()
        startService(context, FocusGuardService.ACTION_STOP)
    }

    fun getEvents(context: Context): List<Map<String, Any?>> {
        return FocusGuardStateStore(context).getEvents()
    }

    fun clearEvents(context: Context) {
        FocusGuardStateStore(context).clearEvents()
    }

    fun getSnapshot(context: Context): Map<String, Any?> {
        val state = FocusGuardStateStore(context).readState()
        val now = System.currentTimeMillis()
        val remainingSeconds = if (
            state != null &&
            state.active &&
            !state.paused &&
            state.deadlineEpochMs != null
        ) {
            ((state.deadlineEpochMs - now + 999L) / 1000L)
                .coerceAtLeast(0L)
                .toInt()
        } else {
            state?.remainingSeconds ?: 0
        }

        return mapOf(
            "isSupported" to true,
            "serviceRunning" to (state?.active == true),
            "usageAccessGranted" to hasUsageAccess(context),
            "notificationsEnabled" to notificationsEnabled(context),
            "sessionId" to state?.sessionId,
            "originDevice" to state?.originDevice,
            "taskName" to state?.taskName,
            "phase" to when {
                state == null || !state.active -> "inactive"
                state.paused -> "paused"
                else -> state.phase
            },
            "remainingSeconds" to remainingSeconds,
            "warningThresholdSeconds" to (state?.warningThresholdSeconds ?: 30),
            "currentPackage" to state?.currentPackage,
        )
    }

    fun hasUsageAccess(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun notificationsEnabled(context: Context): Boolean {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            manager.areNotificationsEnabled()
        } else {
            true
        }
    }

    private fun startService(context: Context, action: String) {
        val intent = Intent(context, FocusGuardService::class.java).setAction(action)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    private fun parsePlan(raw: Any?): List<FocusGuardPlanBlock> {
        return (raw as? List<*>)
            ?.mapNotNull { item ->
                val map = item as? Map<*, *> ?: return@mapNotNull null
                val type = map.string("type") ?: "focus"
                val seconds = map.int("durationSeconds")
                if (seconds <= 0) null else FocusGuardPlanBlock(type, seconds)
            }
            ?: emptyList()
    }
}

private fun Map<*, *>.string(key: String): String? {
    return this[key] as? String
}

private fun Map<*, *>.int(key: String): Int {
    return (this[key] as? Number)?.toInt() ?: 0
}
