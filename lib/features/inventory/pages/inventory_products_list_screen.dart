import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../shared/widgets/loaders/loading_widget.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import '../../../core/services/error_manager.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/inventory_product_provider.dart';
import '../../../core/services/runtime_permission_service.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../../../shared/widgets/kanban/mobo_kanban_board.dart';
import '../../../shared/widgets/toggles/view_mode_toggle.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';
import '../../../shared/widgets/filters/active_filters_badge.dart';
import '../widgets/inventory_product_list_tile.dart';
import '../../../shared/widgets/search/mobo_search_filter_bar.dart';
import '../../../shared/widgets/filters/premium_filter_bottom_sheet.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../adjustment/providers/adjustment_provider.dart';
import '../../adjustment/widgets/adjustmentDialogWidget.dart';
import '../../adjustment/models/inventory_adjustment_model.dart';
import '../../adjustment/services/adjustment_service.dart';
import '../../../shared/widgets/layout/collapsible_header_layout.dart';
import '../models/inventory_product.dart';
import '../widgets/adjustment_picker_sheet.dart';
import '../widgets/create_adjustment_dialog.dart';
import '../widgets/inventory_product_kanban_card.dart';
import '../utils/inventory_access.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/services/haptics_service.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/theme/app_theme.dart';

/// Screen displaying a searchable and filterable list of inventory products.
class InventoryProductsListScreen extends StatefulWidget {
  const InventoryProductsListScreen({super.key});

  @override
  State<InventoryProductsListScreen> createState() =>
      _InventoryProductsListScreenState();
}

