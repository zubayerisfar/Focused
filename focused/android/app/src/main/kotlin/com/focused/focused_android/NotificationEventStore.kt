package com.focused.focused_android

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object NotificationEventStore {
    private const val PREFS_NAME = "focused_notification_events"
    private const val EVENTS_KEY = "events"
    private const val MAX_EVENTS = 5000
    private const val RETENTION_MILLIS = 14L * 24L * 60L * 60L * 1000L

    data class Event(
        val packageName: String,
        val timestampMillis: Long,
        val notificationKey: String,
    ) {
        fun toMap(): Map<String, Any> = mapOf(
            "packageName" to packageName,
            "timestampMillis" to timestampMillis,
            "notificationKey" to notificationKey,
        )
    }

    @Synchronized
    fun append(
        context: Context,
        packageName: String,
        timestampMillis: Long,
        notificationKey: String,
    ) {
        if (packageName.isBlank() || notificationKey.isBlank()) return

        val cutoff = timestampMillis - RETENTION_MILLIS
        val events = load(context)
            .filter { it.timestampMillis >= cutoff }
            .toMutableList()

        events.add(
            Event(
                packageName = packageName,
                timestampMillis = timestampMillis,
                notificationKey = notificationKey,
            ),
        )

        val trimmed = if (events.size > MAX_EVENTS) {
            events.takeLast(MAX_EVENTS)
        } else {
            events
        }
        save(context, trimmed)
    }

    @Synchronized
    fun query(
        context: Context,
        startMillis: Long,
        endMillis: Long,
    ): List<Map<String, Any>> {
        if (endMillis <= startMillis) return emptyList()
        return load(context)
            .asSequence()
            .filter { it.timestampMillis >= startMillis && it.timestampMillis < endMillis }
            .sortedBy { it.timestampMillis }
            .map { it.toMap() }
            .toList()
    }

    @Synchronized
    fun pruneBefore(context: Context, cutoffMillis: Long) {
        save(
            context,
            load(context).filter { it.timestampMillis >= cutoffMillis },
        )
    }

    private fun load(context: Context): List<Event> {
        val raw = context
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(EVENTS_KEY, null)
            ?: return emptyList()

        return try {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    val packageName = item.optString("packageName")
                    val notificationKey = item.optString("notificationKey")
                    val timestampMillis = item.optLong("timestampMillis", -1L)
                    if (packageName.isBlank() ||
                        notificationKey.isBlank() ||
                        timestampMillis < 0L
                    ) {
                        continue
                    }
                    add(Event(packageName, timestampMillis, notificationKey))
                }
            }
        } catch (_: Throwable) {
            emptyList()
        }
    }

    private fun save(context: Context, events: List<Event>) {
        val array = JSONArray()
        for (event in events) {
            array.put(
                JSONObject()
                    .put("packageName", event.packageName)
                    .put("timestampMillis", event.timestampMillis)
                    .put("notificationKey", event.notificationKey),
            )
        }

        context
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(EVENTS_KEY, array.toString())
            .apply()
    }
}
