package com.dovahkin.sms_guard

import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Telephony
import android.util.Log

/**
 * Bu sınıf SMS gönderme ve yönetme işlemlerini native olarak gerçekleştirir.
 * Flutter tarafından Method Channel üzerinden çağrılır.
 */
class SmsManager {
    companion object {
        private const val TAG = "SmsManager"
        
        /**
         * SMS gönderir ve sonucu döndürür.
         * @param context Uygulama context'i
         * @param phoneNumber SMS gönderilecek telefon numarası
         * @param message Gönderilecek mesaj içeriği
         * @return Gönderim sonucunu içeren Map
         */
        fun sendSms(context: Context, phoneNumber: String, message: String): Map<String, Any> {
            val resultMap = mutableMapOf<String, Any>()
            
            try {
                // İzin kontrolü
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                    context.checkSelfPermission(android.Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                    Log.e(TAG, "SMS permission not granted")
                    resultMap["success"] = false
                    resultMap["message"] = "SMS izni verilmedi"
                    return resultMap
                }
                
                // Android versiyonuna göre SmsManager alınması
                val androidSmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    context.getSystemService(android.telephony.SmsManager::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    android.telephony.SmsManager.getDefault()
                }
                
                // Uzun mesajları parçalama ve gönderme
                if (message.length > 160) {
                    val messageParts = androidSmsManager.divideMessage(message)
                    androidSmsManager.sendMultipartTextMessage(
                        phoneNumber,
                        null,
                        messageParts,
                        null,
                        null
                    )
                } else {
                    // Kısa mesajları doğrudan gönderme
                    androidSmsManager.sendTextMessage(phoneNumber, null, message, null, null)
                }
                
                // Gönderilen mesajı cihaz SMS veritabanına kaydetme
                saveToSentBox(context, phoneNumber, message)
                
                Log.i(TAG, "SMS sent successfully to $phoneNumber")
                resultMap["success"] = true
                resultMap["message"] = "SMS başarıyla gönderildi"
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send SMS: ${e.message}")
                e.printStackTrace()
                resultMap["success"] = false
                resultMap["message"] = "SMS gönderme hatası: ${e.message}"
            }
            
            return resultMap
        }
        
        /**
         * Gönderilen mesajı cihaz SMS veritabanına kaydeder
         */
        fun saveToSentBox(context: Context, address: String?, message: String?) {
            try {
                val smsValues = ContentValues().apply {
                    put(Telephony.Sms.ADDRESS, address)
                    put(Telephony.Sms.BODY, message)
                    put(Telephony.Sms.DATE, System.currentTimeMillis())
                    put(Telephony.Sms.READ, 1)
                    put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_SENT)
                }
                
                context.contentResolver.insert(Uri.parse("content://sms/sent"), smsValues)
                Log.i(TAG, "SMS saved to sent box")
            } catch (e: Exception) {
                Log.e(TAG, "Error saving SMS to sent box: ${e.message}")
                e.printStackTrace()
            }
        }
        
        fun deleteThread(context: Context, threadId: String?): Int {
            if (threadId == null) {
                Log.e(TAG, "Cannot delete thread: threadId is null")
                return 0
            }

            try {
                val threadDeleteUri = Uri.parse("content://sms/conversations/$threadId")
                val deletedRows = context.contentResolver.delete(threadDeleteUri, null, null)
                Log.d(TAG, "Deleted $deletedRows rows using conversation URI")
                return deletedRows
            } catch (e: Exception) {
                Log.e(TAG, "Error deleting by conversation URI: ${e.message}")
                return 0
            }
        }
        
        /**
         * SMS mesajlarını okundu olarak işaretler
         * @param context Uygulama context'i
         * @param threadId Okundu olarak işaretlenecek mesaj konusunun thread ID'si
         * @return Güncellenen mesaj sayısı
         */
        fun markThreadAsRead(context: Context, threadId: String?): Int {
            if (threadId == null) {
                Log.e(TAG, "Cannot mark thread as read: threadId is null")
                return 0
            }
            
            // İzin kontrolü
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (context.checkSelfPermission(android.Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
                    Log.e(TAG, "SMS read/write permissions not granted")
                    return 0
                }
            }
            
            var updatedRows = 0
            
            try {
                // SMS içeriğini güncelleyecek değerler
                val values = ContentValues().apply {
                    put(Telephony.Sms.READ, 1) // 1 = okundu
                }
                
                // Önce inbox (gelen kutusu) URI'sinde threadId ile eşleşen ve okunmamış olan mesajları güncelle
                val inboxUri = Uri.parse("content://sms/inbox")
                val selection = "${Telephony.Sms.THREAD_ID} = ? AND ${Telephony.Sms.READ} = 0"
                val selectionArgs = arrayOf(threadId)
                
                updatedRows = context.contentResolver.update(inboxUri, values, selection, selectionArgs)
                Log.i(TAG, "Marked $updatedRows messages as read in thread $threadId")
                
                // Content provider'a değişiklik bildir
                if (updatedRows > 0) {
                    context.contentResolver.notifyChange(Uri.parse("content://sms"), null)
                    context.contentResolver.notifyChange(Uri.parse("content://sms/inbox"), null)
                    context.contentResolver.notifyChange(Uri.parse("content://sms/conversations"), null)
                }
                
                return updatedRows
            } catch (e: Exception) {
                Log.e(TAG, "Error marking messages as read: ${e.message}")
                e.printStackTrace()
                return updatedRows
            }
        }
        
        fun getThreadsReadStatus(context: Context, threadIds: List<String>): Map<String, Boolean> {
            val statusMap = mutableMapOf<String, Boolean>()
            if (threadIds.isEmpty()) {
                return statusMap
            }

            try {
                val inboxUri = Uri.parse("content://sms/inbox")
                val projection = arrayOf(Telephony.Sms.THREAD_ID)
                val selection = "${Telephony.Sms.THREAD_ID} IN (${threadIds.joinToString(",")}) AND ${Telephony.Sms.READ} = 0"

                context.contentResolver.query(
                    inboxUri,
                    projection,
                    selection,
                    null,
                    null
                )?.use { cursor ->
                    val unreadThreadIds = mutableSetOf<String>()
                    while (cursor.moveToNext()) {
                        val threadId = cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Sms.THREAD_ID))
                        unreadThreadIds.add(threadId)
                    }
                    for (threadId in threadIds) {
                        statusMap[threadId] = !unreadThreadIds.contains(threadId)
                    }
                }
            } catch (e: Exception) {
                for (threadId in threadIds) {
                    statusMap[threadId] = true
                }
            }
            return statusMap
        }
    }
}