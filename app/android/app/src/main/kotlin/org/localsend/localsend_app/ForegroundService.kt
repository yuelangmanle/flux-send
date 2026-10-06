package org.localsend.localsend_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

/**
 * 前台服务：经典蓝牙 RFCOMM 监听/传输期间保活，避免息屏后 Doze 冻结导致断连。
 * 通过 `startForegroundService` 启动，停止蓝牙时由 Flutter 侧调用 stop 方法结束。
 */
class ForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "flux_foreground"
        const val NOTIFICATION_ID = 4711
        const val ACTION_START = "org.localsend.localsend_app.START"
        const val ACTION_STOP = "org.localsend.localsend_app.STOP"

        fun start(context: Context) {
            val intent = Intent(context, ForegroundService::class.java).setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.startService(Intent(context, ForegroundService::class.java).setAction(ACTION_STOP))
        }
    }

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Flux 传输", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(NOTIFICATION_ID, buildNotification())
        return START_STICKY
    }

    private fun buildNotification(): Notification {
        val title = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) "Flux 传输服务运行中" else "Flux"
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText("经典蓝牙通道保持连接，息屏后不会断开")
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setOngoing(true)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