class _InventoryProductsListScreenState
    extends State<InventoryProductsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  // No ScrollController on the product lists: on a short (landscape) screen
  // the header scrolls away with the list through NestedScrollView, which
  // only works if the list picks up its PrimaryScrollController.
  final Debouncer _searchDebouncer = Debouncer(milliseconds: 500);

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _voiceInput = '';
  bool _isListeningDialogShown = false;
  Timer? _listeningTimeoutTimer;
  VoidCallback? _updateDialogCallback;
  bool _isProcessingSpeech = false;

  bool _isScanning = false;

  /// Decoded `image_128` per product id, with the base64 it came from so an
  /// image changed in the product form is decoded afresh.
  final Map<int, ({String source, Uint8List bytes})> _imageCache = {};

  final Map<String, bool> _expandedGroups = {};
  bool _allGroupsExpanded = false;

  /// Groups whose "Load more" is fetching.
  final Set<String> _loadingMoreGroups = {};

  static const String _viewModePrefKey = 'inventory_products_view_mode';

  /// Kanban (grid of cards) rather than list view.
  bool _isKanban = false;

  /// Clearance below the last item so the create button never covers it.
  static const double _fabClearance = 96;

  /// The user's access rights, read at the top of each build.
  late InventoryAccess _access;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _restoreViewMode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<InventoryProductProvider>();
      _fetchData(provider);
    });
  }

  void _fetchData(InventoryProductProvider provider) {
    if (provider.products.isEmpty) {
      provider.fetchProducts();
      provider.fetchCategories();
    }
    if (provider.groupByOptions.isEmpty) {
      provider.fetchGroupByOptions();
    }
  }

  Future<void> _restoreViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isKanban = prefs.getString(_viewModePrefKey) == 'kanban';
      if (mounted && isKanban != _isKanban) {
        setState(() => _isKanban = isKanban);
      }
    } catch (_) {
      // No stored preference: stay on the list view.
    }
  }

  Future<void> _setViewMode(bool isKanban) async {
    if (isKanban == _isKanban) return;
    HapticsService.light();
    setState(() => _isKanban = isKanban);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_viewModePrefKey, isKanban ? 'kanban' : 'list');
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _listeningTimeoutTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openProductDetail(int productId) async {
    final updated = await context.pushNamed<bool>(
      AppRoutes.inventoryProductDetail,
      extra: {'productId': productId},
    );
    if (updated == true && mounted) await _reloadAfterChange();
  }

  void _openViewStock(InventoryProduct product) {
    context.pushNamed(
      AppRoutes.viewStock,
      extra: {'productId': product.id, 'productName': product.displayname},
    );
  }

  Future<void> _openCreateProduct() async {
    final created = await context.pushNamed<bool>(
      AppRoutes.inventoryProductEdit,
      extra: {'create': true},
    );
    if (created != true || !mounted) return;
    CustomSnackbar.showSuccess(context, 'Product created successfully');
    await _reloadAfterChange();
  }

  /// Reloads the list (and the group counts, when grouped) keeping the
  /// current search and filters.
  Future<void> _reloadAfterChange() async {
    final provider = context.read<InventoryProductProvider>();
    await provider.fetchProducts(forceRefresh: true);
    if (provider.selectedGroupBy != null) await provider.fetchGroupSummary();
  }

  void _onSearchChanged() {
    _searchDebouncer.run(() {
      if (mounted) _search();
    });
  }

  /// Searches for what the field holds, under the filters already applied.
  /// Typing, the clear button, voice and the barcode scan all end up here.
  void _search() {
    final provider = context.read<InventoryProductProvider>();
    final query = _searchController.text.trim();
    // The field also notifies on a cursor move or a focus change; only a
    // different text is a new search (and a reload of the list).
    if (query == provider.searchQuery) return;

    // Forced, so a search typed while another is still loading is not
    // dropped — which left the list on the old search with the field cleared.
    provider.fetchProducts(searchQuery: query, forceRefresh: true);
    // A grouped list shows its groups, not `products`: their counts and
    // records are searched too, or clearing the search would leave them on
    // the old result.
    if (provider.selectedGroupBy != null) provider.fetchGroupSummary();
    HapticsService.light();
  }

  /// Clears the search, every filter and the grouping, and reloads.
  void _clearAllFilters() {
    final provider = context.read<InventoryProductProvider>();
    _searchController.clear();
    _searchDebouncer.cancel();
    provider.clearFilters();
    provider.fetchProducts(searchQuery: '', forceRefresh: true);
  }

  Future<void> _onRefresh() async {
    final provider = context.read<InventoryProductProvider>();
    await provider.fetchProducts(forceRefresh: true);
  }

  Future<void> _openAdjustmentForProduct(dynamic product) async {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) =>
          Center(child: CircularProgressIndicator(color: theme.primaryColor)),
    );

    final adjProvider = AdjustmentProvider();
    final productName = (product.displayname ?? product.name ?? '').toString();
    await adjProvider.fetchAdjustments(
      searchQuery: productName,
      productId: product.id,
      updateFilters: true,
    );

    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!mounted) return;

    if (adjProvider.adjustments.isEmpty) {
      final svc = AdjustmentService();

      final locations = await svc.fetchLocations();
      if (!mounted) return;
      if (locations.isEmpty) {
        if (mounted) {
          CustomSnackbar.showError(context, 'No internal locations available');
        }
        return;
      }

      final adjustment = await CreateAdjustmentDialog.show(
        context,
        locations: locations,
      );
      if (adjustment != null) {
        final countedQty = adjustment.countedQuantity;
        try {
          final createdId = await svc.createInventoryLine(
            productId: product.id,
            locationId: adjustment.locationId,
            countedQuantity: countedQty,
          );
          if (createdId != null) {
            // Without the right to apply, the count is recorded for a stock
            // manager to apply.
            if (adjustment.apply) await svc.applyAdjustment(createdId);
            if (mounted) {
              CustomSnackbar.showSuccess(
                context,
                adjustment.apply
                    ? 'Inventory applied: qty $countedQty at selected location'
                    : 'Count of $countedQty saved; a stock manager needs to apply it',
              );
              HapticsService.success();
            }
          } else {
            if (mounted)
              CustomSnackbar.showError(
                context,
                'Failed to create inventory line',
              );
          }
        } catch (e) {
          if (mounted)
            CustomSnackbar.showError(context, 'Error applying inventory: $e');
          HapticsService.error();
        }
        if (mounted) {
          await context.read<InventoryProductProvider>().fetchProducts(
            forceRefresh: true,
          );
        }
      }
      return;
    }

    Future<void> openDialog(InventoryAdjustment adjustment) async {
      await showDialog(
        context: context,
        builder: (_) => ChangeNotifierProvider<AdjustmentProvider>.value(
          value: adjProvider,
          child: AdjustmentDialog(adjustment: adjustment),
        ),
      );
    }

    if (adjProvider.adjustments.length == 1) {
      await openDialog(adjProvider.adjustments.first);
    } else {
      final selected = await AdjustmentPickerSheet.show(
        context,
        adjustments: adjProvider.adjustments,
      );

      if (selected != null) {
        await openDialog(selected);
      }
    }

    await context.read<InventoryProductProvider>().fetchProducts(
      forceRefresh: true,
    );
  }

  Future<void> _listen() async {
    if (_isProcessingSpeech) return;

    try {
      if (!_isListening) {
        final hasPermission =
            await RuntimePermissionService.requestMicrophonePermission(
              context,
              showRationale: true,
            );

        if (!hasPermission) return;

        if (!_speech.isAvailable) {
          final isInitialized = await _speech.initialize(
            onStatus: (status) {
              if (!mounted) return;
              setState(() {
                switch (status) {
                  case 'listening':
                    _isListening = true;
                    _isProcessingSpeech = false;
                    break;
                  case 'done':
                  case 'notListening':
                    _isListening = false;
                    _isProcessingSpeech = false;
                    _dismissListeningDialog();
                    _cancelListeningTimeout();
                    break;
                  default:
                    break;
                }
              });
            },
            onError: (error) {
              if (!mounted) return;
              setState(() {
                _isListening = false;
                _isProcessingSpeech = false;
              });
              _dismissListeningDialog();
              _cancelListeningTimeout();
            },
          );

          if (!isInitialized) {
            throw Exception('Failed to initialize speech recognition');
          }
        }

        setState(() {
          _isListening = true;
        });
        _showListeningDialog();
        _startListeningTimeout();

        await _speech.listen(
          onResult: (result) {
            if (!mounted) return;
            setState(() {
              _voiceInput = result.recognizedWords;
              _searchController.text = _voiceInput;
              _searchController.selection = TextSelection.fromPosition(
                TextPosition(offset: _searchController.text.length),
              );
            });
            _updateDialogCallback?.call();
            if (result.recognizedWords.isNotEmpty && result.finalResult) {
              HapticsService.success();

              _speech.stop();
              setState(() {
                _isListening = false;
                _isProcessingSpeech = false;
              });
              _dismissListeningDialog();
              _cancelListeningTimeout();

              _searchDebouncer.cancel();
              _search();
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        );
      } else {
        await _speech.stop();
        setState(() {
          _isListening = false;
          _isProcessingSpeech = false;
        });
        _dismissListeningDialog();
        _cancelListeningTimeout();
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(context, 'Voice recognition error: $e');
    }
  }

  void _showListeningDialog() {
    if (_isListeningDialogShown) return;
    _isListeningDialogShown = true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          _updateDialogCallback = () => setDialogState(() {});

          return AlertDialog(
            backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Voice Search',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: LoadingWidget(
                    color: isDark ? Colors.white : primaryColor,
                    size: 48,
                    variant: LoadingVariant.staggeredDots,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _voiceInput.isEmpty ? 'Listening...' : _voiceInput,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _speech.stop();
                  setState(() {
                    _isListening = false;
                    _isProcessingSpeech = false;
                  });
                  Navigator.of(context).pop();
                  _isListeningDialogShown = false;
                  _cancelListeningTimeout();
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _dismissListeningDialog() {
    if (_isListeningDialogShown && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _isListeningDialogShown = false;
    }
  }

  void _startListeningTimeout() {
    _cancelListeningTimeout();
    _listeningTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (_isListening) {
        setState(() => _isListening = false);
        _speech.stop();
        _dismissListeningDialog();
      }
    });
  }

  void _cancelListeningTimeout() {
    _listeningTimeoutTimer?.cancel();
    _listeningTimeoutTimer = null;
  }

  Future<void> _scanBarcode() async {
    final hasPermission =
        await RuntimePermissionService.requestCameraPermission(
          context,
          showRationale: true,
        );

    if (!hasPermission) return;

    setState(() => _isScanning = true);

    if (!mounted) return;

    final result = await context.pushNamed<String>(AppRoutes.barcodeScanner);

    if (mounted) {
      setState(() => _isScanning = false);
    }

    if (result != null && result.isNotEmpty && mounted) {
      _searchController.text = result;
    }
  }

  static String _snake(String s) => s.toLowerCase().replaceAll(' ', '_');

  void _showFilterBottomSheet() {
    final provider = context.read<InventoryProductProvider>();

    final categoryGroup = FilterGroup(
      title: 'Category',
      options: provider.categories
          .map(
            (cat) => FilterOption(
              title: cat,
              value: provider.selectedCategories.contains(cat),
            ),
          )
          .toList(),
    );

    final stockStatusGroup = FilterGroup(
      title: 'Stock Status',
      options: [
        FilterOption(title: 'In Stock', value: provider.inStockOnly == true),
        FilterOption(
          title: 'Out of Stock',
          value: provider.inStockOnly == false,
        ),
      ],
    );

    // The types as the server defines them: Odoo 18 has no "Storable
    // Product" / "Consumable" types any more but Goods, Service and Combo,
    // with storable a separate `is_storable` flag on goods.
    final productTypeGroup = FilterGroup(
      title: 'Product Type',
      options: [
        for (final entry in provider.typeOptions.entries)
          FilterOption(
            title: entry.value,
            value: provider.productType == entry.key,
          ),
        if (provider.hasStorableField)
          FilterOption(title: 'Storable', value: provider.isStorable == true),
      ],
    );

    final attributesGroup = FilterGroup(
      title: 'Product Attributes',
      options: [
        FilterOption(title: 'Can be Sold', value: provider.saleOk == true),
        FilterOption(
          title: 'Can be Purchased',
          value: provider.purchaseOk == true,
        ),
        // Only with the Point of Sale app installed; filtering on it
        // otherwise fails with "Invalid field".
        if (provider.hasPosField)
          FilterOption(
            title: 'Available in POS',
            value: provider.availableInPos == true,
          ),
        FilterOption(title: 'Archived', value: provider.isActive == false),
      ],
    );

    final groupByGroup = FilterGroup(
      title: 'Group By',
      options: provider.groupByOptions.entries
          .map(
            (entry) => FilterOption(
              title: entry.value,
              value: provider.selectedGroupBy == entry.key,
            ),
          )
          .toList(),
    );

    PremiumFilterBottomSheet.show(
      context: context,
      title: 'Filter & Group By',
      filterGroups: [
        if (categoryGroup.options.isNotEmpty) categoryGroup,
        stockStatusGroup,
        if (productTypeGroup.options.isNotEmpty) productTypeGroup,
        attributesGroup,
      ],
      groupByOptions: [groupByGroup],
      onApply: (values) {
        final selectedCategories = provider.categories
            .where((cat) => values['category_${_snake(cat)}'] == true)
            .toList();

        final inStockOnly = values['stock_status_in_stock'] == true
            ? true
            : (values['stock_status_out_of_stock'] == true ? false : null);

        String? productType;
        for (final entry in provider.typeOptions.entries) {
          if (values['product_type_${_snake(entry.value)}'] == true) {
            productType = entry.key;
            break;
          }
        }
        final isStorable =
            provider.hasStorableField && values['product_type_storable'] == true
            ? true
            : null;

        final saleOk = values['product_attributes_can_be_sold'] == true
            ? true
            : null;
        final purchaseOk = values['product_attributes_can_be_purchased'] == true
            ? true
            : null;
        final availableInPos =
            provider.hasPosField &&
                values['product_attributes_available_in_pos'] == true
            ? true
            : null;
        final isActive = values['product_attributes_archived'] == true
            ? false
            : null;

        String? groupBy;
        for (final entry in provider.groupByOptions.entries) {
          if (values['group_by_${_snake(entry.value)}'] == true) {
            groupBy = entry.key;
            break;
          }
        }

        provider.setGroupBy(groupBy);
        provider.applyFilters(
          categories: selectedCategories,
          inStockOnly: inStockOnly,
          productType: productType,
          isStorable: isStorable,
          saleOk: saleOk,
          purchaseOk: purchaseOk,
          availableInPos: availableInPos,
          isActive: isActive,
        );
        if (groupBy != null) {
          provider.fetchGroupSummary();
        }
      },
    );
  }

  Uint8List? _decodeImage(String? base64String, int productId) {
    if (base64String == null ||
        base64String.isEmpty ||
        base64String == 'false') {
      return null;
    }

    final cached = _imageCache[productId];
    if (cached != null && cached.source == base64String) return cached.bytes;

    try {
      var cleaned = base64String;
      final commaIndex = cleaned.indexOf(',');
      if (cleaned.startsWith('data:') && commaIndex != -1) {
        cleaned = cleaned.substring(commaIndex + 1);
      }

      cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');

      final remainder = cleaned.length % 4;
      if (remainder != 0) {
        cleaned = cleaned.padRight(cleaned.length + (4 - remainder), '=');
      }

      final bytes = base64Decode(cleaned);
      _imageCache[productId] = (source: base64String, bytes: bytes);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Consumer<InventoryProductProvider>(
      builder: (context, provider, child) {
        if (!provider.isLoading &&
            !provider.hasLoadedOnce &&
            provider.error == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fetchData(provider);
          });
        }

        _access = InventoryAccess.watch(context);
        final compact = isCompactHeight(context);
        // Only for users who may create products, and not on the full-screen
        // error state (e.g. Inventory not installed).
        final showFab =
            _access.canCreateProducts &&
            !(provider.error != null && provider.products.isEmpty);

        return Scaffold(
          floatingActionButton: showFab
              ? FloatingActionButton(
                  heroTag: 'createInventoryProductFab',
                  onPressed: _openCreateProduct,
                  backgroundColor: theme.primaryColor,
                  elevation: 0,
                  highlightElevation: 0,
                  tooltip: 'Create Product',
                  child: const Icon(
                    HugeIcons.strokeRoundedPackageAdd,
                    color: Colors.white,
                  ),
                )
              : null,
          body: CollapsibleHeaderLayout(
            header: _buildHeader(isDark, theme, provider, compact),
            body: _buildBody(isDark, theme, provider, compact, showFab),
          ),
        );
      },
    );
  }

  /// Search bar plus the filter row (active filters, group-by, view toggle,
  /// pagination). Pinned on a normal screen; scrolls away with the list on a
  /// short one (see [CollapsibleHeaderLayout]).
  Widget _buildHeader(
    bool isDark,
    ThemeData theme,
    InventoryProductProvider provider,
    bool compact,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: compact
              ? const EdgeInsets.fromLTRB(16, 12, 16, 10)
              : const EdgeInsets.all(16),
          decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
          child: MoboSearchFilterBar(
            controller: _searchController,
            hintText: 'Search products...',
            hasActiveFilter: _activeFilterCount(provider) > 0,
            onFilterTap: _showFilterBottomSheet,
            onChanged: (value) {
              setState(() {});
              _onSearchChanged();
            },
            extraActions: [
              SearchBarAction(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isListening
                      ? const Icon(
                          HugeIcons.strokeRoundedMic01,
                          key: ValueKey('listening'),
                          color: StatusColors.red,
                          size: 20,
                        )
                      : Icon(
                          HugeIcons.strokeRoundedMic01,
                          key: const ValueKey('idle'),
                          color: isDark ? Colors.white : Colors.black,
                          size: 20,
                        ),
                ),
                onTap: _listen,
                tooltip: _isListening ? 'Listening...' : 'Voice Search',
              ),
              SearchBarAction(
                icon: _isScanning
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.primaryColor,
                        ),
                      )
                    : Icon(
                        HugeIcons.strokeRoundedCameraAi,
                        color: isDark ? Colors.white : Colors.black,
                        size: 20,
                      ),
                onTap: _isScanning ? null : _scanBarcode,
                tooltip: 'Scan Barcode',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (provider.hasLoadedOnce)
                        _buildActiveFiltersBadge(provider, theme),
                      if (provider.selectedGroupBy != null) ...[
                        const SizedBox(width: 8),
                        _buildGroupByPill(theme, provider.selectedGroupBy),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ViewModeToggle(
                keyPrefix: 'inventory',
                isKanban: _isKanban,
                isDark: isDark,
                onChanged: _setViewMode,
              ),
              ..._buildPager(provider, isDark, theme),
            ],
          ),
        ),
        if (compact) const SizedBox(height: 4),
      ],
    );
  }

  bool _hasActiveFilters(InventoryProductProvider provider) =>
      _searchController.text.trim().isNotEmpty ||
      provider.selectedCategories.isNotEmpty ||
      provider.inStockOnly != null ||
      provider.productType != null ||
      provider.isStorable == true ||
      provider.saleOk != null ||
      provider.purchaseOk != null ||
      provider.availableInPos != null ||
      provider.isActive == false;

  Widget _buildBody(
    bool isDark,
    ThemeData theme,
    InventoryProductProvider provider,
    bool compact,
    bool showFab,
  ) {
    final bottomPadding = showFab ? _fabClearance : 16.0;

    if ((!provider.hasLoadedOnce || provider.isLoading) &&
        provider.products.isEmpty) {
      if (_isKanban) return const InventoryProductKanbanShimmer();
      return ListShimmer.buildListShimmer(
        context,
        itemCount: 8,
        type: ShimmerType.product,
      );
    }

    if (provider.error != null && provider.products.isEmpty) {
      final info = ErrorManager.analyzeError(provider.error!);
      final lottiePath = info.type == ErrorType.moduleNotInstalled
          ? 'assets/lotties/socialv no data.json'
          : 'assets/lotties/Error 404.json';

      return RefreshIndicator(
        onRefresh: () => provider.fetchProducts(forceRefresh: true),
        child: ListView(
          children: [
            const SizedBox(height: 48),
            EmptyState(
              title: info.title,
              subtitle: info.message,
              lottieAsset: lottiePath,
              actionLabel: 'Retry',
              onAction: () => provider.fetchProducts(forceRefresh: true),
            ),
          ],
        ),
      );
    }

    if (provider.products.isEmpty && provider.hasLoadedOnce) {
      final hasActiveFilters =
          _hasActiveFilters(provider) || provider.selectedGroupBy != null;

      return ListView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        children: [
          const SizedBox(height: 48),
          EmptyState(
            title: 'No products found',
            subtitle: hasActiveFilters
                ? 'Try adjusting your filters'
                : 'Items will appear here',
            lottieAsset: 'assets/lotties/empty ghost.json',
            actionLabel: hasActiveFilters ? 'Clear All Filters' : null,
            onAction: hasActiveFilters ? _clearAllFilters : null,
          ),
        ],
      );
    }

    if (provider.isGrouped && provider.selectedGroupBy != null) {
      return _buildGroupedBody(isDark, theme, provider, compact, bottomPadding);
    }

    final padding = EdgeInsets.fromLTRB(16, 10, 16, bottomPadding);

    if (_isKanban) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        color: theme.primaryColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GridView.builder(
              key: const ValueKey('inventoryKanbanGrid'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              gridDelegate: InventoryKanbanLayout.delegate(
                context,
                constraints.maxWidth - padding.horizontal,
              ),
              itemCount: provider.products.length,
              itemBuilder: (context, index) => _buildKanbanCard(
                provider.products[index],
                isDark,
                name: provider.products[index].displayname,
              ),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: theme.primaryColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        itemCount: provider.products.length,
        itemBuilder: (context, index) {
          final product = provider.products[index];
          return _buildListTile(product, isDark, name: product.displayname);
        },
      ),
    );
  }

  Widget _buildListTile(
    InventoryProduct product,
    bool isDark, {
    required String name,
  }) {
    return InventoryProductListTile(
      id: product.id.toString(),
      name: name,
      defaultCode: product.defaultCode,
      barcode: product.barcode,
      qtyOnHand: product.qtyOnHand,
      qtyIncoming: product.qtyIncoming,
      qtyOutgoing: product.qtyOutgoing,
      qtyAvailable: product.qtyAvailable,
      freeQty: product.freeQty,
      avgCost: product.avgCost,
      totalValue: product.totalValue,
      uomName: product.uomName,
      category: product.categoryName,
      imageBytes: _decodeImage(product.imageSmall, product.id),
      isDark: isDark,
      onTap: () => _openProductDetail(product.id),
      onEdit: _access.canCountStock
          ? () => _openAdjustmentForProduct(product)
          : null,
      onLocate: () => _openViewStock(product),
    );
  }

  Widget _buildKanbanCard(
    InventoryProduct product,
    bool isDark, {
    required String name,
    bool compact = false,
  }) {
    return InventoryProductKanbanCard(
      key: ValueKey('inventoryKanbanCard_${product.id}'),
      compact: compact,
      name: name,
      defaultCode: product.defaultCode,
      qtyOnHand: product.qtyOnHand,
      freeQty: product.freeQty,
      listPrice: product.listPrice,
      uomName: product.uomName,
      imageBytes: _decodeImage(product.imageSmall, product.id),
      isDark: isDark,
      onTap: () => _openProductDetail(product.id),
      onEdit: _access.canCountStock
          ? () => _openAdjustmentForProduct(product)
          : null,
      onLocate: () => _openViewStock(product),
    );
  }

  Widget _buildGroupedBody(
    bool isDark,
    ThemeData theme,
    InventoryProductProvider provider,
    bool compact,
    double bottomPadding,
  ) {
    if (provider.isLoading && provider.groupSummary.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListShimmer.buildGroupedListShimmer(
            context,
            groupCount: 4,
            itemsPerGroup: 2,
            type: ShimmerType.product,
          ),
        ),
      );
    }
    if (provider.groupSummary.isEmpty) {
      final hasActiveFilters = _hasActiveFilters(provider);

      return ListView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        children: [
          const SizedBox(height: 48),
          EmptyState(
            title: 'No groups found',
            subtitle: hasActiveFilters ? 'Try adjusting your filters' : '',
            lottieAsset: 'assets/lotties/empty ghost.json',
            actionLabel: hasActiveFilters ? 'Clear All Filters' : null,
            onAction: hasActiveFilters ? _clearAllFilters : null,
          ),
        ],
      );
    }

    if (_isKanban) {
      // Odoo's grouped kanban: a column per group, scrolled sideways.
      return MoboKanbanBoard<InventoryProduct>(
        key: ValueKey('inventoryKanbanBoard_${provider.selectedGroupBy}'),
        groups: provider.groupSummary,
        loadedGroups: provider.loadedGroups,
        onLoadGroup: provider.loadGroupProducts,
        onLoadMore: provider.loadMoreGroupProducts,
        onRefresh: _reloadAfterChange,
        bottomPadding: bottomPadding,
        itemBuilder: (context, product) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildKanbanCard(
            product,
            isDark,
            name: product.displayname,
            compact: true,
          ),
        ),
      );
    }

    // A group the search (or a filter) dropped is no longer open: it would
    // otherwise come back open, on a spinner that never ends.
    _expandedGroups.removeWhere(
      (key, _) => !provider.groupSummary.containsKey(key),
    );
    for (final groupKey in provider.groupSummary.keys) {
      if (!_expandedGroups.containsKey(groupKey)) {
        _expandedGroups[groupKey] = false;
      }
    }
    _allGroupsExpanded =
        _expandedGroups.isNotEmpty &&
        _expandedGroups.values.every((expanded) => expanded);

    final groupKeys = provider.groupSummary.keys.toList();
    // On a short screen the "N groups / Expand All" row is the list's first
    // item, so it scrolls away too instead of staying pinned.
    final leading = compact ? 1 : 0;

    final list = RefreshIndicator(
      onRefresh: _reloadAfterChange,
      color: theme.primaryColor,
      child: ListView.builder(
        key: const ValueKey('inventoryGroupedList'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, compact ? 4 : 16, 16, bottomPadding),
        itemCount: groupKeys.length + leading,
        itemBuilder: (context, index) {
          if (index < leading) {
            return _buildGroupSummaryRow(
              provider,
              isDark,
              padding: const EdgeInsets.only(bottom: 8),
            );
          }
          final groupKey = groupKeys[index - leading];
          return _buildGroupTile(
            groupKey,
            provider.groupSummary[groupKey] ?? 0,
            provider.loadedGroups[groupKey] ?? const [],
            _expandedGroups[groupKey] ?? false,
            isDark,
            theme,
            provider,
          );
        },
      ),
    );

    if (compact) return list;

    return Column(
      children: [
        _buildGroupSummaryRow(
          provider,
          isDark,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        Expanded(child: list),
      ],
    );
  }

  /// "N groups" with the Expand All / Collapse All actions.
  Widget _buildGroupSummaryRow(
    InventoryProductProvider provider,
    bool isDark, {
    required EdgeInsets padding,
  }) {
    final actionStyle = TextButton.styleFrom(
      foregroundColor: isDark ? Colors.white : Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
    );
    final showExpand = !_allGroupsExpanded && provider.groupSummary.isNotEmpty;
    final showCollapse = _expandedGroups.values.any((expanded) => expanded);

    return Padding(
      key: const ValueKey('inventoryGroupSummaryRow'),
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${provider.groupSummary.length} groups',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (showExpand || showCollapse)
            // Both actions show while only some groups are open; on a narrow
            // phone they shrink to fit rather than overflow the row.
            Flexible(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showExpand)
                        TextButton.icon(
                          onPressed: () async {
                            setState(() {
                              for (final key in provider.groupSummary.keys) {
                                _expandedGroups[key] = true;
                              }
                              _allGroupsExpanded = true;
                            });

                            for (final key in provider.groupSummary.keys) {
                              if (provider.loadedGroups[key] == null ||
                                  provider.loadedGroups[key]!.isEmpty) {
                                await provider.loadGroupProducts(key);
                              }
                            }
                          },
                          icon: const Icon(Icons.expand_more, size: 18),
                          label: const Text('Expand All'),
                          style: actionStyle,
                        ),
                      if (showCollapse)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              for (final key in provider.groupSummary.keys) {
                                _expandedGroups[key] = false;
                              }
                              _allGroupsExpanded = false;
                            });
                          },
                          icon: const Icon(Icons.expand_less, size: 18),
                          label: const Text('Collapse All'),
                          style: actionStyle,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The pager beside the view toggle, as Odoo shows it: ungrouped it
  /// pages the products; a grouped list pages its groups (each group's
  /// header carries its own count); a grouped kanban has none — each column
  /// shows its count.
  List<Widget> _buildPager(
    InventoryProductProvider provider,
    bool isDark,
    ThemeData theme,
  ) {
    if (provider.isGrouped && provider.selectedGroupBy != null) {
      if (_isKanban || provider.groupSummary.isEmpty) return const [];
      return [
        const SizedBox(width: 8),
        PaginationControls(
          canGoToPreviousPage: false,
          canGoToNextPage: false,
          onPreviousPage: () {},
          onNextPage: () {},
          paginationText: PaginationControls.groupsText(
            provider.groupSummary.length,
          ),
          isDark: isDark,
          theme: theme,
        ),
      ];
    }
    if (provider.totalProducts == 0 || provider.isLoading) return const [];
    return [
      const SizedBox(width: 8),
      PaginationControls(
        canGoToPreviousPage: provider.canGoToPreviousPage,
        canGoToNextPage: provider.canGoToNextPage,
        onPreviousPage: () => provider.goToPreviousPage(),
        onNextPage: () => provider.goToNextPage(),
        paginationText: provider.getPaginationText(),
        isDark: isDark,
        theme: theme,
      ),
    ];
  }

  /// "Load more" at the foot of an expanded group showing fewer products
  /// than its count.
  Widget _buildGroupLoadMore(
    InventoryProductProvider provider,
    String groupKey,
    int remaining,
  ) {
    final loading = _loadingMoreGroups.contains(groupKey);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextButton(
        onPressed: loading
            ? null
            : () async {
                setState(() => _loadingMoreGroups.add(groupKey));
                await provider.loadMoreGroupProducts(groupKey);
                if (mounted) {
                  setState(() => _loadingMoreGroups.remove(groupKey));
                }
              },
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text('Load more ($remaining)'),
      ),
    );
  }

  IconData _getGroupIcon(String? groupByField) {
    switch (groupByField) {
      case 'type':
        return Icons.inventory_2_outlined;
      case 'categ_id':
        return Icons.category_outlined;
      case 'pos_categ_ids':
        return Icons.point_of_sale_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  String _groupByLabel(String? groupByField) {
    switch (groupByField) {
      case 'type':
        return 'Type';
      case 'categ_id':
        return 'Category';
      case 'company_id':
        return 'Company';
      case 'uom_id':
        return 'UoM';
      case 'active':
        return 'Active';
      default:
        return 'Custom';
    }
  }

  Widget _buildGroupByPill(ThemeData theme, String? groupBy) {
    return GroupByPill(label: _groupByLabel(groupBy), theme: theme);
  }

  int _activeFilterCount(InventoryProductProvider provider) {
    int count = 0;

    if (provider.selectedCategories.isNotEmpty) count++;
    if (provider.inStockOnly != null) count++;
    if (provider.productType != null) count++;

    if (provider.isStorable == true) count++;
    if (provider.availableInPos != null) count++;
    if (provider.saleOk != null) count++;
    if (provider.purchaseOk != null) count++;
    if (provider.hasActivityException != null) count++;
    if (provider.isActive == false) count++;
    if (provider.hasNegativeStock != null) count++;
    if (_searchController.text.trim().isNotEmpty) count++;

    return count;
  }

  Widget _buildActiveFiltersBadge(
    InventoryProductProvider provider,
    ThemeData theme,
  ) {
    return ActiveFiltersBadge(
      count: _activeFilterCount(provider),
      theme: theme,
      hasGroupBy: provider.selectedGroupBy != null,
    );
  }

  Widget _buildGroupTile(
    String groupKey,
    int count,
    List<InventoryProduct> loadedProducts,
    bool isExpanded,
    bool isDark,
    ThemeData theme,
    InventoryProductProvider provider,
  ) {
    return Container(
      decoration: BoxDecoration(
        // grey[900] in dark so the grey[850] product cards nested inside
        // the expanded group stay visible.
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: AppShadows.card,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: () async {
              setState(() {
                _expandedGroups[groupKey] = !isExpanded;
                _allGroupsExpanded = _expandedGroups.values.every(
                  (expanded) => expanded,
                );
              });

              if (!isExpanded && loadedProducts.isEmpty) {
                await provider.loadGroupProducts(groupKey);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getGroupIcon(provider.selectedGroupBy),
                      color: theme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupKey,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$count ${count == 1 ? 'product' : 'products'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            if (loadedProducts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: CircularProgressIndicator(color: theme.primaryColor),
              )
            else ...[
              for (final product in loadedProducts)
                _buildListTile(product, isDark, name: product.displayname),
              if (loadedProducts.length < count)
                _buildGroupLoadMore(
                  provider,
                  groupKey,
                  count - loadedProducts.length,
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _BarcodeScannerScreen extends StatefulWidget {
  @override
  State<_BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<_BarcodeScannerScreen> {
  MobileScannerController controller = MobileScannerController();
  bool isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          if (!isScanned) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                setState(() => isScanned = true);
                Navigator.pop(context, barcode.rawValue!);
                break;
              }
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
