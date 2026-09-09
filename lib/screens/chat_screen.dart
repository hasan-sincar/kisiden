import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import '../services/database_service.dart';
import '../utils/translations.dart';
import '../utils/chat_risk_detector.dart';
import 'listing_detail_screen.dart';
import '../models/safe_meeting_point.dart';
import '../services/safe_meeting_points_service.dart';
import 'safe_meeting_map_screen.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? listingTitle;
  final String? listingId;
  final String? listingImage;
  final String? listingPrice;
  final double? listingLatitude;
  final double? listingLongitude;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.listingTitle,
    this.listingId,
    this.listingImage,
    this.listingPrice,
    this.listingLatitude,
    this.listingLongitude,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _CounterOfferDialog extends StatefulWidget {
  const _CounterOfferDialog();

  @override
  State<_CounterOfferDialog> createState() => _CounterOfferDialogState();
}

class _CounterOfferDialogState extends State<_CounterOfferDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('counter_offer')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: tr('your_offer_tl'),
          prefixText: '₺ ',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        FilledButton(onPressed: _submit, child: Text(tr('send_offer'))),
      ],
    );
  }
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  bool _isLoadingReadyMessages = true;
  List<String> _customReadyMessages = <String>[];
  String? _chatListingTitle;
  String? _chatListingId;
  String? _chatListingImage;
  String? _chatListingPrice;
  double? _chatListingLatitude;
  double? _chatListingLongitude;
  ChatRiskAnalysis _composerRisk = ChatRiskDetector.analyze('');
  bool _isRestrictionLoading = true;
  bool _canSendMessage = true;
  bool _canStartNewChat = true;
  bool _isLoadingMeetingPoints = false;
  bool _isReceiverTradeEnabled = false;
  int _restrictionLevel = 0;
  String _restrictionReason = '';
  int _restrictionSecondsLeft = 0;

  String get _chatRoomId {
    return DatabaseService.buildChatRoomId(
      firstUserId: currentUserId,
      secondUserId: widget.receiverId,
      listingId: _chatListingId ?? widget.listingId,
    );
  }

  Future<void> _showCounterOfferDialog({
    required String receiverId,
    required String listingTitle,
    required String listingId,
  }) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => const _CounterOfferDialog(),
    );
    if (amount == null) return;
    try {
      await _dbService.sendCounterOffer(
        receiverId: receiverId,
        listingTitle: listingTitle,
        listingId: listingId,
        offerAmount: amount,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('offer_sent'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_offerErrorMessage(e))));
    }
  }

  String _offerErrorMessage(Object error) {
    final code = error is StateError ? error.message : error.toString();
    if (error is FirebaseException) {
      return tr('offer_send_failed');
    }
    return switch (code) {
      'offer_below_minimum' => tr('offer_below_minimum'),
      'offers_disabled' => tr('offers_disabled'),
      'offer_listing_unavailable' => tr('offer_listing_unavailable'),
      'offer_rate_limited' => tr('offer_rate_limited'),
      _ => tr('offer_send_failed'),
    };
  }

  static const List<String> _defaultReadyMessageKeys = <String>[
    'rm_is_it_still_available',
    'rm_what_is_last_price',
    'rm_do_you_consider_trade',
    'rm_is_product_working',
    'rm_is_there_negotiation',
    'rm_do_you_ship',
    'rm_is_hand_delivery_possible',
    'rm_is_invoice_available',
    'rm_is_warranty_active',
    'rm_can_i_see_today',
    'rm_final_price_question',
    'rm_thank_you',
  ];

  @override
  void initState() {
    super.initState();
    _chatListingTitle = widget.listingTitle;
    _chatListingId = widget.listingId;
    _chatListingImage = widget.listingImage;
    _chatListingPrice = widget.listingPrice;
    _chatListingLatitude = widget.listingLatitude;
    _chatListingLongitude = widget.listingLongitude;
    _initSpeech();
    _loadChatRestrictions();
    _loadCustomReadyMessages();
    _ensureChatRoomExists();
    _hydrateChatListingMeta();
  }

  Future<void> _loadChatRestrictions() async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('checkChatRestrictions');

      final result = await callable.call();
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;

      setState(() {
        _canSendMessage = (data['canSend'] as bool?) ?? true;
        _canStartNewChat = (data['canStartNewChat'] as bool?) ?? true;
        _restrictionLevel = (data['level'] as num?)?.toInt() ?? 0;
        final reasonKey = (data['reasonKey'] ?? '').toString();
        _restrictionReason = reasonKey.isNotEmpty
            ? tr(reasonKey)
            : (data['reason'] ?? '').toString();
        _restrictionSecondsLeft = (data['secondsLeft'] as num?)?.toInt() ?? 0;
        _isRestrictionLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRestrictionLoading = false;
      });
    }
  }

  Future<void> _ensureChatRoomExists() async {
    if (!_canStartNewChat) {
      return;
    }
    try {
      final ids = <String>[currentUserId, widget.receiverId]..sort();
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatRoomId)
          .set({
            'participants': ids,
            'listingTitle': _chatListingTitle ?? '',
            'listingId': _chatListingId ?? '',
            'listingImage': _chatListingImage ?? '',
            'listingPrice': _chatListingPrice ?? '',
            if (_chatListingLatitude != null)
              'listingLatitude': _chatListingLatitude,
            if (_chatListingLongitude != null)
              'listingLongitude': _chatListingLongitude,
            'unreadBy': <String>[],
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Ensure chat room failed: $e');
    }
  }

  Future<void> _hydrateChatListingMeta() async {
    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatRoomId)
          .get();

      final chatData = chatDoc.data() as Map<String, dynamic>?;
      if (!chatDoc.exists &&
          (_chatListingId == null || _chatListingId!.isEmpty)) {
        return;
      }
      if (chatData == null) {
        await _loadReceiverTradeSetting();
        return;
      }

      final existingTitle = chatData['listingTitle']?.toString();
      final existingId = chatData['listingId']?.toString();
      final existingImage = chatData['listingImage']?.toString();
      final existingPrice = chatData['listingPrice']?.toString();
      final existingLatitude = (chatData['listingLatitude'] as num?)
          ?.toDouble();
      final existingLongitude = (chatData['listingLongitude'] as num?)
          ?.toDouble();

      if (mounted) {
        setState(() {
          _chatListingTitle = (_chatListingTitle?.isNotEmpty == true)
              ? _chatListingTitle
              : (existingTitle?.isNotEmpty == true ? existingTitle : null);
          _chatListingId = (_chatListingId?.isNotEmpty == true)
              ? _chatListingId
              : (existingId?.isNotEmpty == true ? existingId : null);
          _chatListingImage = (_chatListingImage?.isNotEmpty == true)
              ? _chatListingImage
              : (existingImage?.isNotEmpty == true ? existingImage : null);
          _chatListingPrice = (_chatListingPrice?.isNotEmpty == true)
              ? _chatListingPrice
              : (existingPrice?.isNotEmpty == true ? existingPrice : null);
          _chatListingLatitude ??= existingLatitude;
          _chatListingLongitude ??= existingLongitude;
        });
      }

      if ((_chatListingId == null || _chatListingId!.isEmpty) &&
          (_chatListingTitle != null && _chatListingTitle!.isNotEmpty)) {
        final listingSnap = await FirebaseFirestore.instance
            .collection('listings')
            .where('title', isEqualTo: _chatListingTitle)
            .where('sellerId', whereIn: [widget.receiverId, currentUserId])
            .limit(1)
            .get();

        if (listingSnap.docs.isNotEmpty) {
          final listingDoc = listingSnap.docs.first;
          final listingData = listingDoc.data();
          final resolvedImage = listingData['imageUrl']?.toString() ?? '';
          final resolvedPrice = listingData['price']?.toString() ?? '';
          final resolvedLatitude =
              (listingData['lat'] as num?)?.toDouble() ??
              (listingData['latitude'] as num?)?.toDouble();
          final resolvedLongitude =
              (listingData['lng'] as num?)?.toDouble() ??
              (listingData['longitude'] as num?)?.toDouble();

          if (mounted) {
            setState(() {
              _chatListingId = listingDoc.id;
              if ((_chatListingImage ?? '').isEmpty &&
                  resolvedImage.isNotEmpty) {
                _chatListingImage = resolvedImage;
              }
              if ((_chatListingPrice ?? '').isEmpty &&
                  resolvedPrice.isNotEmpty) {
                _chatListingPrice = resolvedPrice;
              }
              _chatListingLatitude ??= resolvedLatitude;
              _chatListingLongitude ??= resolvedLongitude;
            });
          }

          await FirebaseFirestore.instance
              .collection('chats')
              .doc(_chatRoomId)
              .set({
                'listingId': listingDoc.id,
                if (resolvedImage.isNotEmpty) 'listingImage': resolvedImage,
                if (resolvedPrice.isNotEmpty) 'listingPrice': resolvedPrice,
                if (resolvedLatitude != null)
                  'listingLatitude': resolvedLatitude,
                if (resolvedLongitude != null)
                  'listingLongitude': resolvedLongitude,
              }, SetOptions(merge: true));
        }
      }
      await _loadReceiverTradeSetting();
      if (_chatListingId != null &&
          _chatListingId!.isNotEmpty &&
          (_chatListingLatitude == null || _chatListingLongitude == null)) {
        final listing = await FirebaseFirestore.instance
            .collection('listings')
            .doc(_chatListingId)
            .get();
        final data = listing.data();
        if (mounted && data != null) {
          setState(() {
            _chatListingLatitude =
                (data['lat'] as num?)?.toDouble() ??
                (data['latitude'] as num?)?.toDouble();
            _chatListingLongitude =
                (data['lng'] as num?)?.toDouble() ??
                (data['longitude'] as num?)?.toDouble();
          });
        }
      }
    } catch (e) {
      debugPrint('Hydrate chat listing meta failed: $e');
    }
  }

  Future<void> _loadReceiverTradeSetting() async {
    final listingId = _chatListingId;
    if (listingId == null || listingId.isEmpty) return;
    final listing = await FirebaseFirestore.instance
        .collection('listings')
        .doc(listingId)
        .get();
    if (mounted && listing.exists) {
      setState(() {
        _isReceiverTradeEnabled =
            (listing.data()?['tradeEnabled'] as bool?) ?? false;
      });
    }
  }

  Future<void> _showTradeListingPicker() async {
    if (!_isReceiverTradeEnabled || !_canSendMessage) return;
    final listings = await _dbService.getUserListingsForTrade(
      uid: currentUserId,
    );
    if (!mounted) return;
    if (listings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('trade_offer_missing_own_listing'))),
      );
      return;
    }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.7,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: listings.length,
            itemBuilder: (context, index) {
              final listing = listings[index];
              final image = listing['imageUrl']?.toString() ?? '';
              return Card(
                child: ListTile(
                  leading: image.isEmpty
                      ? const Icon(Icons.image_outlined)
                      : Image.network(
                          image,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                  title: Text(listing['title']?.toString() ?? ''),
                  subtitle: Text('₺${listing['price'] ?? ''}'),
                  onTap: () => Navigator.pop(sheetContext, listing),
                ),
              );
            },
          ),
        ),
      ),
    );
    if (selected == null || !_canSendMessage) return;
    await _dbService.sendMessage(
      widget.receiverId,
      'Takas ilanı: ${selected['title'] ?? ''}',
      _chatListingTitle ?? '',
      listingId: _chatListingId,
      listingImage: _chatListingImage,
      listingPrice: _chatListingPrice,
      type: 'tradeListing',
      tradeListingId: selected['id']?.toString(),
      tradeListingTitle: selected['title']?.toString(),
      tradeListingImage: selected['imageUrl']?.toString(),
      tradeListingPrice: (selected['price'] as num?)?.toDouble(),
    );
    await _dbService.notifyTradeListingShared(
      receiverId: widget.receiverId,
      senderName:
          FirebaseAuth.instance.currentUser?.displayName?.trim().isNotEmpty ==
              true
          ? FirebaseAuth.instance.currentUser!.displayName!
          : tr('user'),
      chatRoomId: _chatRoomId,
    );
  }

  List<String> get _defaultReadyMessages =>
      _defaultReadyMessageKeys.map((key) => tr(key)).toList();

  Future<void> _loadCustomReadyMessages() async {
    try {
      final custom = await _dbService.getCustomReadyMessages();
      if (!mounted) return;
      setState(() {
        _customReadyMessages = custom;
        _isLoadingReadyMessages = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _customReadyMessages = <String>[];
        _isLoadingReadyMessages = false;
      });
    }
  }

  Future<void> _persistCustomReadyMessages(List<String> next) async {
    await _dbService.saveCustomReadyMessages(next);
    if (!mounted) return;
    setState(() {
      _customReadyMessages = next;
    });
  }

  void _initSpeech() async {
    try {
      await _speechToText.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Speech initialize error: $e');
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    try {
      await _speechToText.listen(onResult: _onSpeechResult, localeId: 'tr_TR');
      if (mounted) {
        setState(() => _isListening = true);
      }
    } catch (e) {
      debugPrint('Speech listen error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('voice_typing_start_failed'))),
        );
      }
    }
  }

  Future<void> _stopListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (e) {
      debugPrint('Speech stop error: $e');
    } finally {
      if (mounted) {
        setState(() => _isListening = false);
      }
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final recognizedText = result.recognizedWords.trim();
    if (recognizedText.isEmpty) {
      return;
    }

    final currentText = _messageController.text.trimRight();
    final newText = currentText.isEmpty
        ? recognizedText
        : '$currentText $recognizedText';

    if (mounted) {
      setState(() {
        _messageController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
        _composerRisk = ChatRiskDetector.analyze(newText);
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_isRestrictionLoading) {
      return;
    }

    if (!_canSendMessage) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _restrictionReason.isNotEmpty
                  ? _restrictionReason
                  : tr('chat_send_temporarily_restricted'),
            ),
          ),
        );
      }
      return;
    }

    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      final risk = ChatRiskDetector.analyze(text);

      if (risk.isHighRisk) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('chat_risky_message_title')),
            content: Text(
              '${tr('chat_risky_message_detected')}\n\n${risk.signals.join('\n')}\n\n${tr('chat_risky_message_guidance')}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr('send_anyway')),
              ),
            ],
          ),
        );

        if (proceed != true) {
          return;
        }
      }

      await _dbService.sendMessage(
        widget.receiverId,
        text,
        _chatListingTitle ?? '',
        listingId: _chatListingId,
        listingImage: _chatListingImage,
        listingPrice: _chatListingPrice,
        riskScore: risk.score,
        riskLevel: risk.level,
        riskSignals: risk.signals,
      );
      _messageController.clear();
      if (mounted) {
        setState(() {
          _composerRisk = ChatRiskDetector.analyze('');
        });
      }

      await _loadChatRestrictions();
    }
  }

  Future<void> _shareSafeMeetingPoint() async {
    if (!_canSendMessage ||
        _chatListingLatitude == null ||
        _chatListingLongitude == null) {
      return;
    }
    setState(() => _isLoadingMeetingPoints = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Güvenli buluşma noktaları aranıyor...'),
        duration: Duration(seconds: 2),
      ),
    );
    final points = await SafeMeetingPointsService().fetchNearbyPoints(
      latitude: _chatListingLatitude!,
      longitude: _chatListingLongitude!,
    );
    if (!mounted) return;
    setState(() => _isLoadingMeetingPoints = false);
    if (points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yakında güvenli buluşma noktası bulunamadı.'),
        ),
      );
      return;
    }
    final selected = await Navigator.push<SafeMeetingPoint>(
      context,
      MaterialPageRoute(builder: (_) => SafeMeetingMapScreen(points: points)),
    );
    if (selected == null || !_canSendMessage) return;

    await _dbService.sendMessage(
      widget.receiverId,
      'Güvenli buluşma noktası: ${selected.name}',
      _chatListingTitle ?? '',
      listingId: _chatListingId,
      listingImage: _chatListingImage,
      listingPrice: _chatListingPrice,
      type: 'safeMeetingPoint',
      meetingPoint: selected.toMap(),
    );
    await _loadChatRestrictions();
  }

  void _insertReadyMessage(String message) {
    _messageController.value = TextEditingValue(
      text: message,
      selection: TextSelection.collapsed(offset: message.length),
    );
    setState(() {});
  }

  Future<void> _sendReadyMessageNow(String message) async {
    _insertReadyMessage(message);
    await _sendMessage();
  }

  Future<void> _showAddOrEditReadyMessageDialog({
    String? initial,
    int? editIndex,
  }) async {
    final controller = TextEditingController(text: initial ?? '');
    final isEdit = editIndex != null;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isEdit ? tr('edit_ready_message') : tr('add_ready_message'),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: tr('ready_message_hint'),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('ready_message_empty_error'))),
                  );
                  return;
                }

                final next = List<String>.from(_customReadyMessages);
                if (isEdit) {
                  next[editIndex] = value;
                } else {
                  next.add(value);
                }
                await _persistCustomReadyMessages(next);
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: Text(tr('save_changes')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCustomReadyMessage(int index) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete_ready_message')),
        content: Text(tr('delete_ready_message_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );

    if (approved != true) return;
    final next = List<String>.from(_customReadyMessages)..removeAt(index);
    await _persistCustomReadyMessages(next);
  }

  Future<void> _showReadyMessagesBottomSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final defaultMessages = _defaultReadyMessages;
        final customMessages = _customReadyMessages;
        final colorScheme = Theme.of(context).colorScheme;

        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: DefaultTabController(
            length: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('ready_messages'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('ready_messages_subtitle'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TabBar(
                    tabs: [
                      Tab(text: tr('default_messages')),
                      Tab(text: tr('my_ready_messages')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: TabBarView(
                      children: [
                        if (_isLoadingReadyMessages)
                          const Center(child: CircularProgressIndicator())
                        else
                          ListView(
                            children: defaultMessages
                                .map(
                                  (message) => Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      title: Text(message),
                                      onTap: () {
                                        _insertReadyMessage(message);
                                        Navigator.pop(context);
                                      },
                                      trailing: IconButton(
                                        icon: const Icon(Icons.send_rounded),
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          await _sendReadyMessageNow(message);
                                        },
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        if (_isLoadingReadyMessages)
                          const Center(child: CircularProgressIndicator())
                        else
                          ListView(
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _showAddOrEditReadyMessageDialog();
                                    if (mounted) {
                                      await _showReadyMessagesBottomSheet();
                                    }
                                  },
                                  icon: const Icon(Icons.add_rounded),
                                  label: Text(tr('add')),
                                ),
                              ),
                              if (customMessages.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    bottom: 8,
                                  ),
                                  child: Text(
                                    tr('no_custom_ready_messages'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                              ...customMessages.asMap().entries.map((entry) {
                                final index = entry.key;
                                final message = entry.value;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(message),
                                    onTap: () {
                                      _insertReadyMessage(message);
                                      Navigator.pop(context);
                                    },
                                    trailing: Wrap(
                                      spacing: 2,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            await _showAddOrEditReadyMessageDialog(
                                              initial: message,
                                              editIndex: index,
                                            );
                                            if (mounted) {
                                              await _showReadyMessagesBottomSheet();
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            await _deleteCustomReadyMessage(
                                              index,
                                            );
                                            if (mounted) {
                                              await _showReadyMessagesBottomSheet();
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.send_rounded),
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            await _sendReadyMessageNow(message);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleComposerAction() async {
    if (_isRestrictionLoading) {
      return;
    }
    if (_messageController.text.trim().isNotEmpty) {
      await _stopListening();
      await _sendMessage();
    } else {
      _toggleListening();
    }
  }

  Future<void> _openListingDetails() async {
    if (_chatListingId == null || _chatListingId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('listing_detail_not_found_in_chat'))),
        );
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(_chatListingId)
          .get();

      if (doc.exists && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ListingDetailScreen(
              data: doc.data() as Map<String, dynamic>,
              listingId: _chatListingId!,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Listing detail open error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatRoomId = _chatRoomId;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.receiverName,
          style: LocalFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .snapshots(),
        builder: (context, userSnap) {
          if (userSnap.hasData && userSnap.data!.exists) {
            var userData = userSnap.data!.data() as Map<String, dynamic>;
            List<String> hiddenUsers = [
              ...List<String>.from(userData['blockedUsers'] ?? []),
              ...List<String>.from(userData['blockedBy'] ?? []),
            ];
            if (hiddenUsers.contains(widget.receiverId)) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.block, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      tr('cannot_contact_blocked_seller'),
                      style: LocalFonts.poppins(
                        fontSize: 15,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              );
            }
          }
          return Column(
            children: [
              if ((_chatListingTitle ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 0,
                    child: InkWell(
                      onTap: _openListingDetails,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            if ((_chatListingImage ?? '').isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  _chatListingImage!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.sell_rounded,
                                  color: Colors.blue[700],
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    _chatListingTitle ?? '',
                                    style: LocalFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (_chatListingPrice ?? '').isNotEmpty
                                        ? '₺${_chatListingPrice}'
                                        : '-',
                                    style: LocalFonts.poppins(
                                      color: Colors.blue[800],
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatRoomId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    var messages = snapshot.data!.docs;

                    return ListView.builder(
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        var data =
                            messages[index].data() as Map<String, dynamic>;
                        bool isMe = data['senderId'] == currentUserId;

                        // --- YENİ: ÖZEL TEKLİF BALONCUĞU UI ---
                        if (data['type'] == 'offer') {
                          double offerAmount = (data['offerAmount'] ?? 0)
                              .toDouble();
                          String status = data['offerStatus'] ?? 'pending';
                          String messageId = messages[index].id;
                          final expiresAt = data['offerExpiresAt'];
                          final isExpired =
                              status == 'pending' &&
                              expiresAt is Timestamp &&
                              expiresAt.toDate().isBefore(DateTime.now());
                          if (isExpired) status = 'expired';
                          if (isExpired) {
                            _dbService.expireOfferIfNeeded(
                              chatRoomId,
                              messageId,
                              isMe ? widget.receiverId : currentUserId,
                            );
                          }

                          Color statusColor = Colors.orange;
                          String statusText = '${tr('trade_status_pending')} ⏳';
                          if (status == 'accepted') {
                            statusColor = Colors.green;
                            statusText = '${tr('trade_status_accepted')} ✅';
                          } else if (status == 'rejected') {
                            statusColor = Colors.red;
                            statusText = '${tr('trade_status_rejected')} ❌';
                          } else if (status == 'expired') {
                            statusColor = Colors.grey;
                            statusText = '${tr('offer_expired')} ⌛';
                          } else if (status == 'cancelled') {
                            statusColor = Colors.grey;
                            statusText = '${tr('offer_cancelled')}';
                          }

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              padding: const EdgeInsets.all(16),
                              width: MediaQuery.of(context).size.width * 0.75,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.purple.shade200,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.local_offer,
                                        color: Colors.purple,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          data['offerKind'] == 'counter'
                                              ? tr('counter_offer_received')
                                              : isMe
                                              ? tr('your_offer_to_seller')
                                              : tr('buyers_offer'),
                                          style: LocalFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(), const SizedBox(height: 8),
                                  Text(
                                    '₺${offerAmount.toStringAsFixed(0)}',
                                    style: LocalFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        '${tr('status')}: ',
                                        style: LocalFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        statusText,
                                        style: LocalFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Satıcı teklifi görüyorsa Kabul Et / Reddet butonlarını çıkar
                                  if (!isMe && status == 'pending') ...[
                                    const SizedBox(height: 16),
                                    Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.red[600],
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                onPressed: () => _dbService
                                                    .updateOfferStatus(
                                                      chatRoomId,
                                                      messageId,
                                                      'rejected',
                                                      data['senderId'],
                                                    ),
                                                child: Text(
                                                  tr('reject'),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.green[600],
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                onPressed: () => _dbService
                                                    .updateOfferStatus(
                                                      chatRoomId,
                                                      messageId,
                                                      'accepted',
                                                      data['senderId'],
                                                    ),
                                                child: Text(
                                                  tr('accept'),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                _showCounterOfferDialog(
                                                  receiverId: data['senderId']
                                                      .toString(),
                                                  listingTitle:
                                                      (_chatListingTitle ?? '')
                                                          .toString(),
                                                  listingId:
                                                      (_chatListingId ?? '')
                                                          .toString(),
                                                ),
                                            icon: const Icon(Icons.swap_horiz),
                                            label: Text(tr('counter_offer')),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (isMe && status == 'pending') ...[
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _dbService.updateOfferStatus(
                                            chatRoomId,
                                            messageId,
                                            'cancelled',
                                            widget.receiverId,
                                          ),
                                      icon: const Icon(Icons.undo),
                                      label: Text(tr('cancel')),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }
                        // -------------------------------------

                        if (data['type'] == 'safeMeetingPoint') {
                          final rawPoint = data['meetingPoint'];
                          final point = rawPoint is Map
                              ? SafeMeetingPoint.fromMap(
                                  Map<String, dynamic>.from(rawPoint),
                                )
                              : null;
                          if (point == null) return const SizedBox.shrink();
                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.verified_user_outlined,
                                  color: Colors.green,
                                ),
                                title: Text(point.name),
                                subtitle: Text(point.address),
                                trailing: const Icon(Icons.map_outlined),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SafeMeetingMapScreen(
                                      points: [point],
                                      initialSelectedId: point.id,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        if (data['type'] == 'tradeListing') {
                          final tradeListingId =
                              data['tradeListingId']?.toString() ?? '';
                          final tradeTitle =
                              data['tradeListingTitle']?.toString() ?? '';
                          final tradeImage =
                              data['tradeListingImage']?.toString() ?? '';
                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: tradeListingId.isEmpty
                                    ? null
                                    : () async {
                                        final listing = await FirebaseFirestore
                                            .instance
                                            .collection('listings')
                                            .doc(tradeListingId)
                                            .get();
                                        if (!mounted || !listing.exists) {
                                          return;
                                        }
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ListingDetailScreen(
                                              data: listing.data()!,
                                              listingId: tradeListingId,
                                            ),
                                          ),
                                        );
                                      },
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.swap_horiz_rounded,
                                    color: Colors.deepPurple,
                                  ),
                                  title: Text(
                                    tr('trade_listing_shared'),
                                    style: LocalFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                  subtitle: Text(
                                    tradeTitle.isEmpty
                                        ? tr('listing_detail')
                                        : tradeTitle,
                                  ),
                                  trailing: tradeImage.isEmpty
                                      ? const Icon(Icons.chevron_right)
                                      : Image.network(
                                          tradeImage,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                            ),
                          );
                        }

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.green[600]
                                      : Colors.blue[600],
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: isMe
                                        ? const Radius.circular(16)
                                        : const Radius.circular(4),
                                    bottomRight: isMe
                                        ? const Radius.circular(4)
                                        : const Radius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  data['message'],
                                  style: LocalFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (((data['riskScore'] as num?)?.toInt() ??
                                      ChatRiskDetector.analyze(
                                        (data['message'] ?? '').toString(),
                                      ).score) >=
                                  40)
                                Container(
                                  margin: const EdgeInsets.only(
                                    left: 12,
                                    right: 12,
                                    bottom: 4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.orange.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.security_rounded,
                                        color: Colors.orange[800],
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        tr('chat_risky_message_badge'),
                                        style: LocalFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.orange[900],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
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

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 12.0,
                    right: 12.0,
                    top: 8.0,
                    bottom: 24.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_restrictionLevel > 0)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _canSendMessage
                                ? Colors.amber[50]
                                : Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _canSendMessage
                                  ? Colors.amber.shade200
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Text(
                            _restrictionReason.isNotEmpty
                                ? _restrictionReason
                                : tr(
                                    'chat_security_level',
                                  ).replaceFirst('%s', '$_restrictionLevel'),
                            style: LocalFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _canSendMessage
                                  ? Colors.amber[900]
                                  : Colors.red[900],
                            ),
                          ),
                        ),
                      if (_composerRisk.isRisky)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange[800],
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _composerRisk.signals.isNotEmpty
                                      ? tr(
                                          'chat_composer_risk_warning_with_signal',
                                        ).replaceFirst(
                                          '%s',
                                          _composerRisk.signals.first,
                                        )
                                      : tr('chat_composer_risk_warning'),
                                  style: LocalFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              onChanged: (value) {
                                setState(() {
                                  _composerRisk = ChatRiskDetector.analyze(
                                    value,
                                  );
                                });
                              },
                              decoration: InputDecoration(
                                hintText: tr('chat_message_hint'),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_chatListingLatitude != null &&
                              _chatListingLongitude != null)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                tooltip: 'Güvenli buluşma noktası paylaş',
                                icon: _isLoadingMeetingPoints
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.green[700],
                                        ),
                                      )
                                    : Icon(
                                        Icons.location_on_outlined,
                                        color: Colors.green[700],
                                      ),
                                onPressed: _isLoadingMeetingPoints
                                    ? null
                                    : _shareSafeMeetingPoint,
                              ),
                            ),
                          if (_chatListingLatitude != null &&
                              _chatListingLongitude != null)
                            const SizedBox(width: 8),
                          if (_isReceiverTradeEnabled)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.deepPurple[50],
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                tooltip: tr('share_trade_listing'),
                                icon: Icon(
                                  Icons.swap_horiz_rounded,
                                  color: Colors.deepPurple[700],
                                ),
                                onPressed: _showTradeListingPicker,
                              ),
                            ),
                          if (_isReceiverTradeEnabled) const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.indigo[50],
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              tooltip: tr('ready_messages'),
                              icon: Icon(
                                Icons.quickreply_outlined,
                                color: Colors.indigo[700],
                              ),
                              onPressed: _showReadyMessagesBottomSheet,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color:
                                  (!_canSendMessage &&
                                      _messageController.text.trim().isNotEmpty)
                                  ? Colors.grey[400]
                                  : (_messageController.text.trim().isNotEmpty
                                        ? Colors.blue[800]
                                        : (_isListening
                                              ? Colors.red[600]
                                              : Colors.grey[200])),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                _messageController.text.trim().isNotEmpty
                                    ? Icons.send
                                    : (_isListening
                                          ? Icons.mic
                                          : Icons.mic_none),
                                color:
                                    _messageController.text.trim().isNotEmpty ||
                                        _isListening
                                    ? Colors.white
                                    : Colors.blue[800],
                              ),
                              onPressed: _handleComposerAction,
                            ),
                          ),
                        ],
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
}
