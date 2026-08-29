import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'; // YENİ: Sıkıştırma paketi
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../utils/translations.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _aboutController =
      TextEditingController(); // YENİ
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  Uint8List? _coverImageBytes; // YENİ
  String _contactPreference = 'both'; // YENİ
  bool _isLoading = false;
  String _originalPhoneNumber = '';
  DateTime? _lastSmsTime; // YENİ: Spam gönderimi engellemek için eklendi

  @override
  void initState() {
    super.initState();
    _nameController.text = FirebaseAuth.instance.currentUser?.displayName ?? '';
    _emailController.text = FirebaseAuth.instance.currentUser?.email ?? '';
    _originalPhoneNumber = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    _phoneController.text = _originalPhoneNumber.replaceAll('+90', '');
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();
    if (doc.exists && mounted) {
      var data = doc.data() as Map<String, dynamic>;
      setState(() {
        _emailController.text =
            data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';
        _aboutController.text = data['aboutMe'] ?? '';
        _contactPreference = data['contactPreference'] ?? 'both';
        _instagramController.text = data['instagram'] ?? '';
        _facebookController.text = data['facebook'] ?? '';
        _websiteController.text = data['website'] ?? '';
      });
    }
  }

  // YENİ: RESİM SIKIŞTIRMA FONKSİYONU
  Future<Uint8List?> _compressImage(Uint8List bytes) async {
    try {
      return await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 800,
        minHeight: 800,
        quality: 70,
        format: CompressFormat.jpeg,
      );
    } catch (e) {
      return bytes; // Web veya emülatörde desteklenmiyorsa orijinali döndür
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      final compressed = await _compressImage(bytes);
      setState(() => _imageBytes = compressed ?? bytes);
    }
  }

  Future<void> _pickCoverImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      final compressed = await _compressImage(bytes);
      setState(() => _coverImageBytes = compressed ?? bytes);
    }
  }

  void _verifyPhone() async {
    if (_phoneController.text.trim().length != 10) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('enter_10_digits'))));
      return;
    }

    // YENİ: 60 Saniye Spam Kontrolü
    if (_lastSmsTime != null &&
        DateTime.now().difference(_lastSmsTime!).inSeconds < 60) {
      int secondsLeft = 60 - DateTime.now().difference(_lastSmsTime!).inSeconds;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tr('wait_before_retry')} $secondsLeft ${tr('seconds')}',
          ),
        ),
      );
      return;
    }

    String newPhone = '+90${_phoneController.text.trim()}';
    if (newPhone == _originalPhoneNumber) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('already_current_number'))));
      return;
    }

    setState(() => _isLoading = true);

    bool isRegistered = await _dbService.isPhoneNumberRegistered(newPhone);
    if (isRegistered) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('number_already_registered'))));
      return;
    }

    _lastSmsTime = DateTime.now(); // Son SMS gönderim zamanını kaydet
    if (_originalPhoneNumber.isNotEmpty) {
      _startVerification(
        _originalPhoneNumber,
        isOldNumber: true,
        newPhone: newPhone,
      );
    } else {
      _startVerification(newPhone, isOldNumber: false, newPhone: newPhone);
    }
  }

  void _startVerification(
    String phoneToVerify, {
    required bool isOldNumber,
    required String newPhone,
  }) async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneToVerify,
      verificationCompleted: (PhoneAuthCredential c) async {
        if (isOldNumber) {
          try {
            await FirebaseAuth.instance.currentUser
                ?.reauthenticateWithCredential(c);
            _startVerification(
              newPhone,
              isOldNumber: false,
              newPhone: newPhone,
            );
          } catch (e) {
            setState(() => _isLoading = false);
          }
        } else {
          try {
            await FirebaseAuth.instance.currentUser?.updatePhoneNumber(c);
            await _dbService.updatePhoneNumber(
              FirebaseAuth.instance.currentUser!.uid,
              newPhone,
            );
            if (mounted) {
              setState(() {
                _isLoading = false;
                _originalPhoneNumber = newPhone;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('number_updated_successfully'))),
              );
            }
          } catch (e) {
            setState(() => _isLoading = false);
          }
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        String msg = '${tr('error')} ${e.message}';
        // YENİ: Too Many Requests hatasını Türkçe yakalama
        if (e.code == 'too-many-requests') msg = tr('too_many_sms_requests');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      },
      codeSent: (String vId, int? resendToken) {
        setState(() => _isLoading = false);
        _showOTPDialog(
          vId,
          phoneToVerify,
          isOldNumber: isOldNumber,
          newPhone: newPhone,
        );
      },
      codeAutoRetrievalTimeout: (String vId) {},
    );
  }

  // YENİ: E-POSTA İLE DOĞRULAMA (FALLBACK) PENCERESİ
  void _sendEmailCodeAndShowDialog(String email, String newPhone) async {
    setState(() => _isLoading = true);

    String code = (100000 + Random().nextInt(900000)).toString();

    await FirebaseFirestore.instance.collection('mailCodes').add({
      'email': email,
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() => _isLoading = false);

    final TextEditingController codeController = TextEditingController();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  size: 40,
                  color: Colors.orange[800],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('email_verification'),
                style: LocalFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                tr('enter_email_security_code').replaceFirst('%s', email),
                style: LocalFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: LocalFonts.poppins(
                  fontSize: 20,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: tr('masked_code_placeholder'),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        tr('cancel'),
                        style: LocalFonts.poppins(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (codeController.text.trim() == code) {
                          Navigator.pop(context);
                          setState(() => _isLoading = true);
                          _lastSmsTime = DateTime.now();
                          _startVerification(
                            newPhone,
                            isOldNumber: false,
                            newPhone: newPhone,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(tr('invalid_verification_code')),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        tr('verify'),
                        style: LocalFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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

  void _showEmailFallbackDialog(String newPhone) {
    final TextEditingController emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.security, size: 40, color: Colors.blue[800]),
              ),
              const SizedBox(height: 16),
              Text(
                tr('security_verification'),
                style: LocalFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                tr('email_fallback_desc'),
                style: LocalFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: tr('your_email_address'),
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        tr('cancel'),
                        style: LocalFonts.poppins(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (emailController.text.trim().toLowerCase() ==
                            FirebaseAuth.instance.currentUser?.email
                                ?.toLowerCase()) {
                          Navigator.pop(context);
                          _sendEmailCodeAndShowDialog(
                            emailController.text.trim(),
                            newPhone,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(tr('email_mismatch'))),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        tr('verify'),
                        style: LocalFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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

  void _showOTPDialog(
    String vId,
    String phoneBeingVerified, {
    required bool isOldNumber,
    required String newPhone,
  }) {
    final TextEditingController otpController = TextEditingController();
    String title = isOldNumber
        ? tr('verify_current_number')
        : tr('verify_new_number');
    String hint = isOldNumber
        ? tr('code_sent_to_old_number')
        : tr('code_sent_to_new_number');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.message_outlined,
                  size: 40,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: LocalFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                hint,
                style: LocalFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: LocalFonts.poppins(
                  fontSize: 20,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: tr('masked_code_placeholder'),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              if (isOldNumber) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showEmailFallbackDialog(newPhone);
                  },
                  child: Text(
                    tr('no_access_to_old_number'),
                    style: LocalFonts.poppins(
                      color: Colors.red[600],
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => _isLoading = false);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        tr('cancel'),
                        style: LocalFonts.poppins(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          PhoneAuthCredential c = PhoneAuthProvider.credential(
                            verificationId: vId,
                            smsCode: otpController.text.trim(),
                          );
                          if (isOldNumber) {
                            await FirebaseAuth.instance.currentUser
                                ?.reauthenticateWithCredential(c);
                            if (context.mounted) {
                              Navigator.pop(context);
                              setState(() => _isLoading = true);
                              _startVerification(
                                newPhone,
                                isOldNumber: false,
                                newPhone: newPhone,
                              );
                            }
                          } else {
                            await FirebaseAuth.instance.currentUser
                                ?.updatePhoneNumber(c);
                            await _dbService.updatePhoneNumber(
                              FirebaseAuth.instance.currentUser!.uid,
                              newPhone,
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                              setState(() {
                                _originalPhoneNumber = newPhone;
                                _isLoading = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    tr('number_updated_successfully'),
                                  ),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(tr('invalid_code_or_failed')),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        tr('verify'),
                        style: LocalFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      String? photoUrl;
      String? coverPhotoUrl;
      if (_imageBytes != null)
        photoUrl = await _dbService.uploadImage(
          _imageBytes!,
          "profile_${FirebaseAuth.instance.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}",
        );
      if (_coverImageBytes != null)
        coverPhotoUrl = await _dbService.uploadImage(
          _coverImageBytes!,
          "cover_${FirebaseAuth.instance.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}",
        );
      await _dbService.updateUserProfile(
        _nameController.text.trim(),
        _emailController.text.trim(),
        photoUrl,
        _aboutController.text.trim(),
        coverPhotoUrl,
        _contactPreference,
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
            'instagram': _instagramController.text.trim(),
            'facebook': _facebookController.text.trim(),
            'website': _websiteController.text.trim(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('profile_updated_successfully'))),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${tr('error')}$e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(
    String label,
    String hint,
    IconData icon,
    TextEditingController controller, {
    int maxLines = 1,
    bool readOnly = false,
    TextInputType? keyboardType,
    Color? iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: LocalFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          readOnly: readOnly,
          keyboardType: keyboardType,
          style: LocalFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: LocalFonts.poppins(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            prefixIcon: Icon(
              icon,
              color: iconColor ?? Colors.grey[500],
              size: 22,
            ),
            filled: true,
            fillColor: readOnly ? Colors.grey[100] : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          tr('edit_profile'),
          style: LocalFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: _isLoading
              ? const SizedBox(
                  height: 54,
                  child: Center(child: CircularProgressIndicator()),
                )
              : ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                  ),
                  child: Text(
                    tr('save_changes'),
                    style: LocalFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // MODERN KAPAK VE PROFİL RESMİ YERLEŞİMİ
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                GestureDetector(
                  onTap: _pickCoverImage,
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    margin: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 20,
                      bottom: 50,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(16),
                      image: _coverImageBytes != null
                          ? DecorationImage(
                              image: MemoryImage(_coverImageBytes!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _coverImageBytes == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                color: Colors.blue[300],
                                size: 36,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tr('add_cover_photo'),
                                style: LocalFonts.poppins(
                                  color: Colors.blue[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : const Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                radius: 18,
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 10),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[100],
                            backgroundImage: _imageBytes != null
                                ? MemoryImage(_imageBytes!)
                                : (FirebaseAuth
                                                  .instance
                                                  .currentUser
                                                  ?.photoURL !=
                                              null
                                          ? NetworkImage(
                                              FirebaseAuth
                                                  .instance
                                                  .currentUser!
                                                  .photoURL!,
                                            )
                                          : null)
                                      as ImageProvider?,
                            child:
                                _imageBytes == null &&
                                    FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.photoURL ==
                                        null
                                ? Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.blue[800],
                                  )
                                : null,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue[800],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: Colors.blue[800],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tr('personal_information'),
                              style: LocalFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          tr('full_name'),
                          tr('your_name_and_surname'),
                          Icons.person_outline,
                          _nameController,
                        ),
                        _buildTextField(
                          tr('email_address'),
                          tr('your_email_address'),
                          Icons.email_outlined,
                          _emailController,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        _buildTextField(
                          tr('about_me_store_description'),
                          tr('tell_about_yourself_or_store'),
                          Icons.info_outline,
                          _aboutController,
                          maxLines: 3,
                        ),

                        Text(
                          tr('contact_preference'),
                          style: LocalFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _contactPreference,
                          isExpanded: true,
                          icon: const Icon(Icons.expand_more),
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.contact_mail_outlined,
                              color: Colors.grey[500],
                              size: 22,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.blue.shade400,
                                width: 2,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'both',
                              child: Text(
                                tr('all_message_call'),
                                style: LocalFonts.poppins(fontSize: 14),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'message_only',
                              child: Text(
                                tr('message_only'),
                                style: LocalFonts.poppins(fontSize: 14),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'call_only',
                              child: Text(
                                tr('call_whatsapp_only'),
                                style: LocalFonts.poppins(fontSize: 14),
                              ),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => _contactPreference = val!),
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<bool>(
                          stream: _dbService.emailNotificationsStream(),
                          builder: (context, snapshot) {
                            bool isEnabled = snapshot.data ?? true;
                            return SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                tr('email_notifications'),
                                style: LocalFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                tr('email_notifications_desc'),
                                style: LocalFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              value: isEnabled,
                              activeThumbColor: Colors.blue[800],
                              onChanged: (bool value) async {
                                await _dbService.toggleEmailNotifications(
                                  value,
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.link, color: Colors.blue[800], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              tr('social_media_and_web'),
                              style: LocalFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          tr('instagram_username_or_link'),
                          '@kullaniciadi',
                          Icons.camera_alt_outlined,
                          _instagramController,
                          iconColor: Colors.purple,
                        ),
                        _buildTextField(
                          tr('facebook_profile_link'),
                          'facebook.com/profil',
                          Icons.facebook,
                          _facebookController,
                          iconColor: Colors.blue,
                        ),
                        _buildTextField(
                          tr('your_website'),
                          tr('example_website'),
                          Icons.language,
                          _websiteController,
                          iconColor: Colors.green,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.security,
                              color: Colors.blue[800],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tr('contact_info_sms_verified'),
                              style: LocalFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('phone_verification_desc'),
                          style: LocalFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          tr('your_phone_number'),
                          '555 555 55 55',
                          Icons.phone_outlined,
                          _phoneController,
                          keyboardType: TextInputType.phone,
                        ),

                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                                onPressed: _verifyPhone,
                                icon: const Icon(
                                  Icons.verified_user,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                label: Text(
                                  tr('verify_number'),
                                  style: LocalFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[600],
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
