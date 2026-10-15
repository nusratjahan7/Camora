import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OverlayTrayTab { opacity, frame }

/// How the overlay controls tray is presented. Kept in Riverpod rather than
/// widget state because the camera rebuilds its controls on every camera
/// switch and app resume, which would otherwise reset the tray.
@immutable
class OverlayTrayState {
  const OverlayTrayState({
    this.tab = OverlayTrayTab.opacity,
    this.expanded,
    this.minimized = false,
  });

  final OverlayTrayTab tab;

  /// Whether the open tab's controls show below the header; null follows the
  /// screen size (folded on short, landscape screens).
  final bool? expanded;

  /// Collapsed to a small chip so the preview is unobstructed.
  final bool minimized;

  OverlayTrayState copyWith({
    OverlayTrayTab? tab,
    ValueGetter<bool?>? expanded,
    bool? minimized,
  }) {
    return OverlayTrayState(
      tab: tab ?? this.tab,
      expanded: expanded != null ? expanded() : this.expanded,
      minimized: minimized ?? this.minimized,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OverlayTrayState &&
          other.tab == tab &&
          other.expanded == expanded &&
          other.minimized == minimized;

  @override
  int get hashCode => Object.hash(tab, expanded, minimized);
}

class OverlayTrayController extends Notifier<OverlayTrayState> {
  @override
  OverlayTrayState build() => const OverlayTrayState();

  /// Opens [tab]; tapping the tab that is already open folds the tray down
  /// to its header. [currentlyExpanded] is the expansion actually on screen.
  void selectTab(OverlayTrayTab tab, {required bool currentlyExpanded}) {
    if (currentlyExpanded && tab == state.tab) {
      state = state.copyWith(expanded: () => false);
    } else {
      state = state.copyWith(tab: tab, expanded: () => true);
    }
  }

  void minimize() => state = state.copyWith(minimized: true);

  void restore() => state = state.copyWith(minimized: false);

  /// A freshly picked image shows the full tray, so its controls are found.
  void showForNewImage() => state = state.copyWith(minimized: false);
}

final overlayTrayProvider =
    NotifierProvider<OverlayTrayController, OverlayTrayState>(
      OverlayTrayController.new,
    );
