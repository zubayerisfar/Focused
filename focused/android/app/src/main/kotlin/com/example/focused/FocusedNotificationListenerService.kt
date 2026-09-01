package com.example.focused

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class FocusedNotificationListenerService : NotificationListenerService() {
    private val activeKeys = mutableSetOf<String>()

    override fun onListenerConnected() {
        super.onListenerConnected()
        activeKeys.clear()
        try {
            activeNotifications?.forEach { notification ->
                notification.key?.let(activeKeys::add)
            }
        } catch (_: Throwable) {
            // Some OEMs can temporarily reject active-notification access.
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn ?: return
        val packageName = notification.packageName?.trim().orEmpty()
        val key = notification.key?.trim().orEmpty()

        if (packageName.isEmpty() || key.isEmpty() || packageName == this.packageName) {
            return
        }

        // Updates to an already-active notification keep the same key. Count
        // only the first post so progress/media/service notifications cannot
        // inflate the metric by updating continuously.
        if (!activeKeys.add(key)) {
            return
        }

        NotificationEventStore.append(
            context = applicationContext,
            packageName = packageName,
            timestampMillis = notification.postTime.takeIf { it > 0L }
                ?: System.currentTimeMillis(),
            notificationKey = key,
        )
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        sbn?.key?.let(activeKeys::remove)
    }
}
