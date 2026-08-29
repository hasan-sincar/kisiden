part of 'home_screen.dart';

extension _HomeScreenController on _HomeScreenState {
  Future<void> _checkPendingDeepLink() async {
    if (pendingDeepLink != null) {
      Uri uri = pendingDeepLink!;
      pendingDeepLink = null;

      final path = uri.path.toLowerCase();
      if (path.contains('/favoriler')) {
        if (!mounted) return;
        if (!await AuthGate.requireRegisteredUser(
          context,
          message: 'Favori ilanlarinizi gormek icin giris yapmalisiniz.',
        )) {
          return;
        }
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FavoritesScreen()),
        );
        return;
      }

      if (path.contains('/ilan-ver')) {
        if (!mounted) return;
        if (!await AuthGate.requireRegisteredUser(
          context,
          message: 'Ilan verebilmek icin giris yapmalisiniz.',
        )) {
          return;
        }
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddListingScreen()),
        );
        return;
      }

      if (path.contains('/ilanlar')) {
        return;
      }

      if (path.contains('/bildirimler')) {
        if (!mounted) return;
        if (!await AuthGate.requireRegisteredUser(
          context,
          message: 'Bildirimlerinizi gormek icin giris yapmalisiniz.',
        )) {
          return;
        }
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        return;
      }

      if (uri.path.contains('/ilan') || uri.queryParameters.containsKey('id')) {
        String? listingId = uri.queryParameters['id'];
        if (listingId != null) {
          var doc = await FirebaseFirestore.instance
              .collection('listings')
              .doc(listingId)
              .get();
          if (doc.exists && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ListingDetailScreen(
                  data: doc.data() as Map<String, dynamic>,
                  listingId: listingId,
                ),
              ),
            );
          }
        }
      }
    }
  }

  void _initSpeech() async {
    try {
      await _speechToText.initialize();
      setState(() {});
    } catch (e) {}
  }

  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult, localeId: 'tr_TR');
    setState(() => _isListening = true);
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _searchController.text = result.recognizedWords;
      _searchText = result.recognizedWords.toLowerCase();
      _isFiltering = true;
    });
    _savePreferences();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isFiltering = false);
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _searchText = prefs.getString('searchText') ?? "";
        if (_searchText.isNotEmpty) _searchController.text = _searchText;
        _filterCity = prefs.getString('filterCity');
        _filterDistrict = prefs.getString('filterDistrict');
        _distance = prefs.getDouble('distance') ?? 30.0;
        _sortBy = 'date_desc';
        _minPriceController.text = prefs.getString('minPrice') ?? "";
        _maxPriceController.text = prefs.getString('maxPrice') ?? "";
        _filterNeighborhood = prefs.getString('filterNeighborhood');
        _neighborhoodController.text = _filterNeighborhood ?? "";
      });
      await prefs.remove('sortBy');
    } catch (e) {
      print(e);
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('searchText', _searchText);
      if (_filterCity != null) {
        await prefs.setString('filterCity', _filterCity!);
      } else {
        await prefs.remove('filterCity');
      }
      if (_filterDistrict != null) {
        await prefs.setString('filterDistrict', _filterDistrict!);
      } else {
        await prefs.remove('filterDistrict');
      }
      await prefs.setDouble('distance', _distance);
      await prefs.remove('sortBy');
      await prefs.setString('minPrice', _minPriceController.text);
      await prefs.setString('maxPrice', _maxPriceController.text);
      if (_filterNeighborhood != null && _filterNeighborhood!.isNotEmpty) {
        await prefs.setString('filterNeighborhood', _filterNeighborhood!);
      } else if (_neighborhoodController.text.isNotEmpty) {
        await prefs.setString(
          'filterNeighborhood',
          _neighborhoodController.text,
        );
      } else {
        await prefs.remove('filterNeighborhood');
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      try {
        Position? cachedPosition = await Geolocator.getLastKnownPosition();
        if (cachedPosition != null && mounted) {
          setState(() => _userPosition = cachedPosition);
        }
      } catch (e) {}

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (mounted) setState(() => _userPosition = position);
    } catch (e) {
      print(e);
    }
  }

  void _playSound() {
    try {
      FlutterRingtonePlayer().playNotification();
    } catch (e) {}
  }

  String _formatLocation(String? text) {
    if (text == null || text.isEmpty) return '';
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  Future<void> _fetchCategoryFeatures(String categoryId) async {
    if (categoryId.isEmpty) {
      if (mounted) {
        setState(() {
          _categoryFeatures.clear();
          _featureDropdownValues.clear();
        });
      }
      return;
    }
    try {
      var doc = await FirebaseFirestore.instance
          .collection('categories')
          .doc(categoryId)
          .get();
      if (doc.exists && mounted) {
        var data = doc.data() as Map<String, dynamic>;
        List<dynamic> rawFeatures = data['features'] ?? [];
        setState(() {
          _categoryFeatures.clear();
          _featureDropdownValues.clear();
          for (var f in rawFeatures) {
            if (f is Map) {
              String name = f['name'];
              List<String> options = List<String>.from(f['options'] ?? []);
              if (options.isNotEmpty) {
                _categoryFeatures.add({'name': name, 'options': options});
                _featureDropdownValues[name] = null;
              }
            }
          }
        });
      }
    } catch (e) {
      print("Kategori özellikleri alınırken hata oluştu: $e");
    }
  }

  void _showCategoryPickerForFilter(
    String initialParentId,
    String initialPath, [
    String initialDisplayPath = "",
    bool openFilterOnClose = true,
  ]) {
    List<Map<String, String>> history = [
      {
        'id': initialParentId,
        'path': initialPath,
        'display': initialDisplayPath,
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            var currentData = history.last;
            String activeParentId = currentData['id']!;
            String activePath = currentData['path']!;
            String activeDisplayPath = currentData['display']!;

            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.6,
                child: StreamBuilder<QuerySnapshot>(
                  stream: DatabaseService().getCategoriesStream(activeParentId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    var docs = snapshot.data!.docs.toList();
                    docs.sort((a, b) {
                      var ad = a.data() as Map<String, dynamic>;
                      var bd = b.data() as Map<String, dynamic>;
                      int orderA = ad['order'] ?? 0;
                      int orderB = bd['order'] ?? 0;
                      if (orderA != orderB) return orderA.compareTo(orderB);
                      Timestamp? tA = ad['createdAt'];
                      Timestamp? tB = bd['createdAt'];
                      if (tA != null && tB != null) return tA.compareTo(tB);
                      return 0;
                    });
                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            children: [
                              if (history.length > 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.black87,
                                  ),
                                  onPressed: () {
                                    setSheetState(() {
                                      history.removeLast();
                                    });
                                  },
                                )
                              else
                                const SizedBox(width: 48),
                              Expanded(
                                child: Text(
                                  activeDisplayPath.isEmpty
                                      ? tr('select_category')
                                      : activeDisplayPath.split(' > ').last,
                                  textAlign: TextAlign.center,
                                  style: LocalFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.grey,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                        ListTile(
                          title: Text(
                            tr('all'),
                            style: LocalFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                          trailing: const Icon(
                            Icons.check,
                            color: Colors.green,
                          ),
                          onTap: () async {
                            try {
                              setState(() {
                                _isFiltering = true;
                                _filterCategoryName = activePath.isEmpty
                                    ? tr('all')
                                    : activePath;
                                _filterCategoryDisplayName =
                                    activeDisplayPath.isEmpty
                                    ? tr('all')
                                    : activeDisplayPath.split(' > ').last;
                                if (_filterCategoryName == tr('all')) {
                                  _currentParentId = "";
                                  _currentParentName = tr('all');
                                  _currentParentDisplayName = tr('all');
                                } else {
                                  _currentParentId = activeParentId;
                                  _currentParentName = _filterCategoryName;
                                  _currentParentDisplayName =
                                      _filterCategoryDisplayName;
                                }
                              });
                              _savePreferences();
                              await _fetchCategoryFeatures(_currentParentId);
                              if (context.mounted) {
                                Navigator.pop(context);
                                if (openFilterOnClose) {
                                  _showFilterModal();
                                }
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isFiltering = false);
                              }
                            }
                          },
                        ),
                        const Divider(height: 1),
                        if (docs.isEmpty)
                          Expanded(
                            child: Center(
                              child: Text(
                                tr('no_subcategories'),
                                style: LocalFonts.poppins(),
                              ),
                            ),
                          ),
                        if (docs.isNotEmpty)
                          Expanded(
                            child: ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                var docData =
                                    docs[index].data() as Map<String, dynamic>;
                                String originalName = docData['name'];
                                String translatedName = getTranslatedText(
                                  docData,
                                  'name',
                                );
                                String clickedId = docs[index].id;
                                return ListTile(
                                  title: Text(
                                    translatedName,
                                    style: LocalFonts.poppins(),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () async {
                                    String newPath = activePath.isEmpty
                                        ? originalName
                                        : "$activePath > $originalName";
                                    String newDisplayPath =
                                        activeDisplayPath.isEmpty
                                        ? translatedName
                                        : "$activeDisplayPath > $translatedName";

                                    var subCats = await FirebaseFirestore
                                        .instance
                                        .collection('categories')
                                        .where('parentId', isEqualTo: clickedId)
                                        .limit(1)
                                        .get();
                                    if (subCats.docs.isEmpty) {
                                      try {
                                        Navigator.pop(context);
                                        setState(() {
                                          _isFiltering = true;
                                          _filterCategoryName = newPath;
                                          _filterCategoryDisplayName =
                                              newDisplayPath.split(' > ').last;
                                          _currentParentId = clickedId;
                                          _currentParentName =
                                              _filterCategoryName;
                                          _currentParentDisplayName =
                                              _filterCategoryDisplayName;
                                        });
                                        _savePreferences();
                                        await _fetchCategoryFeatures(
                                          _currentParentId,
                                        );
                                        if (context.mounted &&
                                            openFilterOnClose) {
                                          _showFilterModal();
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isFiltering = false);
                                        }
                                      }
                                    } else {
                                      setSheetState(() {
                                        history.add({
                                          'id': clickedId,
                                          'path': newPath,
                                          'display': newDisplayPath,
                                        });
                                      });
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr('filter'),
                            style: LocalFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    _isFiltering = true;
                                    _minPriceController.clear();
                                    _maxPriceController.clear();
                                    _distance = 30.0;
                                    _filterCity = null;
                                    _filterDistrict = null;
                                    _neighborhoodController.clear();
                                    _filterNeighborhood = null;
                                    _featureDropdownValues.clear();
                                  });
                                  setState(() {
                                    _minPriceController.clear();
                                    _maxPriceController.clear();
                                    _distance = 30.0;
                                    _filterCity = null;
                                    _filterDistrict = null;
                                    _neighborhoodController.clear();
                                    _filterNeighborhood = null;
                                    _featureDropdownValues.clear();
                                    _filterCategoryName = tr('all');
                                    _filterCategoryDisplayName = tr('all');
                                    _currentParentId = "";
                                    _currentParentName = tr('all');
                                    _currentParentDisplayName = tr('all');
                                  });
                                  _savePreferences();
                                  _fetchCategoryFeatures("");
                                  Future.delayed(
                                    const Duration(milliseconds: 400),
                                    () {
                                      if (mounted) {
                                        setState(() => _isFiltering = false);
                                      }
                                    },
                                  );
                                },
                                child: Text(
                                  tr('clear_filter'),
                                  style: LocalFonts.poppins(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 10),
                      Text(
                        tr('price_range'),
                        style: LocalFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minPriceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: tr('min_price'),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (val) {
                                setModalState(() {});
                                setState(() {});
                                _savePreferences();
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _maxPriceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: tr('max_price'),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (val) {
                                setModalState(() {});
                                setState(() {});
                                _savePreferences();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr('distance'),
                            style: LocalFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _distance == 30.0
                                ? tr('all')
                                : '${_distance.toStringAsFixed(1)} km',
                            style: LocalFonts.poppins(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _distance,
                        min: 0.1,
                        max: 30.0,
                        divisions: 300,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          setModalState(() => _distance = val);
                          setState(() => _distance = val);
                          _savePreferences();
                        },
                      ),
                      if (_userPosition == null)
                        InkWell(
                          onTap: () async {
                            await _getUserLocation();
                            setModalState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '${tr('location_permission_warning')} (Tekrar Dene)',
                              style: LocalFonts.poppins(
                                fontSize: 10,
                                color: Colors.red,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        tr('location_filter'),
                        style: LocalFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: tr('city'),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                              ),
                              initialValue: _filterCity,
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(tr('all')),
                                ),
                                ...turkeyLocations.keys.map(
                                  (city) => DropdownMenuItem(
                                    value: city,
                                    child: Text(
                                      city,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                setModalState(() {
                                  _filterCity = val;
                                  _filterDistrict = null;
                                  _filterNeighborhood = null;
                                  _neighborhoodController.clear();
                                });
                                setState(() {
                                  _filterCity = val;
                                  _filterDistrict = null;
                                  _filterNeighborhood = null;
                                  _neighborhoodController.clear();
                                });
                                _savePreferences();
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: tr('district'),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                              ),
                              initialValue: _filterDistrict,
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(tr('all')),
                                ),
                                if (_filterCity != null)
                                  ...turkeyLocations[_filterCity]!.map(
                                    (d) => DropdownMenuItem(
                                      value: d,
                                      child: Text(
                                        d,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                              ],
                              onChanged: (val) {
                                setModalState(() => _filterDistrict = val);
                                setState(() => _filterDistrict = val);
                                _savePreferences();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _neighborhoodController,
                        decoration: InputDecoration(
                          labelText: tr('neighborhood_optional'),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() => _filterNeighborhood = val);
                          setState(() => _filterNeighborhood = val);
                          _savePreferences();
                        },
                      ),
                      if (_categoryFeatures.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          tr('category_specific_filters'),
                          style: LocalFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._categoryFeatures.map((feature) {
                          String name = feature['name'];
                          List<String> options = feature['options'];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: name,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                              ),
                              initialValue: _featureDropdownValues[name],
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(tr('all')),
                                ),
                                ...options.toSet().map(
                                  (opt) => DropdownMenuItem(
                                    value: opt,
                                    child: Text(
                                      opt,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                setModalState(
                                  () => _featureDropdownValues[name] = val,
                                );
                                setState(() {
                                  _featureDropdownValues[name] = val;
                                  _isFiltering = true;
                                });
                                Future.delayed(
                                  const Duration(milliseconds: 400),
                                  () {
                                    if (mounted) {
                                      setState(() => _isFiltering = false);
                                    }
                                  },
                                );
                              },
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          tr('show_results'),
                          style: LocalFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSortModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('sort_criteria'),
                  style: LocalFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(
                    tr('newest_listings'),
                    style: LocalFonts.poppins(
                      fontWeight: _sortBy == 'date_desc'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: _sortBy == 'date_desc'
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      _sortBy = 'date_desc';
                      _isFiltering = true;
                    });
                    _savePreferences();
                    Navigator.pop(context);
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (mounted) setState(() => _isFiltering = false);
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(
                    tr('oldest_listings'),
                    style: LocalFonts.poppins(
                      fontWeight: _sortBy == 'date_asc'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: _sortBy == 'date_asc'
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      _sortBy = 'date_asc';
                      _isFiltering = true;
                    });
                    _savePreferences();
                    Navigator.pop(context);
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (mounted) setState(() => _isFiltering = false);
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.arrow_upward),
                  title: Text(
                    tr('price_low_to_high'),
                    style: LocalFonts.poppins(
                      fontWeight: _sortBy == 'price_asc'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: _sortBy == 'price_asc'
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      _sortBy = 'price_asc';
                      _isFiltering = true;
                    });
                    _savePreferences();
                    Navigator.pop(context);
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (mounted) setState(() => _isFiltering = false);
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.arrow_downward),
                  title: Text(
                    tr('price_high_to_low'),
                    style: LocalFonts.poppins(
                      fontWeight: _sortBy == 'price_desc'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: _sortBy == 'price_desc'
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      _sortBy = 'price_desc';
                      _isFiltering = true;
                    });
                    _savePreferences();
                    Navigator.pop(context);
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (mounted) setState(() => _isFiltering = false);
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll('ş', 's')
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }

  Widget _buildAuctionShowcase() {
    return const SizedBox.shrink();
  }
}
