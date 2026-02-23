import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

PageRoute<T> slidingPageTransitionRL<T>(BuildContext context, Widget page) {
  const curve = Curves.easeOutCubic;
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offsetAnimation = Tween<Offset>(
        begin: const Offset(0.3, 0.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: curve)).animate(animation);

      final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOut),
      );

      return SlideTransition(
        position: offsetAnimation,
        child: FadeTransition(
          opacity: fadeAnimation,
          child: child,
        ),
      );
    },
  );
}

PageRoute<T> slidingPageTransitionLR<T>(BuildContext context, Widget page) {
  const curve = Curves.easeOutCubic;
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offsetAnimation = Tween<Offset>(
        begin: const Offset(-0.3, 0.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: curve)).animate(animation);

      final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOut),
      );

      return SlideTransition(
        position: offsetAnimation,
        child: FadeTransition(
          opacity: fadeAnimation,
          child: child,
        ),
      );
    },
  );
}

PageRoute<T> dynamicRoute<T>(BuildContext context, Widget page, {bool fromLeft = false}) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return CupertinoPageRoute<T>(
      builder: (context) => page,
      fullscreenDialog: false,
    );
  }
  return fromLeft ? slidingPageTransitionLR<T>(context, page) : slidingPageTransitionRL<T>(context, page);
}
