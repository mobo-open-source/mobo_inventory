import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobo_inv_app/core/routing/app_routes.dart';
import 'package:mobo_inv_app/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/dialogs/confirm_discard_dialog.dart';
import '../../../shared/widgets/forms/custom_dropdown_field.dart';
import '../../../shared/widgets/forms/custom_text_field.dart';
import '../viewmodels/inventory_product_edit_view_model.dart';
import '../../../core/services/haptics_service.dart';

/// Screen for editing an existing product's details and uploading product images.
class InventoryProductEditScreen extends StatefulWidget {
  final int productId;

  const InventoryProductEditScreen({super.key, required this.productId});

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
  final _leadTimeCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  bool _controllersInitialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _salePriceCtrl.dispose();
    _costPriceCtrl.dispose();
    _weightCtrl.dispose();
    _volumeCtrl.dispose();
    _leadTimeCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _initializeControllers(InventoryProductEditViewModel vm) {
    if (!_controllersInitialized && !vm.loading && vm.name.isNotEmpty) {
      _nameCtrl.text = vm.name;
      _skuCtrl.text = vm.sku;
      _barcodeCtrl.text = vm.barcode;
      _descriptionCtrl.text = vm.description;
      _salePriceCtrl.text = vm.listPrice?.toStringAsFixed(2) ?? '';
      _costPriceCtrl.text = vm.standardPrice?.toStringAsFixed(2) ?? '';
      _weightCtrl.text = vm.weight?.toString() ?? '';
      _volumeCtrl.text = vm.volume?.toString() ?? '';
      _leadTimeCtrl.text = vm.leadTime?.toStringAsFixed(0) ?? '';
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

    vm.name = _nameCtrl.text.trim();
    vm.sku = _skuCtrl.text.trim();
    vm.barcode = _barcodeCtrl.text.trim();
    vm.description = _descriptionCtrl.text.trim();
    vm.listPrice = _parseDouble(_salePriceCtrl.text);
    vm.standardPrice = _parseDouble(_costPriceCtrl.text);
    vm.weight = _parseDouble(_weightCtrl.text);
    vm.volume = _parseDouble(_volumeCtrl.text);
    vm.leadTime = _parseDouble(_leadTimeCtrl.text);

    final success = await vm.save(widget.productId);

    if (!mounted) return;

    if (success) {
      HapticsService.success();
      context.pop(true);
    } else {
      CustomSnackbar.showError(context, vm.error ?? 'Failed to save product');
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
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
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
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Remove Image',
                    style: TextStyle(color: Colors.red),
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

  Future<void> _scanBarcode() async {
    final result = await context.pushNamed<String>(AppRoutes.barcodeScanner);
    if (result != null && result.isNotEmpty) {
      _barcodeCtrl.text = result;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider(
      create: (_) => InventoryProductEditViewModel()..load(widget.productId),
      child: Consumer<InventoryProductEditViewModel>(
        builder: (context, vm, _) {
          _initializeControllers(vm);

          final hasUnsavedChanges = vm.hasUnsavedChanges;

          return PopScope(
            canPop: false,
            onPopInvoked: (didPop) async {
              if (didPop) return;

              final discard = await ConfirmDiscardDialog.show(context);
              if (discard == true && context.mounted) {
                context.pop();
              }
            },
            child: Scaffold(
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              appBar: AppBar(
                leading: IconButton(
                  icon: Icon(
                    HugeIcons.strokeRoundedArrowLeft01,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onPressed: () => context.pop(),
                ),
                title: Text(
                  'Edit Product',
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
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    onPressed: vm.loading
                        ? null
                        : () {
                            _controllersInitialized = false;
                            vm.load(widget.productId);
                          },
                  ),
                ],
              ),
              body: vm.loading
                  ? _buildShimmerLoading(isDark)
                  : Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _buildImageSection(vm, isDark),
                          const SizedBox(height: 24),

                          CustomTextField(
                            labelText: 'Product Name *',
                            controller: _nameCtrl,
                            hintText: 'Enter product name',
                            validator: (v) => (v?.trim().isEmpty ?? true)
                                ? 'Product name is required'
                                : null,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),

                          CustomTextField(
                            controller: _skuCtrl,
                            labelText: 'SKU/Default Code',
                            hintText: 'Enter SKU',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),

                          CustomTextField(
                            labelText: 'Barcode',
                            controller: _barcodeCtrl,
                            hintText: 'Enter barcode or scan using camera',
                            isDark: isDark,
                            suffixIcon: IconButton(
                              icon: Icon(
                                HugeIcons.strokeRoundedScanImage,
                                size: 24,
                              ),
                              onPressed: _scanBarcode,
                            ),
                          ),
                          const SizedBox(height: 20),

                          CustomDropdownField(
                            value: vm.categId?.toString(),
                            labelText: 'Category',
                            hintText: 'Select category',
                            isDark: isDark,
                            items: vm.categoryOptions
                                .map(
                                  (opt) => DropdownMenuItem<String>(
                                    value: opt['value']!,
                                    child: Text(opt['label']!),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) => vm.setCategory(
                              val == null ? null : int.tryParse(val),
                            ),
                          ),
                          const SizedBox(height: 20),

                          CustomTextField(
                            controller: _salePriceCtrl,
                            labelText: 'List Price',
                            hintText: '0.00',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            isDark: isDark,
                            validator: _validatePrice,
                          ),
                          const SizedBox(height: 20),

                          CustomTextField(
                            controller: _costPriceCtrl,
                            labelText: 'Cost Price',
                            hintText: '0.00',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            isDark: isDark,
                            validator: _validatePrice,
                          ),
                          const SizedBox(height: 20),

                          CustomDropdownField(
                            value: (vm.taxes.isNotEmpty ? vm.taxes.first : null)
                                ?.toString(),
                            labelText: 'Tax',
                            hintText: 'Select tax',
                            isDark: isDark,
                            items: vm.taxOptions
                                .map(
                                  (opt) => DropdownMenuItem<String>(
                                    value: opt['value']!,
                                    child: Text(opt['label']!),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) => vm.setTaxes(
                              val == null ? [] : [int.parse(val)],
                            ),
                          ),
                          const SizedBox(height: 20),

                          CustomDropdownField(
                            value: vm.uomId?.toString(),
                            labelText: 'Unit of Measure',
                            hintText: 'Select unit',
                            isDark: isDark,
                            items: vm.uomOptions
                                .map(
                                  (opt) => DropdownMenuItem<String>(
                                    value: opt['value']!,
                                    child: Text(opt['label']!),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) => vm.setUom(
                              val == null ? null : int.tryParse(val),
                            ),
                          ),
                          const SizedBox(height: 20),

                          CustomDropdownField(
                            value: vm.currencyId?.toString(),
                            labelText: 'Currency',
                            hintText: 'Select currency',
                            isDark: isDark,
                            items: vm.currencyOptions
                                .map(
                                  (opt) => DropdownMenuItem<String>(
                                    value: opt['value']!,
                                    child: Text(opt['label']!),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) => vm.setCurrency(
                              val == null ? null : int.tryParse(val),
                            ),
                          ),
                          const SizedBox(height: 20),

                          CustomTextField(
                            controller: _weightCtrl,
                            labelText: 'Weight',
                            hintText: '0.0',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            isDark: isDark,
                            validator: _validateNumber,
                          ),
                          const SizedBox(height: 20),

                          CustomTextField(
                            controller: _volumeCtrl,
                            labelText: 'Volume',
                            hintText: '0.0',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            isDark: isDark,
                            validator: _validateNumber,
                          ),
                          const SizedBox(height: 20),

                          CustomTextField(
                            controller: _descriptionCtrl,
                            labelText: 'Description',
                            hintText: 'Enter product description',
                            maxLines: 4,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 24),

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

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: vm.saving
                                  ? null
                                  : () => _saveProduct(vm),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
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
                                  : const Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
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
    return Center(
      child: GestureDetector(
        onTap: () {
          if (vm.imageBase64 != null) {
            context.pushNamed(
              AppRoutes.fullImage,
              extra: {
                'imageBytes': base64Decode(vm.imageBase64!),
                'title': vm.name,
              },
            );
          } else {
            _showImageOptions(vm);
          }
        },
        child: Stack(
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : const Color(0xFFF5E6F0),
                shape: BoxShape.circle,
                image: vm.imageBase64 != null
                    ? DecorationImage(
                        image: MemoryImage(base64Decode(vm.imageBase64!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: vm.imageBase64 == null
                  ? Icon(
                      Icons.image,
                      size: 48,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _showImageOptions(vm),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD81B60),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          }),

          Container(
            width: double.infinity,
            height: 54,
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
