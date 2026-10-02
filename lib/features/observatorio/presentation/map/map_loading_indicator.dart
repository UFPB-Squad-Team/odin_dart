import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/panel.dart';
import 'map_providers.dart';

/// How the map's activity feedback is drawn.
enum MapLoadingStyle {
  /// Hairline progress bar across the top of the canvas (default).
  bar,

  /// Discrete floating pill: "Atualizando mapa…" with a small spinner.
  pill,
}

/// Instant, non-blocking feedback while the camera moves or geometry refetches.
///
/// Contract:
///  * never intercepts pointers — everything is wrapped in [IgnorePointer], so
///    pan/zoom/tap keep working while geometry loads;
///  * never renders a scrim, dialog or full-screen overlay;
///  * never flickers — see [MapActivityLatch].
///
/// It is injected as the last child of `FlutterMap`, which lays out non-mobile
/// children as a *static* stack (cf. `RichAttributionWidget`), so it stays
/// pinned to the canvas while the camera moves and is clipped to it.
class MapLoadingIndicator extends ConsumerWidget {
  const MapLoadingIndicator({super.key, this.style = MapLoadingStyle.bar});

  final MapLoadingStyle style;

  /// Distance from the top of the map canvas, chosen to clear the observatory
  /// page's top chrome (status bar + logo/search row + filter row, see
  /// `observatorio_page.dart`).
  static const chromeInset = 112.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = MediaQuery.viewPaddingOf(context).top + chromeInset;

    return MapActivityLatch(
      active: ref.watch(mapBusyProvider),
      child: switch (style) {
        MapLoadingStyle.bar => _LoadingBar(topInset: topInset),
        MapLoadingStyle.pill => _LoadingPill(topInset: topInset),
      },
    );
  }
}

/// Shows [child] while [active] is true and keeps it up for a minimum window
/// plus a trailing grace.
///
/// That latch is what turns the 220 ms settle debounce plus a short round-trip
/// into *one* smooth pulse instead of an off-then-on blink, without adding a
/// single timer to the provider graph or an extra rebuild of the map.
///
/// While idle the child is removed from the tree, so the indeterminate progress
/// animation does not keep ticking behind `opacity: 0`.
class MapActivityLatch extends StatefulWidget {
  const MapActivityLatch({
    super.key,
    required this.active,
    required this.child,
    this.fadeIn = const Duration(milliseconds: 160),
    this.fadeOut = const Duration(milliseconds: 240),
    this.minimumVisible = const Duration(milliseconds: 400),
    this.trailingGrace = const Duration(milliseconds: 320),
  });

  final bool active;
  final Widget child;
  final Duration fadeIn;
  final Duration fadeOut;

  /// How long the feedback may stay on after the first activation.
  final Duration minimumVisible;

  /// How long the feedback keeps its position after [active] goes false,
  /// absorbing the camera-settle window before a fetch begins.
  final Duration trailingGrace;

  @override
  State<MapActivityLatch> createState() => _MapActivityLatchState();
}

class _MapActivityLatchState extends State<MapActivityLatch> {
  bool _visible = false;
  bool _present = false;
  Timer? _minimum;
  Timer? _grace;

  @override
  void initState() {
    super.initState();
    if (widget.active) _show();
  }

  @override
  void didUpdateWidget(MapActivityLatch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;

    if (widget.active) {
      _show();
    } else if (_minimum == null) {
      // The minimum window has already elapsed, so the grace may start now.
      _scheduleHide();
    }
    // Otherwise the running minimum timer will start the grace window itself.
  }

  @override
  void dispose() {
    _minimum?.cancel();
    _grace?.cancel();
    super.dispose();
  }

  void _show() {
    _grace?.cancel();
    _grace = null;
    _minimum ??= Timer(widget.minimumVisible, _onMinimumElapsed);
    if (_visible && _present) return;
    setState(() {
      _present = true;
      _visible = true;
    });
  }

  void _onMinimumElapsed() {
    _minimum = null;
    if (widget.active) return;
    _scheduleHide();
  }

  void _scheduleHide() {
    _grace ??= Timer(widget.trailingGrace, () {
      _grace = null;
      if (!mounted || widget.active) return;
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      setState(() {
        _visible = false;
        // With animations disabled there is no fade to ride out, so drop the
        // child straight away instead of waiting for an `onEnd`.
        if (reduceMotion) _present = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (!_present && !_visible) return const SizedBox.shrink();

    return IgnorePointer(
      child: ExcludeSemantics(
        excluding: !_visible,
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: reduceMotion
              ? Duration.zero
              : (_visible ? widget.fadeIn : widget.fadeOut),
          curve: Curves.easeOut,
          onEnd: () {
            if (!_visible && _present) setState(() => _present = false);
          },
          // The child stays mounted while it fades out; it is only dropped once
          // the fade has finished (`onEnd` above), never mid-animation.
          child: _present ? widget.child : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Semantics(
          container: true,
          liveRegion: true,
          label: 'Atualizando mapa',
          child: SizedBox(
            height: 2.5,
            child: LinearProgressIndicator(
              minHeight: 2.5,
              color: scheme.primary,
              backgroundColor: scheme.primary.withAlpha(38),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 12, top: topInset),
        child: Panel(
          opacity: 0.94,
          radius: 999,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Atualizando mapa…',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
