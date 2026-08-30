package com.example.focused

internal data class FocusGuardAttentionResult(
    val outsideWorkspaceStartedAtMs: Long?,
    val warnedForCurrentExcursion: Boolean,
    val shouldWarnNow: Boolean,
)

internal object FocusGuardAttentionRule {
    fun evaluate(
        nowMs: Long,
        monitoringEnabled: Boolean,
        isAllowedWorkspace: Boolean,
        previousOutsideStartedAtMs: Long?,
        previouslyWarned: Boolean,
        warningThresholdSeconds: Int,
    ): FocusGuardAttentionResult {
        if (!monitoringEnabled || isAllowedWorkspace) {
            return FocusGuardAttentionResult(
                outsideWorkspaceStartedAtMs = null,
                warnedForCurrentExcursion = false,
                shouldWarnNow = false,
            )
        }

        val outsideSince = previousOutsideStartedAtMs ?: nowMs
        val thresholdMs = warningThresholdSeconds.coerceAtLeast(1) * 1000L
        val thresholdReached = nowMs - outsideSince >= thresholdMs
        val shouldWarn = thresholdReached && !previouslyWarned

        return FocusGuardAttentionResult(
            outsideWorkspaceStartedAtMs = outsideSince,
            warnedForCurrentExcursion = previouslyWarned || shouldWarn,
            shouldWarnNow = shouldWarn,
        )
    }
}
