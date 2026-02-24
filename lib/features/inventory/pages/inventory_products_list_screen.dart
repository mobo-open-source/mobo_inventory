import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../shared/widgets/loaders/loading_widget.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/inventory_product_provider.dart';
import '../../../core/services/runtime_permission_service.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../widgets/inventory_product_list_tile.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../adjustment/providers/adjustment_provider.dart';
import '../../adjustment/widgets/adjustmentDialogWidget.dart';
import '../../adjustment/models/inventory_adjustment_model.dart';
import '../../adjustment/services/adjustment_service.dart';
import '../../../shared/widgets/forms/custom_dropdown.dart';
import '../../../shared/widgets/forms/custom_text_field.dart';
import '../../../shared/widgets/dialogs/common_dialog.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/services/haptics_service.dart';
import '../../../shared/widgets/empty_state.dart';

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
  final ScrollController _scrollController = ScrollController();
  final Debouncer _searchDebouncer = Debouncer(milliseconds: 500);

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _voiceInput = '';
  bool _isListeningDialogShown = false;
  Timer? _listeningTimeoutTimer;
  VoidCallback? _updateDialogCallback;
  bool _isProcessingSpeech = false;

  bool _isScanning = false;

  final Map<int, Uint8List> _imageCache = {};

  final Map<String, bool> _expandedGroups = {};
  bool _allGroupsExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

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

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _listeningTimeoutTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebouncer.run(() {
      if (!mounted) return;
      final provider = context.read<InventoryProductProvider>();
      provider.fetchProducts(searchQuery: _searchController.text.trim());
      HapticsService.light();
    });
  }

  Future<void> _onRefresh() async {
    final provider = context.read<InventoryProductProvider>();
    await provider.fetchProducts(forceRefresh: true);
  }

  Future<void> _openAdjustmentForProduct(dynamic product) async {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      if (locations.isEmpty) {
        if (mounted) {
          CustomSnackbar.showError(context, 'No internal locations available');
        }
        return;
      }

      int selectedLocationId = locations.first['id'] as int;
      double countedQty = 0;
      final isDarkLocal = isDark;
      final qtyController = TextEditingController(text: '');

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return CommonDialog(
            title: 'Create Inventory Adjustment',
            primaryLabel: 'Create & Apply',
            onPrimary: () => Navigator.of(ctx).pop(true),
            secondaryLabel: 'Cancel',
            onSecondary: () => Navigator.of(ctx).pop(false),
            body: StatefulBuilder(
              builder: (ctx, setState) {
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomDropdown<int>(
                        value: selectedLocationId,
                        labelText: 'Location',
                        hintText: 'Select location',
                        isDark: isDarkLocal,
                        items: [
                          for (final l in locations)
                            DropdownMenuItem<int>(
                              value: l['id'] as int,
                              child: Text(
                                l['complete_name']?.toString() ??
                                    l['name']?.toString() ??
                                    'Location',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(
                          () => selectedLocationId = v ?? selectedLocationId,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: qtyController,
                        labelText: 'Counted Quantity',
                        hintText: 'Enter counted quantity',
                        isDark: isDarkLocal,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val.trim());
                          countedQty = parsed ?? 0;
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );

      if (confirmed == true) {
        try {
          final createdId = await svc.createInventoryLine(
            productId: product.id,
            locationId: selectedLocationId,
            countedQuantity: countedQty,
          );
          if (createdId != null) {
            await svc.applyAdjustment(createdId);
            if (mounted) {
              CustomSnackbar.showSuccess(
                context,
                'Inventory applied: qty $countedQty at selected location',
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
      final selected = await showModalBottomSheet<InventoryAdjustment>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.6,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF232323) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select Location / Lot',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: adjProvider.adjustments.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                    itemBuilder: (_, i) {
                      final a = adjProvider.adjustments[i];
                      return ListTile(
                        title: Text(
                          a.location ?? 'Unknown Location',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'On hand: ${a.onHandQuantity.toStringAsFixed(2)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(ctx, a),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
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

              final provider = context.read<InventoryProductProvider>();
              _searchDebouncer.cancel();
              provider.fetchProducts(
                searchQuery: _searchController.text.trim(),

                forceRefresh: true,
              );
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
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Voice Search',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
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

  void _showFilterBottomSheet() {
    final provider = context.read<InventoryProductProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(
        provider: provider,
        onClearSearch: () => _searchController.clear(),
      ),
    );
  }

  Uint8List? _decodeImage(String? base64String, int productId) {
    if (base64String == null ||
        base64String.isEmpty ||
        base64String == 'false') {
      return null;
    }

    if (_imageCache.containsKey(productId)) {
      return _imageCache[productId];
    }

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
      _imageCache[productId] = bytes;
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

        return Scaffold(
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
                child: TextField(
                  onTapOutside: (val) {
                    FocusScope.of(context).unfocus();
                  },
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xff1E1E1E),
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                    ),
                    prefixIcon: IconButton(
                      icon: Icon(
                        HugeIcons.strokeRoundedFilterHorizontal,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        size: 18,
                      ),
                      tooltip: 'Filter & Group By',
                      onPressed: _showFilterBottomSheet,
                    ),
                    suffixIcon: Container(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            Transform.translate(
                              offset: const Offset(4, 0),
                              child: IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () => _searchController.clear(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                              ),
                            ),
                          Transform.translate(
                            offset: const Offset(-4, 0),
                            child: IconButton(
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _isListening
                                    ? const Icon(
                                        HugeIcons.strokeRoundedMic01,
                                        key: ValueKey('listening'),
                                        color: Colors.red,
                                        size: 20,
                                      )
                                    : Icon(
                                        HugeIcons.strokeRoundedMic01,
                                        key: const ValueKey('idle'),
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                        size: 20,
                                      ),
                              ),
                              onPressed: _listen,
                              tooltip: _isListening
                                  ? 'Listening...'
                                  : 'Voice Search',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(-8, 0),
                            child: IconButton(
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
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      size: 20,
                                    ),
                              onPressed: _isScanning ? null : _scanBarcode,
                              tooltip: 'Scan Barcode',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey[850] : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.primaryColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                ),
              ),

              Consumer<InventoryProductProvider>(
                builder: (context, provider, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  _buildGroupByPill(
                                    theme,
                                    provider.selectedGroupBy,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (provider.totalProducts > 0 && !provider.isLoading)
                          PaginationControls(
                            canGoToPreviousPage: provider.canGoToPreviousPage,
                            canGoToNextPage: provider.canGoToNextPage,
                            onPreviousPage: () => provider.goToPreviousPage(),
                            onNextPage: () => provider.goToNextPage(),
                            paginationText: provider.getPaginationText(),
                            isDark: isDark,
                            theme: theme,
                          ),
                      ],
                    ),
                  );
                },
              ),

              Expanded(child: _buildBody(isDark, theme, provider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(
    bool isDark,
    ThemeData theme,
    InventoryProductProvider provider,
  ) {
    if (!provider.hasLoadedOnce && provider.products.isEmpty) {
      return ListShimmer.buildListShimmer(
        context,
        itemCount: 8,
        type: ShimmerType.product,
      );
    }

    if (provider.isLoading && provider.products.isEmpty) {
      return ListShimmer.buildListShimmer(
        context,
        itemCount: 8,
        type: ShimmerType.product,
      );
    }

    if (provider.error != null && provider.products.isEmpty) {
      final err = provider.error!.toLowerCase();
      final isModuleNotInstalled =
          err.contains('module') && err.contains('not installed');
      final title = isModuleNotInstalled
          ? 'Feature unavailable'
          : 'Something went wrong';
      final subtitle = isModuleNotInstalled
          ? 'This module is not installed on your server. Please contact your administrator.'
          : 'Pull to refresh or tap retry';
      final lottiePath = isModuleNotInstalled
          ? 'assets/lotties/socialv no data.json'
          : 'assets/lotties/Error 404.json';

      return RefreshIndicator(
        onRefresh: () => provider.fetchProducts(forceRefresh: true),
        child: ListView(
          children: [
            const SizedBox(height: 48),
            EmptyState(
              title: title,
              subtitle: subtitle,
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
          provider.selectedCategories.isNotEmpty ||
          provider.inStockOnly != null ||
          provider.productType != null ||
          provider.saleOk != null ||
          provider.purchaseOk != null ||
          provider.availableInPos != null ||
          provider.isActive != null ||
          provider.selectedGroupBy != null;

      return ListView(
        children: [
          const SizedBox(height: 48),
          EmptyState(
            title: 'No products found',
            subtitle: hasActiveFilters
                ? 'Try adjusting your filters'
                : 'Items will appear here',
            lottieAsset: 'assets/lotties/empty ghost.json',
            actionLabel: hasActiveFilters ? 'Clear All Filters' : null,
            onAction: hasActiveFilters
                ? () {
                    provider.clearFilters();
                    provider.fetchProducts();
                  }
                : null,
          ),
        ],
      );
    }

    if (provider.isGrouped && provider.selectedGroupBy != null) {
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
        final hasActiveFilters =
            provider.selectedCategories.isNotEmpty ||
            provider.inStockOnly != null ||
            provider.productType != null ||
            provider.saleOk != null ||
            provider.purchaseOk != null ||
            provider.availableInPos != null ||
            provider.isActive != null;

        return EmptyState(
          title: 'No groups found',
          subtitle: hasActiveFilters ? 'Try adjusting your filters' : '',
          lottieAsset: 'assets/lotties/empty ghost.json',
          actionLabel: hasActiveFilters ? 'Clear All Filters' : null,
          onAction: hasActiveFilters
              ? () {
                  provider.clearFilters();
                  provider.fetchProducts();
                }
              : null,
        );
      }

      for (final groupKey in provider.groupSummary.keys) {
        if (!_expandedGroups.containsKey(groupKey)) {
          _expandedGroups[groupKey] = false;
        }
      }

      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${provider.groupSummary.length} groups',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    if (!_allGroupsExpanded && provider.groupSummary.isNotEmpty)
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
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    if (_expandedGroups.values.any((expanded) => expanded))
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
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: provider.groupSummary.length,
                itemBuilder: (context, index) {
                  final groupKey = provider.groupSummary.keys.elementAt(index);
                  final count = provider.groupSummary[groupKey]!;
                  final isExpanded = _expandedGroups[groupKey] ?? false;
                  final loadedProducts = provider.loadedGroups[groupKey] ?? [];

                  return _buildGroupTile(
                    groupKey,
                    count,
                    loadedProducts,
                    isExpanded,
                    isDark,
                    theme,
                    provider,
                  );
                },
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: theme.primaryColor,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              itemCount: provider.products.length,
              itemBuilder: (context, index) {
                final product = provider.products[index];
                final imageBytes = _decodeImage(product.imageSmall, product.id);

                return InventoryProductListTile(
                  id: product.id.toString(),
                  name: product.displayname,
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
                  imageBytes: imageBytes,
                  isDark: isDark,
                  onTap: () {
                    context.pushNamed(
                      AppRoutes.inventoryProductDetail,
                      extra: {'productId': product.id},
                    );
                  },
                  onEdit: () => _openAdjustmentForProduct(product),
                  onLocate: () {
                    context.pushNamed(
                      AppRoutes.viewStock,
                      extra: {
                        'productId': product.id,
                        'productName': product.displayname,
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
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
    final label = _groupByLabel(groupBy);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.white70
            : Colors.black,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.layers_outlined,
            size: 14,
            color: isDark ? Colors.black : Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.black : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersBadge(
    InventoryProductProvider provider,
    ThemeData theme,
  ) {
    int count = 0;

    if (provider.selectedCategories.isNotEmpty) count++;
    if (provider.inStockOnly != null) count++;
    if (provider.productType != null) count++;

    if (provider.isStorable != null && provider.isStorable == false) count++;
    if (provider.availableInPos != null) count++;
    if (provider.saleOk != null) count++;
    if (provider.purchaseOk != null) count++;
    if (provider.hasActivityException != null) count++;
    if (provider.isActive != null) count++;
    if (provider.hasNegativeStock != null) count++;
    if (_searchController.text.trim().isNotEmpty) count++;

    final bool isDark = theme.brightness == Brightness.dark;
    final bool hasGroupBy = provider.selectedGroupBy != null;

    if (count == 0) {
      if (hasGroupBy) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'No filters applied',
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? Colors.white70
                : theme.colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white70 : Colors.black,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count Active',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.black : Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTile(
    String groupKey,
    int count,
    List<dynamic> loadedProducts,
    bool isExpanded,
    bool isDark,
    ThemeData theme,
    InventoryProductProvider provider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 6),
              color: Colors.black.withOpacity(0.08),
            ),
        ],
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
            else
              ...loadedProducts.map((product) {
                final imageBytes = _decodeImage(product.imageSmall, product.id);
                return InventoryProductListTile(
                  id: product.id.toString(),
                  name: product.name,
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
                  imageBytes: imageBytes,
                  isDark: isDark,
                  onTap: () {},
                  onEdit: () => _openAdjustmentForProduct(product),
                  onLocate: () {
                    context.pushNamed(
                      AppRoutes.viewStock,
                      extra: {
                        'productId': product.id,
                        'productName': product.name,
                      },
                    );
                  },
                );
              }),
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
