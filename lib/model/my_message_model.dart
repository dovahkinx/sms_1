import 'package:flutter/material.dart';

class MyMessage {
  String? name;
  String? lastMessage;
  String? address;
  DateTime? date;
  int? threadId;
  bool isRead;
  Color? avatarColor;
  String? formattedDate;
  String? formattedSubtitle;

  MyMessage({
    required this.name,
    required this.lastMessage,
    required this.address,
    required this.date,
    required this.threadId,
    this.isRead = true,
    this.avatarColor,
    this.formattedDate,
    this.formattedSubtitle,
  });
}
