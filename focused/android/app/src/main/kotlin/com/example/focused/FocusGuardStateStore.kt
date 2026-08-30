package com.example.focused

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

internal data class FocusGuardPlanBlock(
    val type: String,
    val durationSeconds: Int,
) {
    val isBreak: Boolean
        get() = type == "break"
}

internal data class FocusGuardNativeState(
    val active: Boolean,
    val sessionId: String,
    val taskName: String,
    val originDevice: String,
    val plan: List<FocusGuardPlanBlock>,
    val currentBlockIndex: Int,
    val phase: String,
    val deadlineEpochMs: Long?,
    val remainingSeconds: Int,
    val paused: Boolean,
    val warningThresholdSeconds: Int,
    val currentPackage: String?,
    val outsideWorkspaceStartedAtMs: Long?,
    val warnedForCurrentExcursion: Boolean,
)

internal class FocusGuardStateStore(context: Context) {
    companion object {
        private const val PREFS = "focused_focus_guard"
        private const val KEY_STATE = "state_json"
        private const val KEY_ALLOWED_PACKAGES = "allowed_packages"
        private const val KEY_EVENTS = "events_json"
        private const val MAX_EVENTS = 250
    }

    private val prefs = context.applicationContext.getSharedPreferences(
        PREFS,
        Context.MODE_PRIVATE,
    )

    fun saveState(state: FocusGuardNativeState) {
        prefs.edit().putString(KEY_STATE, stateToJson(state).toString()).apply()
    }

    fun readState(): FocusGuardNativeState? {
        val raw = prefs.getString(KEY_STATE, null) ?: return null
        return try {
            stateFromJson(JSONObject(raw))
        } catch (_: Throwable) {
            null
        }
    }

    fun clearActiveState() {
        val state = readState() ?: return
        saveState(
            state.copy(
                active = false,
                deadlineEpochMs = null,
                remainingSeconds = 0,
                currentPackage = null,
                outsideWorkspaceStartedAtMs = null,
                warnedForCurrentExcursion = false,
            ),
        )
    }

    fun setAllowedPackages(packageNames: Set<String>) {
        prefs.edit()
            .putStringSet(KEY_ALLOWED_PACKAGES, packageNames.toSet())
            .apply()
    }

    fun getAllowedPackages(): Set<String> {
        return prefs.getStringSet(KEY_ALLOWED_PACKAGES, emptySet())
            ?.toSet()
            ?: emptySet()
    }

    fun appendEvent(
        sessionId: String,
        type: String,
        occurredAtMs: Long,
        message: String,
        packageName: String? = null,
        appLabel: String? = null,
        outsideWorkspaceSeconds: Int? = null,
    ) {
        val events = readEventArray()
        val event = JSONObject()
            .put("id", UUID.randomUUID().toString())
            .put("sessionId", sessionId)
            .put("type", type)
            .put("occurredAtMs", occurredAtMs)
            .put("message", message)

        if (packageName != null) event.put("packageName", packageName)
        if (appLabel != null) event.put("appLabel", appLabel)
        if (outsideWorkspaceSeconds != null) {
            event.put("outsideWorkspaceSeconds", outsideWorkspaceSeconds)
        }

        events.put(event)

        val trimmed = JSONArray()
        val start = (events.length() - MAX_EVENTS).coerceAtLeast(0)
        for (index in start until events.length()) {
            trimmed.put(events.getJSONObject(index))
        }

        prefs.edit().putString(KEY_EVENTS, trimmed.toString()).apply()
    }

    fun getEvents(): List<Map<String, Any?>> {
        val events = readEventArray()
        val result = mutableListOf<Map<String, Any?>>()

        for (index in 0 until events.length()) {
            val item = events.optJSONObject(index) ?: continue
            result.add(
                mapOf(
                    "id" to item.optString("id"),
                    "sessionId" to item.optString("sessionId"),
                    "type" to item.optString("type"),
                    "occurredAtMs" to item.optLong("occurredAtMs"),
                    "packageName" to item.optNullableString("packageName"),
                    "appLabel" to item.optNullableString("appLabel"),
                    "outsideWorkspaceSeconds" to
                        if (item.has("outsideWorkspaceSeconds")) {
                            item.optInt("outsideWorkspaceSeconds")
                        } else {
                            null
                        },
                    "message" to item.optString("message"),
                ),
            )
        }

        return result
    }

    fun clearEvents() {
        prefs.edit().remove(KEY_EVENTS).apply()
    }

    private fun readEventArray(): JSONArray {
        val raw = prefs.getString(KEY_EVENTS, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (_: Throwable) {
            JSONArray()
        }
    }

    private fun stateToJson(state: FocusGuardNativeState): JSONObject {
        val plan = JSONArray()
        state.plan.forEach { block ->
            plan.put(
                JSONObject()
                    .put("type", block.type)
                    .put("durationSeconds", block.durationSeconds),
            )
        }

        return JSONObject()
            .put("active", state.active)
            .put("sessionId", state.sessionId)
            .put("taskName", state.taskName)
            .put("originDevice", state.originDevice)
            .put("plan", plan)
            .put("currentBlockIndex", state.currentBlockIndex)
            .put("phase", state.phase)
            .put("deadlineEpochMs", state.deadlineEpochMs ?: JSONObject.NULL)
            .put("remainingSeconds", state.remainingSeconds)
            .put("paused", state.paused)
            .put("warningThresholdSeconds", state.warningThresholdSeconds)
            .put("currentPackage", state.currentPackage ?: JSONObject.NULL)
            .put(
                "outsideWorkspaceStartedAtMs",
                state.outsideWorkspaceStartedAtMs ?: JSONObject.NULL,
            )
            .put("warnedForCurrentExcursion", state.warnedForCurrentExcursion)
    }

    private fun stateFromJson(json: JSONObject): FocusGuardNativeState {
        val planJson = json.optJSONArray("plan") ?: JSONArray()
        val plan = mutableListOf<FocusGuardPlanBlock>()

        for (index in 0 until planJson.length()) {
            val block = planJson.optJSONObject(index) ?: continue
            val type = block.optString("type", "focus")
            val durationSeconds = block.optInt("durationSeconds", 0)
            if (durationSeconds > 0) {
                plan.add(FocusGuardPlanBlock(type, durationSeconds))
            }
        }

        return FocusGuardNativeState(
            active = json.optBoolean("active", false),
            sessionId = json.optString("sessionId", ""),
            taskName = json.optString("taskName", "Focus"),
            originDevice = json.optString("originDevice", "android"),
            plan = plan,
            currentBlockIndex = json.optInt("currentBlockIndex", 0),
            phase = json.optString("phase", "inactive"),
            deadlineEpochMs = json.optNullableLong("deadlineEpochMs"),
            remainingSeconds = json.optInt("remainingSeconds", 0),
            paused = json.optBoolean("paused", false),
            warningThresholdSeconds =
                json.optInt("warningThresholdSeconds", 30).coerceAtLeast(1),
            currentPackage = json.optNullableString("currentPackage"),
            outsideWorkspaceStartedAtMs =
                json.optNullableLong("outsideWorkspaceStartedAtMs"),
            warnedForCurrentExcursion =
                json.optBoolean("warnedForCurrentExcursion", false),
        )
    }
}

private fun JSONObject.optNullableString(key: String): String? {
    if (!has(key) || isNull(key)) return null
    return optString(key).takeIf { it.isNotBlank() }
}

private fun JSONObject.optNullableLong(key: String): Long? {
    if (!has(key) || isNull(key)) return null
    return optLong(key)
}
