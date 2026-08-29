import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../utils/translations.dart';
import '../../utils/theme_colors.dart';
import '../../services/database_service.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  final String subject;
  final String status;

  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.subject,
    required this.status,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
    _listenToStatus();
  }

  void _listenToStatus() {
    FirebaseFirestore.instance
        .collection('tickets')
        .doc(widget.ticketId)
        .snapshots()
        .listen((doc) {
          if (doc.exists && mounted) {
            setState(() {
              _currentStatus = doc.data()?['status'] ?? 'open';
            });
          }
        });
  }

  Future<void> _sendMessage({File? imageFile}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && imageFile == null) return;

    setState(() {
      _isSending = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final ticketDoc = await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .get();
      final ticketOwnerId = ticketDoc.data()?['userId'] ?? '';
      final bool isAdmin = user.uid != ticketOwnerId;

      String? imageUrl;
      if (imageFile != null) {
        final ref = FirebaseStorage.instance.ref().child(
          'tickets/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await ref.putFile(imageFile);
        imageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .collection('messages')
          .add({
            'senderId': user.uid,
            'senderName': user.displayName ?? 'İsimsiz',
            'message': text,
            'imageUrl': imageUrl,
            'createdAt': FieldValue.serverTimestamp(),
          });

      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .update({
            'updatedAt': FieldValue.serverTimestamp(),
            'status': isAdmin ? 'answered' : 'open',
          });

      if (isAdmin && ticketOwnerId.isNotEmpty) {
        await DatabaseService().sendNotification(
          ticketOwnerId,
          tr('ticket_status_answered'),
          '${widget.subject} konulu destek talebinize yeni bir cevap geldi.',
          type: 'ticket',
          targetId: widget.ticketId,
        );
      }

      _messageController.clear();
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${tr('error')} $e')));
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked != null) {
      _sendMessage(imageFile: File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    bool isClosed = _currentStatus == 'closed';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.subject,
          style: LocalFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          if (isClosed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade100,
              child: Text(
                tr('ticket_closed_cannot_reply'),
                textAlign: TextAlign.center,
                style: LocalFonts.poppins(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tickets')
                  .doc(widget.ticketId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == user?.uid;
                    final message = data['message'] ?? '';
                    final imageUrl = data['imageUrl'];
                    final time = data['createdAt'] as Timestamp?;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (imageUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(imageUrl),
                                ),
                              ),
                            if (message.isNotEmpty)
                              Text(message, style: LocalFonts.poppins()),
                            const SizedBox(height: 4),
                            Text(
                              time != null
                                  ? DateFormat('HH:mm').format(time.toDate())
                                  : '',
                              style: LocalFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (!isClosed)
            SafeArea(
              child: Container(
                padding: const EdgeInsets.only(
                  left: 8,
                  right: 8,
                  top: 8,
                  bottom: 20,
                ),
                color: Colors.white,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image, color: Colors.blue),
                      onPressed: _isSending ? null : _pickImage,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: tr('reply_ticket'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isSending
                        ? const CircularProgressIndicator()
                        : IconButton(
                            icon: const Icon(
                              Icons.send,
                              color: AppColors.primary,
                            ),
                            onPressed: _sendMessage,
                          ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
