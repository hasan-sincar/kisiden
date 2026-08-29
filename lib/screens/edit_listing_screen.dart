import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_service.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/translations.dart';

class EditListingScreen extends StatefulWidget {
  final String listingId;
  final Map<String, dynamic> currentData;
  final bool isAdminEditor;

  const EditListingScreen({
    super.key,
    required this.listingId,
    required this.currentData,
    this.isAdminEditor = false,
  });

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;

  final DatabaseService _dbService = DatabaseService();
  final ImagePicker _picker = ImagePicker();

  final List<dynamic> _currentImages =
      []; // Karma liste: String (URL) veya Uint8List (yeni resim)
  bool _isLoading = false;
  String _loadingText = "";
  bool _autoRenew = false;
  String _selectedCategoryPath = '';
  String? _selectedCategoryId;
  bool _isCategoryTreeLoading = false;
  final Map<String, Map<String, dynamic>> _categoriesById = {};
  final Map<String, List<String>> _childrenByParent = {};

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.currentData['title']);
    _descriptionController = TextEditingController(
      text: widget.currentData['description'],
    );

    int initialPrice = (widget.currentData['price'] as num).toInt();
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '',
      decimalDigits: 0,
    );
    _priceController = TextEditingController(
      text: formatter.format(initialPrice).trim(),
    );

    if (widget.currentData['imageUrl'] != null &&
        widget.currentData['imageUrl'].toString().isNotEmpty) {
      _currentImages.add(widget.currentData['imageUrl']);
    }
    if (widget.currentData['additionalImages'] != null) {
      for (var img in widget.currentData['additionalImages']) {
        if (img.toString().isNotEmpty) _currentImages.add(img.toString());
      }
    }

    _autoRenew = widget.currentData['autoRenew'] ?? false;
    _selectedCategoryPath =
        (widget.currentData['categoryPath'] ??
                widget.currentData['category'] ??
                '')
            .toString()
            .trim();
    _prepareCategoryTree();
  }

  Future<void> _prepareCategoryTree() async {
    if (_isCategoryTreeLoading || _categoriesById.isNotEmpty) return;
    setState(() => _isCategoryTreeLoading = true);
    try {
      final categoriesSnap = await FirebaseFirestore.instance
          .collection('categories')
          .get();

      _categoriesById.clear();
      _childrenByParent.clear();

      for (final doc in categoriesSnap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        _categoriesById[doc.id] = data;
        final parentId = (data['parentId'] ?? '').toString();
        _childrenByParent.putIfAbsent(parentId, () => <String>[]).add(doc.id);
      }

      for (final entry in _childrenByParent.entries) {
        entry.value.sort((a, b) {
          final ad = _categoriesById[a] ?? const <String, dynamic>{};
          final bd = _categoriesById[b] ?? const <String, dynamic>{};

          final ao = (ad['order'] as num?)?.toInt() ?? 0;
          final bo = (bd['order'] as num?)?.toInt() ?? 0;
          if (ao != bo) return ao.compareTo(bo);

          final an = (ad['name'] ?? '').toString();
          final bn = (bd['name'] ?? '').toString();
          return an.compareTo(bn);
        });
      }

      if (_selectedCategoryPath.isNotEmpty) {
        for (final id in _categoriesById.keys) {
          if (_buildPathForId(id) == _selectedCategoryPath) {
            _selectedCategoryId = id;
            break;
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isCategoryTreeLoading = false);
      }
    }
  }

  String _buildPathForId(String id) {
    final parts = <String>[];
    String current = id;
    while (current.isNotEmpty && _categoriesById.containsKey(current)) {
      final data = _categoriesById[current]!;
      final name = (data['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        parts.insert(0, name);
      }
      current = (data['parentId'] ?? '').toString();
    }
    return parts.join(' > ');
  }

  List<String> _getTrailIds(String? id) {
    if (id == null || id.isEmpty || !_categoriesById.containsKey(id)) {
      return const <String>[];
    }
    final trail = <String>[];
    String current = id;
    while (current.isNotEmpty && _categoriesById.containsKey(current)) {
      trail.insert(0, current);
      current = (_categoriesById[current]!['parentId'] ?? '').toString();
    }
    return trail;
  }

  Future<void> _pickCategory() async {
    await _prepareCategoryTree();
    if (!mounted) return;

    if (_categoriesById.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('category_list_fetch_failed'))));
      return;
    }

    final initialTrail = _getTrailIds(_selectedCategoryId);
    String currentParentId = '';
    final trailIds = <String>[];

    if (initialTrail.length > 1) {
      trailIds.addAll(initialTrail.take(initialTrail.length - 1));
      currentParentId = trailIds.last;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final childIds =
                _childrenByParent[currentParentId] ?? const <String>[];

            String headerPath = '';
            if (trailIds.isNotEmpty) {
              headerPath = trailIds
                  .map(
                    (id) =>
                        (_categoriesById[id]?['name'] ?? '').toString().trim(),
                  )
                  .where((n) => n.isNotEmpty)
                  .join(' > ');
            }

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.72,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                      child: Row(
                        children: [
                          if (trailIds.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () {
                                setSheetState(() {
                                  if (trailIds.isNotEmpty) {
                                    trailIds.removeLast();
                                  }
                                  currentParentId = trailIds.isEmpty
                                      ? ''
                                      : trailIds.last;
                                });
                              },
                            )
                          else
                            const SizedBox(width: 48),
                          Expanded(
                            child: Text(
                              headerPath.isEmpty ? 'Kategori Seç' : headerPath,
                              style: LocalFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: Text(tr('cancel')),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: childIds.isEmpty
                          ? Center(
                              child: Text(
                                'Alt kategori bulunamadı',
                                style: LocalFonts.poppins(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: childIds.length,
                              itemBuilder: (context, index) {
                                final id = childIds[index];
                                final data =
                                    _categoriesById[id] ??
                                    const <String, dynamic>{};
                                final name = (data['name'] ?? '').toString();
                                final hasChildren =
                                    (_childrenByParent[id] ?? const <String>[])
                                        .isNotEmpty;
                                final selected = _selectedCategoryId == id;

                                return ListTile(
                                  title: Text(
                                    name,
                                    style: LocalFonts.poppins(fontSize: 13),
                                  ),
                                  trailing: hasChildren
                                      ? const Icon(Icons.chevron_right)
                                      : (selected
                                            ? const Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                              )
                                            : const Icon(
                                                Icons.radio_button_unchecked,
                                              )),
                                  onTap: () {
                                    if (hasChildren) {
                                      setSheetState(() {
                                        trailIds.add(id);
                                        currentParentId = id;
                                      });
                                      return;
                                    }

                                    setState(() {
                                      _selectedCategoryId = id;
                                      _selectedCategoryPath = _buildPathForId(
                                        id,
                                      );
                                    });
                                    Navigator.pop(sheetContext);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Uint8List> _addWatermark(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    canvas.drawImage(image, Offset.zero, Paint());

    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.35),
      fontSize: image.width * 0.15,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.3),
          offset: const Offset(2, 2),
          blurRadius: 6,
        ),
      ],
    );

    final textSpan = TextSpan(text: 'Kişiden', style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    canvas.translate(image.width / 2, image.height / 2);
    canvas.rotate(-0.5);
    canvas.translate(-image.width / 2, -image.height / 2);

    final offset = Offset(
      (image.width - textPainter.width) / 2,
      (image.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image watermarkedImage = await picture.toImage(
      image.width,
      image.height,
    );
    final ByteData? byteData = await watermarkedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    image.dispose();
    watermarkedImage.dispose();
    codec.dispose();

    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List?> _compressImage(Uint8List bytes) async {
    try {
      return await FlutterImageCompress.compressWithList(
        bytes,
        quality: 70,
        minWidth: 1080,
        minHeight: 1080,
        format: CompressFormat.jpeg,
      );
    } catch (e) {
      return bytes;
    }
  }

  Future<void> _pickMultipleImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _loadingText = tr('processing_photos_wait');
      });

      int loopCount = pickedFiles.length > 15 ? 15 : pickedFiles.length;
      for (int i = 0; i < loopCount; i++) {
        if (_currentImages.length >= 15) break;
        setState(() {
          _loadingText = "${tr('processing_photos')} (${i + 1}/$loopCount)";
        });
        await Future.delayed(const Duration(milliseconds: 300));

        Uint8List originalBytes = await pickedFiles[i].readAsBytes();
        Uint8List watermarkedBytes = await _addWatermark(originalBytes);
        Uint8List? compressedBytes = await _compressImage(watermarkedBytes);

        if (compressedBytes != null) {
          _currentImages.add(compressedBytes);
        } else {
          _currentImages.add(watermarkedBytes);
        }
      }
      setState(() {
        _isLoading = false;
        _loadingText = "";
      });
    }
  }

  Future<void> _updateListing() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final priceText = _priceController.text.replaceAll('.', '').trim();

    if (title.isEmpty || description.isEmpty || priceText.isEmpty) return;

    if (_currentImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('please_add_at_least_one_photo'))),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingText = tr('updating_listing');
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      List<String> finalUrls = [];

      for (int i = 0; i < _currentImages.length; i++) {
        var item = _currentImages[i];
        if (item is String) {
          finalUrls.add(item);
        } else if (item is Uint8List) {
          String fileName =
              "${user?.uid}_${DateTime.now().millisecondsSinceEpoch}_$i";
          String? url = await _dbService.uploadImage(item, fileName);
          if (url != null) {
            finalUrls.add(url);
          }
        }
      }

      String? finalMainImageUrl = finalUrls.isNotEmpty ? finalUrls.first : null;
      List<String> finalAdditionalImages = finalUrls.length > 1
          ? finalUrls.sublist(1)
          : [];

      final categoryPath = _selectedCategoryPath.isNotEmpty
          ? _selectedCategoryPath
          : (widget.currentData['categoryPath'] ??
                    widget.currentData['category'] ??
                    '')
                .toString();
      final categoryLeaf = categoryPath.split('>').last.trim();

      await _dbService.updateListing(
        listingId: widget.listingId,
        title: title,
        description: description,
        price: double.parse(priceText),
        newImageUrl: finalMainImageUrl,
        additionalImages: finalAdditionalImages,
        autoRenew: _autoRenew,
        category: categoryLeaf,
        categoryPath: categoryPath,
        isAdmin: widget.isAdminEditor,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isAdminEditor
                  ? 'İlan admin tarafından güncellendi.'
                  : tr('listing_updated_sent_approval'),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${tr('error')}: $e')));
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
          _loadingText = "";
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('edit_listing_title'), style: LocalFonts.poppins()),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _loadingText,
                    style: LocalFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: _pickMultipleImages,
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue, width: 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_photo_alternate,
                            size: 40,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr('bulk_photo_select'),
                            style: LocalFonts.poppins(color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('delete_photo_hint'),
                    textAlign: TextAlign.center,
                    style: LocalFonts.poppins(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  if (_currentImages.isNotEmpty)
                    SizedBox(
                      height: 100,
                      child: ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _currentImages.length,
                        onReorder: (int oldIndex, int newIndex) {
                          setState(() {
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            final dynamic item = _currentImages.removeAt(
                              oldIndex,
                            );
                            _currentImages.insert(newIndex, item);
                          });
                        },
                        proxyDecorator:
                            (
                              Widget child,
                              int index,
                              Animation<double> animation,
                            ) {
                              return Material(
                                color: Colors.transparent,
                                child: child,
                              );
                            },
                        itemBuilder: (context, index) {
                          final image = _currentImages[index];
                          final isExisting = image is String;
                          return Container(
                            key: ObjectKey(image),
                            margin: const EdgeInsets.only(right: 8),
                            width: 85,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: index == 0
                                  ? Border.all(color: Colors.blue, width: 3)
                                  : null,
                              image: DecorationImage(
                                image: isExisting
                                    ? NetworkImage(image)
                                    : MemoryImage(image as Uint8List)
                                          as ImageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Stack(
                              children: [
                                if (index == 0)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(
                                          alpha: 0.9,
                                        ),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              bottom: Radius.circular(5),
                                            ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        "Kapak",
                                        textAlign: TextAlign.center,
                                        style: LocalFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                Align(
                                  alignment: Alignment.topRight,
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_currentImages.length <= 1) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              tr(
                                                'listing_requires_min_one_photo',
                                              ),
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      setState(
                                        () => _currentImages.removeAt(index),
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                      child: const Icon(
                                        Icons.cancel,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: tr('listing_title'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _priceController,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CurrencyInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: tr('price_tl'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    onChanged: (_) => setState(() {}),
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: tr('description'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickCategory,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.category, color: Colors.blue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selectedCategoryPath.isNotEmpty
                                  ? _selectedCategoryPath
                                  : 'Kategori seçilmedi',
                              style: LocalFonts.poppins(fontSize: 13),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: Text(
                      tr('auto_renew'),
                      style: LocalFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      tr('auto_renew_desc'),
                      style: LocalFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    value: _autoRenew,
                    onChanged: (val) =>
                        setState(() => _autoRenew = val ?? false),
                    activeColor: Colors.blue[800],
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _updateListing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      tr('save_changes'),
                      style: LocalFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    int value = int.parse(newValue.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '',
      decimalDigits: 0,
    );
    String newText = formatter.format(value).trim();
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
