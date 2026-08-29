import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../utils/translations.dart';
import '../../../services/database_service.dart';

class AdminTicketDetailScreen extends StatefulWidget {
  final String ticketId;
  final String subject;
  final String userId;

  const AdminTicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.subject,
    required this.userId,
  });

  @override
  State<AdminTicketDetailScreen> createState() =>
      _AdminTicketDetailScreenState();
}

class _AdminTicketDetailScreenState extends State<AdminTicketDetailScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  String _currentStatus = 'open';

  @override
  void initState() {
    super.initState();
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

  Future<void> _updateStatus(String newStatus, {bool notify = false}) async {
    await FirebaseFirestore.instance
        .collection('tickets')
        .doc(widget.ticketId)
        .update({
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

    if (notify) {
      final ticketDoc = await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .get();
      final targetUserId = ticketDoc.data()?['userId'] ?? widget.userId;

      if (targetUserId != null && targetUserId.toString().isNotEmpty) {
        String statusText = newStatus == 'closed'
            ? tr('ticket_status_closed')
            : (newStatus == 'answered'
                  ? tr('ticket_status_answered')
                  : tr('ticket_status_open'));

        await DatabaseService().sendNotification(
          targetUserId,
          tr('ticket_updated_title'),
          '${widget.subject} ${tr('ticket_updated_message_suffix_1')} "$statusText"${tr('ticket_updated_message_suffix_2')}',
          type: 'ticket',
          targetId: widget.ticketId,
        );
      }
    }
  }

  Future<void> _sendMessage({File? imageFile}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && imageFile == null) return;

    setState(() {
      _isSending = true;
    });
    try {
      const adminUploaderId = 'admin';

      String? imageUrl;
      if (imageFile != null) {
        final ref = FirebaseStorage.instance.ref().child(
          'tickets/$adminUploaderId/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await ref.putFile(imageFile);
        imageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .collection('messages')
          .add({
            'senderId': adminUploaderId,
            'message': text,
            'imageUrl': imageUrl,
            'createdAt': FieldValue.serverTimestamp(),
          });

      await _updateStatus('answered');

      // YENİ: Bildirimin doğru kişiye gitmesi için asıl kullanıcının ID'sini garantili olarak DB'den çekiyoruz
      final ticketDoc = await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .get();
      final targetUserId = ticketDoc.data()?['userId'] ?? widget.userId;

      if (targetUserId != null && targetUserId.toString().isNotEmpty) {
        await DatabaseService().sendNotification(
          targetUserId,
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
    bool isClosed = _currentStatus == 'closed';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin: ${widget.subject}',
          style: LocalFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) => _updateStatus(val, notify: true),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'open', child: Text(tr('open_ticket'))),
              PopupMenuItem(
                value: 'answered',
                child: Text(tr('ticket_status_answered')),
              ),
              PopupMenuItem(value: 'closed', child: Text(tr('close_ticket'))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: _currentStatus == 'closed'
                ? Colors.red.shade100
                : (_currentStatus == 'answered'
                      ? Colors.green.shade100
                      : Colors.blue.shade100),
            child: Text(
              'Durum: ${_currentStatus.toUpperCase()}',
              textAlign: TextAlign.center,
              style: LocalFonts.poppins(fontWeight: FontWeight.bold),
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
                    final isAdmin = data['senderId'] == 'admin';
                    final message = data['message'] ?? '';
                    final imageUrl = data['imageUrl'];
                    final time = data['createdAt'] as Timestamp?;

                    return Align(
                      alignment: isAdmin
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? Colors.green.shade100
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAdmin ? tr('admin_role') : tr('user'),
                              style: LocalFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
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
            Container(
              padding: const EdgeInsets.all(8),
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
                          icon: const Icon(Icons.send, color: Colors.green),
                          onPressed: _sendMessage,
                        ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
