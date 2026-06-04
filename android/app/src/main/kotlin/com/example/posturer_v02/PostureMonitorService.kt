package com.example.posturer_v02

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

class PostureMonitorService : Service() {
    private var executor: ScheduledExecutorService? = null
    private var lastPostureValue: Boolean? = null
    private var lastTimestampMs: Long? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        startForeground(FOREGROUND_NOTIFICATION_ID, buildForegroundNotification())
        startPolling()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        executor?.shutdownNow()
        executor = null
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    private fun startPolling() {
        if (executor != null) {
            return
        }

        executor = Executors.newSingleThreadScheduledExecutor().also { scheduler ->
            scheduler.scheduleWithFixedDelay(
                { pollLatestPosture() },
                0,
                POLL_INTERVAL_SECONDS,
                TimeUnit.SECONDS,
            )
        }
    }

    private fun pollLatestPosture() {
        try {
            val latest = fetchLatestPosture() ?: return
            val previousValue = lastPostureValue
            val previousTimestamp = lastTimestampMs

            lastPostureValue = latest.isGoodPosture
            lastTimestampMs = latest.timestampMs

            val isNewEvent = previousTimestamp != latest.timestampMs
            val changedGoodToBad = previousValue == true && !latest.isGoodPosture
            if (isNewEvent && changedGoodToBad) {
                showBadPostureNotification()
            }
        } catch (_: Exception) {
            // Keep the foreground service alive through short network/Supabase failures.
        }
    }

    private fun fetchLatestPosture(): PostureEntry? {
        val select = URLEncoder.encode(
            "$TIMESTAMP_COLUMN,$POSTURE_VALUE_COLUMN",
            Charsets.UTF_8.name(),
        )
        val order = URLEncoder.encode("$TIMESTAMP_COLUMN.desc", Charsets.UTF_8.name())
        val url = URL("$SUPABASE_REST_URL/$POSTURE_TABLE?select=$select&order=$order&limit=1")
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 5000
            readTimeout = 5000
            setRequestProperty("apikey", SUPABASE_ANON_KEY)
            setRequestProperty("Authorization", "Bearer $SUPABASE_ANON_KEY")
        }

        return connection.use {
            if (responseCode !in 200..299) {
                null
            } else {
                val body = inputStream.bufferedReader().use { reader -> reader.readText() }
                val rows = JSONArray(body)
                if (rows.length() == 0) {
                    null
                } else {
                    val row = rows.getJSONObject(0)
                    PostureEntry(
                        timestampMs = row.optLong(TIMESTAMP_COLUMN, 0L),
                        isGoodPosture = row.optBoolean(POSTURE_VALUE_COLUMN, false),
                    )
                }
            }
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                MONITOR_CHANNEL_ID,
                "Posture monitoring",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps posture monitoring active while the app is in the background."
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                ALERT_CHANNEL_ID,
                "Posture changes",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Alerts when good posture turns bad."
            },
        )
    }

    private fun buildForegroundNotification() =
        NotificationCompat.Builder(this, MONITOR_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Posturer is monitoring")
            .setContentText("Background posture alerts are active.")
            .setContentIntent(openAppPendingIntent())
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

    private fun showBadPostureNotification() {
        val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Posture changed")
            .setContentText("Your posture changed to bad. Sit upright.")
            .setContentIntent(openAppPendingIntent())
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        getSystemService(NotificationManager::class.java)
            .notify(BAD_POSTURE_NOTIFICATION_ID, notification)
    }

    private fun openAppPendingIntent(): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        } ?: Intent(this, MainActivity::class.java)

        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun <T> HttpURLConnection.use(block: HttpURLConnection.() -> T): T {
        try {
            return block()
        } finally {
            disconnect()
        }
    }

    private data class PostureEntry(
        val timestampMs: Long,
        val isGoodPosture: Boolean,
    )

    companion object {
        private const val POLL_INTERVAL_SECONDS = 2L
        private const val FOREGROUND_NOTIFICATION_ID = 4200
        private const val BAD_POSTURE_NOTIFICATION_ID = 4201
        private const val MONITOR_CHANNEL_ID = "posture_monitoring"
        private const val ALERT_CHANNEL_ID = "posture_changes"
        private const val SUPABASE_REST_URL = "https://lkkjiejhaltupvsxbfhi.supabase.co/rest/v1"
        private const val SUPABASE_ANON_KEY =
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxra2ppZWpoYWx0dXB2c3hiZmhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3NTYyNDIsImV4cCI6MjA5MTMzMjI0Mn0.GfePO510fNsMm3U1EGdkh_ZhLokWrJFvwtatk8hVROA"
        private const val POSTURE_TABLE = "posture_events"
        private const val POSTURE_VALUE_COLUMN = "is_posture_correct"
        private const val TIMESTAMP_COLUMN = "timestamp_ms"
    }
}
