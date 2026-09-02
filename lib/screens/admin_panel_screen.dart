import 'dart:async';

import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'edit_listing_screen.dart';
import 'listing_detail_screen.dart';
import '../utils/translations.dart';
import 'admin/admin_ticket_detail_screen.dart'; // YENİ: Ticket Detay Ekranı İçin
import 'package:intl/intl.dart'; // YENİ: Tarihler için
import 'seller_profile_screen.dart'; // YENİ: Kullanıcı profiline gitmek için eklendi
import 'package:cached_network_image/cached_network_image.dart'; // YENİ: CachedNetworkImage Eklendi
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:translator/translator.dart';
import '../utils/theme_colors.dart';
import '../services/auth_service.dart';

part 'admin_panel_management_tabs.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  StreamSubscription<QuerySnapshot>? _adminAlertSubscription;
  bool _seededAdminAlerts = false;
  Set<String> _knownAdminAlertIds = <String>{};

  @override
  void initState() {
    super.initState();
    _listenAdminAlerts();
  }

  @override
  void dispose() {
    _adminAlertSubscription?.cancel();
    super.dispose();
  }

  void _listenAdminAlerts() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    _adminAlertSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('notifications')
        .where('source', isEqualTo: 'admin_alert')
        .snapshots()
        .listen((snapshot) {
          final currentIds = snapshot.docs.map((doc) => doc.id).toSet();

          if (!_seededAdminAlerts) {
            _seededAdminAlerts = true;
            _knownAdminAlertIds = currentIds;
            return;
          }

          final newDocs = snapshot.docs
              .where((doc) => !_knownAdminAlertIds.contains(doc.id))
              .toList();
          _knownAdminAlertIds = currentIds;

          if (newDocs.isEmpty || !mounted) {
            return;
          }

          newDocs.sort((a, b) {
            final aTime = a.data()['timestamp'];
            final bTime = b.data()['timestamp'];
            final aMillis = aTime is Timestamp
                ? aTime.millisecondsSinceEpoch
                : 0;
            final bMillis = bTime is Timestamp
                ? bTime.millisecondsSinceEpoch
                : 0;
            return aMillis.compareTo(bMillis);
          });

          final latest = newDocs.last.data();
          final title = (latest['title'] ?? tr('admin_panel_title')).toString();
          final message = (latest['message'] ?? '').toString();

          FlutterRingtonePlayer().playNotification();

          final messenger = ScaffoldMessenger.of(context);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                message.isEmpty ? title : '$title\n$message',
                style: LocalFonts.poppins(),
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 9, // Sekme sayısı düzeltildi
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            tr('admin_panel_title'),
            style: LocalFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.red[800],
            ),
          ),
          bottom: TabBar(
            labelColor: Colors.red[800],
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.red[800],
            isScrollable: true,
            tabs: [
              Tab(
                icon: const Icon(Icons.pending_actions, color: Colors.orange),
                text: tr('pending_approvals'),
              ),
              Tab(
                icon: const Icon(Icons.list_alt),
                text: tr('active_listings_tab'),
              ),
              Tab(
                icon: const Icon(Icons.shopping_cart, color: Colors.blue),
                text: tr('purchases'),
              ),
              Tab(icon: const Icon(Icons.report_problem), text: tr('reports')),
              Tab(icon: const Icon(Icons.category), text: tr('categories')),
              Tab(icon: const Icon(Icons.people), text: tr('members')),
              Tab(
                icon: const Icon(Icons.monetization_on, color: Colors.green),
                text: tr('ads'),
              ), // YENİ: Reklam Sekmesi
              Tab(
                icon: const Icon(Icons.support_agent, color: Colors.deepPurple),
                text: tr('admin_tickets'),
              ), // YENİ: Destek Talepleri
              Tab(
                icon: const Icon(Icons.explicit, color: Colors.brown),
                text: tr('profanity_filter'),
              ), // YENİ: Küfür Filtresi
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AdminPendingListingsTab(),
            _AdminListingsTab(),
            _AdminPurchasesTab(), // YENİ: Satın Almalar sekmesi
            _AdminReportsTab(),
            _AdminCategoriesTab(),
            _AdminUsersTab(),
            _AdminAdsTab(), // YENİ: Reklam Kontrol Paneli
            _AdminTicketsTab(), // YENİ: Destek Talepleri Paneli
            _AdminProfanityTab(), // YENİ: Küfür Filtresi Paneli
          ],
        ),
      ),
    );
  }
}

