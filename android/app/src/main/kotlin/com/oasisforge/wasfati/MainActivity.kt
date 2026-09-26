package com.oasisforge.wasfati

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // IMP-8, Decision 19: "Report a mistake" opens the user's own mail
        // app with a draft they read and send themselves
        // (lib/services/mail.dart). ACTION_SENDTO with a mailto: link is
        // answered only by mail apps; it needs no permission, and no
        // <queries> entry because nothing is resolved before it starts.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.oasisforge.wasfati/mail",
        ).setMethodCallHandler { call, result ->
            if (call.method != "compose") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val to = call.argument<String>("to") ?: ""
            val subject = Uri.encode(call.argument<String>("subject") ?: "")
            val body = Uri.encode(call.argument<String>("body") ?: "")
            val intent = Intent(
                Intent.ACTION_SENDTO,
                Uri.parse("mailto:$to?subject=$subject&body=$body"),
            )
            try {
                startActivity(intent)
                result.success(true)
            } catch (e: ActivityNotFoundException) {
                result.success(false)
            }
        }
        // LOOK-13: the recipe page's source chip opens the recipe's own
        // link in the browser (lib/services/links.dart). ACTION_VIEW for an
        // http(s) link only: no permission, and no <queries> entry, since
        // nothing is resolved before it starts.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.oasisforge.wasfati/links",
        ).setMethodCallHandler { call, result ->
            if (call.method != "open") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val uri = Uri.parse(call.argument<String>("url") ?: "")
            if (uri.scheme != "http" && uri.scheme != "https") {
                result.success(false)
                return@setMethodCallHandler
            }
            val intent = Intent(Intent.ACTION_VIEW, uri)
                .addCategory(Intent.CATEGORY_BROWSABLE)
            try {
                startActivity(intent)
                result.success(true)
            } catch (e: ActivityNotFoundException) {
                result.success(false)
            }
        }
        // PAY-11: "Manage or cancel" opens Google Play's own page for this
        // app's subscription (lib/services/play_store.dart), where it's
        // changed or cancelled. An ACTION_VIEW intent for Play's https link:
        // no permission, and no <queries> entry, since nothing is resolved
        // before it starts. Only this one page, built here from the app's
        // own package name.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.oasisforge.wasfati/store",
        ).setMethodCallHandler { call, result ->
            if (call.method != "openSubscription") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val sku = Uri.encode(call.argument<String>("sku") ?: "")
            val intent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse(
                    "https://play.google.com/store/account/subscriptions" +
                        "?sku=$sku&package=$packageName",
                ),
            )
            try {
                startActivity(intent)
                result.success(true)
            } catch (e: ActivityNotFoundException) {
                result.success(false)
            }
        }
    }
}
