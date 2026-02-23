import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/module_validation_service.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/routing/app_routes.dart';
import '../../widgets/snackbars/custom_snackbar.dart';

/// The initial application screen that plays a promotional video and performs background module validation.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static bool _hasPlayedOnce = false;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isValidatingModules = false;
  Timer? _safetyTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    if (_hasPlayedOnce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigateSafely();
        }
      });
      return;
    }
    _hasPlayedOnce = true;
    _startSafetyTimer();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.asset(
        'assets/splash/splash.mp4',
      );

      await _videoController!.initialize().timeout(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });

        try {
          await _videoController!.play().timeout(const Duration(seconds: 1));
        } catch (_) {}

        _videoController!.addListener(() {
          if (!_hasNavigated &&
              _videoController!.value.position >=
                  _videoController!.value.duration) {
            if (mounted) {
              _navigateSafely();
            }
          }
        });
      }
    } on TimeoutException {
    } catch (e) {
      if (mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _navigateSafely();
          }
        });
      }
    }
  }

  void _startSafetyTimer() {
    _safetyTimer?.cancel();
    _safetyTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _navigateSafely();
      }
    });
  }

  void _navigateSafely() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    _safetyTimer?.cancel();

    if (!mounted) return;
    context.goNamed(AppRoutes.app);

    Future.microtask(_runPostNavigationValidation);
  }

  Future<void> _runPostNavigationValidation() async {
    if (_isValidatingModules) return;

    setState(() {
      _isValidatingModules = true;
    });

    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null) {
        return;
      }

      final moduleStatus = await ModuleValidationService.instance
          .validateRequiredModules(forceRefresh: true);

      final inventoryInstalled = moduleStatus['stock'] ?? false;

      if (!inventoryInstalled) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            CustomSnackbar.show(
              context: context,
              title: 'Missing Module',
              message:
                  '📦 The Inventory app is not installed on your Odoo server. '
                  'Some features may not work. Please contact your administrator.',
              type: SnackbarType.warning,
              duration: const Duration(seconds: 8),
            );
          }
        });
      }
    } catch (e) {}
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _safetyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: AppTheme.primaryColor)),

          if (_isVideoInitialized && _videoController != null)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
