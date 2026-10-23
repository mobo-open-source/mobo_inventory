import 'package:flutter/material.dart';

import '../../design/mobo_tokens.dart';

/// The app's two buttons: one filled, one outlined.
///
/// There is no third. A screen that needs a third action has a layout problem,
/// not a button problem — and every extra weight makes the other two mean less.
///
/// Both share their shape, height and label weight, so a Cancel/Save pair sits
/// level and matches edge for edge. Sizing comes from [MoboSpacing.buttonHeight]
/// rather than from padding, which is what keeps a one-word button and a
/// five-word button the same height.
enum MoboButtonVariant {
  /// The action being invited. One per screen or dialog.
  filled,

  /// Everything else — Cancel, Clear, Back.
  outlined,
}

class MoboButton extends StatelessWidget {
  const MoboButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = MoboButtonVariant.filled,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.danger = false,
  });

  /// Shorthand for the primary action.
  const MoboButton.filled({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.danger = false,
  }) : variant = MoboButtonVariant.filled;

  /// Shorthand for the secondary action.
  const MoboButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.danger = false,
  }) : variant = MoboButtonVariant.outlined;

  final String label;

  /// Null disables the button. A disabled button explains itself by staying in
  /// place — hiding it instead moves everything else and leaves the user
  /// wondering what they missed.
  final VoidCallback? onPressed;

  final MoboButtonVariant variant;
  final IconData? icon;

  /// Swaps the label for a spinner and blocks the tap, so a slow save cannot
  /// be submitted twice.
  final bool isLoading;

  /// False sizes the button to its label instead of the available width.
  final bool expand;

  /// For an action that destroys something — delete, archive, sign out.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.mobo;
    final accent = danger ? colors.error : colors.primary;
    final enabled = onPressed != null && !isLoading;

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == MoboButtonVariant.filled
                  ? Colors.white
                  : accent,
            ),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: MoboType.button(),
                ),
              ),
            ],
          );

    final button = variant == MoboButtonVariant.filled
        ? ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: accent.withValues(alpha: 0.4),
              disabledForegroundColor: Colors.white70,
              elevation: 0,
              // Flat on press too: a shadow that appears under the finger
              // reads as the button lifting away from the tap.
              shadowColor: Colors.transparent,
              minimumSize: Size(0, MoboSpacing.buttonHeight),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MoboRadius.button),
              ),
            ),
            child: child,
          )
        : OutlinedButton(
            onPressed: enabled ? onPressed : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              disabledForegroundColor: accent.withValues(alpha: 0.4),
              backgroundColor: Colors.transparent,
              minimumSize: Size(0, MoboSpacing.buttonHeight),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              side: BorderSide(
                color: enabled ? accent : accent.withValues(alpha: 0.4),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MoboRadius.button),
              ),
            ),
            child: child,
          );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A Cancel/Confirm pair, level and equal width.
///
/// The outlined one leads because the filled one is the action being invited,
/// and the inviting action belongs under the thumb on the right.
class MoboButtonRow extends StatelessWidget {
  const MoboButtonRow({
    super.key,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.primaryLabel,
    required this.onPrimary,
    this.isLoading = false,
    this.danger = false,
    this.gap = 12,
  });

  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool isLoading;
  final bool danger;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MoboButton.outlined(
            label: secondaryLabel,
            onPressed: onSecondary,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: MoboButton.filled(
            label: primaryLabel,
            onPressed: onPrimary,
            isLoading: isLoading,
            danger: danger,
          ),
        ),
      ],
    );
  }
}
