import 'package:camera_overlay/features/overlay/presentation/providers/overlay_tray_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer.test());

  OverlayTrayState state() => container.read(overlayTrayProvider);
  OverlayTrayController controller() =>
      container.read(overlayTrayProvider.notifier);

  test('starts on the opacity tab, expanded by screen size, not minimized', () {
    expect(state(), const OverlayTrayState());
    expect(state().expanded, isNull);
  });

  test('selecting another tab opens it; the open tab folds the tray', () {
    controller().selectTab(OverlayTrayTab.frame, currentlyExpanded: true);
    expect(state().tab, OverlayTrayTab.frame);
    expect(state().expanded, isTrue);

    controller().selectTab(OverlayTrayTab.frame, currentlyExpanded: true);
    expect(state().expanded, isFalse);

    // From folded, tapping the same tab opens it again.
    controller().selectTab(OverlayTrayTab.frame, currentlyExpanded: false);
    expect(state().expanded, isTrue);
  });

  test('minimize and restore keep the tab and expansion', () {
    controller()
      ..selectTab(OverlayTrayTab.frame, currentlyExpanded: true)
      ..minimize();
    expect(state().minimized, isTrue);

    controller().restore();
    expect(state().minimized, isFalse);
    expect(state().tab, OverlayTrayTab.frame);
    expect(state().expanded, isTrue);
  });

  test('a new image un-minimizes the tray', () {
    controller()
      ..minimize()
      ..showForNewImage();
    expect(state().minimized, isFalse);
  });
}