class _AdminPendingListingsTab extends StatelessWidget {
  const _AdminPendingListingsTab();

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    return DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate());
  }

  Widget _buildIconActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
    bool filled = false,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: filled
            ? null
            : Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: filled ? Colors.white : color),
      ),
    );
  }

  void _showRejectDialog(
    BuildContext context,
    String listingId,
    String sellerId,
    String title,
  ) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tr('reject_listing_title'),
          style: const TextStyle(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('reject_listing_reason_prompt'),
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: tr('reject_listing_reason_hint'),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () async {
              String reason = reasonController.text.trim();
              Navigator.pop(ctx); // Dialog'u kapat

              // İlanı veritabanından reddet (yeni eklediğimiz "reason" parametresiyle gönderiyoruz)
              await DatabaseService().rejectListing(
                listingId,
                sellerId,
                title,
                reason: reason.isNotEmpty
                    ? reason
                    : null, // Boş bırakıldıysa null gönder
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('listing_rejected_notified'))),
                );
              }
            },
            child: Text(
              tr('reject'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestEditDialog(
    BuildContext context,
    String listingId,
    String sellerId,
    String title,
  ) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tr('request_edit_title'),
          style: TextStyle(color: Colors.orange),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('request_edit_prompt'), style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: tr('request_edit_hint'),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.secondary,
            ),
            onPressed: () async {
              String reason = reasonController.text.trim();
              Navigator.pop(ctx);

              await DatabaseService().requestEditListing(
                listingId,
                sellerId,
                title,
                reason.isNotEmpty ? reason : tr('request_edit_default_reason'),
              );

              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('request_edit_sent'))),
                );
            },
            child: Text(
              tr('request_edit_action'),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snapshot.data!.docs.toList();

        // Düzenleme sonrası yeniden onaya gelen ilanları listenin üstüne taşı.
        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;

          final isEditedA = dataA['lastEditChangeSummary'] != null;
          final isEditedB = dataB['lastEditChangeSummary'] != null;
          if (isEditedA != isEditedB) {
            return isEditedA ? -1 : 1;
          }

          Timestamp? tsA;
          Timestamp? tsB;
          if (isEditedA) {
            final sumA = dataA['lastEditChangeSummary'];
            final sumB = dataB['lastEditChangeSummary'];
            if (sumA is Map && sumA['updatedAt'] is Timestamp) {
              tsA = sumA['updatedAt'] as Timestamp;
            }
            if (sumB is Map && sumB['updatedAt'] is Timestamp) {
              tsB = sumB['updatedAt'] as Timestamp;
            }
          }
          tsA ??= dataA['createdAt'] as Timestamp?;
          tsB ??= dataB['createdAt'] as Timestamp?;

          return (tsB ?? Timestamp.now()).compareTo(tsA ?? Timestamp.now());
        });
        if (docs.isEmpty) {
          return Center(
            child: Text(tr('no_pending_listings'), style: LocalFonts.poppins()),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
          children: [
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final isEdited = data['lastEditChangeSummary'] != null;
              final createdAt = data['createdAt'] as Timestamp?;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
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
                  border: Border.all(
                    color: isEdited
                        ? Colors.orange.withValues(alpha: 0.24)
                        : Colors.blue.withValues(alpha: 0.12),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ListingDetailScreen(data: data, listingId: doc.id),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: data['imageUrl'] ?? '',
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                placeholder: (c, u) => Container(
                                  width: 64,
                                  height: 64,
                                  color: Colors.grey[100],
                                  alignment: Alignment.center,
                                  child: const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (c, u, e) => Container(
                                  width: 64,
                                  height: 64,
                                  color: Colors.grey[100],
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.image_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['title'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: LocalFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_outlined,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          _formatDateTime(createdAt),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: LocalFonts.poppins(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isEdited) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        'Duzenlendi',
                                        style: LocalFonts.poppins(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildIconActionButton(
                              icon: Icons.check_circle_outline_rounded,
                              color: const Color(0xFF15803D),
                              filled: true,
                              tooltip: tr('accept'),
                              onTap: () => DatabaseService().approveListing(
                                doc.id,
                                data['sellerId'],
                                data['title'],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildIconActionButton(
                              icon: Icons.edit_note_rounded,
                              color: const Color(0xFFD97706),
                              tooltip: tr('request_edit_action'),
                              onTap: () => _showRequestEditDialog(
                                context,
                                doc.id,
                                data['sellerId'],
                                data['title'],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildIconActionButton(
                              icon: Icons.edit_outlined,
                              color: AppColors.primary,
                              tooltip: tr('edit_listing_title'),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditListingScreen(
                                    listingId: doc.id,
                                    currentData: data,
                                    isAdminEditor: true,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildIconActionButton(
                              icon: Icons.cancel_outlined,
                              color: Colors.red.shade700,
                              tooltip: tr('reject'),
                              onTap: () => _showRejectDialog(
                                context,
                                doc.id,
                                data['sellerId'],
                                data['title'],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _AdminReportsTab extends StatelessWidget {
  const _AdminReportsTab();

  String _resolveReporterDisplay({
    required String reporterId,
    required Map<String, dynamic> reportData,
    Map<String, dynamic>? userData,
  }) {
    final inlineName = (reportData['reporterName'] ?? '').toString().trim();
    if (inlineName.isNotEmpty) return inlineName;

    final legacyInlineName =
        ((reportData['userName'] ?? reportData['name']) ?? '')
            .toString()
            .trim();
    if (legacyInlineName.isNotEmpty && legacyInlineName != reporterId) {
      return legacyInlineName;
    }

    final name = (userData?['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    final displayName = (userData?['displayName'] ?? '').toString().trim();
    if (displayName.isNotEmpty) return displayName;

    final inlineEmail = (reportData['reporterEmail'] ?? '').toString().trim();
    if (inlineEmail.isNotEmpty) {
      final localPart = inlineEmail.split('@').first.trim();
      if (localPart.isNotEmpty) return localPart;
      return inlineEmail;
    }

    final legacyInlineEmail = (reportData['email'] ?? '').toString().trim();
    if (legacyInlineEmail.isNotEmpty) {
      final localPart = legacyInlineEmail.split('@').first.trim();
      if (localPart.isNotEmpty) return localPart;
      return legacyInlineEmail;
    }

    final email = (userData?['email'] ?? '').toString().trim();
    if (email.isNotEmpty) {
      final localPart = email.split('@').first.trim();
      if (localPart.isNotEmpty) return localPart;
      return email;
    }

    if (reporterId.isNotEmpty) {
      return tr('unknown_user');
    }
    return '-';
  }

  String _formatReportTime(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    return DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate());
  }

  Widget _metaPill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: LocalFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return FilledButton.tonalIcon(
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      onPressed: onPressed,
    );
  }

  void _showBanDialog(BuildContext context, String sellerId) {
    showModalBottomSheet(
      context: context,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('suspend_user_from_system'),
              style: LocalFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(tr('suspend_1_day')),
              onTap: () async {
                await DatabaseService().banUser(sellerId, 1);
                if (c.mounted) {
                  Navigator.pop(c);
                  ScaffoldMessenger.of(c).showSnackBar(
                    SnackBar(content: Text(tr('user_banned_1_day'))),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(tr('suspend_1_week')),
              onTap: () async {
                await DatabaseService().banUser(sellerId, 7);
                if (c.mounted) {
                  Navigator.pop(c);
                  ScaffoldMessenger.of(c).showSnackBar(
                    SnackBar(content: Text(tr('user_banned_1_week'))),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(tr('suspend_1_month')),
              onTap: () async {
                await DatabaseService().banUser(sellerId, 30);
                if (c.mounted) {
                  Navigator.pop(c);
                  ScaffoldMessenger.of(c).showSnackBar(
                    SnackBar(content: Text(tr('user_banned_1_month'))),
                  );
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(
                tr('remove_ban_grant_access'),
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                await DatabaseService().unbanUser(sellerId);
                if (c.mounted) {
                  Navigator.pop(c);
                  ScaffoldMessenger.of(c).showSnackBar(
                    SnackBar(content: Text(tr('user_ban_removed'))),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // YENİ: KULLANICIYA UYARI BİLDİRİMİ GÖNDERME EKRANI
  void _showWarnDialog(BuildContext context, String sellerId) {
    final TextEditingController warnController = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          tr('warn_user_title'),
          style: LocalFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
        content: TextField(
          controller: warnController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: tr('warn_user_hint'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.secondary,
            ),
            onPressed: () async {
              if (warnController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(sellerId)
                    .collection('notifications')
                    .add({
                      'title': tr('system_warning_title'),
                      'message': warnController.text.trim(),
                      'isRead': false,
                      'timestamp': FieldValue.serverTimestamp(),
                      'type': 'general',
                      'targetId': '',
                    });
                if (c.mounted) {
                  Navigator.pop(c);
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('warn_user_sent'))),
                    );
                }
              }
            },
            child: Text(
              tr('send'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showReporterNotifyDialog(
    BuildContext context,
    String reporterId,
    String reporterLabel,
  ) {
    if (reporterId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('report_missing_reporter_user'))),
      );
      return;
    }

    final TextEditingController messageController = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          tr('notify_reporter_title'),
          style: LocalFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reporterLabel,
              style: LocalFonts.poppins(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: tr('write_message_hint'),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.secondary,
            ),
            onPressed: () async {
              final message = messageController.text.trim();
              if (message.isEmpty) return;
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(reporterId)
                    .collection('notifications')
                    .add({
                      'title': tr('report_info_notification_title'),
                      'message': message,
                      'isRead': false,
                      'timestamp': FieldValue.serverTimestamp(),
                      'type': 'general',
                      'targetId': '',
                    });

                if (c.mounted) {
                  Navigator.pop(c);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('notify_reporter_sent'))),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('notify_reporter_failed'))),
                  );
                }
              }
            },
            child: Text(
              tr('send'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return Center(
            child: Text(
              tr('no_reports_currently'),
              style: LocalFonts.poppins(),
            ),
          );

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey.shade50, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              var reportData = docs[index].data() as Map<String, dynamic>;
              String reportId = docs[index].id;
              String listingId = reportData['listingId'];
              final reporterId = (reportData['reporterId'] ?? '').toString();
              final reportTimestamp = reportData['timestamp'] as Timestamp?;
              final delay = (index * 70).clamp(0, 220);

              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 320 + delay),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.red.shade100,
                                  Colors.orange.shade100,
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      tr('reports'),
                                      style: LocalFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const Spacer(),
                                    _metaPill(
                                      icon: Icons.schedule,
                                      text: _formatReportTime(reportTimestamp),
                                      color: Colors.blueGrey,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  reportData['reason'] ?? '',
                                  style: LocalFonts.poppins(
                                    color: Colors.black87,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),
                                FutureBuilder<DocumentSnapshot>(
                                  future: reporterId.isEmpty
                                      ? null
                                      : FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(reporterId)
                                            .get(),
                                  builder: (context, reporterSnap) {
                                    Map<String, dynamic>? reporterData;
                                    if (reporterSnap.hasData &&
                                        reporterSnap.data!.exists) {
                                      reporterData =
                                          reporterSnap.data!.data()
                                              as Map<String, dynamic>?;
                                    }

                                    final reporterDisplay =
                                        _resolveReporterDisplay(
                                          reporterId: reporterId,
                                          reportData: reportData,
                                          userData: reporterData,
                                        );
                                    final reporterEmail =
                                        ((reportData['reporterEmail'] ??
                                                    reporterData?['email']) ??
                                                '')
                                            .toString()
                                            .trim();

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _metaPill(
                                              icon: Icons.person_outline,
                                              text: reporterDisplay,
                                              color: Colors.indigo,
                                            ),
                                            if (reporterEmail.isNotEmpty)
                                              _metaPill(
                                                icon: Icons.alternate_email,
                                                text: reporterEmail,
                                                color: Colors.teal,
                                              ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: Colors.grey.shade200, height: 1),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.grey,
                              size: 20,
                            ),
                            tooltip: tr('delete_report'),
                            onPressed: () =>
                                DatabaseService().deleteReport(reportId),
                          ),
                          _reportActionButton(
                            icon: Icons.notifications_active_outlined,
                            label: tr('warn_seller_action'),
                            color: Colors.orange.shade700,
                            onPressed: () async {
                              var listingDoc = await FirebaseFirestore.instance
                                  .collection('listings')
                                  .doc(listingId)
                                  .get();
                              if (listingDoc.exists && context.mounted) {
                                _showWarnDialog(
                                  context,
                                  listingDoc.data()!['sellerId'],
                                );
                              }
                            },
                          ),
                          _reportActionButton(
                            icon: Icons.campaign_outlined,
                            label: tr('notify_reporter_action'),
                            color: Colors.deepOrange.shade600,
                            onPressed: () {
                              final reporterName =
                                  (reportData['reporterName'] ?? '').toString();
                              final reporterMail =
                                  (reportData['reporterEmail'] ?? '')
                                      .toString();
                              final label = reporterName.trim().isNotEmpty
                                  ? reporterName
                                  : (reporterMail.trim().isNotEmpty
                                        ? reporterMail
                                        : tr('user'));
                              _showReporterNotifyDialog(
                                context,
                                reporterId,
                                label,
                              );
                            },
                          ),
                          _reportActionButton(
                            icon: Icons.visibility_outlined,
                            label: tr('view'),
                            color: Colors.blue.shade800,
                            onPressed: () async {
                              var listingDoc = await FirebaseFirestore.instance
                                  .collection('listings')
                                  .doc(listingId)
                                  .get();
                              if (listingDoc.exists && context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ListingDetailScreen(
                                      data:
                                          listingDoc.data()
                                              as Map<String, dynamic>,
                                      listingId: listingId,
                                    ),
                                  ),
                                );
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(tr('this_listing_deleted')),
                                  ),
                                );
                              }
                            },
                          ),
                          _reportActionButton(
                            icon: Icons.block_outlined,
                            label: tr('ban'),
                            color: Colors.red.shade800,
                            onPressed: () async {
                              var listingDoc = await FirebaseFirestore.instance
                                  .collection('listings')
                                  .doc(listingId)
                                  .get();
                              if (listingDoc.exists && context.mounted) {
                                _showBanDialog(
                                  context,
                                  listingDoc.data()!['sellerId'],
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AdminCategoriesTab extends StatelessWidget {
  const _AdminCategoriesTab();

  Future<void> _runBulkFeatureTranslation(BuildContext context) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(
              'Tüm özellikleri çevir',
              style: LocalFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            content: Text(
              'Tüm kategorilerdeki özelliklerin TR alanını baz alıp EN ve AR alanlarını otomatik dolduracağım. Bu işlem birkaç dakika sürebilir. Devam edilsin mi?',
              style: LocalFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(tr('cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text('Devam Et'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Kategoriler taranıyor ve çeviriler veritabanına yazılıyor...',
                style: LocalFonts.poppins(),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final result = await DatabaseService()
          .backfillCategoryFeatureTranslations(overwriteExisting: true);

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text(
              'Bitti. Taranan kategori: ${result['categoriesScanned']}, güncellenen kategori: ${result['categoriesUpdated']}, güncellenen özellik: ${result['featuresUpdated']}.',
              style: LocalFonts.poppins(),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Toplu çeviri başarısız oldu: $e',
              style: LocalFonts.poppins(),
            ),
          ),
        );
      }
    }
  }

  void _showAddDialog(
    BuildContext context,
    String parentId,
    String parentName,
  ) {
    final TextEditingController controllerTr = TextEditingController();
    final TextEditingController controllerEn = TextEditingController();
    final TextEditingController controllerAr = TextEditingController();
    final TextEditingController attributeTypeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '$parentName ${tr('add_under')}',
          style: LocalFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controllerTr,
              decoration: InputDecoration(
                hintText: '${tr('enter_category_name')} (TR)',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controllerEn,
              decoration: InputDecoration(
                hintText: '${tr('enter_category_name')} (EN)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controllerAr,
              decoration: InputDecoration(
                hintText: '${tr('enter_category_name')} (AR)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: attributeTypeCtrl,
              decoration: InputDecoration(hintText: tr('attribute_type_hint')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controllerTr.text.trim().isNotEmpty) {
                String nameTr = controllerTr.text.trim();
                String nameEn = controllerEn.text.trim().isNotEmpty
                    ? controllerEn.text.trim()
                    : nameTr;
                String nameAr = controllerAr.text.trim().isNotEmpty
                    ? controllerAr.text.trim()
                    : nameTr;
                await DatabaseService().addCategory(
                  nameTr,
                  nameEn,
                  nameAr,
                  parentId,
                  attributeType: attributeTypeCtrl.text.trim(),
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text(tr('add'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBulkAddFeatureDialog(BuildContext context) {
    final TextEditingController nameTr = TextEditingController();
    final TextEditingController nameEn = TextEditingController();
    final TextEditingController nameAr = TextEditingController();
    final TextEditingController optTr = TextEditingController();
    final TextEditingController optEn = TextEditingController();
    final TextEditingController optAr = TextEditingController();
    List<String> selectedCategoryIds = [];
    bool isLoading = true;
    List<Map<String, dynamic>> allCategories = [];
    String searchQuery = "";

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setState) {
          if (isLoading && allCategories.isEmpty) {
            FirebaseFirestore.instance.collection('categories').get().then((
              snapshot,
            ) {
              if (context.mounted) {
                Map<String, String> idToName = {};
                Map<String, String> idToParent = {};
                for (var doc in snapshot.docs) {
                  idToName[doc.id] = doc['name'];
                  idToParent[doc.id] = doc['parentId'] ?? '';
                }

                // Kategori ağacını metin olarak tam yol halinde oluşturuyoruz
                String getFullPath(String id) {
                  String path = idToName[id] ?? '';
                  String parent = idToParent[id] ?? '';
                  while (parent.isNotEmpty && idToName.containsKey(parent)) {
                    path = '${idToName[parent]} > $path';
                    parent = idToParent[parent] ?? '';
                  }
                  return path;
                }

                setState(() {
                  allCategories = snapshot.docs
                      .map(
                        (doc) => {
                          'id': doc.id,
                          'fullPath': getFullPath(doc.id),
                        },
                      )
                      .toList();
                  allCategories.sort(
                    (a, b) => a['fullPath'].toString().compareTo(
                      b['fullPath'].toString(),
                    ),
                  );
                  isLoading = false;
                });
              }
            });
          }

          return AlertDialog(
            title: Text(
              tr('bulk_add_feature'),
              style: LocalFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  Flexible(
                    flex: 5,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          TextField(
                            controller: nameTr,
                            decoration: InputDecoration(
                              hintText: '${tr('feature_name_hint')} (TR)',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameEn,
                            decoration: InputDecoration(
                              hintText: '${tr('feature_name_hint')} (EN)',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameAr,
                            decoration: InputDecoration(
                              hintText: '${tr('feature_name_hint')} (AR)',
                              isDense: true,
                            ),
                          ),
                          const Divider(height: 16),
                          TextField(
                            controller: optTr,
                            decoration: InputDecoration(
                              hintText: '${tr('options_comma_separated')} (TR)',
                              isDense: true,
                            ),
                            maxLines: 1,
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: optEn,
                            decoration: InputDecoration(
                              hintText: '${tr('options_comma_separated')} (EN)',
                              isDense: true,
                            ),
                            maxLines: 1,
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: optAr,
                            decoration: InputDecoration(
                              hintText: '${tr('options_comma_separated')} (AR)',
                              isDense: true,
                            ),
                            maxLines: 1,
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              tr('categories_to_apply'),
                              style: LocalFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: InputDecoration(
                              hintText: tr('search_category_hint'),
                              prefixIcon: const Icon(Icons.search),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) {
                              setState(() {
                                searchQuery = val.toLowerCase();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 6,
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Builder(
                            builder: (context) {
                              var filteredCats = allCategories
                                  .where(
                                    (c) => c['fullPath']
                                        .toString()
                                        .toLowerCase()
                                        .contains(searchQuery),
                                  )
                                  .toList();
                              if (filteredCats.isEmpty) {
                                return Center(
                                  child: Text(
                                    tr('category_not_found'),
                                    style: LocalFonts.poppins(fontSize: 12),
                                  ),
                                );
                              }

                              bool isAllSelected = filteredCats.every(
                                (cat) =>
                                    selectedCategoryIds.contains(cat['id']),
                              );

                              return Column(
                                children: [
                                  CheckboxListTile(
                                    title: Text(
                                      tr('select_all_count').replaceFirst(
                                        '%s',
                                        '${filteredCats.length}',
                                      ),
                                      style: LocalFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.purple[800],
                                      ),
                                    ),
                                    value: isAllSelected,
                                    activeColor: Colors.purple[700],
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    dense: true,
                                    onChanged: (bool? val) {
                                      setState(() {
                                        if (val == true) {
                                          for (var cat in filteredCats) {
                                            if (!selectedCategoryIds.contains(
                                              cat['id'],
                                            )) {
                                              selectedCategoryIds.add(
                                                cat['id'],
                                              );
                                            }
                                          }
                                        } else {
                                          for (var cat in filteredCats) {
                                            selectedCategoryIds.remove(
                                              cat['id'],
                                            );
                                          }
                                        }
                                      });
                                    },
                                  ),
                                  const Divider(height: 1),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: filteredCats.length,
                                      itemBuilder: (context, index) {
                                        var cat = filteredCats[index];
                                        bool isSelected = selectedCategoryIds
                                            .contains(cat['id']);
                                        return CheckboxListTile(
                                          title: Text(
                                            cat['fullPath'],
                                            style: LocalFonts.poppins(
                                              fontSize: 12,
                                            ),
                                          ),
                                          value: isSelected,
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          dense: true,
                                          onChanged: (bool? value) {
                                            setState(() {
                                              if (value == true) {
                                                selectedCategoryIds.add(
                                                  cat['id'],
                                                );
                                              } else {
                                                selectedCategoryIds.remove(
                                                  cat['id'],
                                                );
                                              }
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(tr('cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                ),
                onPressed: () async {
                  if (nameTr.text.trim().isNotEmpty &&
                      selectedCategoryIds.isNotEmpty) {
                    List<String> oTr = optTr.text.trim().isNotEmpty
                        ? optTr.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList()
                        : [];
                    List<String> oEn = optEn.text.trim().isNotEmpty
                        ? optEn.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList()
                        : [];
                    List<String> oAr = optAr.text.trim().isNotEmpty
                        ? optAr.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList()
                        : [];

                    // Tüm seçili kategorilere döngü ile ekle
                    for (String catId in selectedCategoryIds) {
                      await DatabaseService().addCategoryFeature(
                        catId,
                        nameTr.text.trim(),
                        nameEn.text.trim(),
                        nameAr.text.trim(),
                        oTr,
                        oEn,
                        oAr,
                      );
                    }
                    if (c.mounted) {
                      Navigator.pop(c);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tr('feature_added_successfully')),
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tr('please_enter_feature_and_select_category'),
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  tr('add_to_selected'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: DatabaseService().getCategoriesStream(""),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty)
                return Center(
                  child: Text(
                    tr('no_categories_at_all'),
                    style: LocalFonts.poppins(),
                  ),
                );

              var docs = snapshot.data!.docs.toList();
              docs.sort((a, b) {
                var ad = a.data() as Map<String, dynamic>;
                var bd = b.data() as Map<String, dynamic>;
                int orderA = ad['order'] ?? 0;
                int orderB = bd['order'] ?? 0;
                if (orderA != orderB) return orderA.compareTo(orderB);
                Timestamp? tA = ad['createdAt'];
                Timestamp? tB = bd['createdAt'];
                if (tA != null && tB != null) return tA.compareTo(tB);
                return 0;
              });

              return ReorderableListView.builder(
                buildDefaultDragHandles:
                    false, // YENİ: Sürükleme performansını artırmak için
                padding: const EdgeInsets.only(top: 8),
                itemCount: docs.length,
                onReorder: (oldIndex, newIndex) async {
                  if (newIndex > oldIndex) newIndex -= 1;
                  var item = docs.removeAt(oldIndex);
                  docs.insert(newIndex, item);
                  List<Map<String, dynamic>> updatedOrders = [];
                  for (int i = 0; i < docs.length; i++) {
                    updatedOrders.add({'id': docs[i].id, 'order': i});
                  }
                  await DatabaseService().updateCategoriesOrder(updatedOrders);
                },
                itemBuilder: (context, index) {
                  var doc = docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  return CategoryTreeTile(
                    index:
                        index, // YENİ: Tutamaç (DragHandle) için index ekliyoruz
                    key: ValueKey(doc.id),
                    categoryId: doc.id,
                    categoryData: data,
                    features: data['features'] ?? [],
                    level: 0,
                    onAdd: (id, name) => _showAddDialog(
                      context,
                      id,
                      getTranslatedText(data, 'name'),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: () =>
                    _showAddDialog(context, "", tr('add_new_main_category')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(
                  tr('add_new_main_category'),
                  style: LocalFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _showBulkAddFeatureDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: const Icon(Icons.playlist_add, color: Colors.white),
                label: Text(
                  tr('bulk_add_feature_filter'),
                  style: LocalFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _runBulkFeatureTranslation(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: const Icon(Icons.translate, color: Colors.white),
                label: Text(
                  'Tüm Özellikleri TR -> EN/AR Çevir',
                  style: LocalFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CategoryTreeTile extends StatelessWidget {
  final String categoryId;
  final Map<String, dynamic> categoryData;
  final List<dynamic> features;
  final Function(String, String) onAdd;
  final int level;
  final int index; // YENİ: Liste sırası

  const CategoryTreeTile({
    super.key,
    required this.categoryId,
    required this.categoryData,
    required this.features,
    required this.onAdd,
    required this.index, // YENİ
    this.level = 0,
  });

  static const Map<String, Map<String, String>> _featureAutoLexicon = {
    'marka': {'en': 'Brand', 'ar': 'العلامة التجارية'},
    'seri': {'en': 'Series', 'ar': 'السلسلة'},
    'model': {'en': 'Model', 'ar': 'الموديل'},
    'paket': {'en': 'Package', 'ar': 'الباقة'},
    'renk': {'en': 'Color', 'ar': 'اللون'},
    'yil': {'en': 'Year', 'ar': 'السنة'},
    'yakit': {'en': 'Fuel', 'ar': 'الوقود'},
    'vites': {'en': 'Transmission', 'ar': 'ناقل الحركة'},
    'manuel': {'en': 'Manual', 'ar': 'يدوي'},
    'otomatik': {'en': 'Automatic', 'ar': 'أوتوماتيك'},
    'benzin': {'en': 'Gasoline', 'ar': 'بنزين'},
    'dizel': {'en': 'Diesel', 'ar': 'ديزل'},
    'elektrik': {'en': 'Electric', 'ar': 'كهرباء'},
    'hibrit': {'en': 'Hybrid', 'ar': 'هجين'},
    'durum': {'en': 'Condition', 'ar': 'الحالة'},
    'sifir': {'en': 'New', 'ar': 'جديد'},
    'ikinci el': {'en': 'Used', 'ar': 'مستعمل'},
    'km': {'en': 'Mileage', 'ar': 'عدد الكيلومترات'},
    'kasa tipi': {'en': 'Body Type', 'ar': 'نوع الهيكل'},
    'kapi': {'en': 'Door', 'ar': 'باب'},
    'cekis': {'en': 'Traction', 'ar': 'الدفع'},
    'fiyat': {'en': 'Price', 'ar': 'السعر'},
    'beyaz': {'en': 'White', 'ar': 'أبيض'},
    'siyah': {'en': 'Black', 'ar': 'أسود'},
    'gri': {'en': 'Gray', 'ar': 'رمادي'},
    'kirmizi': {'en': 'Red', 'ar': 'أحمر'},
    'mavi': {'en': 'Blue', 'ar': 'أزرق'},
    'yesil': {'en': 'Green', 'ar': 'أخضر'},
  };

  String _normalizeForTranslate(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _autoTranslateFeatureText(String text, String lang) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    final normalized = _normalizeForTranslate(trimmed);
    final direct = _featureAutoLexicon[normalized]?[lang];
    if (direct != null && direct.isNotEmpty) return direct;

    final words = normalized.split(' ');
    if (words.length > 1) {
      final translatedWords = <String>[];
      bool translatedAny = false;
      for (final w in words) {
        final mapped = _featureAutoLexicon[w]?[lang];
        if (mapped != null && mapped.isNotEmpty) {
          translatedWords.add(mapped);
          translatedAny = true;
        } else {
          translatedWords.add(w);
        }
      }
      if (translatedAny) {
        return translatedWords.join(' ');
      }
    }

    // Unknown words fallback to original text to avoid data loss.
    return trimmed;
  }

  Future<String> _autoTranslateFeatureTextOnline(
    String text,
    String lang,
  ) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    try {
      final translated = await GoogleTranslator().translate(
        trimmed,
        from: 'tr',
        to: lang,
      );
      final translatedText = translated.text.trim();
      if (translatedText.isNotEmpty) {
        return translatedText;
      }
    } catch (_) {}

    return _autoTranslateFeatureText(trimmed, lang);
  }

  String _autoTranslateCommaSeparated(String input, String lang) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    final translated = trimmed
        .split(',')
        .map((e) => _autoTranslateFeatureText(e.trim(), lang))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return translated.join(', ');
  }

  void _delete(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          tr('delete_category'),
          style: const TextStyle(color: Colors.red),
        ),
        content: Text(tr('category_delete_confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
            ),
            onPressed: () async {
              await DatabaseService().deleteCategory(categoryId);
              if (c.mounted) Navigator.pop(c);
            },
            child: Text(
              tr('delete'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _editName(BuildContext context) {
    final TextEditingController controllerTr = TextEditingController(
      text: categoryData['name'],
    );
    final TextEditingController controllerEn = TextEditingController(
      text: categoryData['name_en'] ?? '',
    );
    final TextEditingController controllerAr = TextEditingController(
      text: categoryData['name_ar'] ?? '',
    );
    final TextEditingController attributeTypeCtrl = TextEditingController(
      text: categoryData['attributeType'] ?? '',
    );
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          tr('edit_category_name'),
          style: LocalFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controllerTr,
              decoration: InputDecoration(hintText: tr('lang_short_tr')),
              autofocus: true,
            ),
            TextField(
              controller: controllerEn,
              decoration: InputDecoration(hintText: tr('lang_short_en')),
            ),
            TextField(
              controller: controllerAr,
              decoration: InputDecoration(hintText: tr('lang_short_ar')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: attributeTypeCtrl,
              decoration: InputDecoration(hintText: tr('attribute_type_hint')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controllerTr.text.trim().isNotEmpty) {
                String nameTr = controllerTr.text.trim();
                String nameEn = controllerEn.text.trim().isNotEmpty
                    ? controllerEn.text.trim()
                    : nameTr;
                String nameAr = controllerAr.text.trim().isNotEmpty
                    ? controllerAr.text.trim()
                    : nameTr;
                await DatabaseService().updateCategoryName(
                  categoryId,
                  nameTr,
                  nameEn,
                  nameAr,
                  attributeTypeCtrl.text.trim(),
                );
                if (c.mounted) Navigator.pop(c);
              }
            },
            child: Text(
              tr('save'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _addFeature(BuildContext context) {
    final TextEditingController nameTr = TextEditingController();
    final TextEditingController nameEn = TextEditingController();
    final TextEditingController nameAr = TextEditingController();
    final TextEditingController optTr = TextEditingController();
    final TextEditingController optEn = TextEditingController();
    final TextEditingController optAr = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          tr('add_feature'),
          style: LocalFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameTr,
                decoration: InputDecoration(
                  hintText: '${tr('feature_name')} (TR)',
                ),
              ),
              TextField(
                controller: nameEn,
                decoration: InputDecoration(
                  hintText: '${tr('feature_name')} (EN)',
                ),
              ),
              TextField(
                controller: nameAr,
                decoration: InputDecoration(
                  hintText: '${tr('feature_name')} (AR)',
                ),
              ),
              const Divider(),
              TextField(
                controller: optTr,
                decoration: InputDecoration(
                  hintText: '${tr('options_comma_separated')} (TR)',
                ),
              ),
              TextField(
                controller: optEn,
                decoration: InputDecoration(
                  hintText: '${tr('options_comma_separated')} (EN)',
                ),
              ),
              TextField(
                controller: optAr,
                decoration: InputDecoration(
                  hintText: '${tr('options_comma_separated')} (AR)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameTr.text.trim().isNotEmpty) {
                List<String> oTr = optTr.text.trim().isNotEmpty
                    ? optTr.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList()
                    : [];
                List<String> oEn = optEn.text.trim().isNotEmpty
                    ? optEn.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList()
                    : [];
                List<String> oAr = optAr.text.trim().isNotEmpty
                    ? optAr.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList()
                    : [];

                await DatabaseService().addCategoryFeature(
                  categoryId,
                  nameTr.text.trim(),
                  nameEn.text.trim(),
                  nameAr.text.trim(),
                  oTr,
                  oEn,
                  oAr,
                );
                if (c.mounted) Navigator.pop(c);
              }
            },
            child: Text(tr('add')),
          ),
        ],
      ),
    );
  }

  void _editFeature(BuildContext context, dynamic feature) {
    String initialNameTr = '';
    String initialNameEn = '';
    String initialNameAr = '';
    List<String> initialOptTr = [];
    List<String> initialOptEn = [];
    List<String> initialOptAr = [];

    if (feature is String) {
      initialNameTr = feature;
    } else if (feature is Map) {
      final f = Map<String, dynamic>.from(feature);
      initialNameTr = (f['name'] ?? '').toString();
      initialNameEn = (f['name_en'] ?? '').toString();
      initialNameAr = (f['name_ar'] ?? '').toString();
      initialOptTr = List<String>.from(f['options'] ?? []);
      initialOptEn = List<String>.from(f['options_en'] ?? []);
      initialOptAr = List<String>.from(f['options_ar'] ?? []);
    }

    final TextEditingController nameTr = TextEditingController(
      text: initialNameTr,
    );
    final TextEditingController nameEn = TextEditingController(
      text: initialNameEn,
    );
    final TextEditingController nameAr = TextEditingController(
      text: initialNameAr,
    );
    final TextEditingController optTr = TextEditingController(
      text: initialOptTr.join(', '),
    );
    final TextEditingController optEn = TextEditingController(
      text: initialOptEn.join(', '),
    );
    final TextEditingController optAr = TextEditingController(
      text: initialOptAr.join(', '),
    );

    bool autoFillEn = nameEn.text.trim().isEmpty;
    bool autoFillAr = nameAr.text.trim().isEmpty;
    bool autoFillOptEn = optEn.text.trim().isEmpty;
    bool autoFillOptAr = optAr.text.trim().isEmpty;
    bool isAutoSettingNameEn = false;
    bool isAutoSettingNameAr = false;
    int trNameTranslateSeq = 0;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            tr('edit'),
            style: LocalFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameTr,
                  onChanged: (value) async {
                    final next = value.trim();
                    final currentSeq = ++trNameTranslateSeq;

                    if (autoFillEn) {
                      final translatedEn =
                          await _autoTranslateFeatureTextOnline(next, 'en');
                      if (!c.mounted || currentSeq != trNameTranslateSeq) {
                        return;
                      }
                      isAutoSettingNameEn = true;
                      nameEn.value = TextEditingValue(
                        text: translatedEn,
                        selection: TextSelection.collapsed(
                          offset: translatedEn.length,
                        ),
                      );
                      isAutoSettingNameEn = false;
                    }

                    if (autoFillAr) {
                      final translatedAr =
                          await _autoTranslateFeatureTextOnline(next, 'ar');
                      if (!c.mounted || currentSeq != trNameTranslateSeq) {
                        return;
                      }
                      isAutoSettingNameAr = true;
                      nameAr.value = TextEditingValue(
                        text: translatedAr,
                        selection: TextSelection.collapsed(
                          offset: translatedAr.length,
                        ),
                      );
                      isAutoSettingNameAr = false;
                    }
                  },
                  decoration: InputDecoration(
                    hintText: '${tr('feature_name')} (TR)',
                  ),
                ),
                TextField(
                  controller: nameEn,
                  onChanged: (value) {
                    if (isAutoSettingNameEn) return;
                    setDialogState(() {
                      autoFillEn = value.trim().isEmpty;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: '${tr('feature_name')} (EN)',
                  ),
                ),
                TextField(
                  controller: nameAr,
                  onChanged: (value) {
                    if (isAutoSettingNameAr) return;
                    setDialogState(() {
                      autoFillAr = value.trim().isEmpty;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: '${tr('feature_name')} (AR)',
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr('feature_name_auto_fill_hint'),
                    style: LocalFonts.poppins(fontSize: 11, color: Colors.grey),
                  ),
                ),
                const Divider(),
                TextField(
                  controller: optTr,
                  onChanged: (value) {
                    if (autoFillOptEn) {
                      final translated = _autoTranslateCommaSeparated(
                        value,
                        'en',
                      );
                      optEn.value = TextEditingValue(
                        text: translated,
                        selection: TextSelection.collapsed(
                          offset: translated.length,
                        ),
                      );
                    }
                    if (autoFillOptAr) {
                      final translated = _autoTranslateCommaSeparated(
                        value,
                        'ar',
                      );
                      optAr.value = TextEditingValue(
                        text: translated,
                        selection: TextSelection.collapsed(
                          offset: translated.length,
                        ),
                      );
                    }
                  },
                  decoration: InputDecoration(
                    hintText: '${tr('options_comma_separated')} (TR)',
                  ),
                ),
                TextField(
                  controller: optEn,
                  onChanged: (value) {
                    final expected = _autoTranslateCommaSeparated(
                      optTr.text,
                      'en',
                    );
                    setDialogState(() {
                      autoFillOptEn =
                          value.trim().isEmpty || value.trim() == expected;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: '${tr('options_comma_separated')} (EN)',
                  ),
                ),
                TextField(
                  controller: optAr,
                  onChanged: (value) {
                    final expected = _autoTranslateCommaSeparated(
                      optTr.text,
                      'ar',
                    );
                    setDialogState(() {
                      autoFillOptAr =
                          value.trim().isEmpty || value.trim() == expected;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: '${tr('options_comma_separated')} (AR)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameTr.text.trim().isEmpty) return;

                List<String> oTr = optTr.text.trim().isNotEmpty
                    ? optTr.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList()
                    : [];
                List<String> oEn = optEn.text.trim().isNotEmpty
                    ? optEn.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList()
                    : [];
                List<String> oAr = optAr.text.trim().isNotEmpty
                    ? optAr.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList()
                    : [];

                await DatabaseService().updateCategoryFeature(
                  categoryId,
                  feature,
                  nameTr.text.trim(),
                  nameEn.text.trim(),
                  nameAr.text.trim(),
                  oTr,
                  oEn,
                  oAr,
                );
                if (c.mounted) Navigator.pop(c);
              },
              child: Text(tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkAddCategoryDialog(BuildContext outerContext) {
    final TextEditingController bulkController = TextEditingController();
    final TextEditingController attributeTypeCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: outerContext,
      builder: (c) => StatefulBuilder(
        builder: (innerContext, setState) {
          return AlertDialog(
            title: Text(
              tr('bulk_add_category'),
              style: LocalFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('bulk_add_category_hint'),
                  style: LocalFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bulkController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    hintText: "BMW\nMercedes\nAudi\n...",
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: attributeTypeCtrl,
                  decoration: InputDecoration(
                    hintText: tr('attribute_type_hint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(tr('cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (bulkController.text.trim().isEmpty) return;
                        setState(() => isLoading = true);

                        List<String> categories = bulkController.text
                            .split(RegExp(r'[,\n]'))
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        await DatabaseService().addMultipleCategories(
                          categoryId,
                          categories,
                          attributeType: attributeTypeCtrl.text.trim(),
                        );

                        setState(() => isLoading = false);
                        if (c.mounted) Navigator.pop(c);
                        if (outerContext.mounted)
                          ScaffoldMessenger.of(outerContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                tr('categories_added_successfully'),
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        tr('add'),
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(
        left: level == 0 ? 12.0 : 16.0,
        right: level == 0 ? 12.0 : 0.0,
        top: 4.0,
        bottom: 4.0,
      ),
      elevation: level == 0 ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: level == 0 ? Colors.grey.shade300 : Colors.blue.shade100,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.only(
            right: 8,
          ), // Sağdaki boşluğu daralttık
          leading: ReorderableDragStartListener(
            // YENİ: Sadece bu ikondan tutularak sürüklenebilir
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(left: 8.0, right: 4.0),
              child: Icon(Icons.drag_handle, color: Colors.grey),
            ),
          ),
          title: Text(
            getTranslatedText(categoryData, 'name'),
            style: LocalFonts.poppins(
              fontWeight: level == 0 ? FontWeight.bold : FontWeight.w600,
              fontSize: level == 0 ? 15 : 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          childrenPadding: EdgeInsets.zero,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.add_circle,
                  color: Colors.green,
                  size: 22,
                ),
                tooltip: tr('add_under'),
                onPressed: () =>
                    onAdd(categoryId, getTranslatedText(categoryData, 'name')),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey, size: 22),
                tooltip: tr('actions'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    _editName(context);
                  } else if (value == 'add_feature')
                    _addFeature(context);
                  else if (value == 'bulk_add')
                    _showBulkAddCategoryDialog(context);
                  else if (value == 'delete')
                    _delete(context);
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          tr('edit_category_name'),
                          style: LocalFonts.poppins(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'add_feature',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.list_alt,
                          color: Colors.purple,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tr('add_feature'),
                          style: LocalFonts.poppins(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'bulk_add',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.library_add,
                          color: Colors.teal,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tr('bulk_add_category'),
                          style: LocalFonts.poppins(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          tr('delete_category'),
                          style: LocalFonts.poppins(
                            fontSize: 13,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            if (features.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        top: 8.0,
                        bottom: 4.0,
                      ),
                      child: Text(
                        tr('listing_features_for_category'),
                        style: LocalFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[800],
                        ),
                      ),
                    ),
                    ...features.map((f) {
                      String fName = "";
                      String fOptions = "";
                      if (f is String) {
                        fName = f;
                      } else if (f is Map<String, dynamic>) {
                        fName = getTranslatedText(f, 'name');
                        fOptions = getTranslatedList(f, 'options').join(', ');
                      }
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          fName,
                          style: LocalFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: fOptions.isNotEmpty
                            ? Text(
                                fOptions,
                                style: LocalFonts.poppins(fontSize: 11),
                              )
                            : Text(
                                tr('text_box_user_types'),
                                style: LocalFonts.poppins(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                size: 18,
                                color: Colors.blue,
                              ),
                              onPressed: () => _editFeature(context, f),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                size: 18,
                                color: Colors.red,
                              ),
                              onPressed: () => DatabaseService()
                                  .deleteCategoryFeature(categoryId, f),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            StreamBuilder<QuerySnapshot>(
              stream: DatabaseService().getCategoriesStream(categoryId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                var docs = snapshot.data!.docs.toList();
                docs.sort((a, b) {
                  var ad = a.data() as Map<String, dynamic>;
                  var bd = b.data() as Map<String, dynamic>;
                  int orderA = ad['order'] ?? 0;
                  int orderB = bd['order'] ?? 0;
                  if (orderA != orderB) return orderA.compareTo(orderB);
                  Timestamp? tA = ad['createdAt'];
                  Timestamp? tB = bd['createdAt'];
                  if (tA != null && tB != null) return tA.compareTo(tB);
                  return 0;
                });
                if (docs.isEmpty) return const SizedBox();
                return ReorderableListView.builder(
                  buildDefaultDragHandles:
                      false, // YENİ: Alt listelerdeki yavaşlamayı kesmek için
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex -= 1;
                    var item = docs.removeAt(oldIndex);
                    docs.insert(newIndex, item);
                    List<Map<String, dynamic>> updatedOrders = [];
                    for (int i = 0; i < docs.length; i++) {
                      updatedOrders.add({'id': docs[i].id, 'order': i});
                    }
                    await DatabaseService().updateCategoriesOrder(
                      updatedOrders,
                    );
                  },
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    return CategoryTreeTile(
                      index:
                          index, // YENİ: Alt menünün tutamacı için index ekliyoruz
                      key: ValueKey(doc.id),
                      categoryId: doc.id,
                      categoryData: data,
                      features: data['features'] ?? [],
                      onAdd: onAdd,
                      level: level + 1,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminListingsTab extends StatefulWidget {
  const _AdminListingsTab();

  @override
  State<_AdminListingsTab> createState() => _AdminListingsTabState();
}

class _AdminListingsTabState extends State<_AdminListingsTab> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int _totalActiveListings = 0;
  bool _showSearchField = false;

  @override
  void initState() {
    super.initState();
    _fetchTotalCount();
  }

  Future<void> _fetchTotalCount() async {
    int count = await DatabaseService().getTotalActiveListingsCount();
    if (mounted) {
      setState(() {
        _totalActiveListings = count;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showShowcaseDialog(BuildContext context, String listingId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('move_listing_to_showcase'),
                style: LocalFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.amber[800],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.flash_on, color: Colors.blue),
                title: Text(tr('showcase_1_day')),
                onTap: () async {
                  await DatabaseService().upgradeListingToShowcase(
                    listingId,
                    1,
                  );
                  if (c.mounted) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(content: Text(tr('listing_showcased_1_day'))),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.rocket_launch, color: Colors.purple),
                title: Text(tr('showcase_1_week')),
                onTap: () async {
                  await DatabaseService().upgradeListingToShowcase(
                    listingId,
                    7,
                  );
                  if (c.mounted) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(content: Text(tr('listing_showcased_1_week'))),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.diamond, color: Colors.amber),
                title: Text(tr('showcase_1_month')),
                onTap: () async {
                  await DatabaseService().upgradeListingToShowcase(
                    listingId,
                    30,
                  );
                  if (c.mounted) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(content: Text(tr('listing_showcased_1_month'))),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              const Divider(),
              Text(
                tr('move_listing_to_category_showcase'),
                style: LocalFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.orange[800],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.flash_on, color: Colors.orange),
                title: Text(tr('category_showcase_1_day')),
                onTap: () async {
                  await DatabaseService().upgradeListingToCategoryShowcase(
                    listingId,
                    1,
                  );
                  if (c.mounted) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(
                        content: Text(tr('listing_cat_showcased_1_day')),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.rocket_launch, color: Colors.orange),
                title: Text(tr('category_showcase_1_week')),
                onTap: () async {
                  await DatabaseService().upgradeListingToCategoryShowcase(
                    listingId,
                    7,
                  );
                  if (c.mounted) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(
                        content: Text(tr('listing_cat_showcased_1_week')),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.diamond, color: Colors.orange),
                title: Text(tr('category_showcase_1_month')),
                onTap: () async {
                  await DatabaseService().upgradeListingToCategoryShowcase(
                    listingId,
                    30,
                  );
                  if (c.mounted) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(
                        content: Text(tr('listing_cat_showcased_1_month')),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              const Divider(),
              Text(
                tr('move_listing_to_urgent'),
                style: LocalFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.notifications_active,
                  color: Colors.red,
                ),
                title: Text(tr('urgent_1_day')),
                onTap: () async {
                  await DatabaseService().upgradeListingToUrgent(listingId, 1);
                  if (c.mounted) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(content: Text(tr('urgent_promoted_1_day'))),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.bolt, color: Colors.deepOrange),
                title: Text(tr('urgent_3_days')),
                onTap: () async {
                  await DatabaseService().upgradeListingToUrgent(listingId, 3);
                  if (c.mounted) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(content: Text(tr('urgent_promoted_3_days'))),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.local_fire_department,
                  color: Colors.red,
                ),
                title: Text(tr('urgent_7_days')),
                onTap: () async {
                  await DatabaseService().upgradeListingToUrgent(listingId, 7);
                  if (c.mounted) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(content: Text(tr('urgent_promoted_7_days'))),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('listings')
                .where('status', isEqualTo: 'active')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              var allDocs = snapshot.data!.docs;

              // Arama sorgusuna göre filtreleme yapıyoruz
              var docs = allDocs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String title = (data['title'] ?? '').toString().toLowerCase();
                String listingNo =
                    (data['listingNo'] ??
                            doc.id
                                .replaceAll(RegExp(r'[^0-9]'), '')
                                .padRight(8, '0')
                                .substring(0, 8))
                        .toString()
                        .toLowerCase();
                return title.contains(_searchQuery) ||
                    listingNo.contains(_searchQuery);
              }).toList();

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(
                        children: [
                          const Icon(Icons.list_alt, color: Colors.blue),
                          const SizedBox(width: 6),
                          Text(
                            '$_totalActiveListings',
                            style: LocalFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: tr('search_listing_title_or_no'),
                            onPressed: () {
                              setState(() {
                                _showSearchField = !_showSearchField;
                                if (!_showSearchField) {
                                  _searchController.clear();
                                  _searchQuery = '';
                                }
                              });
                            },
                            icon: Icon(
                              _showSearchField ? Icons.close : Icons.search,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showSearchField)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          onChanged: (value) => setState(
                            () => _searchQuery = value.toLowerCase(),
                          ),
                          decoration: InputDecoration(
                            hintText: tr('search_listing_title_or_no'),
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (docs.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          tr('no_active_listings_matching_criteria'),
                          style: LocalFonts.poppins(),
                        ),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;

                        // İlanın halihazırda vitrinde olup olmadığını kontrol ediyoruz
                        bool isShowcased = false;
                        if (data['showcaseUntil'] != null) {
                          DateTime showcaseDate =
                              (data['showcaseUntil'] as Timestamp).toDate();
                          if (showcaseDate.isAfter(DateTime.now())) {
                            isShowcased = true;
                          }
                        }
                        bool isCatShowcased = false;
                        if (data['categoryShowcaseUntil'] != null) {
                          DateTime catShowcaseDate =
                              (data['categoryShowcaseUntil'] as Timestamp)
                                  .toDate();
                          if (catShowcaseDate.isAfter(DateTime.now())) {
                            isCatShowcased = true;
                          }
                        }
                        bool isUrgentActive = false;
                        if (data['isUrgent'] == true &&
                            data['urgentUntil'] != null) {
                          DateTime urgentUntil =
                              (data['urgentUntil'] as Timestamp).toDate();
                          if (urgentUntil.isAfter(DateTime.now())) {
                            isUrgentActive = true;
                          }
                        }

                        return ListTile(
                          tileColor: isShowcased ? Colors.amber[50] : null,
                          leading: CachedNetworkImage(
                            imageUrl: data['imageUrl'] ?? '',
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => const SizedBox(
                              width: 50,
                              height: 50,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (c, u, e) => const Icon(Icons.image),
                          ),
                          title: Text(data['title'] ?? ''),
                          subtitle: Text('₺${data['price']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                ),
                                tooltip: tr('move_to_showcase'),
                                onPressed: () => _showShowcaseDialog(
                                  context,
                                  docs[index].id,
                                ),
                              ),
                              if (isShowcased)
                                Tooltip(
                                  message: tr('on_home_showcase'),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                    ),
                                    child: Icon(
                                      Icons.verified,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              if (isCatShowcased)
                                Tooltip(
                                  message: tr('on_category_showcase'),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                    ),
                                    child: Icon(
                                      Icons.category,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              if (isUrgentActive)
                                const Tooltip(
                                  message: 'Acil listede',
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                    ),
                                    child: Icon(
                                      Icons.notifications_active,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                tooltip: tr('edit_listing_title'),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditListingScreen(
                                      listingId: docs[index].id,
                                      currentData: data,
                                      isAdminEditor: true,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                tooltip: tr('delete_listing'),
                                onPressed: () => DatabaseService()
                                    .deleteListing(docs[index].id),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AdminUsersTab extends StatefulWidget {
  const _AdminUsersTab();

  @override
  State<_AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<_AdminUsersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showProOnly = false;
  bool _showSearchField = false;

  String _resolveUserName(Map<String, dynamic> data) {
    final raw = (data['name'] ?? '').toString().trim();
    if (raw.isNotEmpty && raw != 'İsimsiz') return raw;

    final email = (data['email'] ?? '').toString().trim();
    if (email.isNotEmpty) {
      final localPart = email.split('@').first.trim();
      if (localPart.isNotEmpty) return localPart;
    }

    final phone = (data['phoneNumber'] ?? '').toString().trim();
    if (phone.isNotEmpty) return phone;

    return tr('anonymous_name');
  }

  bool _isRealMemberDoc(Map<String, dynamic> data, String docId) {
    final uid = (data['uid'] ?? '').toString().trim();
    final hasName = (data['name'] ?? '').toString().trim().isNotEmpty;
    final hasEmail = (data['email'] ?? '').toString().trim().isNotEmpty;
    final hasPhone = (data['phoneNumber'] ?? '').toString().trim().isNotEmpty;
    final hasCreatedAt = data['createdAt'] != null;

    if (uid.isNotEmpty) return true;
    if (docId.isNotEmpty && docId == uid) return true;
    return hasCreatedAt && (hasName || hasEmail || hasPhone);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _hasActivePro(Map<String, dynamic> data) {
    final proUntil = data['proUntil'];
    if (proUntil is Timestamp) {
      return proUntil.toDate().isAfter(DateTime.now());
    }
    if (proUntil is DateTime) {
      return proUntil.isAfter(DateTime.now());
    }
    return false;
  }

  Future<void> _showAdminBroadcastDialog({
    required bool sendToAll,
    String? userId,
    String? userName,
  }) async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final targetIdController = TextEditingController();
    final imageUrlController = TextEditingController();
    var selectedType = 'announcement';
    var isSending = false;

    Future<void> applyTemplate(
      String type,
      void Function(void Function()) setStateDialog,
    ) async {
      setStateDialog(() {
        selectedType = type;
        if (type == 'campaign') {
          titleController.text = tr('campaign_template_new_title');
          messageController.text = tr('campaign_template_new_message');
          imageUrlController.text = '';
        } else if (type == 'category_promo') {
          titleController.text = tr('category_promo_template_title');
          messageController.text = tr('category_promo_template_message');
          imageUrlController.text = '';
        } else {
          titleController.text = tr('marketing_announcement_label');
          messageController.text = tr('announcement_template_message');
          imageUrlController.text = '';
        }
      });
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogBuildContext, setStateDialog) => AlertDialog(
          title: Text(
            sendToAll
                ? tr('send_notification_to_all_members')
                : '${userName ?? tr('user')} ${tr('send_notification_to_user_suffix')}',
            style: LocalFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('template_label'),
                  style: LocalFonts.poppins(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(tr('template_general_announcement')),
                      selected: selectedType == 'announcement',
                      onSelected: isSending
                          ? null
                          : (_) =>
                                applyTemplate('announcement', setStateDialog),
                    ),
                    ChoiceChip(
                      label: Text(tr('marketing_campaign_label')),
                      selected: selectedType == 'campaign',
                      onSelected: isSending
                          ? null
                          : (_) => applyTemplate('campaign', setStateDialog),
                    ),
                    ChoiceChip(
                      label: Text(tr('marketing_category_promo_label')),
                      selected: selectedType == 'category_promo',
                      onSelected: isSending
                          ? null
                          : (_) =>
                                applyTemplate('category_promo', setStateDialog),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleController,
                  enabled: !isSending,
                  maxLength: 70,
                  decoration: InputDecoration(
                    labelText: tr('title_label_common'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: messageController,
                  enabled: !isSending,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 220,
                  decoration: const InputDecoration(
                    labelText: 'Mesaj',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: targetIdController,
                  enabled: !isSending,
                  decoration: InputDecoration(
                    labelText: selectedType == 'category_promo'
                        ? tr('category_name_optional')
                        : tr('target_id_optional'),
                    helperText: selectedType == 'category_promo'
                        ? tr('category_promo_target_helper')
                        : tr('target_id_example_listing'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: imageUrlController,
                  enabled: !isSending,
                  decoration: InputDecoration(
                    labelText: tr('image_url_optional_label'),
                    helperText: tr('campaign_banner_https_helper'),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(dialogContext),
              child: Text(tr('cancel'), style: LocalFonts.poppins()),
            ),
            FilledButton.icon(
              onPressed: isSending
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      final message = messageController.text.trim();
                      final targetId = targetIdController.text.trim();
                      final imageUrl = imageUrlController.text.trim();

                      if (title.isEmpty || message.isEmpty) {
                        ScaffoldMessenger.of(dialogBuildContext).showSnackBar(
                          SnackBar(content: Text(tr('title_message_required'))),
                        );
                        return;
                      }

                      if (!sendToAll && (userId == null || userId.isEmpty)) {
                        ScaffoldMessenger.of(dialogBuildContext).showSnackBar(
                          SnackBar(content: Text(tr('user_info_not_found'))),
                        );
                        return;
                      }

                      setStateDialog(() => isSending = true);
                      try {
                        final sentCount = await DatabaseService()
                            .sendAdminBroadcastNotification(
                              title: title,
                              message: message,
                              notificationType: selectedType,
                              targetUserIds: sendToAll ? null : [userId!],
                              targetId: targetId,
                              imageUrl: imageUrl,
                            );

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${tr('notification_sent_prefix')}$sentCount${tr('notification_sent_suffix')}',
                              ),
                            ),
                          );
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          setStateDialog(() => isSending = false);
                          ScaffoldMessenger.of(dialogBuildContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${tr('send_failed_prefix')}: $error',
                              ),
                            ),
                          );
                        }
                      }
                    },
              icon: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(tr('send'), style: LocalFonts.poppins()),
            ),
          ],
        ),
      ),
    );

    // Dialog kapanış animasyonunda TextField bir frame daha rebuild olabildiği
    // için controller'ları bir sonraki frame'de temizliyoruz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      titleController.dispose();
      messageController.dispose();
      targetIdController.dispose();
      imageUrlController.dispose();
    });
  }

  Future<void> _showGrantProDialog(BuildContext context, String userId) async {
    final limitController = TextEditingController(text: '10');
    var selectedDays = 30;
    var includePro = true;
    var includeListingRights = true;
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogBuildContext, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr('grant_package_and_rights_title'),
                          style: LocalFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildBenefitSwitch(
                    title: tr('pro_package_label'),
                    subtitle: tr('pro_package_subtitle'),
                    icon: Icons.workspace_premium_outlined,
                    value: includePro,
                    enabled: !isSaving,
                    onChanged: (value) =>
                        setDialogState(() => includePro = value),
                  ),
                  if (includePro) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: selectedDays,
                      decoration: InputDecoration(
                        labelText: tr('package_duration_label'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 30,
                          child: Text(tr('package_duration_1_month')),
                        ),
                        DropdownMenuItem(
                          value: 90,
                          child: Text(tr('package_duration_3_months')),
                        ),
                        DropdownMenuItem(
                          value: 180,
                          child: Text(tr('package_duration_6_months')),
                        ),
                        DropdownMenuItem(
                          value: 365,
                          child: Text(tr('package_duration_1_year')),
                        ),
                      ],
                      onChanged: isSaving
                          ? null
                          : (value) =>
                                setDialogState(() => selectedDays = value!),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildBenefitSwitch(
                    title: tr('additional_listing_rights_label'),
                    subtitle: tr('additional_listing_rights_subtitle'),
                    icon: Icons.add_chart_outlined,
                    value: includeListingRights,
                    enabled: !isSaving,
                    onChanged: (value) =>
                        setDialogState(() => includeListingRights = value),
                  ),
                  if (includeListingRights) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: limitController,
                      enabled: !isSaving,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: tr('listing_rights_to_add_label'),
                        helperText: tr('listing_rights_to_add_helper'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(dialogContext),
                          child: Text(
                            tr('cancel'),
                            style: LocalFonts.poppins(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final additionalRights = includeListingRights
                                      ? int.tryParse(
                                              limitController.text.trim(),
                                            ) ??
                                            0
                                      : null;
                                  if (!includePro && !includeListingRights) {
                                    ScaffoldMessenger.of(
                                      dialogBuildContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          tr('select_at_least_one_option'),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (additionalRights != null &&
                                      additionalRights <= 0) {
                                    ScaffoldMessenger.of(
                                      dialogBuildContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          tr(
                                            'listing_rights_must_be_at_least_one',
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setDialogState(() => isSaving = true);
                                  try {
                                    final assignedLimit =
                                        await DatabaseService().grantProToUser(
                                          userId: userId,
                                          grantPro: includePro,
                                          days: includePro
                                              ? selectedDays
                                              : null,
                                          additionalListingRights:
                                              additionalRights,
                                        );
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            assignedLimit == null
                                                ? tr(
                                                    'pro_package_assigned_success',
                                                  )
                                                : '${tr('total_listing_limit_updated_prefix')}$assignedLimit${tr('total_listing_limit_updated_suffix')}',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (error) {
                                    if (dialogContext.mounted) {
                                      setDialogState(() => isSaving = false);
                                      ScaffoldMessenger.of(
                                        dialogBuildContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${tr('operation_failed_prefix')}: $error',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  tr('assign_action'),
                                  style: LocalFonts.poppins(),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      limitController.dispose();
    });
  }

  Widget _buildBenefitSwitch({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      color: value ? const Color(0xFFF3F6FF) : Colors.grey.shade50,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: value ? const Color(0xFF356AE6) : const Color(0x16000000),
        ),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: enabled ? onChanged : null,
        secondary: Icon(
          icon,
          color: value ? const Color(0xFF356AE6) : Colors.grey,
        ),
        title: Text(
          title,
          style: LocalFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: LocalFonts.poppins(fontSize: 11)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  Widget _buildUserAvatar(String? photoUrl, {double radius = 20}) {
    final imageUrl = photoUrl?.trim() ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: imageUrl.isEmpty
          ? Icon(Icons.person, size: radius, color: Colors.white)
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Icon(Icons.person, size: radius, color: Colors.white),
              ),
            ),
    );
  }

  void _showUserOptionsDialog(
    BuildContext context,
    String userId,
    String userName,
    String currentPhone,
    bool isBanned,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('user_operations'),
              style: LocalFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.workspace_premium, color: Colors.amber),
              title: Text(
                tr('define_pro_package_action'),
                style: LocalFonts.poppins(),
              ),
              subtitle: Text(
                tr('define_pro_package_subtitle'),
                style: LocalFonts.poppins(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(c);
                _showGrantProDialog(context, userId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign, color: Colors.indigo),
              title: Text(
                tr('send_notification_title'),
                style: LocalFonts.poppins(),
              ),
              subtitle: Text(
                tr('send_notification_subtitle'),
                style: LocalFonts.poppins(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(c);
                _showAdminBroadcastDialog(
                  sendToAll: false,
                  userId: userId,
                  userName: userName,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_android, color: Colors.teal),
              title: Text(
                tr('admin_edit_user_phone'),
                style: LocalFonts.poppins(),
              ),
              subtitle: Text(
                tr('admin_edit_user_phone_desc'),
                style: LocalFonts.poppins(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(c);
                _showEditUserPhoneDialog(context, userId, currentPhone);
              },
            ),
            if (!isBanned) ...[
              ListTile(
                leading: const Icon(Icons.block),
                title: Text(tr('suspend_1_day')),
                onTap: () async {
                  await DatabaseService().banUser(userId, 1);
                  if (c.mounted) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(content: Text(tr('user_banned_1_day'))),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: Text(tr('suspend_1_week')),
                onTap: () async {
                  await DatabaseService().banUser(userId, 7);
                  if (c.mounted) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(content: Text(tr('user_banned_1_week'))),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: Text(tr('suspend_1_month')),
                onTap: () async {
                  await DatabaseService().banUser(userId, 30);
                  if (c.mounted) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(content: Text(tr('user_banned_1_month'))),
                    );
                  }
                },
              ),
            ],
            if (isBanned)
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(
                  tr('remove_ban_grant_access'),
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () async {
                  await DatabaseService().unbanUser(userId);
                  if (c.mounted) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(content: Text(tr('user_ban_removed'))),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditUserPhoneDialog(
    BuildContext context,
    String userId,
    String currentPhone,
  ) async {
    final phoneController = TextEditingController(text: currentPhone);
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogBuildContext, setDialogState) => AlertDialog(
          title: Text(
            tr('admin_edit_user_phone'),
            style: LocalFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: phoneController,
            enabled: !isSaving,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: tr('phone_number'),
              hintText: tr('enter_valid_phone_example'),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: Text(tr('cancel')),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final rawPhone = phoneController.text.trim();
                      final normalizedPhone = normalizePhoneNumber(rawPhone);

                      if (!isValidTurkishPhone(normalizedPhone)) {
                        ScaffoldMessenger.of(dialogBuildContext).showSnackBar(
                          SnackBar(
                            content: Text(tr('enter_valid_phone_example')),
                          ),
                        );
                        return;
                      }

                      final normalizedCurrent = normalizePhoneNumber(
                        currentPhone,
                      );
                      if (normalizedCurrent == normalizedPhone) {
                        ScaffoldMessenger.of(dialogBuildContext).showSnackBar(
                          SnackBar(content: Text(tr('already_current_number'))),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .set({
                              'phoneNumber': normalizedPhone,
                              'phoneVerified': true,
                              'phoneVerifiedAt': FieldValue.serverTimestamp(),
                              'phoneVerifiedBy': 'admin_panel',
                            }, SetOptions(merge: true));

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(tr('admin_phone_saved_verified')),
                            ),
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(dialogBuildContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${tr('operation_failed_prefix')}: $e',
                              ),
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(tr('save_changes')),
            ),
          ],
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      phoneController.dispose();
    });
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    final displaySubtitle = subtitle.trim().isEmpty
        ? tr('not_specified')
        : subtitle;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(
        title,
        style: LocalFonts.poppins(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Text(
        displaySubtitle,
        style: LocalFonts.poppins(
          fontSize: 15,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showUserDetailsSheet(
    BuildContext context,
    Map<String, dynamic> data,
    String userId,
    bool isBanned,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) {
        String? photoUrl = data['photoUrl']?.toString().trim();
        DateTime? createdAt = data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : null;

        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              const SizedBox(height: 24),
              _buildUserAvatar(photoUrl, radius: 50),
              const SizedBox(height: 16),
              Text(
                _resolveUserName(data),
                style: LocalFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isBanned)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'YASAKLI HESAP',
                    style: LocalFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Divider(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _buildInfoTile(
                      Icons.email,
                      tr('email_address'),
                      (data['email'] ?? '').toString().trim(),
                    ),
                    _buildInfoTile(
                      Icons.phone,
                      tr('phone_number'),
                      (data['phoneNumber'] != null &&
                              data['phoneNumber'].toString().isNotEmpty)
                          ? data['phoneNumber']
                          : tr('not_specified'),
                    ),
                    _buildInfoTile(
                      Icons.date_range,
                      tr('registration_date'),
                      createdAt != null
                          ? DateFormat('dd.MM.yyyy HH:mm').format(createdAt)
                          : tr('unknown'),
                    ),
                    _buildInfoTile(
                      Icons.shopping_bag,
                      tr('sales_count'),
                      (data['soldCount'] ?? 0).toString(),
                    ),
                    _buildInfoTile(
                      Icons.star,
                      'Toplam Puan Skoru',
                      (data['totalRatingScore'] ?? 0).toString(),
                    ),
                    _buildInfoTile(
                      Icons.info_outline,
                      tr('about_store_desc'),
                      (data['aboutMe'] != null &&
                              data['aboutMe'].toString().isNotEmpty)
                          ? data['aboutMe']
                          : tr('not_specified'),
                    ),
                    _buildInfoTile(
                      Icons.workspace_premium,
                      tr('is_pro_store'),
                      data['proUntil'] != null &&
                              (data['proUntil'] as Timestamp).toDate().isAfter(
                                DateTime.now(),
                              )
                          ? tr('yes_active')
                          : tr('no'),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(c);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                SellerProfileScreen(sellerId: userId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.storefront, color: Colors.white),
                      label: Text(
                        tr('go_to_user_showcase_store'),
                        style: LocalFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        final memberDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _isRealMemberDoc(data, doc.id);
        }).toList();
        final normalizedQuery = _searchQuery.trim().toLowerCase();
        final filteredDocs = memberDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (_showProOnly && !_hasActivePro(data)) return false;
          if (normalizedQuery.isEmpty) return true;
          final searchableFields = [
            _resolveUserName(data),
            data['email'],
            data['phoneNumber'],
          ];
          return searchableFields.any(
            (field) =>
                field?.toString().toLowerCase().contains(normalizedQuery) ??
                false,
          );
        }).toList();
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    const Icon(Icons.people, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(
                      '${memberDocs.length}',
                      style: LocalFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: tr('member_search_hint'),
                      onPressed: () {
                        setState(() => _showSearchField = !_showSearchField);
                        if (!_showSearchField) {
                          _searchController.clear();
                          _searchQuery = '';
                        }
                      },
                      icon: Icon(_showSearchField ? Icons.close : Icons.search),
                    ),
                    IconButton(
                      tooltip: tr('show_pro_members'),
                      onPressed: () {
                        setState(() => _showProOnly = !_showProOnly);
                      },
                      isSelected: _showProOnly,
                      color: _showProOnly ? Colors.amber[800] : null,
                      icon: const Icon(Icons.workspace_premium),
                    ),
                    IconButton(
                      tooltip: tr('bulk_notification'),
                      onPressed: () =>
                          _showAdminBroadcastDialog(sendToAll: true),
                      icon: const Icon(Icons.campaign),
                    ),
                  ],
                ),
              ),
            ),
            if (_showSearchField)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: tr('member_search_hint'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            if (filteredDocs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    tr('no_members_match_search'),
                    style: LocalFonts.poppins(color: Colors.grey),
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  var data = filteredDocs[index].data() as Map<String, dynamic>;
                  bool isBanned =
                      data['bannedUntil'] != null &&
                      (data['bannedUntil'] as Timestamp).toDate().isAfter(
                        DateTime.now(),
                      );

                  String? photoUrl = data['photoUrl']?.toString().trim();

                  return ListTile(
                    onTap: () => _showUserDetailsSheet(
                      context,
                      data,
                      filteredDocs[index].id,
                      isBanned,
                    ), // YENİ: Profile erişim tıkı
                    leading: _buildUserAvatar(photoUrl),
                    title: Text(
                      _resolveUserName(data),
                      style: TextStyle(
                        color: isBanned ? Colors.red : Colors.black,
                        fontWeight: isBanned
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      isBanned
                          ? '${tr('banned_user_prefix')}${data['email']}'
                          : (data['email'] ?? ''),
                      style: TextStyle(
                        color: isBanned ? Colors.red : Colors.grey,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.settings, color: Colors.blue),
                      onPressed: () => _showUserOptionsDialog(
                        context,
                        filteredDocs[index].id,
                        _resolveUserName(data),
                        (data['phoneNumber'] ?? '').toString().trim(),
                        isBanned,
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
