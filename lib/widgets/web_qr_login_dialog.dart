import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/web_qr_login_service.dart';
import '../utils/translations.dart';

class WebQrLoginDialog extends StatefulWidget {
  const WebQrLoginDialog({super.key, required this.session});

  final WebQrLoginSession session;

  @override
  State<WebQrLoginDialog> createState() => _WebQrLoginDialogState();
}

class _WebQrLoginDialogState extends State<WebQrLoginDialog> {
  final WebQrLoginService _service = WebQrLoginService();
  bool _isPolling = false;
  bool _isFinished = false;
  String? _error;
  WebQrLoginStatus? _status;

  @override
  void initState() {
    super.initState();
    _pollForApproval();
  }

  Future<void> _pollForApproval() async {
    if (_isPolling || _isFinished) return;
    _isPolling = true;
    try {
      while (mounted && !_isFinished) {
        final result = await _service.pollWebSession(widget.session);
        if (result.status == WebQrLoginStatus.complete) {
          _isFinished = true;
          if (mounted) Navigator.of(context).pop(result.customToken);
          return;
        }
        if (result.status != WebQrLoginStatus.pending) {
          setState(() {
            _status = result.status;
            _isFinished = true;
          });
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 3));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _close() async {
    try {
      await _service.cancelWebSession(widget.session);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('${tr('qr_login_cancel_error')}: $error')),
        );
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isTerminalStatus = _status != null;
    return AlertDialog(
      title: Text(tr('qr_login_title')),
      content: SizedBox(
        width: 310,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isTerminalStatus
                  ? tr(
                      _status == WebQrLoginStatus.expired
                          ? 'qr_login_expired'
                          : _status == WebQrLoginStatus.cancelled
                          ? 'qr_login_cancelled'
                          : 'qr_login_used',
                    )
                  : _error ?? tr('qr_login_scan_instructions'),
              textAlign: TextAlign.center,
            ),
            if (!isTerminalStatus && _error == null) ...[
              const SizedBox(height: 18),
              QrImageView(
                data: widget.session.qrPayload,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                tr('qr_login_waiting'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() => _error = null);
                  _pollForApproval();
                },
                child: Text(tr('qr_login_retry')),
              ),
            ],
          ],
        ),
      ),
      actions: [TextButton(onPressed: _close, child: Text(tr('cancel')))],
    );
  }
}
