import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routing/app_routes.dart';

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
    // Module and portal-access checks run in AppEntry, which signs out a
    // session that no longer qualifies — a second check here would only
    // race it with a contradictory warning.
    context.goNamed(AppRoutes.app);
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
