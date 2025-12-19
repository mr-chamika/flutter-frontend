import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  String? email;
  String? name;
  String? avatar;
  String? userId;
  bool loading = true;
  Uint8List? imageBytes;
  String originalName = '';
  String originalEmail = '';

  TextEditingController _newEmailController = TextEditingController();
  TextEditingController _nameController = TextEditingController();
  bool showOtp = false;
  TextEditingController _otpController = TextEditingController();
  bool isVerifying = false;
  String otpError = "";
  String emailError = "";
  String x = "";
  bool isLoading = false;
  int resendTimer = 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchProfile();
    _startTimer();
    _nameController.addListener(() {
      setState(() {});
    });
    _newEmailController.addListener(() {
      setState(() {});
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (resendTimer > 0) {
        if (mounted) {
          setState(() {
            resendTimer--;
          });
        }
      }
    });
  }

  void _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (mounted) {
        setState(() {
          imageBytes = bytes;
        });
      }
    }
  }

  void _saveProfile() async {
    if (userId == null) return;
    try {
      // Split name into first and last
      List<String> nameParts = _nameController.text.trim().split(' ');
      String firstName = nameParts.isNotEmpty ? nameParts[0] : '';
      String lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';
      // Convert image to base64 if selected
      String? avatarUri;
      if (imageBytes != null) {
        String base64Image = base64Encode(imageBytes!);
        avatarUri = 'data:image/jpeg;base64,$base64Image';
      }
      final response = await http.put(
        Uri.parse('https://flutter-backend-yetypw.fly.dev/user/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': userId,
          'firstName': firstName,
          'lastName': lastName,
          'avatarUri': avatarUri, // Base64 data URL
        }),
      );
      if (response.statusCode == 200) {
        fetchProfile(); // Sync with backend
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Profile updated')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update profile')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Network error')));
    }
  }

  void fetchProfile() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token != null) {
        Map<String, dynamic> decoded = JwtDecoder.decode(token);
        String id = decoded['id'];
        final response = await http.get(
          Uri.parse('https://flutter-backend-yetypw.fly.dev/user/get?id=$id'),
          headers: {'Content-Type': 'application/json'},
        );
        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          if (mounted) {
            setState(() {
              name = data['name'];
              email = data['email'];
              avatar = data['profilePic'] ?? "";
              userId = data['_id'];
            });
          }
          _nameController.text = name ?? '';
          originalName = name ?? '';
          originalEmail = email ?? '';
        }
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void checkEmail() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        emailError = "";
        x = "";
      });
    }
    try {
      final response = await http.put(
        Uri.parse('https://flutter-backend-yetypw.fly.dev/user/email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': userId,
          'x': email,
          'email': _newEmailController.text.trim(),
        }),
      );
      String data = response.body;
      if (response.statusCode == 200) {
        if (data.toLowerCase().contains("success")) {
          handleSendOtp();
        } else {
          if (mounted) {
            setState(() {
              x = data;
            });
          }
        }
      } else {
        setState(() {
          x = data;
        });
      }
    } catch (e) {
      setState(() {
        x = "Network error";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void handleSendOtp() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }
    try {
      final response = await http.post(
        Uri.parse('https://flutter-backend-yetypw.fly.dev/otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _newEmailController.text.trim()}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            showOtp = true;
            resendTimer = 30;
            _otpController.clear();
          });
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send OTP')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Network error')));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void handleResendOtp() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }
    try {
      await http.post(
        Uri.parse('https://flutter-backend-yetypw.fly.dev/otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _newEmailController.text.trim()}),
      );
      if (!mounted) return;
      if (mounted) {
        setState(() {
          _otpController.clear();
          resendTimer = 30;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to resend OTP')));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void handleVerifyOtp() async {
    if (_otpController.text.length != 6) {
      if (mounted) {
        setState(() {
          otpError = "Please enter 6-digit OTP";
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        isVerifying = true;
        otpError = "";
      });
    }
    try {
      final verifyResponse = await http.post(
        Uri.parse('https://flutter-backend-yetypw.fly.dev/otp/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _newEmailController.text.trim(),
          'otp': _otpController.text,
        }),
      );
      if (!mounted) return;
      String verifyText = verifyResponse.body;
      if (!verifyText.contains("successfully")) {
        if (mounted) {
          setState(() {
            otpError = verifyText;
          });
        }
        return;
      }
      // Update email
      final updateResponse = await http.put(
        Uri.parse('https://flutter-backend-yetypw.fly.dev/user/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': userId,
          'email': _newEmailController.text.trim(),
        }),
      );
      if (!mounted) return;
      if (updateResponse.statusCode == 200) {
        // Logout
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update email')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        otpError = "Network error";
      });
    } finally {
      if (mounted) {
        setState(() {
          isVerifying = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _newEmailController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Profile'),
          backgroundColor: Colors.blue.shade700,
          automaticallyImplyLeading: false,
        ),
        body: loading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: imageBytes != null
                                ? MemoryImage(imageBytes!)
                                : (avatar != null && avatar!.isNotEmpty)
                                ? (avatar!.startsWith('data:image')
                                      ? MemoryImage(
                                          base64Decode(avatar!.split(',')[1]),
                                        )
                                      : NetworkImage(avatar!))
                                : NetworkImage(
                                    'https://i.pravatar.cc/150?u=default',
                                  ),
                          ),

                          avatar == null || avatar!.isEmpty
                              ? Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    radius: 15,
                                    backgroundColor: Colors.blue,
                                    child: Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                )
                              : Text(''),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      email ?? 'Email',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    SizedBox(height: 10),
                    if (_nameController.text.trim() != originalName.trim())
                      ElevatedButton(
                        onPressed: _saveProfile,
                        child: Text('Save Changes'),
                      ),
                    SizedBox(height: 30),
                    // Edit Profile (placeholder)
                    // ListTile(
                    //   leading: Icon(Icons.person),
                    //   title: Text('Edit Profile'),
                    //   trailing: Icon(Icons.arrow_forward),
                    //   onTap: () {
                    //     // Navigate to edit profile
                    //   },
                    // ),
                    Divider(),
                    // Change Email
                    Text(
                      'Change Email',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _newEmailController,
                      decoration: InputDecoration(
                        labelText: 'New Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (emailError.isNotEmpty)
                      Text(emailError, style: TextStyle(color: Colors.red)),
                    if (x.isNotEmpty)
                      Text(x, style: TextStyle(color: Colors.red)),
                    SizedBox(height: 10),
                    if (_newEmailController.text.trim().isNotEmpty &&
                        _newEmailController.text.trim() != originalEmail)
                      ElevatedButton(
                        onPressed: isLoading ? null : checkEmail,
                        child: Text(isLoading ? 'Sending...' : 'Get OTP'),
                      ),

                    if (showOtp) ...[
                      SizedBox(height: 20),
                      TextField(
                        controller: _otpController,
                        decoration: InputDecoration(
                          labelText: 'Enter OTP',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                      ),
                      if (otpError.isNotEmpty)
                        Text(otpError, style: TextStyle(color: Colors.red)),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: isVerifying ? null : handleVerifyOtp,
                        child: Text(isVerifying ? 'Verifying...' : 'Verify'),
                      ),
                      SizedBox(height: 10),
                      if (resendTimer > 0)
                        Text('Resend OTP in $resendTimer s')
                      else
                        TextButton(
                          onPressed: isLoading ? null : handleResendOtp,
                          child: Text('Resend OTP'),
                        ),
                    ],
                    SizedBox(height: 30),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: _logout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: Text(
                            'Logout',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }
}
