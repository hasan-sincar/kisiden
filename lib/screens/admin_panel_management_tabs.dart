part of 'admin_panel_screen.dart';

class _AdminProfanityTab extends StatefulWidget {
  const _AdminProfanityTab();

  @override
  State<_AdminProfanityTab> createState() => _AdminProfanityTabState();
}

class _AdminProfanityTabState extends State<_AdminProfanityTab> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _wordController = TextEditingController();
  List<String> _words = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    _words = await _dbService.getProfanityWords();
    setState(() => _isLoading = false);
  }

  Future<void> _addWord() async {
    if (_wordController.text.trim().isNotEmpty) {
      await _dbService.addProfanityWord(_wordController.text.trim());
      _wordController.clear();
      _loadWords();
    }
  }

  Future<void> _removeWord(String word) async {
    await _dbService.removeProfanityWord(word);
    _loadWords();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wordController,
                  decoration: InputDecoration(
                    hintText: tr('word_hint'),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[800],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _addWord,
                child: Text(
                  tr('add_word'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _words.isEmpty
                ? Center(
                    child: Text(
                      tr('no_banned_words'),
                      style: LocalFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _words.length,
                    itemBuilder: (context, index) {
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.block, color: Colors.red),
                          title: Text(
                            _words[index],
                            style: LocalFonts.poppins(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _removeWord(_words[index]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AdminPurchasesTab extends StatelessWidget {
  const _AdminPurchasesTab();

  DateTime? _purchaseDate(Map<String, dynamic> data) {
    final raw = data['timestamp'] ?? data['createdAt'] ?? data['purchaseDate'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  String _formatPurchaseDate(Map<String, dynamic> data) {
    final date = _purchaseDate(data);
    if (date == null) return '-';
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }

  double _parsePurchasePrice(dynamic rawPrice) {
    final value = rawPrice?.toString().trim() ?? '';
    if (value.isEmpty) return 0;

    final normalized = value.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (normalized.contains(',') && normalized.contains('.')) {
      final lastComma = normalized.lastIndexOf(',');
      final lastDot = normalized.lastIndexOf('.');
      if (lastComma > lastDot) {
        return double.tryParse(
              normalized.replaceAll('.', '').replaceFirst(',', '.'),
            ) ??
            0;
      }
      return double.tryParse(normalized.replaceAll(',', '')) ?? 0;
    }
    if (normalized.contains(',')) {
      return double.tryParse(normalized.replaceFirst(',', '.')) ?? 0;
    }
    return double.tryParse(normalized) ?? 0;
  }

  String _resolvePackageName(String pId, [String type = '']) {
    if (pId == 'pro_3_ay') {
      return tr('pro_3_months');
    } else if (pId == 'pro_6_ay') {
      return tr('pro_6_months');
    } else if (pId == 'pro_12_ay') {
      return tr('pro_12_months');
    } else if (pId == 'vitrin_1_gun') {
      return tr('showcase_1_day');
    } else if (pId == 'vitrin_1_hafta') {
      return tr('showcase_1_week');
    } else if (pId == 'vitrin_1_ay') {
      return tr('showcase_1_month');
    } else if (pId == 'kat_vitrin_1_gun') {
      return tr('category_showcase_1_day');
    } else if (pId == 'kat_vitrin_1_hafta') {
      return tr('category_showcase_1_week');
    } else if (pId == 'kat_vitrin_1_ay') {
      return tr('category_showcase_1_month');
    } else if (pId == 'acil_2_gun') {
      return 'Acil 1 Gun';
    } else if (pId == 'acil_3_gun') {
      return 'Acil 3 Gun';
    } else if (pId == 'acil_7_gun') {
      return 'Acil 7 Gun';
    } else if (pId == 'ilan_hakki_5') {
      return '5 Ilan Hakki Paketi';
    } else if (pId == 'ilan_hakki_10') {
      return '10 Ilan Hakki Paketi';
    } else if (pId == 'ilan_hakki_20') {
      return '20 Ilan Hakki Paketi';
    } else if (pId == 'rewarded_ad_1') {
      return 'Reklam Odulu (+1 Hak)';
    }
    if (pId == 'admin_manual' && type.isNotEmpty) return type;
    return pId.isEmpty ? (type.isEmpty ? 'Satın alma' : type) : pId;
  }

  String _resolveLimitText(Map<String, dynamic> data) {
    if (data['addedListingLimit'] != null) {
      return '${data['addedListingLimit']} ek ilan hakki';
    }
    if (data['limit'] != null) {
      return tr(
        'purchase_limit_listing',
      ).replaceFirst('%s', '${data['limit']}');
    }
    return tr('purchase_limit_days').replaceFirst('%s', '${data['days']}');
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LocalFonts.poppins(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: LocalFonts.poppins(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LocalFonts.poppins(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: LocalFonts.poppins(
              fontSize: 15,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(String packageId) {
    final bool isReward = packageId == 'rewarded_ad_1';
    final bool isListingRight = packageId.startsWith('ilan_hakki_');

    final Color color = isReward
        ? Colors.deepOrange
        : (isListingRight ? Colors.indigo : Colors.green);
    final String text = isReward
        ? 'Reklam Odulu'
        : (isListingRight ? 'Ilan Hakki' : 'Paket');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Text(
        text,
        style: LocalFonts.poppins(
          fontSize: 10.5,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('purchases').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = [...snapshot.data!.docs]
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = _purchaseDate(aData);
            final bDate = _purchaseDate(bData);
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });

        double dailyTotal = 0;
        double weeklyTotal = 0;
        double monthlyTotal = 0;
        double listingRightRevenue = 0;
        int paidListingRightSales = 0;
        int rewardedListingRightCount = 0;
        int paidListingRightsGranted = 0;
        int rewardedListingRightsGranted = 0;

        DateTime now = DateTime.now();
        DateTime startOfToday = DateTime(now.year, now.month, now.day);
        DateTime sevenDaysAgo = now.subtract(const Duration(days: 7));
        DateTime startOfMonth = DateTime(now.year, now.month, 1);

        for (var doc in docs) {
          var data = doc.data() as Map<String, dynamic>;
          final date = _purchaseDate(data);
          if (date != null) {
            final price = _parsePurchasePrice(data['price']);
            if (date.isAfter(startOfToday) ||
                date.isAtSameMomentAs(startOfToday)) {
              dailyTotal += price;
            }
            if (date.isAfter(sevenDaysAgo) ||
                date.isAtSameMomentAs(sevenDaysAgo)) {
              weeklyTotal += price;
            }
            if (date.isAfter(startOfMonth) ||
                date.isAtSameMomentAs(startOfMonth)) {
              monthlyTotal += price;
            }

            final packageId = (data['packageId'] ?? data['productId'] ?? '')
                .toString();
            final addedLimit =
                (data['addedListingLimit'] as num?)?.toInt() ?? 0;
            if (packageId.startsWith('ilan_hakki_')) {
              paidListingRightSales += 1;
              paidListingRightsGranted += addedLimit;
              listingRightRevenue += price;
            }
            if (packageId == 'rewarded_ad_1') {
              rewardedListingRightCount += 1;
              rewardedListingRightsGranted += addedLimit;
            }
          }
        }

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey.shade50, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _summaryCard(
                          title: tr('today'),
                          value: '₺${dailyTotal.toStringAsFixed(2)}',
                          icon: Icons.today_outlined,
                          colors: [
                            const Color(0xFF1D4ED8),
                            const Color(0xFF3B82F6),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 58,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _summaryCard(
                          title: tr('last_7_days'),
                          value: '₺${weeklyTotal.toStringAsFixed(2)}',
                          icon: Icons.date_range_outlined,
                          colors: [
                            const Color(0xFFEA580C),
                            const Color(0xFFF59E0B),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 58,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _summaryCard(
                          title: tr('this_month'),
                          value: '₺${monthlyTotal.toStringAsFixed(2)}',
                          icon: Icons.calendar_month_outlined,
                          colors: [
                            const Color(0xFF047857),
                            const Color(0xFF10B981),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 430;
                      return GridView.count(
                        crossAxisCount: isNarrow ? 2 : 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: isNarrow ? 2.0 : 2.1,
                        children: [
                          _miniStatCard(
                            title: 'Ilan Hakki Geliri',
                            value: '₺${listingRightRevenue.toStringAsFixed(0)}',
                            color: Colors.purple,
                          ),
                          _miniStatCard(
                            title: 'Ucretli Paket Satis',
                            value: paidListingRightSales.toString(),
                            color: Colors.teal,
                          ),
                          _miniStatCard(
                            title: 'Reklam Odul Sayisi',
                            value: rewardedListingRightCount.toString(),
                            color: Colors.deepOrange,
                          ),
                          _miniStatCard(
                            title: 'Satilan Hak',
                            value: paidListingRightsGranted.toString(),
                            color: Colors.indigo,
                          ),
                          _miniStatCard(
                            title: 'Reklamdan Hak',
                            value: rewardedListingRightsGranted.toString(),
                            color: Colors.brown,
                          ),
                          _miniStatCard(
                            title: 'Toplam Kayit',
                            value: docs.length.toString(),
                            color: Colors.blueGrey,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (docs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      tr('no_purchases_yet'),
                      style: LocalFonts.poppins(),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  sliver: SliverList.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final pId = (data['packageId'] ?? data['productId'] ?? '')
                          .toString();
                      final type = (data['type'] ?? '').toString();
                      final packageName = _resolvePackageName(pId, type);
                      final limitText = _resolveLimitText(data);
                      final userName = (data['userName'] ?? '').toString();
                      final userEmail = (data['userEmail'] ?? '').toString();
                      final price = (data['price'] ?? '').toString();
                      final dateStr = _formatPurchaseDate(data);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName.isEmpty
                                            ? 'Kullanici'
                                            : userName,
                                        style: LocalFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      if (userEmail.isNotEmpty)
                                        Text(
                                          userEmail,
                                          style: LocalFonts.poppins(
                                            fontSize: 11.5,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  price,
                                  style: LocalFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green.shade700,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _typeBadge(pId),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    dateStr,
                                    style: LocalFonts.poppins(
                                      fontSize: 10.5,
                                      color: Colors.blueGrey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${tr('package')}: $packageName',
                              style: LocalFonts.poppins(
                                fontSize: 12,
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              limitText,
                              style: LocalFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminTicketsTab extends StatelessWidget {
  const _AdminTicketsTab();

  String _resolveTicketUserName({
    required String userId,
    required Map<String, dynamic> ticketData,
    Map<String, dynamic>? userData,
  }) {
    final ticketUserName = (ticketData['userName'] ?? '').toString().trim();
    final userName = (userData?['name'] ?? '').toString().trim();
    final userEmail = (userData?['email'] ?? '').toString().trim();
    final userPhone = (userData?['phoneNumber'] ?? '').toString().trim();

    if (ticketUserName.isNotEmpty && ticketUserName != userId) {
      return ticketUserName;
    }
    if (userName.isNotEmpty) {
      return userName;
    }
    if (userEmail.isNotEmpty) {
      final localPart = userEmail.split('@').first.trim();
      if (localPart.isNotEmpty) return localPart;
      return userEmail;
    }
    if (userPhone.isNotEmpty) {
      return userPhone;
    }
    if (ticketUserName.isNotEmpty) {
      return ticketUserName;
    }
    return userId;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tickets')
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              tr('no_tickets'),
              style: LocalFonts.poppins(fontSize: 16),
            ),
          );
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
            final userId = data['userId'] ?? '';
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminTicketDetailScreen(
                        ticketId: ticketId,
                        subject: subject,
                        userId: userId,
                      ),
                    ),
                  );
                },
                title: Text(
                  subject,
                  style: LocalFonts.poppins(fontWeight: FontWeight.bold),
                ),
                subtitle: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .get(),
                  builder: (context, userSnap) {
                    String displayUser = _resolveTicketUserName(
                      userId: userId,
                      ticketData: data,
                    );
                    if (userSnap.hasData && userSnap.data!.exists) {
                      var uData = userSnap.data!.data() as Map<String, dynamic>;
                      displayUser = _resolveTicketUserName(
                        userId: userId,
                        ticketData: data,
                        userData: uData,
                      );
                    }
                    return Text(
                      '${tr('user')}: $displayUser\n${updatedAt != null ? DateFormat('dd.MM.yyyy HH:mm').format(updatedAt.toDate()) : ''}',
                      style: LocalFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
                isThreeLine: true,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: LocalFonts.poppins(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
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

class _AdminAdsTab extends StatefulWidget {
  const _AdminAdsTab();

  @override
  State<_AdminAdsTab> createState() => _AdminAdsTabState();
}

class _AdminAdsTabState extends State<_AdminAdsTab> {
  final TextEditingController _androidController = TextEditingController();
  final TextEditingController _iosController = TextEditingController();
  final TextEditingController _latestVersionController =
      TextEditingController();
  final TextEditingController _minSupportedVersionController =
      TextEditingController();
  final TextEditingController _updateTitleController = TextEditingController();
  final TextEditingController _updateMessageController =
      TextEditingController();
  final TextEditingController _androidStoreUrlController =
      TextEditingController();
  final TextEditingController _iosStoreUrlController = TextEditingController();
  final TextEditingController _remindIntervalHoursController =
      TextEditingController(text: '24');
  final TextEditingController _rewardedAndroidIdController =
      TextEditingController(text: 'ca-app-pub-3940256099942544/5224354917');
  final TextEditingController _rewardedIosIdController = TextEditingController(
    text: 'ca-app-pub-3940256099942544/1712485313',
  );
  final TextEditingController _rewardDailyMaxController = TextEditingController(
    text: '3',
  );
  final TextEditingController _rewardCooldownMinutesController =
      TextEditingController(text: '10');
  final TextEditingController _paidPackagesController = TextEditingController(
    text:
        'ilan_hakki_5|5|5 İlan Hakkı\nilan_hakki_10|10|10 İlan Hakkı\nilan_hakki_20|20|20 İlan Hakkı',
  );
  bool _isActive = true;
  bool _updateEnabled = true;
  bool _forceUpdate = false;
  bool _isLoading = true;
  String _currentAppVersion = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _androidController.dispose();
    _iosController.dispose();
    _latestVersionController.dispose();
    _minSupportedVersionController.dispose();
    _updateTitleController.dispose();
    _updateMessageController.dispose();
    _androidStoreUrlController.dispose();
    _iosStoreUrlController.dispose();
    _remindIntervalHoursController.dispose();
    _rewardedAndroidIdController.dispose();
    _rewardedIosIdController.dispose();
    _rewardDailyMaxController.dispose();
    _rewardCooldownMinutesController.dispose();
    _paidPackagesController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentAppVersion = packageInfo.version.trim();

      var doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('ads')
          .get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _isActive = data['isActive'] ?? true;
            _androidController.text = data['androidId'] ?? '';
            _iosController.text = data['iosId'] ?? '';
          });
        }
      }

      var listingRightsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('listing_rights')
          .get();
      if (listingRightsDoc.exists) {
        final data = listingRightsDoc.data() as Map<String, dynamic>;
        final rawPackages = (data['paidPackages'] as List<dynamic>? ?? [])
            .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
            .toList();
        final packageLines = rawPackages
            .where(
              (p) =>
                  (p['productId']?.toString().trim().isNotEmpty ?? false) &&
                  (p['grantCount'] is num),
            )
            .map(
              (p) =>
                  '${p['productId']}|${(p['grantCount'] as num).toInt()}|${(p['title'] ?? '').toString()}',
            )
            .join('\n');

        if (mounted) {
          setState(() {
            _rewardedAndroidIdController.text =
                (data['rewardedAndroidAdUnitId'] ?? '').toString();
            _rewardedIosIdController.text = (data['rewardedIosAdUnitId'] ?? '')
                .toString();
            _rewardDailyMaxController.text = (data['rewardDailyMax'] ?? 3)
                .toString();
            _rewardCooldownMinutesController.text =
                (data['rewardCooldownMinutes'] ?? 10).toString();
            if (packageLines.isNotEmpty) {
              _paidPackagesController.text = packageLines;
            }
          });
        }
      }

      var updateDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_update')
          .get();
      if (updateDoc.exists) {
        final data = updateDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _latestVersionController.text =
                (data['latestVersion']?.toString().trim().isNotEmpty ?? false)
                ? data['latestVersion'].toString().trim()
                : _currentAppVersion;
            _updateEnabled = data['updateEnabled'] != false;
            _minSupportedVersionController.text =
                data['minSupportedVersion'] ?? '';
            _forceUpdate = data['forceUpdate'] == true;
            _updateTitleController.text =
                data['updateTitle'] ?? tr('update_default_title');
            _updateMessageController.text =
                data['updateMessage'] ?? tr('update_default_message');
            _androidStoreUrlController.text = data['storeUrlAndroid'] ?? '';
            _iosStoreUrlController.text = data['storeUrlIos'] ?? '';
            _remindIntervalHoursController.text =
                (data['remindIntervalHours'] ?? 24).toString();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _latestVersionController.text = _currentAppVersion;
          });
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      print('Reklam ayarları yüklenirken izin/ağ hatası: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      await DatabaseService().updateAdSettings(
        _isActive,
        _androidController.text.trim(),
        _iosController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('ads_settings_saved_successfully')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${tr('error')}${tr('admin_publish_security_rules')}\n${tr('detail')}: $e',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAppUpdateSettings() async {
    final latestVersion = _latestVersionController.text.trim();
    final minSupportedVersion = _minSupportedVersionController.text.trim();
    final updateTitle = _updateTitleController.text.trim();
    final updateMessage = _updateMessageController.text.trim();
    final androidStoreUrl = _androidStoreUrlController.text.trim();
    final iosStoreUrl = _iosStoreUrlController.text.trim();
    final remindHours =
        int.tryParse(_remindIntervalHoursController.text.trim()) ?? 24;

    if (latestVersion.isEmpty || minSupportedVersion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('update_versions_required')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await DatabaseService().updateAppUpdateSettings(
        updateEnabled: _updateEnabled,
        latestVersion: latestVersion,
        minSupportedVersion: minSupportedVersion,
        forceUpdate: _forceUpdate,
        updateTitle: updateTitle,
        updateMessage: updateMessage,
        storeUrlAndroid: androidStoreUrl,
        storeUrlIos: iosStoreUrl,
        remindIntervalHours: remindHours < 1 ? 24 : remindHours,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('update_settings_saved')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('settings_save_failed')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _parsePaidPackages() {
    final lines = _paidPackagesController.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final output = <Map<String, dynamic>>[];

    for (final line in lines) {
      final parts = line.split('|');
      if (parts.length < 2) continue;

      final productId = parts[0].trim();
      final grantCount = int.tryParse(parts[1].trim()) ?? 0;
      final title = parts.length >= 3 ? parts[2].trim() : '';

      if (productId.isEmpty || grantCount <= 0) continue;
      output.add({
        'productId': productId,
        'grantCount': grantCount,
        'title': title,
      });
    }

    return output;
  }

  Future<void> _saveListingRightsSettings() async {
    final paidPackages = _parsePaidPackages();
    if (paidPackages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('at_least_one_valid_package_line')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final rewardDailyMax =
        int.tryParse(_rewardDailyMaxController.text.trim()) ?? 3;
    final rewardCooldownMinutes =
        int.tryParse(_rewardCooldownMinutesController.text.trim()) ?? 10;

    setState(() => _isLoading = true);
    try {
      await DatabaseService().updateListingRightsSettings(
        rewardedAndroidAdUnitId: _rewardedAndroidIdController.text.trim(),
        rewardedIosAdUnitId: _rewardedIosIdController.text.trim(),
        rewardDailyMax: rewardDailyMax < 1 ? 3 : rewardDailyMax,
        rewardCooldownMinutes: rewardCooldownMinutes < 1
            ? 10
            : rewardCooldownMinutes,
        paidPackages: paidPackages,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('listing_rights_settings_saved')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('listing_rights_settings_save_failed')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              tr('ads_info_text'),
              style: LocalFonts.poppins(fontSize: 12, color: Colors.blue[800]),
            ),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              tr('show_ads_active_passive'),
              style: LocalFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            value: _isActive,
            onChanged: (val) => setState(() => _isActive = val),
            activeThumbColor: Colors.green,
          ),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            tr('android_banner_id'),
            style: LocalFonts.poppins(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _androidController,
            decoration: InputDecoration(
              hintText: tr('example_banner_id_android'),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr('ios_banner_id'),
            style: LocalFonts.poppins(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _iosController,
            decoration: InputDecoration(
              hintText: tr('example_banner_id_ios'),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.save, color: Colors.white),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: _saveSettings,
            label: Text(
              tr('save_and_apply_settings'),
              style: LocalFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 18),
          Text(
            tr('listing_rights_monetization_title'),
            style: LocalFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('listing_rights_monetization_hint'),
            style: LocalFonts.poppins(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _paidPackagesController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: tr('paid_packages_label'),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _rewardedAndroidIdController,
            decoration: const InputDecoration(
              labelText: 'Android Rewarded Ad Unit ID',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _rewardedIosIdController,
            decoration: const InputDecoration(
              labelText: 'iOS Rewarded Ad Unit ID',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _rewardDailyMaxController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('reward_daily_max_label'),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _rewardCooldownMinutesController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('reward_cooldown_minutes_label'),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            icon: const Icon(Icons.workspace_premium, color: Colors.white),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: _saveListingRightsSettings,
            label: Text(
              tr('save_listing_rights_settings'),
              style: LocalFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 18),
          Text(
            tr('app_update_control_title'),
            style: LocalFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('app_update_control_hint'),
            style: LocalFonts.poppins(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _latestVersionController,
            decoration: InputDecoration(
              labelText: tr('latest_version_label'),
              helperText: _currentAppVersion.isEmpty
                  ? tr('current_app_version_unavailable')
                  : '${tr('current_app_version')}: $_currentAppVersion',
              suffixIcon: _currentAppVersion.isEmpty
                  ? null
                  : IconButton(
                      tooltip: tr('write_current_version_tooltip'),
                      icon: const Icon(Icons.my_location_rounded),
                      onPressed: () {
                        setState(() {
                          _latestVersionController.text = _currentAppVersion;
                        });
                      },
                    ),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              tr('update_control_active'),
              style: LocalFonts.poppins(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _updateEnabled
                  ? tr('update_control_enabled_desc')
                  : tr('update_control_disabled_desc'),
              style: LocalFonts.poppins(fontSize: 12, color: Colors.grey[700]),
            ),
            value: _updateEnabled,
            onChanged: (val) => setState(() => _updateEnabled = val),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _minSupportedVersionController,
            decoration: InputDecoration(
              labelText: tr('min_supported_version_label'),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              tr('force_update_label'),
              style: LocalFonts.poppins(fontWeight: FontWeight.w600),
            ),
            value: _forceUpdate,
            onChanged: (val) => setState(() => _forceUpdate = val),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _updateTitleController,
            decoration: InputDecoration(
              labelText: tr('title_label_common'),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _updateMessageController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Mesaj',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _androidStoreUrlController,
            decoration: const InputDecoration(
              labelText: 'Android Store URL',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _iosStoreUrlController,
            decoration: const InputDecoration(
              labelText: 'iOS Store URL',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _remindIntervalHoursController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: tr('remind_interval_hours_label'),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            icon: const Icon(Icons.system_update_alt, color: Colors.white),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: _saveAppUpdateSettings,
            label: Text(
              tr('save_update_settings'),
              style: LocalFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
