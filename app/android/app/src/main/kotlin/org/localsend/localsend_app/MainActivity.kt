package org.localsend.localsend_app

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.net.wifi.WifiManager
import android.provider.DocumentsContract
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread


private const val CHANNEL = "org.localsend.localsend_app/localsend"
private const val CLASSIC_BLUETOOTH_EVENTS_CHANNEL = "org.localsend.localsend_app/classic_bluetooth_events"
private const val REQUEST_CODE_PICK_DIRECTORY = 1
private const val REQUEST_CODE_PICK_DIRECTORY_PATH = 2
private const val REQUEST_CODE_PICK_FILE = 3

class MainActivity : FlutterActivity() {
    // 每个 picker 请求码独立保存 Result，避免连续调用时互相覆盖导致 Future 挂死。
    private val pendingResults = mutableMapOf<Int, MethodChannel.Result>()
    private var multicastLock: WifiManager.MulticastLock? = null
    private lateinit var classicBluetoothBridge: ClassicBluetoothBridge

    // Overriding the static methods we need from the Java class, as described
    // in the documentation of `FlutterActivity.NewEngineIntentBuilder`
    companion object {
        fun withNewEngine(): NewEngineIntentBuilder {
            return NewEngineIntentBuilder(MainActivity::class.java)
        }

        fun createDefaultIntent(launchContext: Context): Intent {
            return withNewEngine().build(launchContext)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        classicBluetoothBridge = ClassicBluetoothBridge(this)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CLASSIC_BLUETOOTH_EVENTS_CHANNEL
        ).setStreamHandler(classicBluetoothBridge)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            if (classicBluetoothBridge.handleMethodCall(call, result)) {
                return@setMethodCallHandler
            }

            when (call.method) {
                "pickDirectory" -> {
                    pendingResults[REQUEST_CODE_PICK_DIRECTORY] = result
                    openDirectoryPicker(REQUEST_CODE_PICK_DIRECTORY)
                }

                "pickFiles" -> {
                    pendingResults[REQUEST_CODE_PICK_FILE] = result
                    openFilePicker()
                }

                "pickDirectoryPath" -> {
                    pendingResults[REQUEST_CODE_PICK_DIRECTORY_PATH] = result
                    openDirectoryPicker(REQUEST_CODE_PICK_DIRECTORY_PATH)
                }

                "createDirectory" -> handleCreateDirectory(call, result)

                "openContentUri" -> {
                    openUri(context, call.argument<String>("uri")!!)
                    result.success(null)
                }

                "openGallery" -> {
                    openGallery()
                    result.success(null)
                }

                "isAnimationsEnabled" -> {
                    result.success(isAnimationsEnabled())
                }

                "acquireMulticastLock" -> {
                    result.success(acquireMulticastLock())
                }

                "releaseMulticastLock" -> {
                    releaseMulticastLock()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        if (::classicBluetoothBridge.isInitialized) {
            classicBluetoothBridge.stop()
        }
        releaseMulticastLock()
        // 回收所有挂起的 picker Result，防止调用方 Future 永久挂起。
        for ((_, result) in pendingResults) {
            result.error("CANCELED", "Activity destroyed", null)
        }
        pendingResults.clear()
        super.onDestroy()
    }

    private fun isAnimationsEnabled() : Boolean {
        return Settings.Global.getFloat(this.getContentResolver(),
            Settings.Global.ANIMATOR_DURATION_SCALE, 1.0f) != 0.0f;
    }

    private fun acquireMulticastLock(): Boolean {
        return try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val lock = multicastLock ?: wifiManager.createMulticastLock("FluxMulticastLock").also {
                it.setReferenceCounted(false)
                multicastLock = it
            }
            if (!lock.isHeld) {
                lock.acquire()
            }
            true
        } catch (e: Exception) {
            Log.w("FluxMulticast", "Could not acquire multicast lock", e)
            false
        }
    }

    private fun releaseMulticastLock() {
        try {
            val lock = multicastLock
            if (lock?.isHeld == true) {
                lock.release()
            }
        } catch (e: Exception) {
            Log.w("FluxMulticast", "Could not release multicast lock", e)
        }
    }

    private fun openDirectoryPicker(requestCode: Int) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        intent.addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        )
        startActivityForResult(intent, requestCode)
    }

    private fun openFilePicker() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            putExtra("multi-pick", true)
            type = "*/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        startActivityForResult(intent, REQUEST_CODE_PICK_FILE)
    }

    @SuppressLint("WrongConstant")
    @Override
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode == Activity.RESULT_CANCELED) {
            pendingResults.remove(requestCode)?.error("CANCELED", "Canceled", null)
            return
        }

        if (resultCode != Activity.RESULT_OK || data == null) {
            pendingResults.remove(requestCode)?.error("Error $resultCode", "Failed to access directory or file", null)
            return
        }

        when (requestCode) {
            REQUEST_CODE_PICK_DIRECTORY -> {
                val uri: Uri? = data.data
                val takeFlags: Int =
                    data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                if (uri != null) {
                    takePersistableDirectoryPermission(uri, takeFlags)

                    // SAF 递归扫描是阻塞的 ContentResolver 查询，移到后台线程避免大目录 ANR。
                    thread {
                        val files = mutableListOf<FileInfo>()
                        listFiles(uri, files)
                        runOnUiThread {
                            pendingResults.remove(requestCode)?.success(PickDirectoryResult(uri.toString(), files).toMap())
                        }
                    }
                } else {
                    pendingResults.remove(requestCode)?.error("Error", "Failed to access directory", null)
                }
            }

            REQUEST_CODE_PICK_DIRECTORY_PATH -> {
                val uri: Uri? = data.data
                val takeFlags: Int =
                    data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                if (uri != null) {
                    takePersistableDirectoryPermission(uri, takeFlags)
                    pendingResults.remove(requestCode)?.success(uri.toString())
                } else {
                    pendingResults.remove(requestCode)?.error("Error", "Failed to access directory", null)
                }
            }

            REQUEST_CODE_PICK_FILE -> {
                val uriList: List<Uri> = when {
                    data.clipData != null -> {
                        val clipData = data.clipData
                        val uris = mutableListOf<Uri>()
                        for (i in 0 until clipData!!.itemCount) {
                            uris.add(clipData.getItemAt(i).uri)
                        }
                        uris
                    }

                    data.data != null -> listOf(data.data!!)
                    else -> {
                        pendingResults.remove(requestCode)?.error("Error", "Failed to access file", null)
                        return
                    }
                }

                val takeFlags: Int =
                    data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)

                val resultList = mutableListOf<FileInfo>()
                for (uri in uriList) {
                    takePersistableReadPermission(uri, takeFlags)
                    val documentFile = FastDocumentFile.fromDocumentUri(this, uri)
                    if (documentFile == null) {
                        pendingResults.remove(requestCode)?.error("Error", "Failed to access file", null)
                        return
                    }
                    resultList.add(
                        FileInfo(
                            name = documentFile.name,
                            size = documentFile.size,
                            uri = uri.toString(),
                            lastModified = documentFile.lastModified,
                        )
                    )
                }

                pendingResults.remove(requestCode)?.success(resultList.map { it.toMap() })
            }
        }
    }

    private fun listFiles(uri: Uri, files: MutableList<FileInfo>, maxEntries: Int = 5000) {
        if (files.size >= maxEntries) {
            return
        }
        val pickedDir: FastDocumentFile = FastDocumentFile.fromTreeUri(this, uri)

        for (file in pickedDir.listFiles()) {
            if (file.isDirectory) {
                // Recursive call
                listFiles(file.uri, files)
            } else if (file.isFile) {
                files.add(
                    FileInfo(
                        name = file.name,
                        size = file.size,
                        uri = file.uri.toString(),
                        lastModified = file.lastModified,
                    ),
                )
            }
        }
    }

    @SuppressLint("WrongConstant")
    private fun handleCreateDirectory(call: MethodCall, result: MethodChannel.Result) {
        val documentUri = Uri.parse(call.argument<String>("documentUri")!!)
        val directoryName = call.argument<String>("directoryName")!!

        if (folderExists(documentUri, directoryName)) {
            result.success(null)
            return
        }

        DocumentsContract.createDocument(
            context.contentResolver, documentUri, DocumentsContract.Document.MIME_TYPE_DIR,
            directoryName
        )

        result.success(null)
    }

    private fun folderExists(documentUri: Uri, folderName: String): Boolean {
        var cursor: Cursor? = null
        try {
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(documentUri, DocumentsContract.getDocumentId(documentUri))
            cursor = contentResolver.query(
                childrenUri,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE
                ),
                null,
                null,
                null,
            )

            if (cursor != null) {
                while (cursor.moveToNext()) {
                    val displayName = cursor.getString(0)
                    val mimeType = cursor.getString(1)

                    if (folderName == displayName && DocumentsContract.Document.MIME_TYPE_DIR == mimeType) {
                        return true
                    }
                }
            }
        } finally {
            cursor?.close()
        }
        return false
    }

    private fun openGallery() {
        val intent = Intent()
        intent.action = Intent.ACTION_VIEW
        intent.type = "image/*"
        startActivity(intent)
    }

    private fun takePersistableReadPermission(uri: Uri, flags: Int) {
        val readFlags = flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
        if (readFlags == 0) {
            return
        }
        try {
            contentResolver.takePersistableUriPermission(uri, readFlags)
        } catch (e: SecurityException) {
            Log.w("FluxFilePicker", "Could not persist URI permission for $uri", e)
        }
    }

    private fun takePersistableDirectoryPermission(uri: Uri, flags: Int) {
        val persistFlags = flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        if (persistFlags == 0) {
            return
        }
        try {
            contentResolver.takePersistableUriPermission(uri, persistFlags)
        } catch (e: SecurityException) {
            Log.w("FluxFilePicker", "Could not persist directory URI permission for $uri", e)
        }
    }
}

data class PickDirectoryResult(
    val directoryUri: String,
    val files: List<FileInfo>,
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "directoryUri" to directoryUri,
            "files" to files.map { it.toMap() }
        )
    }
}

data class FileInfo(
    val name: String,
    val size: Long,
    val uri: String,
    val lastModified: Long
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "name" to name,
            "size" to size,
            "uri" to uri,
            "lastModified" to lastModified
        )
    }
}
