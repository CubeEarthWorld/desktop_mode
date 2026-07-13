package com.xignal.external_touchpad.apps

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.SystemClock
import android.util.Log
import android.util.LruCache
import com.xignal.external_touchpad.HomeAppInfo
import java.io.ByteArrayOutputStream
import kotlin.math.roundToInt

private const val TAG = "AppCatalog"
private const val INSTALLED_APPS_CACHE_TTL_MS = 5 * 60 * 1000L
private const val APP_ICON_MAX_SIZE_PX = 96
private const val APP_ICON_CACHE_BYTES = 4 * 1024 * 1024

/**
 * Read-only catalog of launchable applications and their icons.
 *
 * PackageManager queries, list caching, and bitmap conversion are deliberately kept out of the
 * session coordinator. Both HOME and LAUNCHER lists share the same mapping pipeline.
 */
class AppCatalog(context: Context) {
    private val appContext = context.applicationContext
    private val packageManager = appContext.packageManager
    private val installedAppsCacheLock = Any()

    @Volatile private var installedAppsCache: List<HomeAppInfo>? = null
    @Volatile private var installedAppsCachedAtMs: Long = 0L

    private val appIconCache = object : LruCache<String, ByteArray>(APP_ICON_CACHE_BYTES) {
        override fun sizeOf(key: String, value: ByteArray): Int = value.size
    }

    fun getHomeApps(): List<HomeAppInfo> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        return queryActivities(
            intent = intent,
            excludedPackages = SYSTEM_ONLY_HOME_PACKAGES,
            includeIcons = true,
        )
    }

    fun getInstalledApps(): List<HomeAppInfo> {
        val now = SystemClock.elapsedRealtime()
        installedAppsCache?.takeIf {
            now - installedAppsCachedAtMs < INSTALLED_APPS_CACHE_TTL_MS
        }?.let { return it }

        return synchronized(installedAppsCacheLock) {
            val refreshedAt = SystemClock.elapsedRealtime()
            installedAppsCache?.takeIf {
                refreshedAt - installedAppsCachedAtMs < INSTALLED_APPS_CACHE_TTL_MS
            } ?: loadInstalledApps().also {
                installedAppsCache = it
                installedAppsCachedAtMs = refreshedAt
            }
        }
    }

    fun getAppIcon(packageName: String, activityName: String): ByteArray? {
        val key = "$packageName/$activityName"
        appIconCache.get(key)?.let { return it }
        val activityInfo = resolveActivityInfo(packageName, activityName) ?: return null
        return loadIconBytes(activityInfo)?.also { appIconCache.put(key, it) }
    }

    fun resolveActivityInfo(packageName: String, activityName: String): ActivityInfo? = try {
        packageManager.getActivityInfo(
            ComponentName(packageName, activityName),
            PackageManager.GET_META_DATA,
        )
    } catch (_: PackageManager.NameNotFoundException) {
        null
    }

    private fun loadInstalledApps(): List<HomeAppInfo> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return queryActivities(
            intent = intent,
            excludedPackages = setOf(appContext.packageName),
            includeIcons = false,
        ).sortedBy { it.label.lowercase() }
    }

    private fun queryActivities(
        intent: Intent,
        excludedPackages: Set<String>,
        includeIcons: Boolean,
    ): List<HomeAppInfo> =
        packageManager.queryIntentActivities(intent, PackageManager.MATCH_ALL)
            .mapNotNull { resolveInfo ->
                val activityInfo = resolveInfo.activityInfo ?: return@mapNotNull null
                if (activityInfo.packageName in excludedPackages) return@mapNotNull null
                HomeAppInfo(
                    packageName = activityInfo.packageName,
                    activityName = activityInfo.name,
                    label = resolveInfo.loadLabel(packageManager).toString(),
                    iconPng = if (includeIcons) loadIconBytes(activityInfo) else null,
                )
            }
            .distinctBy { it.packageName to it.activityName }

    private fun loadIconBytes(activityInfo: ActivityInfo): ByteArray? = try {
        val drawable = activityInfo.loadIcon(packageManager) ?: return null
        val bitmap = drawableToBitmap(drawable)
        ByteArrayOutputStream().use { stream ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        }
    } catch (error: Exception) {
        Log.w(TAG, "Unable to load icon for ${activityInfo.packageName}", error)
        null
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            val source = drawable.bitmap
            val largestSide = maxOf(source.width, source.height)
            if (largestSide <= APP_ICON_MAX_SIZE_PX) return source
            val scale = APP_ICON_MAX_SIZE_PX.toFloat() / largestSide
            return Bitmap.createScaledBitmap(
                source,
                (source.width * scale).roundToInt().coerceAtLeast(1),
                (source.height * scale).roundToInt().coerceAtLeast(1),
                true,
            )
        }

        val intrinsicWidth = drawable.intrinsicWidth.takeIf { it > 0 } ?: APP_ICON_MAX_SIZE_PX
        val intrinsicHeight = drawable.intrinsicHeight.takeIf { it > 0 } ?: APP_ICON_MAX_SIZE_PX
        val scale = minOf(
            1f,
            APP_ICON_MAX_SIZE_PX.toFloat() / maxOf(intrinsicWidth, intrinsicHeight),
        )
        val width = (intrinsicWidth * scale).roundToInt().coerceAtLeast(1)
        val height = (intrinsicHeight * scale).roundToInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    private companion object {
        val SYSTEM_ONLY_HOME_PACKAGES = setOf("com.android.settings")
    }
}
