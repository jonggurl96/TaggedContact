package com.contact.tagged.tagged_contact

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.CallLog
import android.provider.ContactsContract
import android.provider.ContactsContract.CommonDataKinds.Phone
import android.provider.OpenableColumns
import android.provider.Settings
import android.provider.Telephony
import android.util.AtomicFile
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.FileNotFoundException
import java.util.UUID
import java.util.concurrent.Executors

class DeviceBridge(private val activity: MainActivity) : MethodChannel.MethodCallHandler {
    companion object {
        private const val PAGE_SIZE = 100
        private const val MESSAGE_LIMIT = 50
        private const val MAX_IMAGE_EDGE = 1920
        private const val MAX_IMAGE_BYTES = 25L * 1024 * 1024
    }

    private val resolver get() = activity.contentResolver
    // 조회와 파일 쓰기를 UI 스레드 밖에서 순서대로 실행한다.
    private val executor = Executors.newSingleThreadExecutor()
    private var channel: MethodChannel? = null
    private var permissionResult: MethodChannel.Result? = null
    private var pickerResult: MethodChannel.Result? = null
    private var pickerKind: String? = null
    private val stateFile get() = AtomicFile(File(activity.filesDir, "tagged_contact.json"))

    private val permissionLauncher = activity.registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        permissionResult?.success(granted)
        permissionResult = null
    }

    private val documentLauncher = activity.registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        val result = pickerResult
        val kind = pickerKind
        pickerResult = null
        pickerKind = null
        if (result != null) {
            if (uri == null) {
                result.success(null)
            } else {
                background(result) {
                    if (kind == "background") importBackground(uri) else linkRecording(uri)
                }
            }
        }
    }

    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "tagged_contact/device").also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "loadState" -> background(result) {
                    if (stateFile.baseFile.exists() || File(activity.filesDir, "tagged_contact.json.bak").exists()) {
                        stateFile.openRead().bufferedReader(Charsets.UTF_8).use { it.readText() }
                    } else {
                        null
                    }
                }
                "saveState" -> background(result) {
                    val json = requireNotNull(call.argument<String>("json"))
                    val parsed = JSONObject(json)
                    require(parsed.getInt("version") == 1)
                    // AtomicFile은 중단된 쓰기로 기존 태그가 손상되지 않게 한다.
                    val file = stateFile
                    val stream = file.startWrite()
                    try {
                        stream.write(json.toByteArray(Charsets.UTF_8))
                        file.finishWrite(stream)
                    } catch (error: Exception) {
                        file.failWrite(stream)
                        throw error
                    }
                    runCatching { cleanUnusedBackgrounds(parsed) }
                    null
                }
                "permissions" -> result.success(mapOf(
                    "contacts" to hasPermission(Manifest.permission.READ_CONTACTS),
                    "calls" to hasPermission(Manifest.permission.READ_CALL_LOG),
                    "sms" to hasPermission(Manifest.permission.READ_SMS)
                ))
                "requestPermission" -> requestPermission(call, result)
                "contacts" -> background(result) { readContacts() }
                "calls" -> background(result) { readCalls(offset = offset(call)) }
                "history" -> background(result) {
                    readCalls(number = phone(call), offset = offset(call))
                }
                "messages" -> background(result) { readMessages(phone(call)) }
                "dial" -> launch(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", phone(call), null)), result)
                "composeMessage" -> launch(Intent(Intent.ACTION_SENDTO, Uri.fromParts("smsto", phone(call), null)), result)
                "openMessage" -> openMessage(call, result)
                "insertContact" -> launch(Intent(Intent.ACTION_INSERT).apply {
                    type = ContactsContract.RawContacts.CONTENT_TYPE
                    putExtra(ContactsContract.Intents.Insert.PHONE, phone(call))
                }, result)
                "openSettings" -> launch(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", activity.packageName, null)), result)
                "pickBackground" -> pickDocument("background", result)
                "pickRecording" -> pickDocument("recording", result)
                "playRecording" -> {
                    val uri = Uri.parse(requireNotNull(call.argument<String>("uri")))
                    require(uri.scheme == "content")
                    // 선택한 문서의 읽기 권한만 재생 앱에 일시적으로 전달한다.
                    resolver.openAssetFileDescriptor(uri, "r")?.close()
                        ?: throw FileNotFoundException()
                    launch(Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "audio/*")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }, result)
                }
                else -> result.notImplemented()
            }
        } catch (_: ActivityNotFoundException) {
            result.error("NO_APP", "이 작업을 실행할 앱이 기기에 없어요.", null)
        } catch (_: SecurityException) {
            result.error("PERMISSION", "접근 권한이 없어요. 기기 설정에서 권한을 확인해 주세요.", null)
        } catch (_: Exception) {
            result.error("DEVICE_ERROR", "작업을 완료하지 못했어요. 파일이나 기기 상태를 확인해 주세요.", null)
        }
    }

    private fun background(result: MethodChannel.Result, task: () -> Any?) {
        executor.execute {
            try {
                val value = task()
                activity.runOnUiThread { result.success(value) }
            } catch (_: SecurityException) {
                activity.runOnUiThread {
                    result.error("PERMISSION", "접근 권한이 없어요. 기기 설정에서 권한을 확인해 주세요.", null)
                }
            } catch (_: Exception) {
                activity.runOnUiThread {
                    result.error("DEVICE_ERROR", "기기 데이터를 처리하지 못했어요. 다시 시도해 주세요.", null)
                }
            }
        }
    }

    private fun hasPermission(permission: String) =
        activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun requirePermission(permission: String) {
        if (!hasPermission(permission)) throw SecurityException()
    }

    private fun requestPermission(call: MethodCall, result: MethodChannel.Result) {
        val permission = when (call.argument<String>("kind")) {
            "contacts" -> Manifest.permission.READ_CONTACTS
            "calls" -> Manifest.permission.READ_CALL_LOG
            "sms" -> Manifest.permission.READ_SMS
            else -> throw IllegalArgumentException()
        }
        if (hasPermission(permission)) {
            result.success(true)
        } else if (permissionResult != null) {
            result.error("BUSY", "진행 중인 권한 요청을 먼저 완료해 주세요.", null)
        } else {
            permissionResult = result
            try {
                permissionLauncher.launch(permission)
            } catch (error: Exception) {
                permissionResult = null
                throw error
            }
        }
    }

    private fun readContacts(): List<Map<String, Any>> {
        requirePermission(Manifest.permission.READ_CONTACTS)
        val rows = mutableListOf<Map<String, Any>>()
        resolver.query(Phone.CONTENT_URI, arrayOf(Phone.NUMBER, Phone.DISPLAY_NAME_PRIMARY),
            null, null, "${Phone.DISPLAY_NAME_PRIMARY} ASC")?.use { cursor ->
            while (cursor.moveToNext()) {
                rows.add(mapOf("number" to (cursor.getString(0) ?: ""),
                    "name" to (cursor.getString(1) ?: "")))
            }
        }
        return rows
    }

    private fun readCalls(number: String? = null, offset: Int): List<Map<String, Any>> {
        requirePermission(Manifest.permission.READ_CALL_LOG)
        val columns = arrayOf(CallLog.Calls._ID, CallLog.Calls.NUMBER, CallLog.Calls.DATE,
            CallLog.Calls.TYPE, CallLog.Calls.DURATION, CallLog.Calls.NUMBER_PRESENTATION)
        val selection = number?.let { numberSelection(CallLog.Calls.NUMBER, it) }
        val uri = CallLog.Calls.CONTENT_URI.buildUpon()
            .appendQueryParameter("limit", PAGE_SIZE.toString())
            .appendQueryParameter("offset", offset.toString()).build()
        val rows = mutableListOf<Map<String, Any>>()
        resolver.query(uri, columns, selection?.first, selection?.second,
            "${CallLog.Calls.DATE} DESC, ${CallLog.Calls._ID} DESC")?.use { cursor ->
            while (cursor.moveToNext() && rows.size < PAGE_SIZE) {
                val rawNumber = cursor.getString(1) ?: ""
                val visibleNumber = if (cursor.getInt(5) == CallLog.Calls.PRESENTATION_ALLOWED &&
                    isPhone(rawNumber)) rawNumber else ""
                rows.add(mapOf("id" to cursor.getString(0), "number" to visibleNumber,
                    "date" to cursor.getLong(2), "type" to cursor.getInt(3),
                    "duration" to cursor.getLong(4)))
            }
        }
        return rows
    }

    private fun readMessages(number: String): List<Map<String, Any>> {
        requirePermission(Manifest.permission.READ_SMS)
        val selection = numberSelection(Telephony.Sms.ADDRESS, number)
        val rows = mutableListOf<Map<String, Any>>()
        resolver.query(Telephony.Sms.CONTENT_URI,
            arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE,
                Telephony.Sms.TYPE, Telephony.Sms._ID, Telephony.Sms.THREAD_ID),
            "(${selection.first}) AND ${Telephony.Sms.TYPE} IN (1, 2)", selection.second,
            "${Telephony.Sms.DATE} DESC, ${Telephony.Sms._ID} DESC")?.use { cursor ->
            while (cursor.moveToNext() && rows.size < MESSAGE_LIMIT) {
                rows.add(mapOf("number" to (cursor.getString(0) ?: ""),
                    "body" to (cursor.getString(1) ?: "").take(500),
                    "date" to cursor.getLong(2), "type" to cursor.getInt(3),
                    "id" to cursor.getString(4), "threadId" to cursor.getString(5)))
            }
        }
        return rows
    }

    private fun openMessage(call: MethodCall, result: MethodChannel.Result) {
        val number = phone(call)
        val messageId = requireNotNull(call.argument<String>("id")?.toLongOrNull())
        val threadId = requireNotNull(call.argument<String>("threadId")?.toLongOrNull())
        require(messageId > 0 && threadId > 0)
        val smsPackage = Telephony.Sms.getDefaultSmsPackage(activity)
            ?: throw ActivityNotFoundException()

        // 기본 앱 안에서 원문 URI, 대화 URI, 번호 순으로 지원되는 경로를 연다.
        // select_id를 지원하는 메시지 앱은 선택한 문자 위치로 이동한다.
        val intents = listOf(
            Intent(Intent.ACTION_VIEW, ContentUris.withAppendedId(Telephony.Sms.CONTENT_URI, messageId)),
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(ContentUris.withAppendedId(Telephony.Threads.CONTENT_URI, threadId),
                    "vnd.android-dir/mms-sms")
            },
            Intent(Intent.ACTION_SENDTO, Uri.fromParts("smsto", number, null))
        )
        for (intent in intents) {
            intent.setPackage(smsPackage)
            intent.putExtra("thread_id", threadId)
            intent.putExtra("select_id", messageId)
            intent.putExtra("address", number)
            try {
                launch(intent, result)
                return
            } catch (_: ActivityNotFoundException) {
                // 현재 앱이 처리하지 않는 URI만 다음 연결 방식으로 재시도한다.
            }
        }
        throw ActivityNotFoundException()
    }

    private fun normalizePhone(value: String): String {
        var number = value.trim().replace(Regex("[\\s().-]"), "")
        if (number.startsWith("0082")) number = "+82" + number.substring(4)
        if (number.startsWith("+82")) {
            val national = number.substring(3)
            number = if (national.startsWith("0")) national else "0$national"
        }
        return number
    }

    private fun isPhone(value: String) = Regex("^\\+?[0-9]{2,15}$").matches(normalizePhone(value))

    private fun phone(call: MethodCall): String {
        val number = normalizePhone(requireNotNull(call.argument<String>("number")))
        require(isPhone(number))
        return number
    }

    private fun offset(call: MethodCall) = (call.argument<Int>("offset") ?: 0).also { require(it >= 0) }

    private fun numberSelection(column: String, number: String): Pair<String, Array<String>> {
        // 뒤쪽 몇 자리만 비교하지 않아 다른 국가의 번호를 잘못 연결하지 않는다.
        val variants = mutableSetOf(number)
        if (number.startsWith("0")) {
            variants.add("+82${number.substring(1)}")
            variants.add("0082${number.substring(1)}")
            variants.add("+82$number")
        }
        val normalized = "REPLACE(REPLACE(REPLACE(REPLACE(REPLACE($column, ' ', ''), '-', ''), '(', ''), ')', ''), '.', '')"
        return "$normalized IN (${variants.joinToString(",") { "?" }})" to variants.toTypedArray()
    }

    private fun launch(intent: Intent, result: MethodChannel.Result) {
        activity.startActivity(intent)
        result.success(null)
    }

    private fun pickDocument(kind: String, result: MethodChannel.Result) {
        if (pickerResult != null) {
            result.error("BUSY", "열려 있는 파일 선택을 먼저 완료해 주세요.", null)
            return
        }
        pickerResult = result
        pickerKind = kind
        try {
            documentLauncher.launch(arrayOf(if (kind == "background") "image/*" else "audio/*"))
        } catch (error: Exception) {
            pickerResult = null
            pickerKind = null
            throw error
        }
    }

    private fun importBackground(uri: Uri): String {
        require(uri.scheme == "content")
        // 큰 원본은 임시 파일 크기와 디코딩 해상도를 모두 제한한다.
        val source = File.createTempFile("background_", ".tmp", activity.cacheDir)
        var target: File? = null
        try {
            resolver.openInputStream(uri).use { input ->
                requireNotNull(input)
                source.outputStream().use { output ->
                    val buffer = ByteArray(8192)
                    var total = 0L
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        total += count
                        require(total <= MAX_IMAGE_BYTES)
                        output.write(buffer, 0, count)
                    }
                }
            }
            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(source.path, options)
            require(options.outWidth > 0 && options.outHeight > 0)
            options.inSampleSize = 1
            while (maxOf(options.outWidth, options.outHeight) / options.inSampleSize > MAX_IMAGE_EDGE) {
                options.inSampleSize *= 2
            }
            options.inJustDecodeBounds = false
            val bitmap = requireNotNull(BitmapFactory.decodeFile(source.path, options))
            try {
                val directory = File(activity.filesDir, "backgrounds").apply { mkdirs() }
                target = File(directory, "${UUID.randomUUID()}.jpg")
                target.outputStream().use { require(bitmap.compress(Bitmap.CompressFormat.JPEG, 90, it)) }
                return target.absolutePath
            } finally {
                bitmap.recycle()
            }
        } catch (error: Exception) {
            target?.delete()
            throw error
        } finally {
            source.delete()
        }
    }

    private fun linkRecording(uri: Uri): Map<String, String> {
        require(uri.scheme == "content")
        require(resolver.getType(uri)?.startsWith("audio/") == true)
        resolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        var name = "통화 녹음"
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) name = cursor.getString(0) ?: name
        }
        return mapOf("uri" to uri.toString(), "name" to name)
    }

    private fun cleanUnusedBackgrounds(state: JSONObject) {
        // 저장이 끝난 뒤 앱 전용 배경 폴더의 미사용 파일만 정리한다.
        val backgrounds = state.getJSONObject("settings").getJSONObject("backgrounds")
        val retained = backgrounds.keys().asSequence().map { backgrounds.getString(it) }.toSet()
        File(activity.filesDir, "backgrounds").listFiles()?.forEach { file ->
            if (file.absolutePath !in retained && System.currentTimeMillis() - file.lastModified() > 60_000) {
                file.delete()
            }
        }
    }

    fun close() {
        channel?.setMethodCallHandler(null)
        permissionResult?.error("CLOSED", "화면이 닫혔어요. 다시 시도해 주세요.", null)
        pickerResult?.error("CLOSED", "화면이 닫혔어요. 다시 시도해 주세요.", null)
        permissionResult = null
        pickerResult = null
        executor.shutdown()
    }
}
