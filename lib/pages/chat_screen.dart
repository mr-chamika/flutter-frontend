import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:convert';
import '../pages/home.dart';

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final String timestamp;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.timestamp,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['_id'] ?? '',
      chatId: json['chatId'] ?? '',
      senderId: json['senderId'] ?? '',
      content: json['text'] ?? '',
      timestamp: json['createdAt'] ?? '',
    );
  }
}

class ChatScreen extends StatefulWidget {
  // Removed chatId from constructor

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Message> messages = [];
  TextEditingController _messageController = TextEditingController();
  String userId = "";
  String userIdOther = "";
  String message = "";

  late String chatId;
  String otherUserName = "";
  ScrollController scrollController = ScrollController();
  ValueNotifier<bool> canSend = ValueNotifier(false);
  bool isEditing = false;
  String editedName = "";

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _messageController.addListener(() {
      canSend.value = _messageController.text.trim().isNotEmpty;
    });
    // Fetch messages after chatId is set
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      chatId = args['chatId'];
      otherUserName = args['userName'];
      userIdOther = args['userIdOther'];
      editedName = otherUserName;
      message = args.toString();
      _fetchMessages();
    });
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;

    return text.split(" ")[0][0].toUpperCase() +
        text.split(" ")[0].substring(1) +
        " " +
        text.split(" ")[1][0].toUpperCase() +
        text.split(" ")[1].substring(1);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (token != null) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      setState(() {
        userId = decodedToken['id'];
      });
    }
  }

  Future<String?> getProfilePic() async {
    final res = await http.get(
      Uri.parse(
        "https://flutter-backend-yetypw.fly.dev/user/get?id=$userIdOther",
      ),
    );

    Map<String, dynamic> user = jsonDecode(res.body);

    return user['profilePic'];
  }

  void _fetchMessages() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://flutter-backend-yetypw.fly.dev/message/get?id=${chatId}',
        ),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body); // Expect a list
        setState(() {
          messages = data
              .map((json) => Message.fromJson(json))
              .toList()
              .reversed
              .toList();
        });
        // Scroll to bottom after loading
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.jumpTo(scrollController.position.minScrollExtent);
          }
        });
      } else {
        print('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching messages: $e');
    }
  }

  void _sendMessage() async {
    if (_messageController.text.isEmpty) return;
    // Backend has /message/create
    final response = await http.post(
      Uri.parse('https://flutter-backend-yetypw.fly.dev/message/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'chatId': chatId,
        'senderId': userId,
        'text': _messageController.text.trim(), // Backend uses 'text'
      }),
    );
    if (response.statusCode == 200) {
      _messageController.clear();
      _fetchMessages(); // Refresh messages
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actionsPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
        title: Text(otherUserName != "" ? _capitalize(otherUserName) : 'Chat'),
        leading: Padding(
          padding: EdgeInsets.symmetric(
            vertical: 8.0,
            horizontal: 5.0,
          ), // Add margin around the CircleAvatar
          child: FutureBuilder<String?>(
            future: getProfilePic(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircleAvatar(
                  child: CircularProgressIndicator(),
                  backgroundColor: Colors.blue.shade200,
                );
              } else if (snapshot.hasError || snapshot.data == null) {
                return CircleAvatar(
                  child: Text(otherUserName[0].toUpperCase()),
                  backgroundColor: Colors.blue.shade200,
                );
              } else {
                String data = snapshot.data!;
                if (data.startsWith('data:image')) {
                  List<String> parts = data.split(',');
                  if (parts.length == 2) {
                    String base64 = parts[1];
                    return CircleAvatar(
                      backgroundImage: MemoryImage(base64Decode(base64)),
                      backgroundColor: Colors.blue.shade200,
                    );
                  } else {
                    return CircleAvatar(
                      child: Text(otherUserName[0].toUpperCase()),
                      backgroundColor: Colors.blue.shade200,
                    );
                  }
                } else {
                  return CircleAvatar(
                    backgroundImage: NetworkImage(data),
                    backgroundColor: Colors.blue.shade200,
                  );
                }
              }
            },
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController, // Add controller
              reverse: true, // Align messages to bottom
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                bool isMe = message.senderId == userId;
                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: 100.0, // Minimum width
                      maxWidth:
                          MediaQuery.of(context).size.width *
                          0.7, // Max 70% of screen width
                    ),
                    child: Container(
                      margin: EdgeInsets.all(8.0),
                      padding: EdgeInsets.symmetric(
                        vertical: 4.0,
                        horizontal: 6.0,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue : Colors.grey,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          !isMe
                              ? Text(
                                  otherUserName.split(" ")[0][0].toUpperCase() +
                                      otherUserName.split(" ")[0].substring(1),
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                )
                              : Text(
                                  "You",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.start,
                                ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(10.0, 0, 10.0, 3.0),
                            child: Text(
                              message.content,
                              style: TextStyle(color: Colors.white),
                              textAlign: TextAlign.justify,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLines: null, // Allow unlimited lines, expands vertically
                    minLines: 1, // Start with 1 line
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: canSend,
                  builder: (context, enabled, child) {
                    return IconButton(
                      icon: Icon(Icons.send),
                      onPressed: enabled ? _sendMessage : null,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
