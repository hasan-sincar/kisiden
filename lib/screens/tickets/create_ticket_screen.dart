import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/database_service.dart';
import '../../utils/translations.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;
  File? _selectedImage;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  Future<void> _submitTicket() async {
    if (_subjectController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('please_add_image_and_fill'))));
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();

      final profileName = (userData?['name'] ?? '').toString().trim();
      final email = (userData?['email'] ?? user.email ?? '').toString().trim();
      final emailLocalPart = email.split('@').first.trim();
      final fallbackName = user.displayName?.trim() ?? '';
      final ticketUserName = profileName.isNotEmpty
          ? profileName
          : (emailLocalPart.isNotEmpty
                ? emailLocalPart
                : (fallbackName.isNotEmpty ? fallbackName : 'İsimsiz'));

      String? imageUrl;
      if (_selectedImage != null) {
        final ref = FirebaseStorage.instance.ref().child(
          'tickets/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      final ticketRef = await FirebaseFirestore.instance
          .collection('tickets')
          .add({
            'userId': user.uid,
            'userName': ticketUserName,
            'subject': _subjectController.text.trim(),
            'status': 'open',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      await ticketRef.collection('messages').add({
        'senderId': user.uid,
        'message': _messageController.text.trim(),
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      try {
        await DatabaseService().notifyAdminsForNewTicket(
          ticketId: ticketRef.id,
          subject: _subjectController.text.trim(),
          userName: ticketUserName,
        );
      } catch (_) {
        // Admin alert is best-effort and should not block ticket creation.
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('ticket_created_success'))));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${tr('error')} $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('create_ticket'),
          style: LocalFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      labelText: tr('ticket_subject'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: tr('ticket_message'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedImage != null) ...[
                    Image.file(_selectedImage!, height: 150, fit: BoxFit.cover),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: Text(
                      _selectedImage == null
                          ? tr(
                              'image_selected',
                            ).replaceFirst(' seçildi', ' Seç')
                          : tr('image_selected'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitTicket,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      tr('send'),
                      style: LocalFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
