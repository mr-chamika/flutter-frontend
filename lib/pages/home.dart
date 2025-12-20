import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'dart:async';
import '../components/chat_list_card.dart';

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
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class Chat {
  final String id;
  final List<String> participants;
  final String? lastMessageId;
  final bool status;
  final bool isOnline;
  final String userName;
  final bool consent1;
  final bool consent2;
  final int unreadCount;
  final String createdAt;
  final String updatedAt;
  final bool isSynced;
  final List<Message> messages;

  Chat({
    required this.id,
    required this.participants,
    this.lastMessageId,
    required this.status,
    required this.isOnline,
    required this.userName,
    required this.consent1,
    required this.consent2,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
    required this.messages,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['_id'] ?? '',
      participants: json['participants'] != null
          ? List<String>.from(json['participants'])
          : [],
      lastMessageId: json['lastMessageId'],
      status: json['status'] ?? false,
      isOnline: json['isOnline'] ?? false,
      userName: json['userName'] ?? '',
      consent1: json['consent1'] ?? false,
      consent2: json['consent2'] ?? false,
      unreadCount: json['unreadCount'] ?? 0,
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      isSynced: json['isSynced'] ?? true,
      messages: json['messages'] != null
          ? List<Message>.from(json['messages'].map((x) => Message.fromJson(x)))
          : [],
    );
  }
}

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  TextEditingController _searchController = TextEditingController();
  List<Chat> _chats = [];
  List<Chat> _filteredChats = [];
  bool _isLoading = true;
  String userId = "";
  String message = "";
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  String lastMsgId = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.contains(ConnectivityResult.none)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No internet connection')));
      }
    });
    _loadUserId();
    _filteredChats = _chats;
    _searchController.addListener(_filterChats);
    setState(() {
      message = "Loading";
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      message = "user id loading";
    });

    String? token = prefs.getString('token');
    if (token != null) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      setState(() {
        userId = decodedToken['id'];
      });
      _fetchChats();
    }
  }

  void _fetchChats() async {
    setState(() {
      message = "fetching";
    });

    if (userId.isEmpty) return;

    var connectivityResult = await Connectivity().checkConnectivity();
    bool isOnline = connectivityResult != ConnectivityResult.none;

    if (!isOnline) {
      setState(() {
        message = "No internet connection";
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No internet connection')));
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8080/chat/list?id=$userId'),
      );
      if (response.statusCode == 200) {
        List<dynamic> serverChatsJson = jsonDecode(response.body);
        setState(() {
          message = serverChatsJson.toString();
        });
        List<Chat> serverChats = serverChatsJson
            .map((json) => Chat.fromJson(json))
            .toList();
        setState(() {
          _chats = serverChats;
          _filteredChats = _chats;
        });
      } else {
        setState(() {
          message = "Error get chat list";
        });
      }
    } catch (e) {
      setState(() {
        message = '$e';
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _filterChats() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredChats = _chats
          .where((chat) => chat.userName.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchChats(); // Refresh chats when app resumes
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text("PR Chat"),
          centerTitle: false,
          backgroundColor: Colors.blue.shade700,
          automaticallyImplyLeading: false,
          // actions: [
          //   IconButton(
          //     icon: Icon(Icons.account_circle),
          //     onPressed: () {
          //       Navigator.pushNamed(context, '/profile');
          //     },
          //   ),
          // ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade100, Colors.blue.shade400],
            ),
          ),
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    //Text(message),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 50.0,
                        vertical: 10.0,
                      ),
                      child: TextField(
                        controller: _searchController,
                        textAlign: TextAlign.start,
                        decoration: InputDecoration(
                          hintText: "Search chats...",
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20.0),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.8),
                          contentPadding: EdgeInsets.symmetric(vertical: 15.0),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = _filteredChats[index];
                          final otherUserName = chat.participants[0] == userId
                              ? chat.userName.split(",")[1]
                              : chat.userName.split(",")[0];
                          return ChatListCard(
                            chat: chat,
                            lastMessageId: chat.lastMessageId,
                            otherUserName: otherUserName,
                            userId: chat.participants[0] == userId
                                ? chat.participants[1]
                                : chat.participants[0],
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/chat',
                                arguments: {
                                  'chatId': chat.id,
                                  'userName': otherUserName,
                                  'userIdOther': chat.participants[0] == userId
                                      ? chat.participants[1]
                                      : chat.participants[0],
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
