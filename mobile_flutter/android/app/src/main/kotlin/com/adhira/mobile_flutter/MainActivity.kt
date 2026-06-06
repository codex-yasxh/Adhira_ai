package com.adhira.mobile_flutter

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.telephony.SmsManager
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.adhira.mobile_flutter/sms"
        private const val TAG = "SOS"
        private const val RESULT_TIMEOUT_SECONDS = 15L
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSms" -> {
                        val phones = call.argument<List<String>>("phones") ?: emptyList()
                        val message = call.argument<String>("message") ?: ""
                        handleSendSms(phones, message, result)
                    }
                    "hasSim" -> result.success(hasSim())
                    else -> result.notImplemented()
                }
            }
    }

    // ─── SIM check ───────────────────────────────────────────────────────────

    private fun hasSim(): Boolean {
        val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        return tm?.simState == TelephonyManager.SIM_STATE_READY
    }

    // ─── SMS sending ─────────────────────────────────────────────────────────

    private fun getSmsManager(): SmsManager {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
    }

    private fun handleSendSms(
        phones: List<String>,
        message: String,
        result: MethodChannel.Result,
    ) {
        if (phones.isEmpty()) {
            result.error("NO_CONTACTS", "No contacts provided", null)
            return
        }

        Log.d(TAG, "SMS sending started — ${phones.size} contact(s)")

        // Run off the main thread so the CountDownLatch doesn't block UI
        Thread {
            val contactResults = ConcurrentHashMap<String, String>()
            val latch = CountDownLatch(phones.size)
            val sms = getSmsManager()
            val timestamp = System.currentTimeMillis()

            val receivers = mutableListOf<BroadcastReceiver>()

            for (phone in phones) {
                val action = "ADHIRA_SOS_SENT_${phone}_$timestamp"

                val sentPI = PendingIntent.getBroadcast(
                    this,
                    (phone + timestamp).hashCode(),
                    Intent(action),
                    PendingIntent.FLAG_UPDATE_CURRENT or
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                                PendingIntent.FLAG_IMMUTABLE else 0,
                )

                val receiver = object : BroadcastReceiver() {
                    override fun onReceive(ctx: Context?, intent: Intent?) {
                        val status = when (resultCode) {
                            Activity.RESULT_OK -> {
                                Log.d(TAG, "SMS sent to $phone")
                                "success"
                            }
                            SmsManager.RESULT_ERROR_NO_SERVICE -> {
                                Log.w(TAG, "SMS failed to $phone — no service")
                                "no_service"
                            }
                            SmsManager.RESULT_ERROR_RADIO_OFF -> {
                                Log.w(TAG, "SMS failed to $phone — radio off")
                                "radio_off"
                            }
                            SmsManager.RESULT_ERROR_NULL_PDU -> {
                                Log.w(TAG, "SMS failed to $phone — null PDU")
                                "null_pdu"
                            }
                            else -> {
                                Log.w(TAG, "SMS failed to $phone — generic failure ($resultCode)")
                                "failed"
                            }
                        }
                        contactResults[phone] = status
                        latch.countDown()
                        try {
                            unregisterReceiver(this)
                        } catch (_: Exception) {}
                    }
                }

                receivers.add(receiver)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(receiver, IntentFilter(action), RECEIVER_NOT_EXPORTED)
                } else {
                    registerReceiver(receiver, IntentFilter(action))
                }

                try {
                    val parts = sms.divideMessage(message)
                    Log.d(TAG, "Sending to $phone — ${parts.size} part(s)")

                    if (parts.size == 1) {
                        sms.sendTextMessage(phone, null, message, sentPI, null)
                    } else {
                        val sentPIs = ArrayList<PendingIntent?>(parts.size)
                        sentPIs.add(sentPI)
                        for (i in 1 until parts.size) sentPIs.add(null)
                        sms.sendMultipartTextMessage(phone, null, parts, sentPIs, null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "SmsManager exception for $phone: ${e.message}")
                    contactResults[phone] = "failed"
                    latch.countDown()
                    try {
                        unregisterReceiver(receiver)
                    } catch (_: Exception) {}
                }
            }

            // Wait for all broadcast results (max 15 seconds)
            val completed = latch.await(RESULT_TIMEOUT_SECONDS, TimeUnit.SECONDS)

            if (!completed) {
                Log.w(TAG, "Timeout — some SMS results not received")
                // Mark any that didn't report back
                for (phone in phones) {
                    contactResults.putIfAbsent(phone, "timeout")
                }
                // Unregister any remaining receivers
                for (r in receivers) {
                    try { unregisterReceiver(r) } catch (_: Exception) {}
                }
            }

            val resultList = phones.map { phone ->
                mapOf("phone" to phone, "status" to (contactResults[phone] ?: "unknown"))
            }

            Log.d(TAG, "All results: $resultList")

            // Post result back to main thread
            runOnUiThread {
                result.success(resultList)
            }
        }.start()
    }
}
