import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

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
  //final bool isSynced;

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
    //required this.isSynced,
  });

  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
    id: json['_id'],
    participants: List<String>.from(json['participants']),
    lastMessageId: json['lastMessageId'],
    status: json['status'],
    isOnline: json['online'],
    userName: json['userName'],
    consent1: json['consent1'],
    consent2: json['consent2'],
    unreadCount: json['unreadCount'],
    createdAt: json['createdAt'],
    updatedAt: json['updatedAt'],
    //isSynced: json['isSynced'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'participants': participants,
    'lastMessageId': lastMessageId,
    'status': status,
    'online': isOnline,
    'userName': userName,
    'consent1': consent1,
    'consent2': consent2,
    'unreadCount': unreadCount,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    //'isSynced': isSynced,
  };
}

class QRScanPage extends StatefulWidget {
  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  MobileScannerController? cameraController;

  bool scanned = false;
  bool isLoading = false;
  bool isOnline = true;
  bool isCameraReady = false;
  PermissionStatus? cameraPermissionStatus;

  String userId = "";
  String myName = "";

  @override
  void initState() {
    super.initState();
    _getToken();
    _checkConnectivity();
    if (!kIsWeb) _requestCameraPermission();
  }

  Future<void> _startCamera() async {
    try {
      if (cameraController != null) {
        await cameraController!.stop();
        cameraController!.dispose();
      }
      cameraController = MobileScannerController();
      await cameraController!.start();

      setState(() {
        isCameraReady = true;
      });
    } catch (e) {
      setState(() {
        isCameraReady = true;
      });
    }
  }

  // ------------------ CAMERA PERMISSION ------------------
  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.status;

    setState(() {
      cameraPermissionStatus = status;
    });

    if (status.isGranted) {
      await _startCamera();
      return;
    }

    if (status.isDenied) {
      final result = await Permission.camera.request();

      setState(() {
        cameraPermissionStatus = result;
      });

      if (result.isGranted) {
        await _startCamera();
      } else if (result.isPermanentlyDenied) {
        _showPermissionDeniedAlert();
      }
      return;
    }

    if (status.isPermanentlyDenied) {
      _showPermissionDeniedAlert();
    }
  }

  @override
  void dispose() {
    cameraController?.stop();
    cameraController?.dispose();
    super.dispose();
  }

  // ------------------ TOKEN ------------------
  Future<void> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null) {
      final decoded = JwtDecoder.decode(token);
      setState(() {
        userId = decoded['id'];
        myName = decoded['name'];
      });
    }
  }

  // ------------------ CONNECTIVITY ------------------
  void _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() => isOnline = result != ConnectivityResult.none);

    Connectivity().onConnectivityChanged.listen((results) {
      setState(() {
        isOnline = results.any((r) => r != ConnectivityResult.none);
      });
    });
  }

  // ------------------ QR SCAN ------------------
  void _handleBarCodeScanned(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty || scanned || isLoading) return;

    final data = capture.barcodes.first.rawValue ?? '';
    _handleBarCodeScannedData(data);
  }

  Future<List<Chat>> _fetchChats() async {
    final response = await http.get(
      Uri.parse(
        'https://flutter-backend-yetypw-production.up.railway.app/chat/list?id=$userId',
      ),
    );
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);

      return data.map((e) => Chat.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load chats');
    }
  }

  Future<void> _handleBarCodeScannedData(String data) async {
    scanned = true;
    isLoading = true;
    setState(() {});

    if (userId.isEmpty) {
      _resetScan("Error", "User not loaded. Try again.");
      return;
    }

    Map<String, dynamic> parsed;
    try {
      parsed = json.decode(data);
    } catch (_) {
      _resetScan("Invalid QR", "Invalid QR code format.");
      return;
    }

    final combinedNames = "$myName,${parsed['name'] ?? 'Unknown'}";

    try {
      List<Chat> chats = await _fetchChats();

      String otherId = parsed['id'];
      Chat? existingChat;

      try {
        existingChat = chats.firstWhere(
          (chat) =>
              chat.participants.contains(userId) &&
              chat.participants.contains(otherId),
        );
      } catch (_) {
        existingChat = null;
      }

      if (existingChat != null) {
        Navigator.pushNamed(
          context,
          '/chat',
          arguments: {
            'chatId': existingChat.id,
            'userName': existingChat.participants[0] == userId
                ? existingChat.userName.split(",")[1]
                : existingChat.userName.split(",")[0],
            'userIdOther': existingChat.participants[0] == userId
                ? existingChat.participants[1]
                : existingChat.participants[0],
          },
        );
      } else {
        final response = await http.get(
          Uri.parse(
            'https://flutter-backend-yetypw-production.up.railway.app/chat/create'
            '?inviteTo=$otherId'
            '&scan=$userId'
            '&userName=$combinedNames',
          ),
        );

        if (response.statusCode == 200) {
          Navigator.pushNamed(context, '/');
        } else {
          _resetScan("Error", "Failed to create chat.");
        }
      }
    } catch (_) {
      _resetScan("Network Error", "hi your internet connection.");
    } finally {
      isLoading = false;
      setState(() {});
    }
  }

  void _resetScan(String title, String message) {
    scanned = false;
    isLoading = false;
    setState(() {});
    _showAlert(title, message);
  }

  // ------------------ UI ------------------
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Scaffold(
        body: Center(child: Text("QR scanning not supported on Web")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan QR Code"),
        backgroundColor: Colors.blue.shade700,
        actions: [
          if (isCameraReady) ...[
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => cameraController?.toggleTorch(),
            ),
            IconButton(
              icon: const Icon(Icons.flip_camera_android),
              onPressed: () => cameraController?.switchCamera(),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          if (isCameraReady)
            MobileScanner(
              controller: cameraController,
              onDetect: _handleBarCodeScanned,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          if (isCameraReady)
            Positioned.fill(
              child: Container(
                alignment: Alignment.center,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          if (cameraPermissionStatus?.isDenied == true ||
              cameraPermissionStatus?.isPermanentlyDenied == true)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Camera permission denied"),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: openAppSettings,
                    child: const Text("Open Settings"),
                  ),
                ],
              ),
            ),
          if (!isCameraReady &&
              (cameraPermissionStatus?.isGranted == true ||
                  cameraPermissionStatus == null))
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _overlay(String text, {bool loader = false}) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loader) const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------ ALERTS ------------------
  void _showPermissionDeniedAlert() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Camera Permission Denied"),
        content: const Text("Enable camera permission in app settings."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
