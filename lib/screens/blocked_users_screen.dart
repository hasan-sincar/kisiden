import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../utils/translations.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('blocked_users'),
          style: LocalFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          List<String> blockedUsers = List<String>.from(
            userData['blockedUsers'] ?? [],
          );

          if (blockedUsers.isEmpty) {
            return Center(
              child: Text(
                'Engellediğiniz hiç kimse yok.',
                style: LocalFonts.poppins(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: blockedUsers.length,
            itemBuilder: (context, index) {
              String blockedUid = blockedUsers[index];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(blockedUid)
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox();
                  var bData =
                      userSnap.data!.data() as Map<String, dynamic>? ?? {};

                  String? photoUrl = bData['photoUrl']?.toString().trim();
                  bool hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                      child: hasPhoto ? null : const Icon(Icons.person),
                    ),
                    title: Text(
                      bData['name'] ?? tr('unknown_user'),
                      style: LocalFonts.poppins(),
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: () async {
                        await DatabaseService().unblockUser(blockedUid);
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(tr('user_unblocked'))),
                          );
                      },
                      child: Text(
                        tr('unblock_user'),
                        style: LocalFonts.poppins(fontSize: 12),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
