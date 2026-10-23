import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobo_inv_app/core/routing/app_routes.dart';
import 'package:mobo_inv_app/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/const/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/dialogs/confirm_discard_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/forms/mobo_form_field.dart';
import '../../../shared/widgets/forms/mobo_typeahead_dropdown_field.dart';
import '../../../shared/widgets/mobo/mobo_multi_select_field.dart';
import '../viewmodels/inventory_product_edit_view_model.dart';
import '../utils/inventory_access.dart';
import '../../../core/services/haptics_service.dart';

/// The product form: edits `product.product` [productId], or creates a new
/// product when [productId] is null.
class InventoryProductEditScreen extends StatefulWidget {
  /// The `product.product` to edit; null opens the form in create mode.
  final int? productId;

  /// Supplied by tests; the screen otherwise makes (and disposes) its own.
  final InventoryProductEditViewModel? viewModel;

  const InventoryProductEditScreen({super.key, this.productId, this.viewModel});

  bool get isCreateMode => productId == null;

  @override
  State<InventoryProductEditScreen> createState() =>
      _InventoryProductEditScreenState();
}

class _InventoryProductEditScreenState
    extends State<InventoryProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _salePriceCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _volumeCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  bool _controllersInitialized = false;

  late final InventoryProductEditViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = widget.viewModel ?? InventoryProductEditViewModel();
    _loadRecord();
  }

  void _loadRecord() {
    _controllersInitialized = false;
    final id = widget.productId;
    if (id == null) {
      _vm.initCreate();
    } else {
      _vm.load(id);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _salePriceCtrl.dispose();
    _costPriceCtrl.dispose();
    _weightCtrl.dispose();
    _volumeCtrl.dispose();
    _descriptionCtrl.dispose();
    _vm.dispose();
    super.dispose();
  }

  /// Fills the text fields from the loaded record (or the create defaults)
  /// once, when it arrives. Keyed on [InventoryProductEditViewModel.recordLoaded]
  /// rather than on the name being non-empty, so a record that loaded with
  /// odd data still fills every other field.
  void _initializeControllers(InventoryProductEditViewModel vm) {
    if (!_controllersInitialized && !vm.loading && vm.recordLoaded) {
      _nameCtrl.text = vm.name;
      _skuCtrl.text = vm.sku;
      _barcodeCtrl.text = vm.barcode;
      _descriptionCtrl.text = vm.description;
      _salePriceCtrl.text = vm.listPrice?.toStringAsFixed(2) ?? '';
      _costPriceCtrl.text = vm.standardPrice?.toStringAsFixed(2) ?? '';
      _weightCtrl.text = vm.weight?.toString() ?? '';
      _volumeCtrl.text = vm.volume?.toString() ?? '';
      _controllersInitialized = true;
    }
  }

  Future<void> _saveProduct(InventoryProductEditViewModel vm) async {
    if (!_formKey.currentState!.validate()) {
      CustomSnackbar.showWarning(
        context,
        'Please fix the errors before saving',
      );
      return;
    }

    if (vm.categId == null || vm.uomId == null) {
      CustomSnackbar.showWarning(context, 'Please fill all required fields');
      return;
    }

    // Numeric fields are already in the view model (their onChanged keeps it
    // in step); re-parsing the 2-decimal text here would round a price the
    // user never touched.
    vm.name = _nameCtrl.text.trim();
    vm.sku = _skuCtrl.text.trim();
    vm.barcode = _barcodeCtrl.text.trim();
    vm.description = _descriptionCtrl.text.trim();

    final success = await vm.save();

    if (!mounted) return;

    if (success) {
      HapticsService.success();
      context.pop(true);
    } else {
      CustomSnackbar.showError(
        context,
        vm.error ??
            (vm.isCreateMode
                ? 'Failed to create product'
                : 'Failed to save product'),
      );
      HapticsService.error();
    }
  }

  double? _parseDouble(String text) {
    if (text.trim().isEmpty) return null;
    return double.tryParse(text.trim());
  }

  Future<void> _pickImage(
    InventoryProductEditViewModel vm,
    ImageSource source,
  ) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        vm.setImage(base64Encode(bytes));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  void _showImageOptions(InventoryProductEditViewModel vm) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.grey[50],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  context.pop();
                  _pickImage(vm, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  context.pop();
                  _pickImage(vm, ImageSource.gallery);
                },
              ),
              if (vm.imageBase64 != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: StatusColors.red),
                  title: const Text(
                    'Remove Image',
                    style: TextStyle(color: StatusColors.red),
                  ),
                  onTap: () {
                    context.pop();
                    vm.setImage(null);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _scanBarcode(InventoryProductEditViewModel vm) async {
    final result = await context.pushNamed<String>(AppRoutes.barcodeScanner);
    if (result != null && result.isNotEmpty) {
      _barcodeCtrl.text = result;
      vm.setBarcode(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final access = InventoryAccess.watch(context);
    // The save button is withheld from users Odoo would refuse anyway.
    final canSubmit = widget.isCreateMode
        ? access.canCreateProducts
        : access.canEditProducts;

    return ChangeNotifierProvider<InventoryProductEditViewModel>.value(
      value: _vm,
      child: Consumer<InventoryProductEditViewModel>(
        builder: (context, vm, _) {
          _initializeControllers(vm);

          return PopScope(
            // Only ask before leaving when there is something to lose.
            canPop: !vm.hasUnsavedChanges,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;

              final discard = await ConfirmDiscardDialog.show(context);
              if (discard == true && context.mounted) {
                context.pop();
              }
            },
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: Icon(
                    HugeIcons.strokeRoundedArrowLeft01,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  // maybePop, so the unsaved-changes check above applies to
                  // this button as well as to the system back gesture.
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                title: Text(
                  widget.isCreateMode ? 'Create Product' : 'Edit Product',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                foregroundColor: isDark ? Colors.white : primaryColor,
                elevation: 0,
                actions: [
                  if (!widget.isCreateMode)
                    IconButton(
                      tooltip: 'Reload',
                      icon: Icon(
                        Icons.refresh,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      onPressed: vm.loading ? null : _loadRecord,
                    ),
                ],
              ),
              body: vm.loading
                  ? _buildShimmerLoading(isDark)
                  : !vm.recordLoaded
                  ? _buildLoadError(vm)
                  : Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _buildImageSection(vm, isDark),
                          const SizedBox(height: 24),

                          MoboFormField(
                            label: 'Product Name',
                            isRequired: true,
                            controller: _nameCtrl,
                            hintText: 'Enter product name',
                            validator: (v) => (v?.trim().isEmpty ?? true)
                                ? 'Product name is required'
                                : null,
                            onChanged: vm.setName,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),

                          MoboFormField(
                            controller: _skuCtrl,
                            label: 'SKU/Default Code',
                            hintText: 'Enter SKU',
                            onChanged: vm.setSku,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),

                          MoboFormField(
                            label: 'Barcode',
                            controller: _barcodeCtrl,
                            hintText: 'Enter barcode or scan using camera',
                            onChanged: vm.setBarcode,
                            isDark: isDark,
                            suffixWidget: IconButton(
                              icon: Icon(
                                HugeIcons.strokeRoundedScanImage,
                                size: 24,
                              ),
                              onPressed: () => _scanBarcode(vm),
                            ),
                          ),
                          const SizedBox(height: 20),

                          MoboTypeaheadDropdownField<String>(
                            label: 'Category',
                            isRequired: true,
                            hintText: 'Select category',
                            isDark: isDark,
                            selectedItem: vm.categId?.toString(),
                            items: [
                              for (final opt in vm.categoryOptions)
                                opt['value']!,
                            ],
                            displayText: (val) =>
                                vm.categoryOptions.firstWhere(
                                  (opt) => opt['value'] == val,
                                  orElse: () => const {},
                                )['label'] ??
                                val,
                            onChanged: (val) => vm.setCategory(
                              val == null ? null : int.tryParse(val),
                            ),
                          ),
                          const SizedBox(height: 20),

                          MoboFormField(
                            controller: _salePriceCtrl,
                            label: 'List Price',
                            hintText: '0.00',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            isDark: isDark,
                            validator: _validatePrice,
                            onChanged: (v) => vm.setListPrice(_parseDouble(v)),
                          ),
                          const SizedBox(height: 20),

                          MoboFormField(
                            controller: _costPriceCtrl,
                            label: 'Cost Price',
                            hintText: '0.00',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            isDark: isDark,
                            validator: _validatePrice,
                            onChanged: (v) =>
                                vm.setStandardPrice(_parseDouble(v)),
                          ),
                          const SizedBox(height: 20),

                          // taxes_id is many2many: a product can carry
                          // several taxes, so every one must stay selectable
                          // (the single-select field kept only the first and
                          // dropped the rest on save). It only exists with
                          // the Invoicing app installed.
                          if (vm.hasTaxesField) ...[
                            MoboMultiSelectField<String>(
                              label: 'Taxes',
                              panelTitle: 'Select Taxes',
                              hintText: 'Select taxes',
                              searchHintText: 'Search taxes...',
                              selectedItems: [
                                for (final id in vm.taxes) id.toString(),
                              ],
                              items: [
                                for (final opt in vm.taxOptions) opt['value']!,
                              ],
                              displayText: (val) =>
                                  vm.taxOptions.firstWhere(
                                    (opt) => opt['value'] == val,
                                    orElse: () => const {},
                                  )['label'] ??
                                  val,
                              onChanged: (vals) => vm.setTaxes([
                                for (final v in vals)
                                  if (int.tryParse(v) != null) int.parse(v),
                              ]),
                            ),
                            const SizedBox(height: 20),
                          ],

                          MoboTypeaheadDropdownField<String>(
                            label: 'Unit of Measure',
                            isRequired: true,
                            hintText: 'Select unit',
                            isDark: isDark,
                            selectedItem: vm.uomId?.toString(),
                            items: [
                              for (final opt in vm.uomOptions) opt['value']!,
                            ],
                            displayText: (val) =>
                                vm.uomOptions.firstWhere(
                                  (opt) => opt['value'] == val,
                                  orElse: () => const {},
                                )['label'] ??
                                val,
                            onChanged: (val) => vm.setUom(
                              val == null ? null : int.tryParse(val),
                            ),
                          ),
                          const SizedBox(height: 20),

                          MoboTypeaheadDropdownField<String>(
                            label: 'Currency',
                            hintText: 'Select currency',
                            isDark: isDark,
                            selectedItem: vm.currencyId?.toString(),
                            items: [
                              for (final opt in vm.currencyOptions)
                                opt['value']!,
                            ],
                            displayText: (val) =>
                                vm.currencyOptions.firstWhere(
                                  (opt) => opt['value'] == val,
                                  orElse: () => const {},
                                )['label'] ??
                                val,
                            onChanged: (val) => vm.setCurrency(
                              val == null ? null : int.tryParse(val),
                            ),
                          ),
                          const SizedBox(height: 20),

                          MoboFormField(
                            controller: _weightCtrl,
                            label: 'Weight',
                            hintText: '0.0',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            isDark: isDark,
                            validator: _validateNumber,
                            onChanged: (v) => vm.setWeight(_parseDouble(v)),
                          ),
                          const SizedBox(height: 20),

                          MoboFormField(
                            controller: _volumeCtrl,
                            label: 'Volume',
                            hintText: '0.0',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            isDark: isDark,
                            validator: _validateNumber,
                            onChanged: (v) => vm.setVolume(_parseDouble(v)),
                          ),
                          const SizedBox(height: 20),

                          MoboFormField(
                            controller: _descriptionCtrl,
                            label: 'Description',
                            hintText: 'Enter product description',
                            maxLines: 4,
                            isDark: isDark,
                            onChanged: vm.setDescription,
                          ),
                          const SizedBox(height: 24),

                          if (widget.isCreateMode && vm.canTrackInventory)
                            _buildCheckboxTile(
                              'Track Inventory',
                              vm.trackInventory,
                              vm.setTrackInventory,
                              isDark,
                            ),
                          _buildCheckboxTile(
                            'Active',
                            vm.isActive,
                            vm.setIsActive,
                            isDark,
                          ),
                          _buildCheckboxTile(
                            'Can be Sold',
                            vm.saleOk,
                            vm.setSaleOk,
                            isDark,
                          ),
                          _buildCheckboxTile(
                            'Can be Purchased',
                            vm.purchaseOk,
                            vm.setPurchaseOk,
                            isDark,
                          ),

                          const SizedBox(height: 32),

                          if (canSubmit)
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: vm.canSave
                                    ? () => _saveProduct(vm)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: isDark
                                      ? Colors.grey[700]
                                      : Colors.grey[300],
                                  disabledForegroundColor: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[500],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: vm.saving
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        widget.isCreateMode
                                            ? 'Create Product'
                                            : 'Save Changes',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageSection(InventoryProductEditViewModel vm, bool isDark) {
    final bytes = vm.imageBytes;
    final placeholder = Icon(
      Icons.image,
      size: 48,
      color: isDark ? Colors.grey[600] : Colors.grey[400],
    );

    return Center(
      child: GestureDetector(
        onTap: () {
          if (bytes != null) {
            context.pushNamed(
              AppRoutes.fullImage,
              extra: {'imageBytes': bytes, 'title': vm.name},
            );
          } else {
            _showImageOptions(vm);
          }
        },
        child: Stack(
          children: [
            Container(
              key: const ValueKey('productImage'),
              width: 140,
              height: 140,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: bytes != null
                  ? Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => Center(child: placeholder),
                    )
                  : Center(child: placeholder),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _showImageOptions(vm),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown instead of the form when the product could not be read, so a
  /// failed load never looks like an empty "new product" form.
  Widget _buildLoadError(InventoryProductEditViewModel vm) {
    return ListView(
      children: [
        const SizedBox(height: 48),
        EmptyState(
          title: 'Couldn\'t load this product',
          subtitle: vm.error ?? 'Something went wrong while loading it.',
          lottieAsset: 'assets/lotties/Error 404.json',
          actionLabel: 'Retry',
          onAction: _loadRecord,
        ),
      ],
    );
  }

  Widget _buildCheckboxTile(
    String label,
    bool value,
    Function(bool) onChanged,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: isDark ? Colors.grey : primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 24),

          ...List.generate(12, (index) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          }),

          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }

  String? _validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Invalid number';
    if (parsed < 0) return 'Must be positive';
    return null;
  }

  String? _validateNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Invalid number';
    if (parsed < 0) return 'Must be non-negative';
    return null;
  }
}
