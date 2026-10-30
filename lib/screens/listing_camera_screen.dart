import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../utils/translations.dart';

class ListingCameraScreen extends StatefulWidget {
  const ListingCameraScreen({super.key});

  @override
  State<ListingCameraScreen> createState() => _ListingCameraScreenState();
}

class _ListingCameraScreenState extends State<ListingCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitializing = false;
  bool _isTakingPicture = false;
  bool _isAppActive = true;
  String? _errorKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  Future<void> _initializeCamera() async {
    if (_isInitializing || !_isAppActive) return;
    _isInitializing = true;
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _errorKey = 'no_camera_available');
        return;
      }

      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted || !_isAppActive) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      controller = null;
      setState(() => _errorKey = null);
    } on CameraException catch (error) {
      await controller?.dispose();
      if (mounted) {
        setState(
          () => _errorKey = error.code.startsWith('CameraAccessDenied')
              ? 'camera_permission_denied'
              : 'camera_unavailable',
        );
      }
    } on Exception {
      await controller?.dispose();
      if (mounted) setState(() => _errorKey = 'camera_unavailable');
    } finally {
      _isInitializing = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    setState(() => _isTakingPicture = true);
    try {
      final photo = await controller.takePicture();
      if (mounted) Navigator.of(context).pop(photo);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('camera_capture_failed'))));
      }
    } finally {
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _isAppActive = false;
      final controller = _controller;
      _controller = null;
      if (controller != null) unawaited(controller.dispose());
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _isAppActive = true;
      unawaited(_initializeCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final hasCamera = controller?.value.isInitialized == true;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(tr('take_photo')),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (hasCamera)
            CameraPreview(controller!)
          else
            Center(
              child: _errorKey == null
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.no_photography_outlined,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr(_errorKey!),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() => _errorKey = null);
                              unawaited(_initializeCamera());
                            },
                            icon: const Icon(Icons.refresh),
                            label: Text(tr('retry')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          if (hasCamera)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: FloatingActionButton.large(
                  onPressed: _isTakingPicture ? null : _takePicture,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  child: _isTakingPicture
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.camera_alt, size: 32),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
