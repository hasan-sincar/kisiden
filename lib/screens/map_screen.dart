import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Haritada Ara (Yakınımdakiler)',
          style: LocalFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: Center(
        child: Text(
          'Harita özelliği devre dışı bırakılmıştır.',
          style: LocalFonts.poppins(fontSize: 16, color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
