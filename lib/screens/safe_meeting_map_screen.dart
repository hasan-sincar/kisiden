import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/safe_meeting_point.dart';
import '../utils/local_fonts.dart';
import '../utils/translations.dart';

class SafeMeetingMapScreen extends StatefulWidget {
  const SafeMeetingMapScreen({
    super.key,
    required this.points,
    this.initialSelectedId,
  });

  final List<SafeMeetingPoint> points;
  final String? initialSelectedId;

  @override
  State<SafeMeetingMapScreen> createState() => _SafeMeetingMapScreenState();
}

class _SafeMeetingMapScreenState extends State<SafeMeetingMapScreen> {
  GoogleMapController? _controller;
  Set<Marker> _markers = <Marker>{};
  SafeMeetingPoint? _selectedPoint;
  double _zoom = 13;
  Timer? _rebuildDebounce;
  bool _locationPermissionGranted = false;

  BitmapDescriptor? _singleMarkerIcon;
  BitmapDescriptor? _selectedMarkerIcon;
  final Map<int, BitmapDescriptor> _clusterIcons = <int, BitmapDescriptor>{};

  @override
  void initState() {
    super.initState();
    _selectedPoint =
        widget.points.where((p) => p.id == widget.initialSelectedId).isNotEmpty
        ? widget.points.firstWhere((p) => p.id == widget.initialSelectedId)
        : (widget.points.isNotEmpty ? widget.points.first : null);
    _checkLocationPermission();
    _prepareIconsAndMarkers();
  }

