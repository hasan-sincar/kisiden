import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_service.dart';

class AppUpdateGate extends StatefulWidget {
  final Widget child;
  const AppUpdateGate({super.key, required this.child});

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  final AppUpdateService _updateService = AppUpdateService();

  AppUpdateDecision _forceDecision = AppUpdateDecision.none;
  bool _isChecking = false;
  bool _isSoftDialogOpen = false;
  String? _shownSoftVersionInSession;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runCheck();
    }
  }

  Future<void> _runCheck() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final decision = await _updateService.checkForUpdate();
      if (!mounted) return;

      if (decision.requirement == AppUpdateRequirement.force) {
        setState(() => _forceDecision = decision);
        return;
      }

      if (_forceDecision.requirement == AppUpdateRequirement.force) {
        setState(() => _forceDecision = AppUpdateDecision.none);
      }

      if (decision.requirement == AppUpdateRequirement.soft) {
        if (_shownSoftVersionInSession == decision.latestVersion) return;
        _shownSoftVersionInSession = decision.latestVersion;
        await _showSoftUpdateDialog(decision);
      }
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _showSoftUpdateDialog(AppUpdateDecision decision) async {
    if (!mounted || _isSoftDialogOpen) return;
    _isSoftDialogOpen = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.system_update_alt_rounded,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        decision.title,
                        style: LocalFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  decision.message,
                  style: LocalFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[800],
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Yeni sürüm: ${decision.latestVersion}',
                  style: LocalFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await _updateService.markSoftDismissed(
                            decision.latestVersion,
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Text('Sonra', style: LocalFonts.poppins()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: decision.storeUrl.isEmpty
                            ? null
                            : () => _openStore(decision.storeUrl),
                        child: Text(
                          'Şimdi Güncelle',
                          style: LocalFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    _isSoftDialogOpen = false;
  }

  Future<void> _openStore(String storeUrl) async {
    if (storeUrl.isEmpty) return;
    final uri = Uri.tryParse(storeUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final force = _forceDecision.requirement == AppUpdateRequirement.force;

    return Stack(
      children: [
        widget.child,
        if (force)
          Positioned.fill(
            child: Material(
              color: Colors.white,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.system_security_update_good_rounded,
                          color: Color(0xFF4338CA),
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _forceDecision.title,
                        textAlign: TextAlign.center,
                        style: LocalFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _forceDecision.message,
                        textAlign: TextAlign.center,
                        style: LocalFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Mevcut: ${_forceDecision.currentVersion} • Gerekli: ${_forceDecision.latestVersion}',
                        textAlign: TextAlign.center,
                        style: LocalFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _forceDecision.storeUrl.isEmpty
                              ? null
                              : () => _openStore(_forceDecision.storeUrl),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: Text(
                            'Güncelle',
                            style: LocalFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _runCheck,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          'Tekrar Kontrol Et',
                          style: LocalFonts.poppins(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
