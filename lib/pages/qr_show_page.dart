import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:convert';

class QRShowPage extends StatefulWidget {
  @override
  _QRShowPageState createState() => _QRShowPageState();
}

class _QRShowPageState extends State<QRShowPage> {
  String userId = "";
  String name = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (token != null) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      setState(() {
        userId = decodedToken['id'];
        name = decodedToken['name'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String qrData = jsonEncode({"id": userId, "name": name});

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text('My QR Code'),
          backgroundColor: Colors.blue.shade700,
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: userId.isEmpty
              ? CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Scan this QR code to start a chat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                    SizedBox(height: 20),
                    Text('Name: $name'),
                    Text('ID: $userId'),
                  ],
                ),
        ),
      ),
    );
  }
}
