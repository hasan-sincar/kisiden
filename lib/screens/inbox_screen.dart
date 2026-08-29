import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'chat_screen.dart';
import 'package:intl/intl.dart';
import '../utils/translations.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});
  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  Set<String> selectedChats = {};
  bool isSelectionMode = false;

  void _deleteSelected() async {
    for (String chatId in selectedChats) {
      await DatabaseService().deleteChat(chatId);
    }
    setState(() {
      selectedChats.clear();
      isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isSelectionMode
              ? tr(
                  'selected_count',
                ).replaceFirst('%s', '${selectedChats.length}')
              : tr('my_messages_title'),
          style: LocalFonts.poppins(),
        ),
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  isSelectionMode = false;
                  selectedChats.clear();
                }),
              )
            : null,
        actions: [
          if (isSelectionMode && selectedChats.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteSelected,
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUserId)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mesaj Kutunuz Boş',
                    style: LocalFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'İlanlarınıza gelen mesajlar, sorular ve yeni teklifler burada listelenecektir.',
                      textAlign: TextAlign.center,
                      style: LocalFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String chatId = docs[index].id;

              List participants = data['participants'];
              String otherUserId = participants.firstWhere(
                (id) => id != currentUserId,
              );

              List unreadBy = data['unreadBy'] ?? [];
              bool isUnread = unreadBy.contains(currentUserId);
              bool isSelected = selectedChats.contains(chatId);

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUserId)
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox();
                  var userData = userSnap.data!.data() as Map<String, dynamic>?;
                  if (userData == null) return const SizedBox();

                  bool hasValidImage =
                      userData['photoUrl'] != null &&
                      userData['photoUrl'].toString().trim().isNotEmpty;

                  DateTime? lastMsgTime;
                  if (data['lastMessageTime'] != null) {
                    lastMsgTime = (data['lastMessageTime'] as Timestamp)
                        .toDate();
                  }
                  String timeString = '';
                  if (lastMsgTime != null) {
                    final now = DateTime.now();
                    if (lastMsgTime.day == now.day &&
                        lastMsgTime.month == now.month &&
                        lastMsgTime.year == now.year) {
                      timeString = DateFormat('HH:mm').format(lastMsgTime);
                    } else {
                      timeString = DateFormat('dd.MM.yyyy').format(lastMsgTime);
                    }
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue.withValues(alpha: 0.1)
                          : (isUnread
                                ? Colors.blue.withValues(alpha: 0.02)
                                : Colors.transparent),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: isUnread
                            ? Colors.blue
                            : Colors.grey[300],
                        backgroundImage: hasValidImage
                            ? NetworkImage(userData['photoUrl'])
                            : null,
                        onBackgroundImageError: hasValidImage
                            ? (exception, stackTrace) {}
                            : null,
                        child: !hasValidImage
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      title: Text(
                        userData['name'] ?? 'İsimsiz',
                        style: LocalFonts.poppins(
                          fontWeight: isUnread
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          if (data['listingTitle'] != null &&
                              data['listingTitle'].toString().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 12,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      data['listingTitle'],
                                      style: LocalFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey[700],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            data['lastMessage'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LocalFonts.poppins(
                              fontSize: 13,
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isUnread
                                  ? Colors.black87
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (timeString.isNotEmpty)
                            Text(
                              timeString,
                              style: LocalFonts.poppins(
                                fontSize: 11,
                                color: isUnread
                                    ? Colors.blue[800]
                                    : Colors.grey[500],
                                fontWeight: isUnread
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          const SizedBox(height: 6),
                          if (isUnread)
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.blue[800],
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      selected: isSelected,
                      onLongPress: () {
                        setState(() {
                          isSelectionMode = true;
                          selectedChats.add(chatId);
                        });
                      },
                      onTap: () {
                        if (isSelectionMode) {
                          setState(() {
                            if (isSelected) {
                              selectedChats.remove(chatId);
                              if (selectedChats.isEmpty)
                                isSelectionMode = false;
                            } else {
                              selectedChats.add(chatId);
                            }
                          });
                        } else {
                          DatabaseService().markChatAsRead(chatId);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                receiverId: otherUserId,
                                receiverName: userData['name'] ?? 'İsimsiz',
                                listingTitle: data['listingTitle'],
                                listingId: data['listingId'],
                                listingImage: data['listingImage'],
                                listingPrice: data['listingPrice']?.toString(),
                              ),
                            ),
                          );
                        }
                      },
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
