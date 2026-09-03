package com.focused.focused_android

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class FocusGuardAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val state = FocusGuardStateStore(context).readState()
        if (state?.active != true || state.paused) {
            return
        }

        val serviceIntent = Intent(context, FocusGuardService::class.java)
            .setAction(FocusGuardService.ACTION_DEADLINE)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
