package com.kisidencom.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AppimHomeWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val PREF_NAME = "appim_widget_prefs"
        private const val KEY_UNREAD_NOTIFICATIONS = "unread_notifications"

        fun forceUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, AppimHomeWidgetProvider::class.java)
            val widgetIds = manager.getAppWidgetIds(componentName)
            if (widgetIds.isEmpty()) return

            val provider = AppimHomeWidgetProvider()
            provider.onUpdate(context, manager, widgetIds)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { widgetId ->
            appWidgetManager.updateAppWidget(
                widgetId,
                buildRemoteViews(context),
            )
        }
    }

    private fun buildRemoteViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.appim_home_widget)

        val lastUpdate = SimpleDateFormat("dd.MM HH:mm", Locale.getDefault())
            .format(Date())
        views.setTextViewText(
            R.id.tvWidgetSubtitle,
            "Hizli erisim • $lastUpdate",
        )

        val unreadCount = context
            .getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .getInt(KEY_UNREAD_NOTIFICATIONS, 0)
            .coerceAtLeast(0)
        val badgeText = if (unreadCount > 99) "99+" else unreadCount.toString()
        views.setTextViewText(R.id.tvNotifBadge, badgeText)
        views.setViewVisibility(
            R.id.tvNotifBadge,
            if (unreadCount > 0) View.VISIBLE else View.GONE,
        )

        views.setOnClickPendingIntent(
            R.id.btnNotifications,
            buildDeepLinkPendingIntent(
                context,
                "open_notifications",
                "https://kisiden.com/bildirimler",
            ),
        )

        views.setOnClickPendingIntent(
            R.id.btnFavorites,
            buildDeepLinkPendingIntent(
                context,
                "open_favorites",
                "https://kisiden.com/favoriler",
            ),
        )
        views.setOnClickPendingIntent(
            R.id.btnSearch,
            buildDeepLinkPendingIntent(
                context,
                "open_listings",
                "https://kisiden.com/ilanlar",
            ),
        )
        views.setOnClickPendingIntent(
            R.id.btnPost,
            buildDeepLinkPendingIntent(
                context,
                "open_post",
                "https://kisiden.com/ilan-ver",
            ),
        )

        // Kartin herhangi bir yerine tiklaninca da uygulamayi acar.
        views.setOnClickPendingIntent(
            R.id.widgetRoot,
            buildDeepLinkPendingIntent(
                context,
                "open_widget",
                "https://kisiden.com/ilanlar",
            ),
        )

        return views
    }

    private fun buildDeepLinkPendingIntent(
        context: Context,
        source: String,
        url: String,
    ): PendingIntent {
        val launchIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            setPackage(context.packageName)
            putExtra("widget_source", source)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        return PendingIntent.getActivity(
            context,
            source.hashCode(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
