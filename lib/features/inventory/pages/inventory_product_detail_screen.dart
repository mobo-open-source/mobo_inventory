import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_inv_app/core/theme/app_theme.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../shared/widgets/dialogs/common_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/inventory_product.dart';
import '../providers/inventory_product_provider.dart';
import '../../../main.dart';
import 'package:provider/provider.dart';
import '../../dashboard/providers/last_opened_provider.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/base64_utils.dart';
import '../utils/inventory_access.dart';

/// Screen displaying comprehensive details for a single inventory product, including pricing and stock metrics.
class InventoryProductDetailScreen extends StatefulWidget {
  final int productId;

  const InventoryProductDetailScreen({super.key, required this.productId});

  @override
  State<InventoryProductDetailScreen> createState() =>
      _InventoryProductDetailScreenState();
}

class _InventoryProductDetailScreenState
    extends State<InventoryProductDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  InventoryProduct? _product;
  bool _updated = false;

  double? _salePrice;

  String? _currencySymbol;
  double? _standardPrice;
  double? _weight;
  double? _volume;
  String? _dimensions;
  double? _leadTime;

  String? _createDate;

  List<String> _taxNames = [];
  String? _descriptionSale;
  bool _active = true;

  Uint8List? _imageBytes;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _load();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final fields = [];

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'product.product',
        'method': 'read',
        'args': [
          [widget.productId],
        ],
        'kwargs': {'fields': fields},
      });

      if (result is List && result.isNotEmpty) {
        final map = Map<String, dynamic>.from(result.first as Map);

        if (!map.containsKey('displayname') &&
            map.containsKey('display_name')) {
          map['displayname'] = map['display_name'];
        }

        final product = InventoryProduct.fromJson(map);

        double? toDouble(dynamic v) {
          if (v == null || v == false) return null;
          if (v is num) return v.toDouble();
          return double.tryParse(v.toString());
        }

        String? currencySym;
        if (map['currency_id'] is List &&
            (map['currency_id'] as List).isNotEmpty) {
          final currId = (map['currency_id'] as List)[0];
          try {
            final currRes = await OdooSessionManager.callKwWithCompany({
              'model': 'res.currency',
              'method': 'read',
              'args': [
                [currId],
              ],
              'kwargs': {
                'fields': ['symbol'],
              },
            });
            if (currRes is List && currRes.isNotEmpty) {
              currencySym = currRes.first['symbol'];
            }
          } catch (_) {}
        }

        List<String> taxes = [];
        if (map['taxes_id'] is List && (map['taxes_id'] as List).isNotEmpty) {
          try {
            final taxRes = await OdooSessionManager.callKwWithCompany({
              'model': 'account.tax',
              'method': 'read',
              'args': [map['taxes_id']],
              'kwargs': {
                'fields': ['name'],
              },
            });
            if (taxRes is List) {
              taxes = taxRes.map((e) => e['name'].toString()).toList();
            }
          } catch (_) {}
        }

        Uint8List? img;
        final imgStr = odooBinaryToBase64(map['image_1920']);
        if (imgStr.isNotEmpty && imgStr != 'false') {
          try {
            img = base64Decode(imgStr);
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            _product = product;
            _imageBytes = img;
            _salePrice = toDouble(map['list_price']);

            _currencySymbol = currencySym ?? '\$';
            _standardPrice = toDouble(map['standard_price']);
            _weight = toDouble(map['weight']);
            _volume = toDouble(map['volume']);
            _dimensions = map['dimensions']?.toString();
            _leadTime = toDouble(map['sale_delay']);

            _createDate = map['create_date']?.toString();

            _taxNames = taxes;
            _descriptionSale = map['description_sale'] is String
                ? map['description_sale']
                : null;
            _active = map['active'] == true;

            _isLoading = false;
          });
          _fadeController.forward();

          if (mounted) {
            context.read<LastOpenedProvider>().trackInventoryProductAccess(
              productId: widget.productId.toString(),
              productName: product.displayname,
              category: product.categoryName,
              productData: {'productId': widget.productId},
            );
          }
        }
      } else {
        if (mounted)
          setState(() {
            _error = 'Product not found';
            _isLoading = false;
          });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'Failed to load: $e';
          _isLoading = false;
        });
    }
  }

  Future<void> _onArchiveProduct() async {
    final confirmed = await CommonDialog.confirm(
      context,
      title: 'Archive Product?',
      message:
          'Are you sure you want to archive this product? It will be hidden from standard views.',
      confirmText: 'Archive',
      cancelText: 'Cancel',
      destructive: true,
      icon: HugeIcons.strokeRoundedArchive,
      topIconCentered: true,
    );

    if (confirmed == true) {
      try {
        await OdooSessionManager.callKwWithCompany({
          'model': 'product.product',
          'method': 'write',
          'args': [
            [widget.productId],
            {'active': false},
          ],
          'kwargs': {},
        });
        if (!mounted) return;
        // Refresh the product list so the archived product disappears.
        context.read<InventoryProductProvider>().fetchProducts(
          forceRefresh: true,
        );
        // The snackbar is a dialog route, so pop this screen first and show
        // it on the root navigator; otherwise the pop would close the snackbar.
        context.pop(true);
        final targetContext = navigatorKey.currentContext;
        if (targetContext != null && targetContext.mounted) {
          CustomSnackbar.showSuccess(
            targetContext,
            'Product archived successfully',
          );
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.showError(context, 'Failed to archive product: $e');
        }
      }
    }
  }

  void _showBarcodeGeneratorDialog() {
    if (_product == null) return;
    final code = _product!.barcode ?? _product!.defaultCode ?? _product!.name;
    final hasBarcode =
        _product!.barcode != null && _product!.barcode!.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => CommonDialog(
        title: 'Product Barcode',
        icon: Icons.qr_code,
        primaryLabel: 'Print/PDF',
        onPrimary: () async {
          try {
            final doc = pw.Document();
            doc.addPage(
              pw.Page(
                build: (pw.Context context) {
                  return pw.Center(
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          _product!.name,
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 20),
                        hasBarcode
                            ? pw.BarcodeWidget(
                                barcode: pw.Barcode.code128(),
                                data: code,
                                width: 200,
                                height: 80,
                              )
                            : pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: code,
                                width: 200,
                                height: 200,
                              ),
                        pw.SizedBox(height: 10),
                        pw.Text(code),
                      ],
                    ),
                  );
                },
              ),
            );
            await Printing.layoutPdf(onLayout: (format) async => doc.save());
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Printing not available: $e')),
            );
          }
        },
        secondaryLabel: 'Close',
        onSecondary: () => context.pop(),
        body: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: hasBarcode
                    ? BarcodeWidget(
                        barcode: Barcode.code128(),
                        data: code,
                        width: 200,
                        height: 80,
                        drawText: true,
                      )
                    : QrImageView(
                        data: code,
                        version: QrVersions.auto,
                        size: 200,
                      ),
              ),
              const SizedBox(height: 12),
              Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  String _generateProductShareText() {
    final p = _product!;
    final buffer = StringBuffer();
    buffer.writeln('🏷️ ${p.displayname}');
    buffer.writeln();

    final code = p.defaultCode;
    if (code != null && code.isNotEmpty) {
      buffer.writeln('📋 Code: $code');
    }

    if (_salePrice != null && _salePrice! > 0) {
      buffer.writeln(
        '💰 Price: ${_currencySymbol ?? ''}${_salePrice!.toStringAsFixed(2)}',
      );
    }

    buffer.writeln(
      '📦 Stock: ${p.qtyAvailable.toStringAsFixed(0)} ${p.uomName}',
    );

    final barcode = p.barcode;
    if (barcode != null && barcode.isNotEmpty) {
      buffer.writeln('🔢 Barcode: $barcode');
    }

    if (_descriptionSale != null && _descriptionSale!.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('📝 Description:');
      buffer.writeln(_descriptionSale!.trim());
    }

    buffer.writeln();
    buffer.writeln('📱 Shared from Inventory App');
    return buffer.toString();
  }

  Future<void> _shareViaSystem() async {
    if (_product == null) return;
    try {
      final text = _generateProductShareText();
      await Share.share(
        text,
        subject: 'Product Information: ${_product!.name}',
      );
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, 'Failed to share product: $e');
      }
    }
  }

  Future<void> _shareViaEmail() async {
    if (_product == null) return;
    try {
      final subject = Uri.encodeComponent(
        'Product Information: ${_product!.name}',
      );
      final body = Uri.encodeComponent(_generateProductShareText());
      final emailUrl = 'mailto:?subject=$subject&body=$body';
      final uri = Uri.parse(emailUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await _shareViaSystem();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, 'Failed to open email app: $e');
      }
    }
  }

  Future<void> _shareViaWhatsApp() async {
    if (_product == null) return;
    try {
      final text = Uri.encodeComponent(_generateProductShareText());
      final whatsappUrl = 'whatsapp://send?text=$text';
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await _shareViaSystem();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, 'Failed to open WhatsApp: $e');
      }
    }
  }

  void _showShareDialog() {
    if (_product == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = _product!.name;

    showDialog(
      context: context,
      builder: (ctx) => CommonDialog(
        title: 'Share Product',

        primaryLabel: 'Cancel',
        onPrimary: () => context.pop(),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose how you want to share "${name}"',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShareAction(
                  label: 'Email',
                  icon: Icons.email_outlined,
                  background: (isDark
                      ? Colors.white.withOpacity(0.06)
                      : StatusColors.blue.withValues(alpha: 0.1)),
                  iconColor: StatusColors.blue,
                  onTap: () async {
                    context.pop();
                    await _shareViaEmail();
                  },
                ),
                _ShareAction(
                  label: 'WhatsApp',
                  faIcon: FontAwesomeIcons.whatsapp,
                  background: (isDark
                      ? Colors.white.withOpacity(0.06)
                      : StatusColors.green.withValues(alpha: 0.1)),
                  iconColor: StatusColors.green,
                  onTap: () async {
                    context.pop();
                    await _shareViaWhatsApp();
                  },
                ),
                _ShareAction(
                  label: 'More',
                  icon: Icons.share,
                  background: (isDark
                      ? Colors.white.withOpacity(0.06)
                      : StatusColors.orange.withValues(alpha: 0.1)),
                  iconColor: StatusColors.orange,
                  onTap: () async {
                    context.pop();
                    await _shareViaSystem();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    // Edit / Archive only for users Odoo lets write products.
    final access = InventoryAccess.watch(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Product Details',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => context.pop(_updated),
        ),
        actions: [
          if (access.canEditProducts)
            IconButton(
              tooltip: 'Edit Product',
              onPressed: _product == null
                  ? null
                  : () async {
                      final res = await context.pushNamed<bool>(
                        AppRoutes.inventoryProductEdit,
                        extra: {'productId': widget.productId},
                      );
                      if (res == true && mounted) {
                        CustomSnackbar.showSuccess(
                          context,
                          'Product updated successfully',
                        );
                        await _load();
                        setState(() {
                          _updated = true;
                        });
                      }
                    },
              icon: Icon(
                HugeIcons.strokeRoundedPencilEdit02,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
              ),
            ),

          PopupMenuButton<String>(
            enabled: !_isLoading && _product != null,
            position: PopupMenuPosition.under,
            icon: Icon(
              Icons.more_vert,
              color:
                  (Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600])
                      ?.withOpacity(_isLoading ? 0.4 : 1.0),
              size: 22,
            ),
            itemBuilder: (context) => [
              _menuItem(
                value: 'share_product',
                label: 'Share Product',
                icon: HugeIcons.strokeRoundedShare08,
                isDark: isDark,
              ),
              _menuItem(
                value: 'generate_barcode',
                label: 'Generate Barcode',
                icon: HugeIcons.strokeRoundedBarCode01,
                isDark: isDark,
              ),
              if (access.canArchiveProducts)
                _menuItem(
                  value: 'archive_product',
                  label: 'Archive Product',
                  icon: HugeIcons.strokeRoundedArchive,
                  isDark: isDark,
                ),
            ],
            onSelected: (value) async {
              switch (value) {
                case 'share_product':
                  _showShareDialog();
                  break;
                case 'generate_barcode':
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _showBarcodeGeneratorDialog();
                  });
                  break;
                case 'archive_product':
                  _onArchiveProduct();
                  break;
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? _buildShimmerLoading(isDark)
          : _error != null
          ? EmptyState(
              title: 'Server Error',
              subtitle:
                  'Something went wrong while loading this product. Please try again.',
              lottieAsset: 'assets/lotties/Error 404.json',
              actionLabel: 'Retry',
              onAction: _load,
            )
          : _product == null
          ? const EmptyState(
              title: 'Product Not Found',
              subtitle: 'The requested product could not be found.',
              lottieAsset: 'assets/lotties/empty ghost.json',
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderAndMetrics(context, isDark),
                      const SizedBox(height: 16),
                      _buildSection(context, isDark, 'Pricing Information', [
                        _buildInfoRow(
                          isDark,
                          'Sale Price',
                          '${_currencySymbol ?? ''}${_salePrice?.toStringAsFixed(2) ?? '0.00'}',
                          isCurrency: true,
                        ),
                        _buildInfoRow(
                          isDark,
                          'Cost',
                          '${_currencySymbol ?? ''}${_standardPrice?.toStringAsFixed(2) ?? '0.00'}',
                          isCurrency: true,
                        ),
                        _buildInfoRow(
                          isDark,
                          'Taxes',
                          _taxNames.isEmpty ? 'None' : _taxNames.join(', '),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection(context, isDark, 'Inventory Information', [
                        _buildInfoRow(
                          isDark,
                          'On Hand',
                          '${_product!.qtyOnHand} ${_product!.uomName}',
                        ),
                        _buildInfoRow(
                          isDark,
                          'Available',
                          '${_product!.qtyAvailable} ${_product!.uomName}',
                          highlight: true,
                        ),
                        _buildInfoRow(
                          isDark,
                          'Incoming',
                          '${_product!.qtyIncoming} ${_product!.uomName}',
                        ),
                        _buildInfoRow(
                          isDark,
                          'Outgoing',
                          '${_product!.qtyOutgoing} ${_product!.uomName}',
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection(context, isDark, 'Logistics Information', [
                        _buildInfoRow(
                          isDark,
                          'Weight',
                          _weight != null ? '$_weight kg' : 'N/A',
                        ),
                        _buildInfoRow(
                          isDark,
                          'Volume',
                          _volume != null ? '$_volume m³' : 'N/A',
                        ),
                        if (_dimensions != null && _dimensions!.isNotEmpty)
                          _buildInfoRow(isDark, 'Dimensions', _dimensions!),
                        if (_leadTime != null)
                          _buildInfoRow(
                            isDark,
                            'Lead Time',
                            '${_leadTime!.toStringAsFixed(0)} days',
                          ),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection(context, isDark, 'Description', [
                        Text(
                          _descriptionSale ?? 'No description available.',
                          style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection(context, isDark, 'System Information', [
                        _buildInfoRow(
                          isDark,
                          'Created',
                          _createDate ?? 'Unknown',
                        ),
                        _buildInfoRow(
                          isDark,
                          'ID',
                          widget.productId.toString(),
                        ),
                        _buildInfoRow(isDark, 'Active', _active ? 'Yes' : 'No'),
                      ]),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderAndMetrics(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.panelDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(context, isDark),
          const SizedBox(height: 16),
          _buildQuickMetrics(context, isDark),
        ],
      ),
    );
  }

  /// A row of the "more options" menu: the action's icon, then its label.
  PopupMenuItem<String> _menuItem({
    required String value,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, bool isDark) {
    return Container(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _imageBytes != null
                ? () {
                    context.pushNamed(
                      AppRoutes.fullImage,
                      extra: {
                        'imageBytes': _imageBytes!,
                        'title': _product!.name,
                      },
                    );
                  }
                : null,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                image: _imageBytes != null
                    ? DecorationImage(
                        image: MemoryImage(_imageBytes!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _imageBytes == null
                  ? Center(
                      child: Text(
                        _product!.name.isNotEmpty ? _product!.name[0] : '?',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _product!.displayname,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                _buildChip(isDark, _product!.categoryName, Icons.category),
                const SizedBox(height: 4),
                _buildChip(
                  isDark,
                  _product!.defaultCode ?? 'No SKU',
                  Icons.qr_code,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(bool isDark, String label, IconData icon) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickMetrics(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            isDark,
            'Price',
            '${_currencySymbol ?? ''}${_salePrice?.toStringAsFixed(2) ?? '0.00'}',
            Colors.black,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            isDark,
            'Available',
            _product!.qtyAvailable.toStringAsFixed(0),
            // Green with stock, red at zero (or below).
            _product!.qtyAvailable > 0 ? StatusColors.green : StatusColors.red,
            colorValue: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            isDark,
            'Status',
            _active ? 'Active' : 'Archived',
            _active ? StatusColors.green : StatusColors.red,
            colorValue: true,
          ),
        ),
      ],
    );
  }

  /// A tile of the header's quick metrics. [color] is the tile's stroke; with
  /// [colorValue] the value is drawn in it as well.
  Widget _buildMetricCard(
    bool isDark,
    String label,
    String value,
    Color color, {
    bool colorValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? (color == Colors.black
                    ? Colors.white
                    : color.withValues(alpha: 0.3))
              : color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorValue ? color : AppTheme.labelColor(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    bool isDark,
    String title,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.panelDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    bool isDark,
    String label,
    String value, {
    bool highlight = false,
    bool isCurrency = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                color: highlight
                    ? Theme.of(context).primaryColor
                    : (isDark ? Colors.white : Colors.black87),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[200]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[50]!,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Container(
                    height: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              3,
              (i) => Container(
                height: 150,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final FaIconData? faIcon;
  final Color background;
  final Color iconColor;
  final VoidCallback onTap;

  const _ShareAction({
    required this.label,
    this.icon,
    this.faIcon,
    required this.background,
    required this.iconColor,
    required this.onTap,
  }) : assert(icon != null || faIcon != null, 'Provide either icon or faIcon');

  @override
  Widget build(BuildContext context) {
    // Each action takes an equal share of the row, so the tiles shrink on
    // narrow screens or large text instead of overflowing, and never grow
    // past 64px on wide ones.
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = (constraints.maxWidth - 12).clamp(40.0, 64.0);
          final iconSize = size * 0.44;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: background,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Center(
                      child: faIcon != null
                          ? FaIcon(faIcon, color: iconColor, size: iconSize)
                          : Icon(icon, color: iconColor, size: iconSize),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
