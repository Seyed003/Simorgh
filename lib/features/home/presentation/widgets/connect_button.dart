import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/status_colors.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../connection/application/vpn_controller.dart';
import '../../../connection/domain/vpn_state.dart';
import '../../../profiles/application/profiles_controller.dart';

Color statusColor(BuildContext context, VpnStatus status) {
  final colors = StatusColors.of(context);
  return switch (status) {
    VpnStatus.connected => colors.connected,
    VpnStatus.connecting || VpnStatus.disconnecting => colors.connecting,
    VpnStatus.disconnected => colors.disconnected,
  };
}

/// The big round power button. Pulses while connecting/disconnecting.
class ConnectButton extends ConsumerStatefulWidget {
  const ConnectButton({super.key, this.size = 176});

  final double size;

  @override
  ConsumerState<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends ConsumerState<ConnectButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _onTap() {
    if (ref.read(selectedProfileProvider) == null &&
        ref.read(vpnControllerProvider).status == VpnStatus.disconnected) {
      context.showSnack(context.l10n.selectConfigFirst);
      return;
    }
    ref.read(vpnControllerProvider.notifier).toggle();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(vpnControllerProvider.select((s) => s.status));
    final busy =
        status == VpnStatus.connecting || status == VpnStatus.disconnecting;
    if (busy && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!busy && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }

    final color = statusColor(context, status);
    final connected = status == VpnStatus.connected;
    final l10n = context.l10n;
    final size = widget.size;

    return Semantics(
      button: true,
      label: connected ? l10n.disconnect : l10n.connect,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = _pulse.value;
          return SizedBox.square(
            dimension: size * 1.35,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (busy)
                  Container(
                    width: size * (1 + 0.3 * t),
                    height: size * (1 + 0.3 * t),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.25 * (1 - t)),
                    ),
                  ),
                if (busy)
                  Transform.rotate(
                    angle: t * 2 * math.pi,
                    child: SizedBox.square(
                      dimension: size + 14,
                      child: CircularProgressIndicator(
                        value: 0.25,
                        strokeWidth: 3,
                        color: color,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                  ),
                child!,
              ],
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: connected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, Color.lerp(color, Colors.black, 0.25)!],
                  )
                : null,
            color: connected ? null : context.colors.surfaceContainerHigh,
            border: Border.all(
              color: color.withValues(alpha: connected ? 0 : 0.6),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: connected ? 0.45 : 0.15),
                blurRadius: connected ? 36 : 18,
                spreadRadius: connected ? 2 : 0,
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: status == VpnStatus.disconnecting ? null : _onTap,
              child: Icon(
                Icons.power_settings_new_rounded,
                size: size * 0.4,
                color: connected ? Colors.white : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
