import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'package:chat_app/pages/loading.dart';

class ChangeLocation extends StatefulWidget {
  const ChangeLocation({super.key});

  @override
  State<ChangeLocation> createState() => _ChangeLocationState();
}

class _ChangeLocationState extends State<ChangeLocation> {
  Map<String, String> param = {};

  String message = "Loading";
  bool fetched = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (!fetched) {
      param = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
      userGet();
      fetched = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Change Location"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Container(child: message == "Loading" ? Loading() : Text(message)),
    );
  }

  Future<void> userGet() async {
    try {
      String x = param["id"]!;

      Response res = await get(
        Uri.parse(
          "https://flutter-backend-yetypw-production.up.railway.app/user/get?id=$x",
        ),
      );
      Map data = jsonDecode(res.body);

      setState(() {
        message = data['email'];
      });
    } catch (e) {
      setState(() {
        message = "Restart App";
      });
    }
  }
}