  Future<void> _checkLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (!mounted) return;
      setState(() {
        _locationPermissionGranted =
            permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationPermissionGranted = false;
      });
    }
  }

  @override
  void dispose() {
    _rebuildDebounce?.cancel();
    super.dispose();
  }

  LatLng get _initialTarget {
    final p =
        _selectedPoint ??
        (widget.points.isNotEmpty ? widget.points.first : null);
    if (p == null) {
      return const LatLng(39.92077, 32.85411);
    }
    return LatLng(p.latitude, p.longitude);
  }

  Future<void> _prepareIconsAndMarkers() async {
    _singleMarkerIcon = await _buildMarkerIcon(
      size: 110,
      fillColor: const Color(0xFF2563EB),
      ringColor: Colors.white,
      label: '',
    );
    _selectedMarkerIcon = await _buildMarkerIcon(
      size: 126,
      fillColor: const Color(0xFF16A34A),
      ringColor: Colors.white,
      label: '',
    );

    if (!mounted) return;
    _rebuildMarkers();
  }

  double _cellSizeForZoom(double zoom) {
    if (zoom >= 16) return 0.002;
    if (zoom >= 15) return 0.004;
    if (zoom >= 14) return 0.007;
    if (zoom >= 13) return 0.012;
    if (zoom >= 12) return 0.02;
    return 0.035;
  }

  Future<BitmapDescriptor> _clusterIconForCount(int count) async {
    final rounded = count <= 9
        ? 10
        : count <= 24
        ? 25
        : count <= 49
        ? 50
        : 100;

    if (_clusterIcons.containsKey(rounded)) {
      return _clusterIcons[rounded]!;
    }

    final icon = await _buildMarkerIcon(
      size: 140,
      fillColor: const Color(0xFF7C3AED),
      ringColor: Colors.white,
      label: '$count',
      labelColor: Colors.white,
      fontSize: 46,
    );
    _clusterIcons[rounded] = icon;
    return icon;
  }

  Future<BitmapDescriptor> _buildMarkerIcon({
    required int size,
    required Color fillColor,
    required Color ringColor,
    required String label,
    Color labelColor = Colors.white,
    double fontSize = 40,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    final ringPaint = Paint()..color = ringColor;
    final fillPaint = Paint()..color = fillColor;

    canvas.drawCircle(center, size * 0.42, ringPaint);
    canvas.drawCircle(center, size * 0.33, fillPaint);

    if (label.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: labelColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2,
        ),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  void _rebuildMarkers() {
    if (_singleMarkerIcon == null || _selectedMarkerIcon == null) return;

    final cellSize = _cellSizeForZoom(_zoom);
    final grouped = <String, List<SafeMeetingPoint>>{};

    for (final point in widget.points) {
      final key =
          '${(point.latitude / cellSize).floor()}_${(point.longitude / cellSize).floor()}';
      grouped.putIfAbsent(key, () => <SafeMeetingPoint>[]).add(point);
    }

    final futures = <Future<Marker>>[];
    for (final entry in grouped.entries) {
      final points = entry.value;

      if (points.length == 1 || _zoom >= 16) {
        final point = points.first;
        final isSelected = _selectedPoint?.id == point.id;
        futures.add(
          Future<Marker>.value(
            Marker(
              markerId: MarkerId('point_${point.id}'),
              position: LatLng(point.latitude, point.longitude),
              icon: isSelected ? _selectedMarkerIcon! : _singleMarkerIcon!,
              onTap: () {
                setState(() {
                  _selectedPoint = point;
                });
                _rebuildMarkers();
              },
              zIndex: isSelected ? 3 : 1,
            ),
          ),
        );
      } else {
        final avgLat =
            points.map((e) => e.latitude).reduce((a, b) => a + b) /
            points.length;
        final avgLng =
            points.map((e) => e.longitude).reduce((a, b) => a + b) /
            points.length;

        futures.add(
          _clusterIconForCount(points.length).then(
            (icon) => Marker(
              markerId: MarkerId('cluster_${entry.key}'),
              position: LatLng(avgLat, avgLng),
              icon: icon,
              onTap: () {
                final nextZoom = min<double>(_zoom + 2.0, 18.0);
                _controller?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(avgLat, avgLng),
                      zoom: nextZoom,
                    ),
                  ),
                );
              },
              zIndex: 2,
            ),
          ),
        );
      }
    }

    Future.wait(futures).then((markers) {
      if (!mounted) return;
      setState(() {
        _markers = markers.toSet();
      });
    });
  }

  String _distanceLabel(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _focusPoint(SafeMeetingPoint point) async {
    setState(() {
      _selectedPoint = point;
    });
    _rebuildMarkers();
    await _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(point.latitude, point.longitude),
          zoom: max(_zoom, 16),
        ),
      ),
    );
  }

  Future<void> _openDirections(SafeMeetingPoint point) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${point.latitude},${point.longitude}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yol tarifi açılamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialTarget,
              zoom: _zoom,
            ),
            myLocationButtonEnabled: _locationPermissionGranted,
            myLocationEnabled: _locationPermissionGranted,
            compassEnabled: true,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers,
            onMapCreated: (controller) {
              _controller = controller;
              _rebuildMarkers();
            },
            onCameraMove: (position) {
              _zoom = position.zoom;
            },
            onCameraIdle: () {
              _rebuildDebounce?.cancel();
              _rebuildDebounce = Timer(
                const Duration(milliseconds: 120),
                _rebuildMarkers,
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        tr('safe_meeting_map_title'),
                        style: LocalFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 14,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 6),
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[350],
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.points.length,
                      itemBuilder: (context, index) {
                        final point = widget.points[index];
                        final selected = _selectedPoint?.id == point.id;
                        return Material(
                          color: selected
                              ? const Color(0xFFF0F7FF)
                              : Colors.transparent,
                          child: InkWell(
                            onTap: () => _focusPoint(point),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.verified_user_outlined,
                                    color: selected
                                        ? Colors.blue[700]
                                        : Colors.grey[700],
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          point.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: LocalFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          '${point.address}\n${tr('distance')}: ${_distanceLabel(point.distanceMeters)}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: LocalFonts.poppins(
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  selected
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: tr('get_directions'),
                                              onPressed: () =>
                                                  _openDirections(point),
                                              icon: const Icon(
                                                Icons.directions,
                                                color: Colors.green,
                                              ),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, point),
                                              child: Text(tr('select')),
                                            ),
                                          ],
                                        )
                                      : OutlinedButton.icon(
                                          onPressed: () => _focusPoint(point),
                                          icon: const Icon(Icons.map_outlined),
                                          label: Text(tr('show_on_map')),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedPoint == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.pop(context, _selectedPoint),
              icon: const Icon(Icons.check),
              label: Text(tr('select')),
            ),
    );
  }
}
