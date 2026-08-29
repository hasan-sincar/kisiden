package com.kisidencom.app
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.enableEdgeToEdge
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import me.leolin.shortcutbadger.ShortcutBadger

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CHANNEL = "appim/widget"
        private const val PREF_NAME = "appim_widget_prefs"
        private const val KEY_UNREAD_NOTIFICATIONS = "unread_notifications"
        private const val BADGE_CHANNEL_ID = "appim_badge_sync"
        private const val BADGE_NOTIFICATION_ID = 44117
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        // YENİ: Flutter'ın arka planda eklediği eski 'shortEdges' kodunu ezer ve Android 15'e uyumlu hale getirir
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_DEFAULT
        }

        ensureBadgeChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setUnreadNotificationCount" -> {
                        val count = when (val raw = call.argument<Any>("count")) {
                            is Int -> raw
                            is Long -> raw.toInt()
                            is Double -> raw.toInt()
                            else -> 0
                        }.coerceAtLeast(0)

                        val prefs = getSharedPreferences(PREF_NAME, MODE_PRIVATE)
                        prefs.edit().putInt(KEY_UNREAD_NOTIFICATIONS, count).apply()

                        updateAppIconBadge(count)

                        AppimHomeWidgetProvider.forceUpdate(this)
                        result.success(true)
                    }

                    "refreshHomeWidget" -> {
                        AppimHomeWidgetProvider.forceUpdate(this)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Deep link intent'ini mevcut activity instance'ina yazarak
        // arkaplandan donuste Flutter tarafinin yeni linki okuyabilmesini saglar.
        setIntent(intent)
    }

    private fun updateAppIconBadge(count: Int) {
        try {
            if (count <= 0) {
                ShortcutBadger.removeCount(this)
            } else {
                ShortcutBadger.applyCount(this, count)
            }
        } catch (_: Throwable) {
            // Some launchers ignore ShortcutBadger; fallback below may still work.
        }

        updateBadgeNotification(count)
    }

    private fun ensureBadgeChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(NotificationManager::class.java)
        val existing = manager.getNotificationChannel(BADGE_CHANNEL_ID)
        if (existing != null) {
            return
        }

        val channel = NotificationChannel(
            BADGE_CHANNEL_ID,
            "Unread badge sync",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps launcher badge count in sync with unread notifications."
            setShowBadge(true)
            setSound(null, null)
            enableVibration(false)
            enableLights(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun updateBadgeNotification(count: Int) {
        val notificationManager = NotificationManagerCompat.from(this)
        if (count <= 0) {
            notificationManager.cancel(BADGE_NOTIFICATION_ID)
            return
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = PendingIntent.getActivity(
            this,
            BADGE_NOTIFICATION_ID,
            launchIntent?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, BADGE_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_kisiden_notification)
            .setContentTitle("Kişiden")
            .setContentText("$count okunmamis bildiriminiz var")
            .setNumber(count)
            .setBadgeIconType(NotificationCompat.BADGE_ICON_SMALL)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setSilent(true)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setShowWhen(false)
            .setContentIntent(contentIntent)
            .build()

        try {
            val extraNotification = notification.javaClass.getDeclaredField("extraNotification")
            val extraNotificationObject = extraNotification.get(notification)
            val method = extraNotificationObject.javaClass.getDeclaredMethod("setMessageCount", Int::class.javaPrimitiveType)
            method.invoke(extraNotificationObject, count)
        } catch (_: Throwable) {
            // Xiaomi-specific badge reflection may not exist on every device.
        }

        notificationManager.notify(BADGE_NOTIFICATION_ID, notification)
    }
}
