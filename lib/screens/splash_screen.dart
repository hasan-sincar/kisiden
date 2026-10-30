import 'dart:async';

import 'package:appim/utils/local_fonts.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../utils/translations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), _checkAuthAndNavigate);
  }

  void _checkAuthAndNavigate() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const RootScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final logoSize = (constraints.maxWidth * 0.34)
                .clamp(112.0, 148.0)
                .toDouble();

            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/logo.png',
                            width: logoSize,
                            height: logoSize,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            tr('app_name'),
                            textAlign: TextAlign.center,
                            style: LocalFonts.poppins(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF17191D),
                              letterSpacing: -0.7,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Text(
                              tr('welcome_new_generation_marketplace'),
                              textAlign: TextAlign.center,
                              style: LocalFonts.poppins(
                                fontSize: 14,
                                height: 1.5,
                                color: const Color(0xFF858994),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  child: Text(
                    'www.kisiden.com',
                    textAlign: TextAlign.center,
                    style: LocalFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF858994),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
