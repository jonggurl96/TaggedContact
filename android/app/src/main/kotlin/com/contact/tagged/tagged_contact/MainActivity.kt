package com.contact.tagged.tagged_contact

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private val deviceBridge = DeviceBridge(this)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        deviceBridge.attach(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        deviceBridge.close()
        super.onDestroy()
    }
}
