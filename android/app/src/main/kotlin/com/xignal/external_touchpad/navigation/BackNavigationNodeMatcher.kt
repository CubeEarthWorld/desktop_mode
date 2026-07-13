package com.xignal.external_touchpad.navigation

import java.util.Locale

/**
 * Identifies the Back control exposed by a display's SystemUI accessibility window.
 *
 * Resource IDs are useful on AOSP, while the system action label keeps the match working on
 * OEM SystemUI implementations and in non-English locales.
 */
internal object BackNavigationNodeMatcher {
    fun matches(
        viewIdResourceName: String?,
        contentDescription: CharSequence?,
        text: CharSequence?,
        systemBackLabel: CharSequence?,
    ): Boolean {
        if (matchesResourceId(viewIdResourceName)) return true

        val label = normalize(systemBackLabel)
        if (label.isNotEmpty()) {
            if (matchesLabel(contentDescription, label) || matchesLabel(text, label)) return true
        }

        // getSystemActions() should normally provide the localized label. Keep an English
        // fallback for OEMs that omit it from the action list.
        return matchesLabel(contentDescription, "back") || matchesLabel(text, "back")
    }

    private fun matchesResourceId(viewIdResourceName: String?): Boolean {
        val resourceName = viewIdResourceName
            ?.substringAfterLast('/')
            ?.lowercase(Locale.ROOT)
            .orEmpty()
        return resourceName == "back" ||
            resourceName == "backbutton" ||
            resourceName == "back_button" ||
            resourceName.startsWith("back_") ||
            resourceName.endsWith("_back")
    }

    private fun matchesLabel(value: CharSequence?, normalizedLabel: String): Boolean {
        val candidate = normalize(value)
        if (candidate == normalizedLabel) return true

        val words = value
            ?.toString()
            ?.lowercase(Locale.ROOT)
            ?.split(Regex("[^\\p{L}\\p{N}]+"))
            ?.filter(String::isNotEmpty)
            .orEmpty()
        if (normalizedLabel in words) return true

        // CJK accessibility descriptions commonly append the equivalent of "button" without a
        // separator (for example, 戻るボタン). Do not use the same prefix rule for plain ASCII:
        // it would incorrectly classify words such as "background" as Back.
        val containsNonAscii = normalizedLabel.any { it.code > 0x7f }
        if (containsNonAscii &&
            (candidate.startsWith(normalizedLabel) || candidate.endsWith(normalizedLabel))
        ) {
            return true
        }

        return candidate == "${normalizedLabel}button" ||
            candidate == "${normalizedLabel}key" ||
            candidate == "go$normalizedLabel" ||
            candidate == "navigate$normalizedLabel"
    }

    private fun normalize(value: CharSequence?): String = value
        ?.toString()
        ?.trim()
        ?.lowercase(Locale.ROOT)
        ?.filter(Char::isLetterOrDigit)
        .orEmpty()
}
