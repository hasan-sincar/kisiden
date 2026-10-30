import 'package:flutter/material.dart';

import '../utils/translations.dart';

const int maxDefectMarkersPerListing = 20;
const int maxDefectDescriptionLength = 160;

class DefectMarker {
  final int imageIndex;
  final double x;
  final double y;
  final String description;

  const DefectMarker({
    required this.imageIndex,
    required this.x,
    required this.y,
    required this.description,
  });

  factory DefectMarker.fromMap(Map<dynamic, dynamic> data) {
    return DefectMarker(
      imageIndex: (data['imageIndex'] as num?)?.toInt() ?? 0,
      x: ((data['x'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
      y: ((data['y'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
      description: (data['description'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'imageIndex': imageIndex,
    'x': x,
    'y': y,
    'description': description,
  };

  DefectMarker copyWith({
    int? imageIndex,
    double? x,
    double? y,
    String? description,
  }) {
    return DefectMarker(
      imageIndex: imageIndex ?? this.imageIndex,
      x: x ?? this.x,
      y: y ?? this.y,
      description: description ?? this.description,
    );
  }

  static List<DefectMarker> fromData(dynamic data) {
    if (data is! List) return <DefectMarker>[];
    return data
        .whereType<Map>()
        .map(DefectMarker.fromMap)
        .where((marker) => marker.description.trim().isNotEmpty)
        .take(maxDefectMarkersPerListing)
        .toList();
  }
}

List<DefectMarker> removeDefectMarkerImage(
  List<DefectMarker> markers,
  int removedIndex,
) {
  return markers
      .where((marker) => marker.imageIndex != removedIndex)
      .map(
        (marker) => marker.imageIndex > removedIndex
            ? marker.copyWith(imageIndex: marker.imageIndex - 1)
            : marker,
      )
      .toList();
}

List<DefectMarker> reorderDefectMarkerImage(
  List<DefectMarker> markers,
  int oldIndex,
  int newIndex,
) {
  return markers.map((marker) {
    final index = marker.imageIndex;
    if (index == oldIndex) return marker.copyWith(imageIndex: newIndex);
    if (oldIndex < newIndex && index > oldIndex && index <= newIndex) {
      return marker.copyWith(imageIndex: index - 1);
    }
    if (oldIndex > newIndex && index >= newIndex && index < oldIndex) {
      return marker.copyWith(imageIndex: index + 1);
    }
    return marker;
  }).toList();
}

Offset? defectMarkerDisplayPosition({
  required Size viewportSize,
  required Size imageSize,
  required BoxFit fit,
  required double x,
  required double y,
}) {
  if (x < 0 || x > 1 || y < 0 || y > 1) return null;
  final fittedSizes = applyBoxFit(fit, imageSize, viewportSize);
  final sourceRect = Alignment.center.inscribe(
    fittedSizes.source,
    Offset.zero & imageSize,
  );
  final imageX = x * imageSize.width;
  final imageY = y * imageSize.height;
  if (imageX < sourceRect.left ||
      imageX > sourceRect.right ||
      imageY < sourceRect.top ||
      imageY > sourceRect.bottom ||
      sourceRect.width <= 0 ||
      sourceRect.height <= 0) {
    return null;
  }
  final destinationRect = Alignment.center.inscribe(
    fittedSizes.destination,
    Offset.zero & viewportSize,
  );
  return Offset(
    destinationRect.left +
        (imageX - sourceRect.left) / sourceRect.width * destinationRect.width,
    destinationRect.top +
        (imageY - sourceRect.top) / sourceRect.height * destinationRect.height,
  );
}

class DefectMarkerPhoto extends StatefulWidget {
  final ImageProvider image;
  final BoxFit fit;
  final List<DefectMarker> markers;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final ValueChanged<Offset>? onImageTap;
  final ValueChanged<DefectMarker>? onMarkerTap;

  const DefectMarkerPhoto({
    super.key,
    required this.image,
    this.fit = BoxFit.contain,
    this.markers = const <DefectMarker>[],
    this.loadingWidget,
    this.errorWidget,
    this.onImageTap,
    this.onMarkerTap,
  });

  @override
  State<DefectMarkerPhoto> createState() => _DefectMarkerPhotoState();
}

class _DefectMarkerPhotoState extends State<DefectMarkerPhoto> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  Size? _imageSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant DefectMarkerPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolveImage();
  }

  void _resolveImage() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _imageSize = null;
    _imageStream = widget.image.resolve(createLocalImageConfiguration(context));
    _imageListener = ImageStreamListener((imageInfo, _) {
      if (!mounted) return;
      setState(() {
        _imageSize = Size(
          imageInfo.image.width.toDouble(),
          imageInfo.image.height.toDouble(),
        );
      });
    });
    _imageStream!.addListener(_imageListener!);
  }

  @override
  void dispose() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    super.dispose();
  }

  void _handleImageTap(TapUpDetails details, Rect imageRect) {
    if (widget.onImageTap == null ||
        !imageRect.contains(details.localPosition) ||
        imageRect.width <= 0 ||
        imageRect.height <= 0) {
      return;
    }
    final imageSize = _imageSize;
    if (imageSize == null) return;
    final fittedSizes = applyBoxFit(widget.fit, imageSize, imageRect.size);
    final sourceRect = Alignment.center.inscribe(
      fittedSizes.source,
      Offset.zero & imageSize,
    );
    final destinationRect = Alignment.center.inscribe(
      fittedSizes.destination,
      Offset.zero & imageRect.size,
    );
    final position = Offset(
      details.localPosition.dx - imageRect.left,
      details.localPosition.dy - imageRect.top,
    );
    if (!destinationRect.contains(position)) return;
    widget.onImageTap!(
      Offset(
        (sourceRect.left +
                (position.dx - destinationRect.left) /
                    destinationRect.width *
                    sourceRect.width) /
            imageSize.width,
        (sourceRect.top +
                (position.dy - destinationRect.top) /
                    destinationRect.height *
                    sourceRect.height) /
            imageSize.height,
      ),
    );
  }

  void _showMarkerDescription(DefectMarker marker) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('defect_marker_details')),
        content: Text(marker.description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final imageSize = _imageSize;
        final fittedSizes = imageSize == null
            ? null
            : applyBoxFit(widget.fit, imageSize, size);
        final imageRect =
            fittedSizes == null || !size.width.isFinite || !size.height.isFinite
            ? (Offset.zero & size)
            : Alignment.center.inscribe(
                fittedSizes.destination,
                Offset.zero & size,
              );
        return Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: widget.image,
              fit: widget.fit,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (frame != null || wasSynchronouslyLoaded) return child;
                return widget.loadingWidget ?? child;
              },
              errorBuilder: (context, error, stackTrace) =>
                  widget.errorWidget ??
                  const Icon(
                    Icons.image_not_supported,
                    size: 50,
                    color: Colors.grey,
                  ),
            ),
            if (widget.onImageTap != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _handleImageTap(details, imageRect),
              ),
            if (imageSize != null)
              ...List<Widget>.generate(widget.markers.length, (i) {
                final marker = widget.markers[i];
                final position = defectMarkerDisplayPosition(
                  viewportSize: size,
                  imageSize: imageSize,
                  fit: widget.fit,
                  x: marker.x,
                  y: marker.y,
                );
                if (position == null) return const SizedBox.shrink();
                return Positioned(
                  key: ValueKey('defect-marker-$i'),
                  left: position.dx - 17,
                  top: position.dy - 17,
                  child: GestureDetector(
                    onTap: () {
                      final onMarkerTap = widget.onMarkerTap;
                      if (onMarkerTap == null) {
                        _showMarkerDescription(marker);
                      } else {
                        onMarkerTap(marker);
                      }
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 4),
                        ],
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class DefectMarkerEditorScreen extends StatefulWidget {
  final List<ImageProvider> images;
  final List<DefectMarker> initialMarkers;

  const DefectMarkerEditorScreen({
    super.key,
    required this.images,
    this.initialMarkers = const <DefectMarker>[],
  });

  @override
  State<DefectMarkerEditorScreen> createState() =>
      _DefectMarkerEditorScreenState();
}

class _DefectMarkerEditorScreenState extends State<DefectMarkerEditorScreen> {
  late final PageController _pageController;
  late List<DefectMarker> _markers;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _markers = List<DefectMarker>.of(widget.initialMarkers);
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _addMarker(Offset position) async {
    if (_markers.length >= maxDefectMarkersPerListing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('defect_marker_limit_reached'))),
      );
      return;
    }
    final description = await _requestDescription();
    if (!mounted || description == null) return;
    setState(() {
      _markers.add(
        DefectMarker(
          imageIndex: _currentIndex,
          x: position.dx,
          y: position.dy,
          description: description,
        ),
      );
    });
    Navigator.pop(context, List<DefectMarker>.of(_markers));
  }

  Future<String?> _requestDescription([String initialValue = '']) async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          DefectDescriptionDialog(initialValue: initialValue),
    );
  }

  Future<void> _editMarker(DefectMarker marker) async {
    final index = _markers.indexOf(marker);
    if (index < 0) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(tr('edit_defect_marker')),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(tr('delete')),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'delete') {
      setState(() => _markers.removeAt(index));
    } else if (action == 'edit') {
      final description = await _requestDescription(marker.description);
      if (description != null && mounted) {
        setState(() {
          _markers[index] = marker.copyWith(description: description);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(tr('mark_photo_defects')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _markers),
            child: Text(
              tr('save_changes'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) => DefectMarkerPhoto(
                image: widget.images[index],
                fit: BoxFit.contain,
                markers: _markers
                    .where((marker) => marker.imageIndex == index)
                    .toList(),
                onImageTap: _addMarker,
                onMarkerTap: _editMarker,
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    tr('defect_marker_instructions'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_currentIndex + 1} / ${widget.images.length} · ${_markers.length}/$maxDefectMarkersPerListing',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DefectDescriptionDialog extends StatefulWidget {
  final String initialValue;

  const DefectDescriptionDialog({super.key, required this.initialValue});

  @override
  State<DefectDescriptionDialog> createState() =>
      _DefectDescriptionDialogState();
}

class _DefectDescriptionDialogState extends State<DefectDescriptionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialValue.isEmpty
            ? tr('add_defect_marker')
            : tr('edit_defect_marker'),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: maxDefectDescriptionLength,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: tr('defect_description_hint'),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isNotEmpty) Navigator.pop(context, value);
          },
          child: Text(tr('save_changes')),
        ),
      ],
    );
  }
}
