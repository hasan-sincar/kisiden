import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'dart:async';
import '../main.dart'; // YENİ: RootScreen kontrolü için ekledik
import '../utils/translations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    
    // Ekran açıldıktan çok kısa bir süre sonra animasyonu tetikleyerek pürüzsüz bir geçiş sağlıyoruz
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isVisible = true;
        });
      }
    });

    // Animasyon bittikten kısa bir süre sonra (1.8 sn) kullanıcı durumunu kontrol edip yönlendirme yapıyoruz
    Future.delayed(const Duration(milliseconds: 1800), () {
      _checkAuthAndNavigate();
    });
  }


  void _checkAuthAndNavigate() {
    if (!mounted) return;
    
    // Doğrudan RootScreen'e yönlendirerek oturum ve telefon numarası kontrolünü devreye sokuyoruz
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const RootScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[900], // Şık ve kurumsal bir lacivert arkaplan
      body: Center(
        child: AnimatedOpacity(
          opacity: _isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeIn,
          child: AnimatedScale(
            scale: _isVisible ? 1.0 : 0.8,
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Image.asset('assets/logo.png', height: 120),
                ),
                const SizedBox(height: 32),
                Text(
                  tr('app_name'),
                  style: LocalFonts.poppins(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('slogan'),
                  style: LocalFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70, letterSpacing: 2.0),
                ),
                const SizedBox(height: 64),
                const SizedBox(
                  width: 30, height: 30,
                  child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white), strokeWidth: 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}