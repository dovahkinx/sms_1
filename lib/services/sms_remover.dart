// ignore_for_file: unintended_html_in_doc_comment

import 'dart:developer' as dev;
import 'package:flutter/services.dart';

class SmsRemover {
  final MethodChannel _channel = const MethodChannel('com.dovahkin.sms_guard');

  Future<String> removeSmsByThreadId(String threadId) async {
    try {
      final result = await _channel.invokeMethod('deleteThread', {
        'threadId': threadId,
      });
      return result.toString();
    } catch (e) {
      return "Konuşma silme işlemi başarısız oldu: $e";
    }
  }
}