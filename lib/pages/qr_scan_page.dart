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
  final bool isSynced;

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
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['_id'],
      participants: List<String>.from(json['participants']),
      lastMessageId: json['lastMessageId'],
      status: json['status'],
      isOnline: json['isOnline'],
      userName: json['userName'],
      consent1: json['consent1'],
      consent2: json['consent2'],
      unreadCount: json['unreadCount'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      isSynced: json['isSynced'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'participants': participants,
      'lastMessageId': lastMessageId,
      'status': status,
      'isOnline': isOnline,
      'userName': userName,
      'consent1': consent1,
      'consent2': consent2,
      'unreadCount': unreadCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isSynced': isSynced,
    };
  }
}

class QRScanPage extends StatefulWidget {
  @override
  _QRScanPageState createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  MobileScannerController? cameraController;

  bool scanned = false;
  bool isLoading = false;
  String userId = "";
  String myName = "";
  bool isOnline = true;
  bool permissionRequested = false;

  @override
  void initState() {
    super.initState();
    _getToken();
    _checkConnectivity();
    if (!kIsWeb) {
      _requestCameraPermission();
    }
  }

  void _requestCameraPermission() async {
    setState(() {
      permissionRequested = true;
    });
    var status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() {
        cameraController = MobileScannerController();
      });
    } else if (status.isPermanentlyDenied) {
      _showPermissionDeniedAlert();
    } else {
      _showAlert(
        "Camera Permission Required",
        "Camera permission is needed to scan QR codes.",
      );
    }
  }

  @override
  void dispose() {
    cameraController?.dispose();
    super.dispose();
  }

  void _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (token != null) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      setUserId(decodedToken['id']);
      setMyName(decodedToken['name']);
    }
  }

  void _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      isOnline = connectivityResult != ConnectivityResult.none;
    });
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      setState(() {
        isOnline = results.any((result) => result != ConnectivityResult.none);
      });
    });
  }

  void setUserId(String id) {
    setState(() {
      userId = id;
    });
  }

  void setMyName(String name) {
    setState(() {
      myName = name;
    });
  }

  void _handleBarCodeScanned(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String data = barcodes.first.rawValue ?? '';
      _handleBarCodeScannedData(data); // Rename existing method or adjust
    }
  }

  void _handleBarCodeScannedData(String data) async {
    if (scanned || isLoading) return;
    setState(() {
      scanned = true;
      isLoading = true;
    });

    if (userId.isEmpty) {
      _showAlert("Error", "User ID not loaded. Please try again.");
      setState(() {
        isLoading = false;
        scanned = false;
      });
      return;
    }

    Map<String, dynamic>? parse;
    try {
      parse = json.decode(data);
    } catch (e) {
      _showAlert("Invalid QR Code", "The scanned QR code is not valid.");
      setState(() {
        isLoading = false;
        scanned = false;
      });
      return;
    }

    String scannedUserName = parse!['name'] ?? "Unknown";
    String combinedUserNames = "$myName,$scannedUserName";

    try {
      final response = await http.get(
        Uri.parse(
          'https://flutter-backend-yetypw.fly.dev/chat/create?inviteTo=${parse['id']}&scan=$userId&userName=$combinedUserNames',
        ),
      );

      if (response.statusCode == 200) {
        String newServerId = response.body;
        // Navigate to chat screen
        Navigator.pushNamed(context, '/chat', arguments: newServerId);
      } else {
        _showAlert(
          "Error",
          "Failed to create chat. Status: ${response.statusCode}",
        );
      }
    } catch (e) {
      _showAlert(
        "Network Error",
        "Unable to create chat. Please check your connection.",
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showPermissionDeniedAlert() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Camera Permission Denied"),
          content: Text(
            "Camera permission is permanently denied. Please enable it in app settings to scan QR codes.",
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Open Settings"),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Scan QR Code'),
          backgroundColor: Colors.blue.shade700,
        ),
        body: Center(
          child: Text('QR Code scanning is not available on the web.'),
        ),
      );
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Scan QR Code'),
          backgroundColor: Colors.blue.shade700,
          automaticallyImplyLeading: false,
          actions: [
            if (cameraController != null) ...[
              IconButton(
                icon: Icon(Icons.flash_on),
                onPressed: () => cameraController?.toggleTorch(),
              ),
              IconButton(
                icon: Icon(Icons.flip_camera_android),
                onPressed: () => cameraController?.switchCamera(),
              ),
            ],
          ],
        ),
        body: Stack(
          children: [
            if (cameraController != null)
              MobileScanner(
                controller: cameraController,
                onDetect: (BarcodeCapture capture) {
                  _handleBarCodeScanned(capture);
                },
              )
            else if (permissionRequested)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Camera permission denied.'),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _requestCameraPermission,
                      child: Text('Retry Permission'),
                    ),
                  ],
                ),
              )
            else
              Center(child: Text('Requesting camera permission...')),
            // Overlay for scanning area
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Text(
                'Align QR code within the frame',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            if (!isOnline)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Text(
                    "You are offline",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            if (isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 20),
                      Text(
                        "Processing QR Code...",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
