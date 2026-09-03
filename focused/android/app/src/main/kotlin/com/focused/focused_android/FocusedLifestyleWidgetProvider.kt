package com.focused.focused_android

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews

class FocusedLifestyleWidgetProvider : AppWidgetProvider() {

    companion object {
        const val PREFS_NAME = "focused_appwidget_data"

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, FocusedLifestyleWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            if (appWidgetIds != null && appWidgetIds.isNotEmpty()) {
                val provider = FocusedLifestyleWidgetProvider()
                provider.onUpdate(context, appWidgetManager, appWidgetIds)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val screenTime = prefs.getString("screen_time", "0m screen time") ?: "0m screen time"
        val comparison = prefs.getString("comparison", "Tracking your daily rhythm") ?: "Tracking your daily rhythm"
        val streak = prefs.getString("streak", "🔥 0d streak") ?: "🔥 0d streak"
        val focusHours = prefs.getString("focus_hours", "⏱️ 0h focused") ?: "⏱️ 0h focused"
        val tasksCount = prefs.getInt("tasks_count", 0)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.focused_lifestyle_widget)

            // Header stats
            views.setTextViewText(R.id.tv_screen_time, screenTime)
            views.setTextViewText(R.id.tv_comparison_text, comparison)
            views.setTextViewText(R.id.tv_streak, streak)
            views.setTextViewText(R.id.tv_focus_hours, focusHours)

            // Main widget tap opens app
            val mainIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                data = Uri.parse("focused://today")
            }
            val mainPendingIntent = PendingIntent.getActivity(
                context,
                0,
                mainIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, mainPendingIntent)

            // Start Focus button
            val focusIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                data = Uri.parse("focused://focus/setup")
                putExtra("route", "/focus/setup")
            }
            val focusPendingIntent = PendingIntent.getActivity(
                context,
                1,
                focusIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.btn_start_focus, focusPendingIntent)

            // Add Task button
            val addTaskIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                data = Uri.parse("focused://task/new")
                putExtra("route", "/task/new")
            }
            val addTaskPendingIntent = PendingIntent.getActivity(
                context,
                2,
                addTaskIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.btn_add_task, addTaskPendingIntent)

            // Tasks checklist
            if (tasksCount <= 0) {
                views.setViewVisibility(R.id.tv_no_tasks, View.VISIBLE)
                views.setViewVisibility(R.id.layout_task_1, View.GONE)
                views.setViewVisibility(R.id.layout_task_2, View.GONE)
                views.setViewVisibility(R.id.layout_task_3, View.GONE)
            } else {
                views.setViewVisibility(R.id.tv_no_tasks, View.GONE)

                // Task 1
                bindTaskSlot(
                    context = context,
                    views = views,
                    slotLayoutId = R.id.layout_task_1,
                    checkId = R.id.tv_task_1_check,
                    titleId = R.id.tv_task_1_title,
                    title = prefs.getString("task_1_title", null),
                    isDone = prefs.getBoolean("task_1_done", false),
                    taskId = prefs.getString("task_1_id", null),
                    requestCode = 10,
                )

                // Task 2
                bindTaskSlot(
                    context = context,
                    views = views,
                    slotLayoutId = R.id.layout_task_2,
                    checkId = R.id.tv_task_2_check,
                    titleId = R.id.tv_task_2_title,
                    title = prefs.getString("task_2_title", null),
                    isDone = prefs.getBoolean("task_2_done", false),
                    taskId = prefs.getString("task_2_id", null),
                    requestCode = 11,
                )

                // Task 3
                bindTaskSlot(
                    context = context,
                    views = views,
                    slotLayoutId = R.id.layout_task_3,
                    checkId = R.id.tv_task_3_check,
                    titleId = R.id.tv_task_3_title,
                    title = prefs.getString("task_3_title", null),
                    isDone = prefs.getBoolean("task_3_done", false),
                    taskId = prefs.getString("task_3_id", null),
                    requestCode = 12,
                )
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun bindTaskSlot(
        context: Context,
        views: RemoteViews,
        slotLayoutId: Int,
        checkId: Int,
        titleId: Int,
        title: String?,
        isDone: Boolean,
        taskId: String?,
        requestCode: Int,
    ) {
        if (title.isNullOrEmpty()) {
            views.setViewVisibility(slotLayoutId, View.GONE)
            return
        }

        views.setViewVisibility(slotLayoutId, View.VISIBLE)
        views.setTextViewText(checkId, if (isDone) "✓" else "○")
        views.setTextViewText(titleId, title)

        val taskIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            val taskPath = if (taskId.isNullOrEmpty()) "/task/new" else "/task/$taskId"
            data = Uri.parse("focused:$taskPath")
            putExtra("route", taskPath)
            putExtra("taskId", taskId)
        }
        val taskPendingIntent = PendingIntent.getActivity(
            context,
            requestCode,
            taskIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(slotLayoutId, taskPendingIntent)
    }
}

