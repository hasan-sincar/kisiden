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
      appBar: AppBar(
        title: Text(tr('support_tickets'), style: LocalFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tickets')
            .where('userId', isEqualTo: user.uid)
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Bu hata genellikle Firestore'da index eksik olduğunda ortaya çıkar.
            // Hata mesajını konsolda (Debug Console) kontrol edin, orada indeksi oluşturmak için bir link olacaktır.
            debugPrint("TICKET LİSTELEME HATASI: ${snapshot.error}");
            return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('${tr('error')} Veri çekilemedi. Lütfen konsoldeki Firestore index hatasını kontrol edin.', textAlign: TextAlign.center)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text(tr('no_tickets'), style: LocalFonts.poppins(fontSize: 16)));
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final ticketId = docs[index].id;
              final subject = data['subject'] ?? '';
              final status = data['status'] ?? 'open';
              final updatedAt = data['updatedAt'] as Timestamp?;
              
              Color statusColor = Colors.blue;
              String statusText = tr('ticket_status_open');
              if (status == 'answered') {
                statusColor = Colors.green;
                statusText = tr('ticket_status_answered');
              } else if (status == 'closed') {
                statusColor = Colors.grey;
                statusText = tr('ticket_status_closed');
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: ticketId, subject: subject, status: status)));
                  },
                  title: Text(subject, style: LocalFonts.poppins(fontWeight: FontWeight.bold)),
                  subtitle: Text(updatedAt != null ? DateFormat('dd.MM.yyyy HH:mm').format(updatedAt.toDate()) : '', style: LocalFonts.poppins(fontSize: 12, color: Colors.grey)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(statusText, style: LocalFonts.poppins(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTicketScreen()));
        },
        icon: const Icon(Icons.add),
        label: Text(tr('create_ticket'), style: LocalFonts.poppins()),
      ),
    );
  }
}
