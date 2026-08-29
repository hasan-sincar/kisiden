import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'listing_detail_screen.dart';
import '../utils/auth_gate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/translations.dart';

int calculateSellerTrustScore(Map<String, dynamic> sellerData) {
  final soldCount = (sellerData['soldCount'] ?? 0) as num;
  final totalReviews = (sellerData['totalReviewCount'] ?? 0) as num;
  final totalScore = (sellerData['totalRatingScore'] ?? 0).toDouble();
  final avgResponseHours = (sellerData['avgResponseHours'] ?? 24) as num;
  final approvalRate = (sellerData['approvalRate'] ?? 95) as num;

  final ratingScore = totalReviews > 0
      ? ((totalScore / totalReviews) / 5) * 40
      : 0.0;
  final salesScore = (soldCount.toDouble() * 1.25).clamp(0, 25).toDouble();
  final reviewScore = (totalReviews.toDouble() * 2.5).clamp(0, 20).toDouble();
  final responseScore = avgResponseHours <= 2
      ? 10.0
      : avgResponseHours <= 6
      ? 8.0
      : avgResponseHours <= 12
      ? 6.0
      : avgResponseHours <= 24
      ? 3.0
      : 0.0;
  final approvalScore = (approvalRate.toDouble() / 10).clamp(0, 10).toDouble();

  return ((ratingScore +
              salesScore +
              reviewScore +
              responseScore +
              approvalScore)
          .round())
      .clamp(0, 100);
}

class SellerProfileScreen extends StatefulWidget {
  final String sellerId;

  const SellerProfileScreen({super.key, required this.sellerId});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _hasReviewPermission = false;
  String? _pendingReviewListingTitle;

  Future<bool> _requireRegisteredUser() async {
    return AuthGate.requireRegisteredUser(
      context,
      message: 'İletişim bilgilerine erişmek için giriş yapmalısınız.',
    );
  }

