import 'dart:convert';
import 'dart:io';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../../shared/widgets/forms/custom_text_field.dart';
import '../../../shared/widgets/forms/custom_dropdown_field.dart';
import '../../../shared/widgets/dialogs/data_loss_warning_dialog.dart';
import '../../../shared/widgets/mobo/mobo_button.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/haptics_service.dart';
import '../../../shared/widgets/odoo_avatar.dart';
import '../../../shared/widgets/search/mobo_search_bar.dart';
import '../../../core/theme/app_theme.dart';

/// A screen that displays and allows editing of detailed user profile information.
///
/// This screen provides a form-based interface for users to view and update
/// their personal details, contact information, and address, synchronized with Odoo.
class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({super.key});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  bool _isEditMode = false;
  bool _isSaving = false;
  bool _isShowingLoadingDialog = false;
  bool _saveSuccess = false;
  File? _pickedImageFile;
  String? _pickedImageBase64;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _functionController = TextEditingController();

  int? _relatedCompanyId;
  String? _relatedCompanyName;

  double _rs(BuildContext context, double size) {
    final w = MediaQuery.of(context).size.width;
    final scale = (w / 390.0).clamp(0.85, 1.2);
    return size * scale;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateControllers();
      _loadRelatedCompany();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Never while editing: this also fires when MediaQuery changes — the
    // keyboard opening is enough — and re-seeding then threw away whatever
    // the user had typed into the field they just tapped.
    if (mounted && !_isEditMode) {
      _updateControllers();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _mobileController.dispose();
    _websiteController.dispose();
    _functionController.dispose();
    super.dispose();
  }

  String _normalizeForEdit(dynamic value) {
    if (value == null) return '';
    if (value is bool) return value ? 'true' : '';
    final s = value.toString().trim();
    if (s.isEmpty) return '';
    if (s.toLowerCase() == 'false') return '';
    return s;
  }

  void _updateControllers() {
    final provider = context.read<ProfileProvider>();
    final userData = provider.userData;
    if (userData != null) {
      _nameController.text = _normalizeForEdit(userData['name']);
      _emailController.text = _normalizeForEdit(userData['email']);
      _phoneController.text = _normalizeForEdit(userData['phone']);
      _mobileController.text = _normalizeForEdit(userData['mobile']);
      _websiteController.text = _normalizeForEdit(userData['website']);
      _functionController.text = _normalizeForEdit(userData['function']);
    }
  }

  Future<void> _loadRelatedCompany() async {
    final provider = context.read<ProfileProvider>();
    final company = await provider.loadRelatedCompany();
    if (mounted && company != null) {
      setState(() {
        _relatedCompanyId = company['id'] as int?;
        _relatedCompanyName = company['name'] as String?;
      });
    }
  }

  void _cancelEdit() {
    _updateControllers();
    setState(() => _isEditMode = false);
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 600,
      );
      if (picked == null || !mounted) return;

      setState(() => _pickedImageFile = File(picked.path));
      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() => _pickedImageBase64 = base64Encode(bytes));

      await _saveImage();
      if (mounted) {
        if (HapticsService.isSupported) {
          await HapticsService.success();
        }
        CustomSnackbar.showSuccess(context, 'Image updated successfully');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, 'Failed to update image: $e');
      }
    }
  }

  void _showImageSourceActionSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.grey[50],
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.pop(context);
              _pickImageFromSource(ImageSource.camera);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCamera02,
                    size: 24,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 16),
                  const Text('Take Photo', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
          InkWell(
            onTap: () {
              Navigator.pop(context);
              _pickImageFromSource(ImageSource.gallery);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedImageCrop,
                    size: 24,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Choose from Gallery',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _saveImage() async {
    if (_pickedImageBase64 == null || !mounted) return;

    final navigator = Navigator.of(context);
    _showLoadingDialog(context, 'Saving Image');
    try {
      final provider = context.read<ProfileProvider>();
      await provider.updateProfileImage(_pickedImageBase64!);
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, 'Failed to update image: $e');
      }
    } finally {
      if (!mounted) return;
      if (_isShowingLoadingDialog) {
        _isShowingLoadingDialog = false;
        if (navigator.canPop()) navigator.pop();
      }
    }
  }

  Future<void> _saveAllChanges() async {
    if (!_formKey.currentState!.validate()) {
      CustomSnackbar.showError(
        context,
        'Please fix the validation errors before saving',
      );
      return;
    }

    setState(() => _isSaving = true);
    _showLoadingDialog(context, 'Saving Changes');

    bool isSuccess = false;

    try {
      final provider = context.read<ProfileProvider>();
      final userData = provider.userData!;

      // Which model each field belongs to is the provider's call, not the
      // screen's: it depends on the connected release and, for mobile, on
      // this server's schema. See ProfileProvider.saveProfileEdits.
      final changes = <String, dynamic>{};
      _editableFields().forEach((field, controller) {
        final value = controller.text.trim();
        if (value != _normalizeForEdit(userData[field])) {
          changes[field] = value;
        }
      });

      await provider.saveProfileEdits(changes);

      isSuccess = true;
      _saveSuccess = true;
      setState(() => _isEditMode = false);
    } catch (e) {
      isSuccess = false;
    } finally {
      if (!mounted) return;

      if (_isShowingLoadingDialog) {
        _isShowingLoadingDialog = false;
        Navigator.pop(context);
      }

      if (isSuccess) {
        if (HapticsService.isSupported) {
          await HapticsService.success();
        }
        CustomSnackbar.showSuccess(context, 'Profile updated successfully');
      } else {
        if (HapticsService.isSupported) {
          await HapticsService.error();
        }
        CustomSnackbar.showError(context, 'Failed to save changes');
      }

      setState(() => _isSaving = false);
    }
  }

  Future<void> _handleBack() async {
    if (_isEditMode && _hasUnsavedChanges()) {
      final shouldPop = await _showUnsavedChangesDialog();
      if (shouldPop && mounted) {
        context.pop(_saveSuccess);
      }
      return;
    }
    if (mounted) {
      context.pop(_saveSuccess);
    }
  }

  /// The text-editable rows currently on screen, keyed by Odoo field name.
  ///
  /// Filtered by availability, so a field this server does not define is
  /// neither diffed for unsaved changes nor sent on save — its controller
  /// still holds seeded text, but no row is showing it.
  Map<String, TextEditingController> _editableFields() {
    final provider = context.read<ProfileProvider>();
    return <String, TextEditingController>{
      'name': _nameController,
      'email': _emailController,
      'phone': _phoneController,
      'mobile': _mobileController,
      'website': _websiteController,
      'function': _functionController,
    }..removeWhere((field, _) => !provider.isProfileFieldAvailable(field));
  }

  bool _hasUnsavedChanges() {
    final provider = context.read<ProfileProvider>();
    final userData = provider.userData;
    if (userData == null) return false;

    return _editableFields().entries.any(
      (entry) =>
          entry.value.text.trim() != _normalizeForEdit(userData[entry.key]),
    );
  }

  Future<bool> _showUnsavedChangesDialog() async {
    final result = await DataLossWarningDialog.show(
      context: context,
      title: 'Discard Changes?',
      message:
          'You have unsaved changes that will be lost if you leave this page. Are you sure you want to discard these changes?',
      confirmText: 'Discard',
      cancelText: 'Keep Editing',
    );
    return result ?? false;
  }

  void _showLoadingDialog(BuildContext context, String message) {
    if (_isShowingLoadingDialog || !mounted) return;
    _isShowingLoadingDialog = true;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: LoadingAnimationWidget.fourRotatingDots(
                  color: isDark ? Colors.white : Theme.of(context).primaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait while we process your request',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Disposes the Edit Address dialog's own controllers once it is actually
  /// gone rather than the moment its `pop()` is requested.
  ///
  /// [Navigator.pop] only starts the dialog route's exit transition; the
  /// `CustomTextField`s bound to these controllers stay mounted and
  /// rebuilding for its duration. Disposing them immediately after `pop()`
  /// used to crash with "A TextEditingController was used after being
  /// disposed" mid fade-out — a full route-transition duration is the
  /// shortest safe margin, since there is no callback for "the popped route
  /// finished leaving".
  void _disposeAddressControllers(List<TextEditingController> controllers) {
    Future.delayed(const Duration(milliseconds: 400), () {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
  }

  void _showEditAddressDialog() {
    final provider = context.read<ProfileProvider>();
    final userData = provider.userData;
    if (userData == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    final streetController = TextEditingController(
      text: _normalizeForEdit(userData['street']),
    );
    final street2Controller = TextEditingController(
      text: _normalizeForEdit(userData['street2']),
    );
    final cityController = TextEditingController(
      text: _normalizeForEdit(userData['city']),
    );
    final zipController = TextEditingController(
      text: _normalizeForEdit(userData['zip']),
    );

    int? selectedCountryId =
        userData['country_id'] is List &&
            userData['country_id'].isNotEmpty &&
            userData['country_id'][0] != null
        ? userData['country_id'][0] as int
        : null;
    int? selectedStateId =
        userData['state_id'] is List &&
            userData['state_id'].isNotEmpty &&
            userData['state_id'][0] != null
        ? userData['state_id'][0] as int
        : null;

    final rootContext = context;

    // Kicked off before the dialog opens rather than from inside its builder:
    // loadStates notifies its listeners synchronously, and doing that mid-build
    // throws "setState() called during build" and leaves the dropdown stuck on
    // "Loading..." because the failed notification never reaches it.
    if (selectedCountryId != null &&
        provider.states.isEmpty &&
        !provider.isLoadingStates) {
      provider.loadStates(selectedCountryId);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      // Consumer, not the captured read: the dialog is its own route, so
      // without this it never rebuilds and the country/state lists stay on
      // whatever they held the moment it opened.
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Consumer<ProfileProvider>(
          builder: (context, provider, _) {
            return AlertDialog(
            backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Edit Address',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Each input is offered only where the server defines the
                    // field behind it, matching the rows on the screen itself.
                    if (provider.isProfileFieldAvailable('street')) ...[
                      CustomTextField(
                        controller: streetController,
                        labelText: 'Street Address',
                        hintText: 'Enter street address',
                        isDark: isDark,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'This field is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (provider.isProfileFieldAvailable('street2')) ...[
                      CustomTextField(
                        controller: street2Controller,
                        labelText: 'Street Address 2',
                        hintText: 'Apartment, suite, etc. (optional)',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (provider.isProfileFieldAvailable('city')) ...[
                      CustomTextField(
                        controller: cityController,
                        labelText: 'City',
                        hintText: 'Enter city',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (provider.isProfileFieldAvailable('zip')) ...[
                      CustomTextField(
                        controller: zipController,
                        labelText: 'ZIP Code',
                        hintText: 'Enter ZIP code',
                        isDark: isDark,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (provider.isProfileFieldAvailable('country_id')) ...[
                      _buildCountryDropdown(
                        selectedCountryId: selectedCountryId,
                        countries: provider.countries,
                        isLoading: provider.isLoadingCountries,
                        isDark: isDark,
                        theme: theme,
                        onChanged: (countryId) {
                          setDialogState(() {
                            selectedCountryId = countryId;
                            selectedStateId = null;
                          });
                          if (countryId != null) {
                            provider.loadStates(countryId);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (provider.isProfileFieldAvailable('state_id'))
                      _buildStateDropdown(
                        selectedStateId: selectedStateId,
                        states: provider.states,
                        isLoading: provider.isLoadingStates,
                        isDark: isDark,
                        theme: theme,
                        enabled: selectedCountryId != null,
                        onChanged: (stateId) {
                          setDialogState(() => selectedStateId = stateId);
                        },
                      ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            actions: [
              MoboButtonRow(
                secondaryLabel: 'Cancel',
                onSecondary: () {
                  Navigator.pop(context);
                  // pop() only starts the dialog's exit transition — these
                  // fields stay mounted and animating for it, so disposing
                  // their controllers here crashes them mid-fade. Deferred
                  // past that, same as the Save handler below.
                  _disposeAddressControllers([
                    streetController,
                    street2Controller,
                    cityController,
                    zipController,
                  ]);
                },
                primaryLabel: 'Save',
                onPrimary: () async {
                  final hasStreet = provider.isProfileFieldAvailable('street');
                  if (hasStreet && streetController.text.trim().isEmpty) {
                    CustomSnackbar.showError(
                      context,
                      'Street address is required',
                    );
                    return;
                  }
                  // The whole address is written as one payload, so a field
                  // the server does not define has to be left out rather than
                  // sent as false — Odoo rejects the entire write for one
                  // unrecognized name.
                  final addressData = <String, dynamic>{
                    if (hasStreet) 'street': streetController.text.trim(),
                    if (provider.isProfileFieldAvailable('street2'))
                      'street2': street2Controller.text.trim().isEmpty
                          ? false
                          : street2Controller.text.trim(),
                    if (provider.isProfileFieldAvailable('city'))
                      'city': cityController.text.trim().isEmpty
                          ? false
                          : cityController.text.trim(),
                    if (provider.isProfileFieldAvailable('zip'))
                      'zip': zipController.text.trim().isEmpty
                          ? false
                          : zipController.text.trim(),
                    if (provider.isProfileFieldAvailable('country_id'))
                      'country_id': selectedCountryId ?? false,
                    if (provider.isProfileFieldAvailable('state_id'))
                      'state_id': selectedStateId ?? false,
                  };

                  final navigator = Navigator.of(rootContext);
                  navigator.pop();

                  // Same reason as Cancel: the dialog (and the CustomTextFields
                  // reading these controllers) is still animating out, not
                  // gone yet, so disposal has to wait for that to finish.
                  _disposeAddressControllers([
                    streetController,
                    street2Controller,
                    cityController,
                    zipController,
                  ]);

                  _showLoadingDialog(rootContext, 'Updating Address');
                  try {
                    await provider.updateAddressFields(addressData);
                    if (mounted) {
                      _isShowingLoadingDialog = false;
                      navigator.pop();
                      CustomSnackbar.showSuccess(
                        rootContext,
                        'Address updated successfully',
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      _isShowingLoadingDialog = false;
                      navigator.pop();
                      CustomSnackbar.showError(
                        rootContext,
                        'Failed to update address: $e',
                      );
                    }
                  }
                },
              ),
            ],
          );
          },
        ),
      ),
    );
  }

  Widget _buildCountryDropdown({
    required int? selectedCountryId,
    required List<Map<String, dynamic>> countries,
    required bool isLoading,
    required bool isDark,
    required ThemeData theme,
    required Function(int?) onChanged,
  }) {
    final validCountryIds = countries.map((c) => c['id']).toSet();
    final safeSelectedCountryId =
        selectedCountryId != null && validCountryIds.contains(selectedCountryId)
        ? selectedCountryId
        : null;

    final stringItems = isLoading
        ? [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Loading...'),
            ),
          ]
        : [
            const DropdownMenuItem<String>(
              value: null,
              child: Text(
                'Select Country',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            ...countries.map(
              (country) => DropdownMenuItem<String>(
                value: country['id'].toString(),
                child: Text(country['name']),
              ),
            ),
          ];

    return CustomDropdownField(
      value: safeSelectedCountryId?.toString(),
      labelText: 'Country',
      hintText: 'Select Country',
      isDark: isDark,
      items: stringItems,
      onChanged: isLoading
          ? null
          : (value) => onChanged(value != null ? int.tryParse(value) : null),
      validator: (value) => value == null ? 'Please select a country' : null,
    );
  }

  Widget _buildStateDropdown({
    required int? selectedStateId,
    required List<Map<String, dynamic>> states,
    required bool isLoading,
    required bool isDark,
    required ThemeData theme,
    required bool enabled,
    required Function(int?) onChanged,
  }) {
    final validStateIds = states.map((s) => s['id']).toSet();
    final safeSelectedStateId =
        selectedStateId != null && validStateIds.contains(selectedStateId)
        ? selectedStateId
        : null;

    final stringItems = !enabled
        ? [
            const DropdownMenuItem<String>(
              value: null,
              child: Text(
                'Select country first',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ]
        : isLoading
        ? [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Loading...'),
            ),
          ]
        : [
            const DropdownMenuItem<String>(
              value: null,
              child: Text(
                'Select State/Province',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            ...states.map(
              (state) => DropdownMenuItem<String>(
                value: state['id'].toString(),
                child: Text(state['name']),
              ),
            ),
          ];

    return CustomDropdownField(
      value: safeSelectedStateId?.toString(),
      labelText: 'State/Province',
      hintText: enabled
          ? (isLoading ? 'Loading...' : 'Select State/Province')
          : 'Select country first',
      isDark: isDark,
      items: stringItems,
      onChanged: (!enabled || isLoading)
          ? null
          : (value) => onChanged(value != null ? int.tryParse(value) : null),
    );
  }

  Future<void> _showRelatedCompanyPicker() async {
    final provider = context.read<ProfileProvider>();
    final userData = provider.userData;
    if (userData == null) return;

    final partnerId = userData['partner_id'];
    if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
      CustomSnackbar.showError(
        context,
        'Partner record not found for this user',
      );
      return;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final TextEditingController searchCtrl = TextEditingController();
    List<Map<String, dynamic>> companies = [];
    bool loading = true;

    Future<void> loadCompanies([String q = '']) async {
      try {
        final domain = [
          ['is_company', '=', true],
        ];
        if (q.trim().isNotEmpty) {
          domain.add(['name', 'ilike', q.trim()]);
        }
        final res = await OdooSessionManager.callKwWithCompany({
          'model': 'res.partner',
          'method': 'search_read',
          'args': [domain],
          'kwargs': {
            'fields': ['id', 'name'],
            'limit': 20,
            'order': 'name asc',
          },
        });
        companies = (res as List).cast<Map<String, dynamic>>();
      } catch (e) {
        companies = [];
      } finally {
        loading = false;
      }
    }

    await loadCompanies();
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Select Related Company',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MoboSearchBar(
                      controller: searchCtrl,
                      hintText: 'Search companies...',
                      onChanged: (val) async {
                        setDlg(() => loading = true);
                        await loadCompanies(val);
                        if (ctx.mounted) setDlg(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 320,
                      width: double.infinity,
                      child: loading
                          ? Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.primaryColor,
                                ),
                              ),
                            )
                          : companies.isEmpty
                          ? Center(
                              child: Text(
                                'No companies found',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: companies.length,
                              separatorBuilder: (_, __) => Divider(
                                height: .01,
                                thickness: .01,
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                              ),
                              itemBuilder: (ctx, i) {
                                final c = companies[i];
                                final selected = c['id'] == _relatedCompanyId;
                                return ListTile(
                                  dense: true,
                                  title: Text(c['name'] ?? ''),
                                  trailing: selected
                                      ? Icon(
                                          Icons.check,
                                          color: theme.primaryColor,
                                          size: 18,
                                        )
                                      : null,
                                  onTap: () async {
                                    Navigator.of(ctx).pop(c);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    ).then((selected) async {
      if (selected is Map<String, dynamic>) {
        try {
          _showLoadingDialog(context, 'Updating Related Company');
          await provider.updateRelatedCompany(selected['id'] as int?);
          if (!mounted) return;
          _isShowingLoadingDialog = false;
          Navigator.pop(context);
          setState(() {
            _relatedCompanyId = selected['id'] as int?;
            _relatedCompanyName = selected['name']?.toString();
          });
          CustomSnackbar.showSuccess(context, 'Related Company updated');
        } catch (e) {
          if (mounted) {
            _isShowingLoadingDialog = false;
            Navigator.pop(context);
            CustomSnackbar.showError(
              context,
              'Failed to update related company: $e',
            );
          }
        }
      }
    });
  }

  /// The profile rows this server can actually store, in display order.
  ///
  /// A field the connected Odoo does not define is left out entirely rather
  /// than shown as an empty row: the row would offer an edit whose value the
  /// write path has nowhere to put, so it would be dropped without an error.
  /// Availability is unknown until the first fetch resolves it, and unknown
  /// counts as present — see [ProfileProvider.isProfileFieldAvailable].
  List<Widget> _buildProfileRows(
    BuildContext context,
    ProfileProvider provider,
    Map<String, dynamic> userData,
    bool isEditingDisabled,
  ) {
    final rows = <Widget>[];

    // The gap belongs before each row, so a hidden row takes its spacing with
    // it instead of leaving a double gap behind.
    void add(String field, Widget Function() row, {double gap = 16}) {
      if (!provider.isProfileFieldAvailable(field)) return;
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      rows.add(row());
    }

    add(
      'name',
      () => _buildCustomTextField(
        context,
        'Full Name',
        userData['name']?.toString(),
        HugeIcons.strokeRoundedUserAccount,
        disabled: isEditingDisabled,
        controller: _nameController,
      ),
    );
    add(
      'email',
      () => _buildCustomTextField(
        context,
        'Email',
        userData['email']?.toString(),
        HugeIcons.strokeRoundedMail01,
        disabled: isEditingDisabled,
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
      ),
    );
    add(
      'phone',
      () => _buildCustomTextField(
        context,
        'Phone',
        userData['phone']?.toString(),
        HugeIcons.strokeRoundedCall02,
        disabled: isEditingDisabled,
        controller: _phoneController,
        keyboardType: TextInputType.phone,
      ),
    );
    add(
      'mobile',
      () => _buildCustomTextField(
        context,
        'Mobile',
        userData['mobile']?.toString(),
        HugeIcons.strokeRoundedSmartPhone01,
        disabled: isEditingDisabled,
        controller: _mobileController,
        keyboardType: TextInputType.phone,
      ),
    );
    add(
      'website',
      () => _buildCustomTextField(
        context,
        'Website',
        userData['website']?.toString(),
        HugeIcons.strokeRoundedWebDesign02,
        disabled: isEditingDisabled,
        controller: _websiteController,
        keyboardType: TextInputType.url,
      ),
    );
    add(
      'function',
      () => _buildCustomTextField(
        context,
        'Job Title',
        userData['function']?.toString(),
        HugeIcons.strokeRoundedWorkHistory,
        disabled: isEditingDisabled,
        controller: _functionController,
      ),
    );
    add(
      'company_id',
      () => _buildCustomTextField(
        context,
        'Company',
        userData['company_id'] is List && userData['company_id'].length > 1
            ? (userData['company_id'][1]?.toString() ?? '')
            : '',
        HugeIcons.strokeRoundedBuilding05,
        disabled: isEditingDisabled,
        showNonEditableMessage: true,
      ),
    );
    add(
      'parent_id',
      () => _buildCustomTextField(
        context,
        'Related Company',
        (_relatedCompanyName ?? ''),
        HugeIcons.strokeRoundedBuilding01,
        disabled: isEditingDisabled,
        onEdit: _isEditMode && !isEditingDisabled
            ? _showRelatedCompanyPicker
            : null,
      ),
    );

    // The Address row stands for six separate partner fields, so it earns its
    // place as long as the server still defines at least one of them.
    if (_availableAddressFields(provider).isNotEmpty) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 20));
      rows.add(
        _buildCustomTextField(
          context,
          'Address',
          provider.formatAddress(userData),
          HugeIcons.strokeRoundedLocation05,
          onEdit: _isEditMode && !isEditingDisabled
              ? _showEditAddressDialog
              : null,
          disabled: isEditingDisabled,
        ),
      );
    }

    return rows;
  }

  static const List<String> _addressFields = [
    'street',
    'street2',
    'city',
    'zip',
    'state_id',
    'country_id',
  ];

  List<String> _availableAddressFields(ProfileProvider provider) =>
      _addressFields.where(provider.isProfileFieldAvailable).toList();

  Widget _buildCustomTextField(
    BuildContext context,
    String labelText,
    String? value,
    IconData icon, {
    VoidCallback? onEdit,
    bool disabled = false,
    TextEditingController? controller,
    TextInputType? keyboardType,
    bool showNonEditableMessage = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue =
        (value == null ||
            value.trim().isEmpty ||
            value.trim().toLowerCase() == 'false')
        ? 'Not set'
        : value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
          ),
        ),
        const SizedBox(height: 8),
        _isEditMode && controller != null && !disabled
            ? _buildEditableField(
                context,
                controller,
                keyboardType,
                labelText,
                isDark,
              )
            : _buildDisplayField(
                context,
                displayValue,
                icon,
                isDark,
                onEdit: onEdit,
                labelText: labelText,
                showNonEditableMessage: showNonEditableMessage,
              ),
      ],
    );
  }

  Widget _buildDisplayField(
    BuildContext context,
    String displayValue,
    IconData icon,
    bool isDark, {
    VoidCallback? onEdit,
    String? labelText,
    bool showNonEditableMessage = false,
  }) {
    return GestureDetector(
      onTap:
          onEdit ??
          (showNonEditableMessage && labelText != null
              ? () {
                  if (mounted) {
                    CustomSnackbar.showInfo(
                      context,
                      '$labelText cannot be modified from this screen',
                    );
                  }
                }
              : null),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xffF8FAFB),
          border: Border.all(color: Colors.transparent, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              HugeIcon(
                icon: icon,
                color: isDark ? Colors.white70 : Colors.black45,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayValue,
                  style: TextStyle(
                    color: displayValue == 'Not set'
                        ? Colors.grey[500]
                        : (isDark ? Colors.white70 : const Color(0xff000000)),
                    fontStyle: displayValue == 'Not set'
                        ? FontStyle.italic
                        : FontStyle.normal,
                    fontSize: 14,
                    height: 1.2,
                    letterSpacing: 0.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField(
    BuildContext context,
    TextEditingController controller,
    TextInputType? keyboardType,
    String labelText,
    bool isDark,
  ) {
    return Focus(
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasFocus = Focus.of(context).hasFocus;
          final hasError =
              _getValidatorForField(labelText)?.call(value.text) != null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xffF8FAFB),
                  border: Border.all(
                    color: hasError
                        ? StatusColors.red
                        : hasFocus
                        ? Theme.of(context).primaryColor
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: _getIconForField(labelText),
                        color: hasFocus
                            ? Theme.of(context).primaryColor
                            : (isDark
                                  ? Colors.white70
                                  : const Color(0xff7F7F7F)),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          keyboardType: keyboardType,
                          validator: _getValidatorForField(labelText),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white70
                                : const Color(0xff000000),
                            fontSize: 14,
                            height: 1.2,
                            letterSpacing: 0.0,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            hintText: controller.text.isEmpty
                                ? 'Enter $labelText'
                                : null,
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                              height: 1.2,
                              letterSpacing: 0.0,
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            errorStyle: const TextStyle(height: 0, fontSize: 0),
                          ),
                          cursorColor: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_getValidatorForField(labelText) != null)
                _buildErrorMessage(controller, labelText, isDark),
            ],
          );
        },
      ),
    );
  }

  IconData _getIconForField(String labelText) {
    switch (labelText.toLowerCase()) {
      case 'full name':
        return HugeIcons.strokeRoundedUserAccount;
      case 'email':
        return HugeIcons.strokeRoundedMail01;
      case 'phone':
        return HugeIcons.strokeRoundedCall02;
      case 'mobile':
        return HugeIcons.strokeRoundedSmartPhone01;
      case 'website':
        return HugeIcons.strokeRoundedWebDesign02;
      case 'job title':
        return HugeIcons.strokeRoundedWorkHistory;
      default:
        return HugeIcons.strokeRoundedUserAccount;
    }
  }

  String? Function(String?)? _getValidatorForField(String labelText) {
    switch (labelText.toLowerCase()) {
      case 'email':
        return (value) {
          if (value == null || value.trim().isEmpty) return null;
          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
          if (!emailRegex.hasMatch(value.trim())) {
            return 'Please enter a valid email address';
          }
          return null;
        };
      case 'website':
        return (value) {
          if (value == null || value.trim().isEmpty) return null;
          final urlRegex = RegExp(
            r'^(https?:\/\/)?(www\.)?[a-zA-Z0-9-]+(\.[a-zA-Z]{2,})+(\/.*)?$',
          );
          if (!urlRegex.hasMatch(value.trim())) {
            return 'Please enter a valid website URL';
          }
          return null;
        };
      default:
        return null;
    }
  }

  Widget _buildErrorMessage(
    TextEditingController controller,
    String labelText,
    bool isDark,
  ) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final validator = _getValidatorForField(labelText);
        final errorMessage = validator?.call(value.text);
        if (errorMessage == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(
            errorMessage,
            style: TextStyle(
              color: StatusColors.red,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileImageSection(
    BuildContext context,
    bool isDark,
    bool isEditingDisabled,
    String? userAvatarBase64,
  ) {
    Widget photoWidget;
    if (_pickedImageFile != null) {
      photoWidget = ClipOval(
        child: Image.file(
          _pickedImageFile!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    } else {
      photoWidget = OdooAvatar(
        imageBase64: userAvatarBase64,
        size: 120,
        iconSize: 60,
        borderRadius: BorderRadius.circular(60),
        placeholderColor: isDark ? Colors.grey[700] : Colors.grey[300],
        iconColor: isDark ? Colors.grey[500] : Colors.grey[600],
      );
    }

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap:
                null, // Full image view temporarily disabled to prevent crash
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: photoWidget,
                ),
                if (_isEditMode && !isEditingDisabled)
                  Positioned(
                    bottom: 2,
                    right: 8,
                    child: InkWell(
                      onTap: _showImageSourceActionSheet,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.grey[900]! : Colors.white,
                            width: 3,
                          ),
                        ),
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedCamera02,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Consumer<ProfileProvider>(
            builder: (context, provider, child) {
              final userData = provider.userData;
              if (userData != null &&
                  _normalizeForEdit(userData['name']).isNotEmpty) {
                return Text(
                  _normalizeForEdit(userData['name']),
                  style: TextStyle(
                    fontSize: _rs(context, 15),
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.grey[400] : Colors.grey[800],
                    letterSpacing: 0.1,
                  ),
                  textAlign: TextAlign.center,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool isEditingDisabled = false;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Profile Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          leading: IconButton(
            onPressed: () async {
              await _handleBack();
            },
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          actions: [
            if (_isEditMode)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton(
                  onPressed: _isSaving ? null : _cancelEdit,
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: isEditingDisabled || _isSaving
                    ? null
                    : () {
                        if (_isEditMode) {
                          _saveAllChanges();
                        } else {
                          // Seeded from the profile as it is *now*, not as
                          // it was when the screen opened: that was the
                          // cached copy, painted before the live fetch
                          // landed, and phone/mobile in particular resolve
                          // to different values once the server answers.
                          // Without this, Edit showed the stale numbers the
                          // rows had already moved on from.
                          _updateControllers();
                          setState(() {
                            _isEditMode = true;
                          });
                        }
                      },
                child: Text(
                  _isEditMode ? 'Save' : 'Edit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _isEditMode
                        ? (isDark ? Colors.white : Colors.black)
                        : Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
          ],
          backgroundColor: isDark ? Colors.grey[900]! : Colors.white,
          systemOverlayStyle: isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
        ),
        backgroundColor: isDark ? Colors.grey[900]! : Colors.white,
        body: Consumer<ProfileProvider>(
          builder: (context, provider, child) {
            if (provider.userData == null) {
              if (!provider.hasInternet) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          size: 40,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You are offline. Profile will appear when data is available.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: _rs(context, 13)),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () =>
                              provider.fetchUserProfile(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (provider.isLoading) {
                return ListShimmer.buildListShimmer(
                  context,
                  itemCount: 1,
                  type: ShimmerType.profile,
                );
              }
              return const Center(child: Text('No profile data available'));
            }

            final userData = provider.userData!;
            return RefreshIndicator(
              onRefresh: () => provider.fetchUserProfile(),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!provider.hasInternet)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2A2A2A)
                                : StatusColors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white12
                                  : StatusColors.orange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.wifi_off_rounded,
                                size: 18,
                                color: isDark
                                    ? Colors.white70
                                    : StatusColors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You are offline. Reconnect to save changes.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProfileImageSection(
                              context,
                              isDark,
                              isEditingDisabled,
                              provider.userAvatarBase64,
                            ),
                            const SizedBox(height: 32),
                            const Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ..._buildProfileRows(
                              context,
                              provider,
                              userData,
                              isEditingDisabled,
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
