import 'dart:convert';

import 'package:flutter/material.dart';
import '../pages/home.dart'; // Assuming Chat is defined there
import 'package:http/http.dart' as http;

class ChatListCard extends StatefulWidget {
  final Chat chat;
  final String otherUserName;
  final VoidCallback onTap;
  final String? lastMessageId;
  final String? userId;

  const ChatListCard({
    Key? key,
    required this.chat,
    required this.otherUserName,
    required this.onTap,
    this.lastMessageId,
    this.userId,
  }) : super(key: key);

  @override
  _ChatListCardState createState() => _ChatListCardState();
}

class _ChatListCardState extends State<ChatListCard> {
  late Future<String?> _profilePicFuture;
  late Future<Map<String, dynamic>> _lastMsgFuture;
  String? lastMsgId;

  @override
  void initState() {
    super.initState();
    _profilePicFuture = getProfilePic();
    _lastMsgFuture = getLastMsg();
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;

    return text.split(" ")[0][0].toUpperCase() +
        text.split(" ")[0].substring(1) +
        " " +
        text.split(" ")[1][0].toUpperCase() +
        text.split(" ")[1].substring(1);
  }

  String _getInitials(String name) {
    List<String> parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }

  String _formatTime(String dateTimeString) {
    try {
      DateTime dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  Future<Map<String, dynamic>> getLastMsg() async {
    if (widget.lastMessageId == null) {
      return {"text": "No message yet", "time": ""};
    }
    final res = await http.get(
      Uri.parse("http://localhost:8080/message/one?id=${widget.lastMessageId}"),
    );

    Map<String, dynamic> msg = jsonDecode(res.body);
    Message x = Message.fromJson(msg);

    lastMsgId = x.senderId;

    return {"text": x.content, "time": x.timestamp};
  }

  Future<String?> getProfilePic() async {
    final res = await http.get(
      Uri.parse("http://localhost:8080/user/get?id=${widget.userId}"),
    );

    Map<String, dynamic> user = jsonDecode(res.body);

    return user['profilePic'];
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        leading: FutureBuilder<String?>(
          future: _profilePicFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircleAvatar(
                child: CircularProgressIndicator(),
                backgroundColor: Colors.grey.shade200,
              );
            } else if (snapshot.hasError || snapshot.data == null) {
              return CircleAvatar(
                child: Text(_getInitials(widget.otherUserName)),
                backgroundColor: Colors.grey.shade200,
              );
            } else {
              String data = snapshot.data!;
              if (data.startsWith('data:image')) {
                List<String> parts = data.split(',');
                if (parts.length == 2) {
                  String base64 = parts[1];
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey, width: 2),
                    ),
                    child: CircleAvatar(
                      backgroundImage: MemoryImage(base64Decode(base64)),
                      backgroundColor: Colors.grey.shade200,
                    ),
                  );
                } else {
                  return CircleAvatar(
                    child: Text(_getInitials(widget.otherUserName)),
                    backgroundColor: Colors.grey.shade200,
                  );
                }
              } else {
                return CircleAvatar(
                  backgroundImage: NetworkImage(data),
                  backgroundColor: Colors.grey.shade200,
                );
              }
            }
          },
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _capitalize(widget.otherUserName),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              _formatTime(widget.chat.updatedAt),
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        subtitle: FutureBuilder<Map<String, dynamic>>(
          future: _lastMsgFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text('Loading last message...');
            } else if (snapshot.hasError) {
              return Text('Error loading message');
            } else {
              Map<String, dynamic>? data = snapshot.data;

              String prefix = lastMsgId == widget.userId ? "" : "You : ";

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${prefix} ${data?['text'] ?? 'No message yet'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            }
          },
        ),
        trailing: widget.chat.unreadCount > 0
            ? CircleAvatar(
                radius: 10,
                backgroundColor: Colors.red,
                child: Text(
                  widget.chat.unreadCount.toString(),
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              )
            : null,
        onTap: widget.onTap,
      ),
    );
  }
}