  Future<void> _launchURL(String urlString, {bool isInstagram = false}) async {
    if (!await _requireRegisteredUser()) return;
    if (urlString.isEmpty) return;
    if (isInstagram && !urlString.contains('instagram.com')) {
      urlString = 'https://instagram.com/${urlString.replaceAll('@', '')}';
    }
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('cannot_open_link'))));
    }
  }

  @override
  void initState() {
    super.initState();
    _checkReviewPermission();
  }

  Future<void> _checkReviewPermission() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sellerId)
          .collection('review_permissions')
          .doc(currentUserId)
          .get();
      if (mounted) {
        setState(() => _hasReviewPermission = doc.exists);
        if (_hasReviewPermission)
          _pendingReviewListingTitle = doc.data()?['listingTitle'];
        if (_hasReviewPermission) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showReviewDialog();
          });
        }
      }
    }
  }

  void _showReviewDialog() {
    double currentRating = 5;
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(
            tr('rate_seller'),
            style: LocalFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      icon: Icon(
                        index < currentRating ? Icons.star : Icons.star_border,
                        color: Colors.orange,
                        size: 40,
                      ),
                      onPressed: () =>
                          setStateDialog(() => currentRating = index + 1.0),
                    ),
                  ),
                ),
              ),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: tr('review_hint'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
              ),
              onPressed: () async {
                if (commentController.text.trim().isNotEmpty) {
                  await _dbService.addSellerReview(
                    widget.sellerId,
                    currentRating,
                    commentController.text.trim(),
                    _pendingReviewListingTitle ?? tr('unknown_product'),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    setState(() => _hasReviewPermission = false);
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
      ),
    );
  }

  void _blockSeller() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          tr('block_seller'),
          style: const TextStyle(color: Colors.red),
        ),
        content: Text(tr('block_seller_confirm')),
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
              await _dbService.blockUser(widget.sellerId);
              if (context.mounted) {
                Navigator.pop(c);
                Navigator.pop(context); // Profil sayfasından da çık
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(tr('seller_blocked'))));
              }
            },
            child: Text(
              tr('block'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sellerId.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('seller_profile'))),
        body: Center(
          child: Text(
            'Satıcı bilgisi bulunamadı.',
            style: LocalFonts.poppins(),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.sellerId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: Text(tr('seller_profile'))),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Satıcı profili yüklenemedi. Giriş yapıp tekrar deneyin.',
                    textAlign: TextAlign.center,
                    style: LocalFonts.poppins(),
                  ),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting)
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Scaffold(
              appBar: AppBar(title: Text(tr('seller_profile'))),
              body: Center(
                child: Text(
                  'Satıcı profili bulunamadı.',
                  style: LocalFonts.poppins(),
                ),
              ),
            );
          }

          var sellerData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          int soldCount = sellerData['soldCount'] ?? 0;
          int followerCount = sellerData['followerCount'] ?? 0;
          bool isPro =
              sellerData['proUntil'] != null &&
              (sellerData['proUntil'] as Timestamp).toDate().isAfter(
                DateTime.now(),
              );

          int membershipDays = 0;
          if (sellerData['createdAt'] != null) {
            membershipDays = DateTime.now()
                .difference((sellerData['createdAt'] as Timestamp).toDate())
                .inDays;
          }

          // YENİ: Güvenilir Satıcı ve Yeni Satıcı Mantığı
          int totalReviews = sellerData['totalReviewCount'] ?? 0;
          double totalScore = (sellerData['totalRatingScore'] ?? 0).toDouble();
          double averageRating = totalReviews > 0
              ? (totalScore / totalReviews)
              : 0.0;
          int trustScore = calculateSellerTrustScore(sellerData);
          bool isReliableSeller = trustScore >= 70 || soldCount >= 3;
          bool isNewSeller = membershipDays <= 30 && !isReliableSeller;
          bool isHighlyRated = totalReviews >= 3 && averageRating >= 4.0;

          String contactPref = sellerData['contactPreference'] ?? 'both';

          String instagram = sellerData['instagram'] ?? '';
          String facebook = sellerData['facebook'] ?? '';
          String website = sellerData['website'] ?? '';

          return Scaffold(
            backgroundColor: Colors.grey[50],
            appBar: AppBar(
              title: Text(tr('seller_profile'), style: LocalFonts.poppins()),
              actions: [
                if (FirebaseAuth.instance.currentUser?.uid != widget.sellerId)
                  IconButton(
                    icon: const Icon(Icons.block, color: Colors.red),
                    tooltip: tr('block_seller'),
                    onPressed: _blockSeller,
                  ),
              ],
            ),
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // SATICI BİLGİ KARTI
                        Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              height: 160,
                              width: double.infinity,
                              margin: const EdgeInsets.only(
                                left: 20,
                                right: 20,
                                top: 16,
                                bottom: 50,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[800],
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                image:
                                    sellerData['coverPhotoUrl'] != null &&
                                        sellerData['coverPhotoUrl'] != ''
                                    ? DecorationImage(
                                        image: NetworkImage(
                                          sellerData['coverPhotoUrl'],
                                        ),
                                        fit: BoxFit.cover,
                                        onError: (e, s) {},
                                      )
                                    : null,
                              ),
                            ),
                            if (instagram.isNotEmpty ||
                                facebook.isNotEmpty ||
                                website.isNotEmpty)
                              Positioned(
                                top: 24,
                                right: 24,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (instagram.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          shape: const CircleBorder(),
                                          clipBehavior: Clip.antiAlias,
                                          child: InkWell(
                                            onTap: () => _launchURL(
                                              instagram,
                                              isInstagram: true,
                                            ),
                                            child: const Padding(
                                              padding: EdgeInsets.all(8),
                                              child: Icon(
                                                Icons.camera_alt,
                                                color: Colors.purple,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (facebook.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          shape: const CircleBorder(),
                                          clipBehavior: Clip.antiAlias,
                                          child: InkWell(
                                            onTap: () => _launchURL(facebook),
                                            child: const Padding(
                                              padding: EdgeInsets.all(8),
                                              child: Icon(
                                                Icons.facebook,
                                                color: Colors.blue,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (website.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          shape: const CircleBorder(),
                                          clipBehavior: Clip.antiAlias,
                                          child: InkWell(
                                            onTap: () => _launchURL(website),
                                            child: const Padding(
                                              padding: EdgeInsets.all(8),
                                              child: Icon(
                                                Icons.language,
                                                color: Colors.green,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.shopping_bag,
                                          size: 14,
                                          color: Colors.green[800],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$soldCount ${tr('sales')}',
                                          style: LocalFonts.poppins(
                                            color: Colors.green[800],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                CircleAvatar(
                                  radius: 54,
                                  backgroundColor: Colors.white,
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage:
                                        sellerData['photoUrl'] != null &&
                                            sellerData['photoUrl'] != ''
                                        ? NetworkImage(sellerData['photoUrl'])
                                        : null,
                                    onBackgroundImageError:
                                        (sellerData['photoUrl'] != null &&
                                            sellerData['photoUrl'] != '')
                                        ? (e, s) {}
                                        : null, // DÜZELTME: Resim yoksa error listener da null olmalı
                                    child:
                                        sellerData['photoUrl'] == null ||
                                            sellerData['photoUrl'] == ''
                                        ? const Icon(
                                            Icons.person,
                                            size: 50,
                                            color: Colors.grey,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.verified,
                                          size: 14,
                                          color: Colors.purple[800],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$membershipDays ${tr('days')}',
                                          style: LocalFonts.poppins(
                                            color: Colors.purple[800],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20.0),
                          padding: const EdgeInsets.fromLTRB(
                            24.0,
                            12.0,
                            24.0,
                            24.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      sellerData['name'] ??
                                          tr('anonymous_seller'),
                                      style: LocalFonts.poppins(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isPro) const SizedBox(width: 8),
                                  if (isPro)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'PRO',
                                        style: LocalFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (isReliableSeller ||
                                  isNewSeller ||
                                  isHighlyRated)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (isReliableSeller)
                                        _buildBadge(
                                          Icons.verified_user,
                                          tr('trustworthy_seller'),
                                          Colors.green,
                                        ),
                                      if (isHighlyRated)
                                        _buildBadge(
                                          Icons.star_rounded,
                                          tr('highly_rated_seller'),
                                          Colors.orange,
                                        ),
                                      if (isNewSeller)
                                        _buildBadge(
                                          Icons.new_releases,
                                          tr('new_seller'),
                                          Colors.blue,
                                        ),
                                    ],
                                  ),
                                ),
                              if (!isReliableSeller &&
                                  !isNewSeller &&
                                  !isHighlyRated)
                                const SizedBox(height: 0),
                              const SizedBox(height: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.blue.shade100,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              tr('trust_score'),
                                              style: LocalFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue[900],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                    ),
                                                    titlePadding:
                                                        const EdgeInsets.fromLTRB(
                                                          16,
                                                          16,
                                                          16,
                                                          0,
                                                        ),
                                                    contentPadding:
                                                        const EdgeInsets.fromLTRB(
                                                          16,
                                                          8,
                                                          16,
                                                          16,
                                                        ),
                                                    title: Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .info_outline_rounded,
                                                          color:
                                                              Colors.blue[800],
                                                          size: 20,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            tr('trust_score'),
                                                            style:
                                                                LocalFonts.poppins(
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    content: Text(
                                                      tr('trust_score_desc'),
                                                      style: LocalFonts.poppins(
                                                        fontSize: 13,
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              context,
                                                            ),
                                                        child: Text(
                                                          tr('close'),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.blue[50],
                                                  border: Border.all(
                                                    color: Colors.blue.shade100,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.info_outline_rounded,
                                                  size: 12,
                                                  color: Colors.blue[800],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: SizedBox(
                                                height: 22,
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      child:
                                                          LinearProgressIndicator(
                                                            value:
                                                                trustScore /
                                                                100,
                                                            backgroundColor:
                                                                Colors
                                                                    .blue[100],
                                                            color:
                                                                trustScore >= 80
                                                                ? Colors.green
                                                                : trustScore >=
                                                                      60
                                                                ? Colors.orange
                                                                : Colors.blue,
                                                            minHeight: 10,
                                                          ),
                                                    ),
                                                    Text(
                                                      '$trustScore/100',
                                                      style: LocalFonts.poppins(
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.blue[900],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.blue.shade100,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.people_alt_rounded,
                                              size: 14,
                                              color: Colors.blue[800],
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              '$followerCount ${tr('followers')}',
                                              style: LocalFonts.poppins(
                                                color: Colors.blue[900],
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (FirebaseAuth.instance.currentUser !=
                                              null &&
                                          FirebaseAuth
                                                  .instance
                                                  .currentUser!
                                                  .uid !=
                                              widget.sellerId)
                                        StreamBuilder<bool>(
                                          stream: _dbService.isFollowingStream(
                                            widget.sellerId,
                                          ),
                                          builder: (context, followSnap) {
                                            bool isFollowing =
                                                followSnap.data ?? false;
                                            return ElevatedButton(
                                              onPressed: () =>
                                                  _dbService.toggleFollowSeller(
                                                    widget.sellerId,
                                                    isFollowing,
                                                  ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: isFollowing
                                                    ? Colors.blue[50]
                                                    : Colors.blue[800],
                                                elevation: 0,
                                                minimumSize: const Size(0, 30),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  side: BorderSide(
                                                    color: Colors.blue[800]!,
                                                    width: 1,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.person_add_alt_1,
                                                    size: 14,
                                                    color: isFollowing
                                                        ? Colors.blue[800]
                                                        : Colors.white,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    isFollowing
                                                        ? tr('unfollow')
                                                        : tr('follow'),
                                                    style: LocalFonts.poppins(
                                                      color: isFollowing
                                                          ? Colors.blue[800]
                                                          : Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (sellerData['aboutMe'] != null &&
                                  sellerData['aboutMe'] != '')
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    '"${sellerData['aboutMe']}"',
                                    textAlign: TextAlign.center,
                                    style: LocalFonts.poppins(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              if (_hasReviewPermission)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: ElevatedButton.icon(
                                    onPressed: _showReviewDialog,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.star,
                                      color: Colors.orange,
                                      size: 24,
                                    ),
                                    label: Text(
                                      tr('rate_and_review'),
                                      style: LocalFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        labelColor: Colors.blue,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.blue,
                        tabs: [
                          Tab(
                            icon: const Icon(Icons.list),
                            text: tr('active_listings'),
                          ),
                          Tab(
                            icon: const Icon(Icons.star),
                            text: tr('reviews'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  // 1. SEKME: SATICININ İLANLARI
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('listings')
                        .where('sellerId', isEqualTo: widget.sellerId)
                        .snapshots(),
                    builder: (context, listingSnap) {
                      if (!listingSnap.hasData)
                        return const Center(child: CircularProgressIndicator());
                      var docs = listingSnap.data!.docs;
                      if (docs.isEmpty)
                        return Center(
                          child: Text(
                            tr('no_active_listings_seller'),
                            style: LocalFonts.poppins(color: Colors.grey),
                          ),
                        );

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.72,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var data = docs[index].data() as Map<String, dynamic>;
                          String formattedPrice = data['price']
                              .toString()
                              .split('.')
                              .first
                              .replaceAllMapped(
                                RegExp(r'\B(?=(\d{3})+(?!\d))'),
                                (m) => '.',
                              );
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ListingDetailScreen(
                                    data: data,
                                    listingId: docs[index].id,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      color: Colors.grey[100],
                                      child: Image.network(
                                        data['imageUrl'] ?? '',
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => const Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '₺$formattedPrice',
                                          style: LocalFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.blue[800],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          data['title'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: LocalFonts.poppins(
                                            fontSize: 13,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
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

                  // 2. SEKME: YORUMLAR
                  Column(
                    children: [
                      _buildRatingDistribution(sellerData),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.sellerId)
                              .collection('reviews')
                              .orderBy('timestamp', descending: true)
                              .snapshots(),
                          builder: (context, reviewSnap) {
                            if (!reviewSnap.hasData)
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            var reviews = reviewSnap.data!.docs;
                            if (reviews.isEmpty)
                              return Center(
                                child: Text(
                                  tr('no_reviews_yet'),
                                  style: LocalFonts.poppins(color: Colors.grey),
                                ),
                              );

                            return ListView.builder(
                              padding: const EdgeInsets.only(top: 8),
                              itemCount: reviews.length,
                              itemBuilder: (context, index) {
                                var rev =
                                    reviews[index].data()
                                        as Map<String, dynamic>;
                                String dateStr = '';
                                if (rev['timestamp'] != null) {
                                  DateTime dt = (rev['timestamp'] as Timestamp)
                                      .toDate();
                                  dateStr =
                                      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
                                }
                                return Container(
                                  margin: const EdgeInsets.only(
                                    bottom: 16.0,
                                    left: 16.0,
                                    right: 16.0,
                                  ),
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.03,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.grey.shade100,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: Colors.blue[50],
                                            backgroundImage:
                                                (rev['buyerPhoto'] != null &&
                                                    rev['buyerPhoto'] != '')
                                                ? NetworkImage(
                                                    rev['buyerPhoto'],
                                                  )
                                                : null,
                                            onBackgroundImageError: (e, s) {},
                                            child:
                                                (rev['buyerPhoto'] == null ||
                                                    rev['buyerPhoto'] == '')
                                                ? const Icon(
                                                    Icons.person,
                                                    color: Colors.blue,
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      rev['buyerName'] ??
                                                          tr('anonymous_user'),
                                                      style: LocalFonts.poppins(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                    if (dateStr.isNotEmpty)
                                                      Text(
                                                        dateStr,
                                                        style:
                                                            LocalFonts.poppins(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .grey[500],
                                                            ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: List.generate(
                                                    5,
                                                    (i) => Icon(
                                                      i < (rev['rating'] ?? 0)
                                                          ? Icons.star
                                                          : Icons.star_border,
                                                      color: Colors.orange,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (rev['listingTitle'] != null) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            '${tr('product_colon')} ${rev['listingTitle']}',
                                            style: LocalFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey[700],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                        rev['comment'],
                                        style: LocalFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.black87,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
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
  }

  // Rozet Oluşturucu Yardımcı Widget
  Widget _buildBadge(IconData icon, String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color[700], size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: LocalFonts.poppins(
              color: color[800],
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactBtn(
    IconData icon,
    String text,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        text,
        style: LocalFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // Değerlendirme Dağılımı (Progress Bar) Yardımcı Widget'ı
  Widget _buildRatingDistribution(Map<String, dynamic> userData) {
    int count1 = userData['ratingCount1'] ?? 0;
    int count2 = userData['ratingCount2'] ?? 0;
    int count3 = userData['ratingCount3'] ?? 0;
    int count4 = userData['ratingCount4'] ?? 0;
    int count5 = userData['ratingCount5'] ?? 0;
    int totalReviews = userData['totalReviewCount'] ?? 0;
    double totalScore = (userData['totalRatingScore'] ?? 0).toDouble();
    double average = totalReviews > 0 ? (totalScore / totalReviews) : 0.0;

    if (totalReviews == 0) return const SizedBox();

    Widget buildRatingBar(int star, int count) {
      double percentage = totalReviews > 0 ? (count / totalReviews) : 0.0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          children: [
            Text(
              '$star',
              style: LocalFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const Icon(Icons.star, size: 14, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey[200],
                  color: Colors.amber,
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 30,
              child: Text(
                '$count',
                style: LocalFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                average.toStringAsFixed(1),
                style: LocalFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < average.round() ? Icons.star : Icons.star_border,
                    size: 16,
                    color: Colors.amber,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalReviews Değerlendirme',
                style: LocalFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                buildRatingBar(5, count5),
                buildRatingBar(4, count4),
                buildRatingBar(3, count3),
                buildRatingBar(2, count2),
                buildRatingBar(1, count1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color:
          Colors.grey[50], // Arka plan ile sekmeler uyumlu olsun diye eklendi
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
