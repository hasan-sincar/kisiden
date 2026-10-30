import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:intl/intl.dart';
import '../../utils/translations.dart';
import 'create_ticket_screen.dart';
import 'ticket_detail_screen.dart';

class UserTicketsScreen extends StatelessWidget {
  const UserTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        title: Text(
          tr('support_tickets'),
          style: LocalFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tickets')
            .where('userId', isEqualTo: user.uid)
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint("TICKET LİSTELEME HATASI: ${snapshot.error}");
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  '${tr('error')} Veri çekilemedi. Lütfen konsoldeki Firestore index hatasını kontrol edin.',
                  textAlign: TextAlign.center,
                  style: LocalFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF657188),
                  ),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF246BDF)),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
            children: [
              _buildHeader(docs.length),
              const SizedBox(height: 20),
              ...docs.map((ticket) {
                final data = ticket.data() as Map<String, dynamic>;
                final ticketId = ticket.id;
                final subject = (data['subject'] ?? '').toString();
                final status = (data['status'] ?? 'open').toString();
                final updatedAt = data['updatedAt'] as Timestamp?;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildTicketCard(
                    context: context,
                    ticketId: ticketId,
                    subject: subject,
                    status: status,
                    updatedAt: updatedAt,
                  ),
                );
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateTicketScreen()),
          );
        },
        backgroundColor: const Color(0xFF1455C0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('create_ticket'), style: LocalFonts.poppins()),
      ),
    );
  }

  Widget _buildHeader(int ticketCount) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF142C67), Color(0xFF1763D4), Color(0xFF3B8AF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5CC1).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('support_tickets'),
                  style: LocalFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$ticketCount',
                  style: LocalFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.headset_mic_rounded,
            color: Color(0xFFFFD875),
            size: 25,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 92,
              width: 92,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FF),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                size: 44,
                color: Color(0xFF246BDF),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              tr('no_tickets'),
              textAlign: TextAlign.center,
              style: LocalFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF34415A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard({
    required BuildContext context,
    required String ticketId,
    required String subject,
    required String status,
    required Timestamp? updatedAt,
  }) {
    final statusInfo = _statusStyle(status);
    final dateText = updatedAt != null
        ? DateFormat('dd.MM.yyyy  HH:mm').format(updatedAt.toDate())
        : '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TicketDetailScreen(
                ticketId: ticketId,
                subject: subject,
                status: status,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7ECF4)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1D345C).withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF3FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  color: Color(0xFF356CC4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: LocalFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF202C43),
                      ),
                    ),
                    if (dateText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: Color(0xFF8994A7),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            dateText,
                            style: LocalFonts.poppins(
                              fontSize: 10,
                              color: const Color(0xFF7B879B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusInfo.$2.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusInfo.$1,
                  style: LocalFonts.poppins(
                    color: statusInfo.$2,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color) _statusStyle(String status) {
    if (status == 'answered') {
      return (tr('ticket_status_answered'), const Color(0xFF258451));
    }
    if (status == 'closed') {
      return (tr('ticket_status_closed'), const Color(0xFF748094));
    }
    return (tr('ticket_status_open'), const Color(0xFF2868C7));
  }
}
