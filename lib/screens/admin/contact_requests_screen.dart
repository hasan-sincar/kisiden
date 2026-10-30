import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/local_fonts.dart';
import '../../utils/theme_colors.dart';
import '../../utils/translations.dart';

class ContactRequestsAdminTab extends StatelessWidget {
  const ContactRequestsAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('contact_requests')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                tr('contact_requests_load_failed'),
                textAlign: TextAlign.center,
                style: LocalFonts.poppins(color: Colors.red.shade700),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final requests = snapshot.data?.docs ?? [];
        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.mark_email_read_outlined,
                    color: AppColors.primary,
                    size: 56,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('contact_requests_empty'),
                    textAlign: TextAlign.center,
                    style: LocalFonts.poppins(
                      color: const Color(0xFF69758A),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data();
            final status = data['status']?.toString() ?? 'open';
            final isAnswered = status == 'answered';
            final createdAt = data['createdAt'] as Timestamp?;
            final topic = data['topic']?.toString() ?? tr('contact_us');
            final name = data['name']?.toString() ?? '';
            final email = data['email']?.toString() ?? '';
            final message = data['message']?.toString() ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE8EDF5)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: Text(
                  topic,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LocalFonts.poppins(
                    color: const Color(0xFF243047),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    '$name · $email\n${createdAt == null ? '' : DateFormat('dd.MM.yyyy HH:mm').format(createdAt.toDate())}\n$message',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: LocalFonts.poppins(
                      color: const Color(0xFF758196),
                      fontSize: 11,
                    ),
                  ),
                ),
                isThreeLine: true,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (isAnswered ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tr(
                      isAnswered
                          ? 'ticket_status_answered'
                          : 'ticket_status_open',
                    ),
                    style: LocalFonts.poppins(
                      color: isAnswered
                          ? Colors.green.shade800
                          : Colors.orange.shade900,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ContactRequestDetailScreen(requestId: request.id),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ContactRequestDetailScreen extends StatefulWidget {
  const ContactRequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<ContactRequestDetailScreen> createState() =>
      _ContactRequestDetailScreenState();
}

class _ContactRequestDetailScreenState
    extends State<ContactRequestDetailScreen> {
  final _replyController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final message = _replyController.text.trim();
    if (_isSending || message.isEmpty) return;
    if (message.length > 5000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('contact_request_reply_too_long'))),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSending = true);
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('replyToContactRequest')
          .call({'requestId': widget.requestId, 'message': message});
      if (!mounted) return;
      _replyController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('contact_request_reply_sent'))));
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = error.code == 'unavailable'
          ? tr('contact_request_email_unavailable')
          : tr('contact_request_reply_failed');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      debugPrint('Bize Ulaşın yanıtı gönderilemedi: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('contact_request_reply_failed'))),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestRef = FirebaseFirestore.instance
        .collection('contact_requests')
        .doc(widget.requestId);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          tr('contact_request_detail'),
          style: LocalFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: requestRef.snapshots(),
        builder: (context, requestSnapshot) {
          if (requestSnapshot.hasError) {
            return Center(child: Text(tr('contact_request_load_failed')));
          }
          if (!requestSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final data = requestSnapshot.data?.data();
          if (data == null) {
            return Center(child: Text(tr('contact_request_load_failed')));
          }

          final createdAt = data['createdAt'] as Timestamp?;
          return Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: requestRef
                      .collection('replies')
                      .orderBy('createdAt')
                      .snapshots(),
                  builder: (context, repliesSnapshot) {
                    final replies = repliesSnapshot.data?.docs ?? [];
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE7ECF4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['topic']?.toString() ?? tr('contact_us'),
                                style: LocalFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF243047),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${data['name'] ?? ''} · ${data['email'] ?? ''}',
                                style: LocalFonts.poppins(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (createdAt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat(
                                    'dd.MM.yyyy HH:mm',
                                  ).format(createdAt.toDate()),
                                  style: LocalFonts.poppins(
                                    color: const Color(0xFF8994A6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                              const Divider(height: 24),
                              SelectableText(
                                data['message']?.toString() ?? '',
                                style: LocalFonts.poppins(
                                  color: const Color(0xFF34415A),
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (repliesSnapshot.hasError)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              tr('contact_request_replies_load_failed'),
                              style: LocalFonts.poppins(
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        for (final reply in replies)
                          _buildReplyCard(reply.data()),
                      ],
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE7ECF4))),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 5000,
                          decoration: InputDecoration(
                            hintText: tr('contact_request_reply_hint'),
                            counterText: '',
                            filled: true,
                            fillColor: const Color(0xFFF5F7FB),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 48,
                        width: 48,
                        child: FilledButton(
                          onPressed: _isSending ? null : _sendReply,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isSending
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 19),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReplyCard(Map<String, dynamic> data) {
    final createdAt = data['createdAt'] as Timestamp?;
    final status = data['status']?.toString() ?? 'sent';
    final failed = status == 'failed';
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        margin: const EdgeInsets.only(top: 12, left: 32),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: failed ? const Color(0xFFFFF0EF) : const Color(0xFFEAF1FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['message']?.toString() ?? '',
              style: LocalFonts.poppins(
                color: const Color(0xFF34415A),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              failed
                  ? tr('contact_request_reply_email_failed')
                  : status != 'sent' || createdAt == null
                  ? tr('contact_request_reply_sending')
                  : DateFormat('dd.MM.yyyy HH:mm').format(createdAt.toDate()),
              style: LocalFonts.poppins(
                color: failed ? Colors.red.shade700 : const Color(0xFF758196),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
