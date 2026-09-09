import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'listing_detail_screen.dart';
import 'chat_screen.dart';
import '../utils/translations.dart';
import 'seller_profile_screen.dart';
import 'tickets/ticket_detail_screen.dart';
import 'admin/admin_ticket_detail_screen.dart';
import 'all_listings_screen.dart';
import '../utils/auth_gate.dart';
import '../utils/home_widget_sync.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _marketingLabel(String type) {
    if (type == 'campaign') return tr('marketing_campaign_label');
    if (type == 'category_promo') return tr('marketing_category_promo_label');
    return tr('marketing_announcement_label');
  }

  Color _marketingColor(String type) {
    if (type == 'campaign') return const Color(0xFF0F766E);
    if (type == 'category_promo') return const Color(0xFF1D4ED8);
    return const Color(0xFF6D28D9);
  }

  String _formatTimestamp(dynamic rawTimestamp) {
    if (rawTimestamp is! Timestamp) return '';
    final dt = rawTimestamp.toDate();
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day.$month • $hour:$minute';
  }

  Future<bool> _openChatNotification(
    BuildContext context,
    String currentUserId,
    String chatRoomId,
  ) async {
    if (chatRoomId.isEmpty) return false;

    final chatDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatRoomId)
        .get();
    final chatData = chatDoc.data();
    final participants = chatData?['participants'];
    if (!chatDoc.exists || chatData == null || participants is! List) {
      return false;
    }

    String? otherUserId;
    for (final participant in participants) {
      final candidate = participant.toString();
      if (candidate != currentUserId && candidate.isNotEmpty) {
        otherUserId = candidate;
        break;
      }
    }
    final receiverId = otherUserId;
    if (receiverId == null || receiverId.isEmpty || !context.mounted) {
      return false;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(receiverId)
        .get();
    final userData = userDoc.data() ?? <String, dynamic>{};
    if (!context.mounted) return false;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: receiverId,
          receiverName: userData['name']?.toString() ?? tr('user'),
          listingTitle: chatData['listingTitle']?.toString(),
          listingId: chatData['listingId']?.toString(),
          listingImage: chatData['listingImage']?.toString(),
          listingPrice: chatData['listingPrice']?.toString(),
          listingLatitude: (chatData['listingLatitude'] as num?)?.toDouble(),
          listingLongitude: (chatData['listingLongitude'] as num?)?.toDouble(),
        ),
      ),
    );
    return true;
  }

  void _markAllAsRead(String uid) async {
    var snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();
    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  void _clearAll(String uid) async {
    var snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .get();
    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (!AuthGate.isRegistered || user == null) {
      HomeWidgetSync.syncUnreadNotifications(0);
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(tr('notifications'), style: LocalFonts.poppins()),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications_off_outlined, size: 54),
                const SizedBox(height: 16),
                Text(
                  tr('login_required_notifications'),
                  textAlign: TextAlign.center,
                  style: LocalFonts.poppins(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => AuthGate.requireRegisteredUser(
                    context,
                    message: tr('login_required_notifications'),
                  ),
                  child: Text(tr('login_action'), style: LocalFonts.poppins()),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final uid = user.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(tr('notifications'), style: LocalFonts.poppins()),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (value) {
              if (value == 'read_all') _markAllAsRead(uid);
              if (value == 'clear_all') _clearAll(uid);
            },
            itemBuilder: (context) => [
              TextPopupMenuItem(
                value: 'read_all',
                child: Text(tr('mark_all_read'), style: LocalFonts.poppins()),
              ),
              TextPopupMenuItem(
                value: 'clear_all',
                child: Text(
                  tr('clear_all'),
                  style: LocalFonts.poppins(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            var docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              HomeWidgetSync.syncUnreadNotifications(0);
              return Center(
                child: Text(
                  tr('no_notifications'),
                  style: LocalFonts.poppins(color: Colors.grey),
                ),
              );
            }

            final unreadCount = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return (data['isRead'] ?? false) == false;
            }).length;
            HomeWidgetSync.syncUnreadNotifications(unreadCount);

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                var data = docs[index].data() as Map<String, dynamic>;
                String docId = docs[index].id;
                bool isRead = data['isRead'] ?? false;
                final title = data['title']?.toString() ?? '';
                final message = data['message']?.toString() ?? '';
                final reason = data['reason']?.toString().trim() ?? '';
                final imageUrl = data['imageUrl']?.toString().trim() ?? '';
                final hasImage = imageUrl.isNotEmpty;
                final hasReason = reason.isNotEmpty;
                final type = data['type']?.toString() ?? 'general';
                final normalizedTitle = title.toLowerCase();
                final isModerationNotice =
                    hasReason ||
                    normalizedTitle.contains('düzenleme') ||
                    normalizedTitle.contains('redded') ||
                    normalizedTitle.contains('needs edit') ||
                    normalizedTitle.contains('rejected');
                final isMarketingNotice =
                    type == 'campaign' ||
                    type == 'category_promo' ||
                    type == 'announcement';

                final tileUnreadColor = isModerationNotice
                    ? Colors.orange.withValues(alpha: 0.07)
                    : (isMarketingNotice
                          ? Colors.indigo.withValues(alpha: 0.06)
                          : Colors.blue.withValues(alpha: 0.05));
                final leadingBgColor = isRead
                    ? Colors.grey[300]
                    : (isModerationNotice
                          ? Colors.orange[100]
                          : (isMarketingNotice
                                ? Colors.indigo[100]
                                : Colors.blue[100]));
                final leadingIconColor = isRead
                    ? Colors.grey[600]
                    : (isModerationNotice
                          ? Colors.deepOrange[800]
                          : (isMarketingNotice
                                ? Colors.indigo[800]
                                : Colors.blue[800]));
                final leadingIcon = isModerationNotice
                    ? Icons.edit_notifications
                    : (isMarketingNotice
                          ? Icons.campaign
                          : Icons.notifications);

                final timestampText = _formatTimestamp(data['timestamp']);

                if (isMarketingNotice) {
                  final accent = _marketingColor(type);
                  final label = _marketingLabel(type);
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, accent.withValues(alpha: 0.04)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.22),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        if (!isRead) {
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .collection('notifications')
                              .doc(docId)
                              .update({'isRead': true});
                        }

                        String type = data['type'] ?? 'general';
                        String targetId = data['targetId'] ?? '';
                        if (type == 'category_promo' && targetId.isNotEmpty) {
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AllListingsScreen(
                                  initialFilters: {'categoryName': targetId},
                                  customTitle:
                                      '$targetId ${tr('listings_suffix')}',
                                ),
                              ),
                            );
                          }
                        } else if (context.mounted) {
                          await showDialog<void>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(
                                title,
                                style: LocalFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (hasImage)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          imageUrl,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const SizedBox.shrink(),
                                        ),
                                      ),
                                    if (hasImage) const SizedBox(height: 12),
                                    Text(
                                      message,
                                      style: LocalFonts.poppins(
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: Text(
                                    tr('close'),
                                    style: LocalFonts.poppins(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                type == 'category_promo'
                                    ? Icons.category_rounded
                                    : (type == 'campaign'
                                          ? Icons.local_offer_rounded
                                          : Icons.campaign_rounded),
                                color: accent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          label,
                                          style: LocalFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: accent,
                                          ),
                                        ),
                                      ),
                                      if (!isRead) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            color: accent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: LocalFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message,
                                    maxLines: hasImage ? 2 : 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: LocalFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[800],
                                      height: 1.28,
                                    ),
                                  ),
                                  if (hasImage)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 9),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: AspectRatio(
                                          aspectRatio: 16 / 6,
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              color: Colors.grey[200],
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons
                                                    .image_not_supported_outlined,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (timestampText.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        timestampText,
                                        style: LocalFonts.poppins(
                                          fontSize: 10,
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.grey,
                                size: 20,
                              ),
                              onPressed: () => FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .collection('notifications')
                                  .doc(docId)
                                  .delete(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Material(
                  color: isRead ? Colors.transparent : tileUnreadColor,
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    minVerticalPadding: 4,
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: leadingBgColor,
                      child: Icon(
                        leadingIcon,
                        color: leadingIconColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      title,
                      style: LocalFonts.poppins(
                        color: isRead
                            ? Colors.grey[500]
                            : (isModerationNotice
                                  ? Colors.deepOrange[800]
                                  : Colors.black87),
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isModerationNotice || isMarketingNotice)
                          Container(
                            margin: const EdgeInsets.only(top: 2, bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isModerationNotice
                                  ? Colors.deepOrange.withValues(alpha: 0.10)
                                  : Colors.indigo.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isModerationNotice
                                  ? tr('moderation_edit_label')
                                  : _marketingLabel(type),
                              style: LocalFonts.poppins(
                                fontSize: 9,
                                color: isModerationNotice
                                    ? Colors.deepOrange[900]
                                    : Colors.indigo[900],
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Text(
                          message,
                          maxLines: hasReason ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: LocalFonts.poppins(
                            color: isRead ? Colors.grey[500] : Colors.grey[800],
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                        if (hasImage)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: AspectRatio(
                                aspectRatio: 16 / 6,
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey[200],
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (hasReason)
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: Colors.deepOrange,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Düzeltme Nedeni: $reason',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: LocalFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange[900],
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    isThreeLine: false,
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () => FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('notifications')
                          .doc(docId)
                          .delete(),
                    ),
                    // --- YENİ: TIKLANINCA YÖNLENDİRME ---
                    onTap: () async {
                      // Okundu olarak işaretle
                      if (!isRead) {
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('notifications')
                            .doc(docId)
                            .update({'isRead': true});
                      }

                      // Tıklanan bildirimin hedefini bul
                      String type = data['type'] ?? 'general';
                      String targetId = data['targetId'] ?? '';

                      if ((type == 'chat' || type == 'trade_offer') &&
                          targetId.isNotEmpty) {
                        final opened = await _openChatNotification(
                          context,
                          uid,
                          targetId,
                        );
                        if (!opened &&
                            type == 'trade_offer' &&
                            context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                tr('listing_detail_not_found_in_chat'),
                              ),
                            ),
                          );
                        }
                      } else if (type == 'listing' && targetId.isNotEmpty) {
                        // İlanı bulup detay sayfasına yönlendir
                        var listingDoc = await FirebaseFirestore.instance
                            .collection('listings')
                            .doc(targetId)
                            .get();
                        if (listingDoc.exists && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ListingDetailScreen(
                                data: listingDoc.data() as Map<String, dynamic>,
                                listingId: targetId,
                              ),
                            ),
                          );
                        } else {
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  tr('listing_deleted_or_unavailable'),
                                ),
                              ),
                            );
                        }
                      } else if (type == 'review' && targetId.isNotEmpty) {
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SellerProfileScreen(sellerId: targetId),
                            ),
                          );
                        }
                      } else if (type == 'ticket' && targetId.isNotEmpty) {
                        // Destek talebi bildirimine tıklanınca ticket detayına git
                        var ticketDoc = await FirebaseFirestore.instance
                            .collection('tickets')
                            .doc(targetId)
                            .get();
                        if (ticketDoc.exists && context.mounted) {
                          var tData = ticketDoc.data() as Map<String, dynamic>;
                          final isAdminViewer =
                              FirebaseAuth.instance.currentUser?.email ==
                              'hasanmardinn@gmail.com';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => isAdminViewer
                                  ? AdminTicketDetailScreen(
                                      ticketId: targetId,
                                      subject:
                                          tData['subject'] ??
                                          tr('support_ticket'),
                                      userId: tData['userId'] ?? '',
                                    )
                                  : TicketDetailScreen(
                                      ticketId: targetId,
                                      subject:
                                          tData['subject'] ??
                                          tr('support_ticket'),
                                      status: tData['status'] ?? 'open',
                                    ),
                            ),
                          );
                        } else {
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  tr('ticket_deleted_or_unavailable'),
                                ),
                              ),
                            );
                        }
                      } else if (type == 'category_promo' &&
                          targetId.isNotEmpty) {
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AllListingsScreen(
                                initialFilters: {'categoryName': targetId},
                                customTitle:
                                    '$targetId ${tr('listings_suffix')}',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class TextPopupMenuItem extends PopupMenuItem<String> {
  const TextPopupMenuItem({
    super.key,
    required super.value,
    required super.child,
  });
}
