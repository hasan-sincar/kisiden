import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/web_qr_login_service.dart';
import '../utils/translations.dart';

class QrLoginScannerScreen extends StatefulWidget {
  const QrLoginScannerScreen({super.key});

  @override
  State<QrLoginScannerScreen> createState() => _QrLoginScannerScreenState();
}

class _QrLoginScannerScreenState extends State<QrLoginScannerScreen> {
  final WebQrLoginService _service = WebQrLoginService();
  bool _isProcessing = false;
  bool _isApproved = false;
  String? _error;

  String? _sessionIdFromBarcode(String? value) {
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'kisiden.com' ||
        uri.path != '/qr-login') {
      return null;
    }
    final sessionId = uri.queryParameters['sessionId'];
    if (sessionId == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(sessionId)) {
      return null;
    }
    return sessionId;
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing || _isApproved || capture.barcodes.isEmpty) return;
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    final sessionId = _sessionIdFromBarcode(capture.barcodes.first.rawValue);
    if (sessionId == null) {
      setState(() => _error = tr('qr_login_invalid_code'));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final accountLabel = user?.displayName ?? user?.email ?? user?.phoneNumber;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('qr_login_confirm_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('qr_login_confirm_message')),
            if (accountLabel != null && accountLabel.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                accountLabel,
                style: Theme.of(dialogContext).textTheme.titleSmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('qr_login_approve')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (approved != true) {
      setState(() => _isProcessing = false);
      return;
    }

    try {
      await _service.approveMobileSession(sessionId);
      if (!mounted) return;
      setState(() {
        _isApproved = true;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '${tr('qr_login_approval_failed')}: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('qr_login_title'))),
      body: _isApproved
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 60,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    Text(tr('qr_login_approved'), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr('close')),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error ?? tr('qr_login_scan_instructions'),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_isProcessing && _error == null)
                  const LinearProgressIndicator(),
                Expanded(child: MobileScanner(onDetect: _handleBarcode)),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _isProcessing = false;
                        _error = null;
                      }),
                      child: Text(tr('qr_login_retry')),
                    ),
                  ),
              ],
            ),
    );
  }
}
