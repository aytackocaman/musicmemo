// Regression tests for the login screen's scroll and keyboard behaviour.
//
// The screen looked correct in a diff while scrolling roughly twice as far as
// it should once the keyboard opened. The cause: the keyboard inset was added
// to the scroll view's bottom padding *and* Scaffold had already shrunk the
// viewport by it (resizeToAvoidBottomInset), so the inset was counted twice.
//
// Measured on an iPhone 13 mini with a 336pt keyboard, sign-up form:
//   before: 670pt of extra scroll range  (~2x the keyboard)
//   after:  263pt                         (<1x, content only partly overflows)
//
// These assert on the measured scroll extent and on focus state rather than on
// the presence of widgets, so a plausible-looking refactor cannot silently
// reintroduce the bug.
//
// Note on tap-to-dismiss: the assertion below passes with or without
// HitTestBehavior.opaque, so it is a guard against regression, not proof that
// `opaque` fixed anything. Measured behaviour did not reproduce a dismissal
// failure in the page area on either version.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:music_memo/config/theme.dart';
import 'package:music_memo/l10n/app_localizations.dart';
import 'package:music_memo/screens/login_screen.dart';

/// iPhone 13 mini: the shortest device the app targets, and the one where the
/// keyboard covers the password field and the submit button.
const Size _mini = Size(375, 812);

/// Roughly an iOS keyboard with its accessory row.
const double _keyboardHeight = 336;

/// The app's real typefaces come from google_fonts, which downloads them at
/// runtime. Tests have no network, so every glyph falls back to Flutter's test
/// font, which draws each character as a full-width box - roughly twice as wide
/// as real text. That produces RenderFlex overflows that have nothing to do
/// with the app and would drown the real assertions in false failures.
///
/// google_fonts registers each face under `"<family>_<variant>"`, e.g.
/// `Inter_600` (see GoogleFontsFamilyWithVariant.toString), so registering the
/// plain family names would not be picked up. Roboto from the Flutter SDK is
/// loaded under every family/variant pair the theme asks for, which makes glyph
/// metrics proportional and realistic.
///
/// Roboto is a stand-in, not the real Plus Jakarta Sans / Inter. Good enough
/// to catch overflow and to make height-based scroll assertions meaningful; not
/// trustworthy for pixel-exact line breaking.
Future<void> _registerRealisticFonts() async {
  final root = _flutterRoot();
  if (root == null) return;

  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;

  // Every weight the theme uses, in google_fonts' naming. Note
  // `PlusJakartaSans` has no spaces - that is the family identifier
  // google_fonts derives from the font's own name, not the display name.
  const families = ['Inter', 'PlusJakartaSans'];
  const variants = ['regular', '500', '600', '700', '800'];

  // Closest available Roboto cut for each variant.
  String? pathFor(String variant) => switch (variant) {
    'regular' => 'Roboto-Regular.ttf',
    '500' => 'Roboto-Medium.ttf',
    '600' => 'Roboto-Bold.ttf',
    '700' => 'Roboto-Bold.ttf',
    '800' => 'Roboto-Black.ttf',
    _ => null,
  };

  for (final family in families) {
    for (final variant in variants) {
      final name = pathFor(variant);
      if (name == null) continue;
      final path = '${dir.path}/$name';
      final file = File(path);
      if (!file.existsSync()) continue;

      final loader = FontLoader('${family}_$variant');
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
      await loader.load();
    }
  }
}

String? _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty && Directory(env).existsSync()) return env;

  // The test runner lives at <root>/bin/cache/dart-sdk/bin/.
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 5; i++) {
    if (Directory('${dir.path}/bin/cache/artifacts').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  return null;
}

Widget _app() {
  return MaterialApp(
    theme: AppTheme.darkTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: const LoginScreen(),
  );
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = _mini;
  tester.view.viewInsets = FakeViewPadding.zero;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
}

/// Raise or lower the software keyboard after the screen is already built.
///
/// The keyboard cannot be simulated before opening the email form: a raised
/// keyboard shrinks the viewport to 476pt, which puts the "Sign in with Email"
/// button itself below the fold, so there would be no way to reach the form.
/// Opening the form first and then raising the keyboard is also what actually
/// happens on device.
Future<void> _setKeyboard(WidgetTester tester, double height) async {
  tester.view.viewInsets = FakeViewPadding(bottom: height);
  await tester.pumpAndSettle();
}

/// The tabs only exist once the email form is open; on first launch the screen
/// shows the three one-tap providers.
Future<void> _openEmailForm(WidgetTester tester, {bool signUp = false}) async {
  await tester.tap(find.text('Sign in with Email'));
  await tester.pumpAndSettle();
  if (signUp) {
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
  }
}

/// The scroll position of the screen's single scroll view.
ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position;

bool _anythingFocused(WidgetTester tester) =>
    FocusScope.of(tester.element(find.byType(LoginScreen))).hasFocus;

void main() {
  setUpAll(_registerRealisticFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('scroll range', () {
    testWidgets('is zero when the content already fits', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      // maxScrollExtent == 0 is the precise statement of "this page does not
      // scroll". A tolerance here would hide the exact regression being guarded
      // against, so it is asserted exactly.
      expect(
        _position(tester).maxScrollExtent,
        0,
        reason:
            'With no keyboard and content that fits there must be nothing '
            'to scroll. A non-zero extent means dead scroll range was added.',
      );
    });

    testWidgets('is zero on the sign-up form, the tallest view', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await _openEmailForm(tester, signUp: true);

      expect(_position(tester).maxScrollExtent, 0);
    });

    testWidgets('is non-zero when the keyboard covers the lower fields', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await _openEmailForm(tester, signUp: true);
      await _setKeyboard(tester, _keyboardHeight);

      expect(
        _position(tester).maxScrollExtent,
        greaterThan(0),
        reason:
            'With the keyboard open the password field and submit button '
            'sit below the fold, so the page must scroll or they are '
            'unreachable. This is what NeverScrollableScrollPhysics caused.',
      );
    });

    testWidgets('grows by about one keyboard, not two', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await _openEmailForm(tester, signUp: true);
      final closed = _position(tester).maxScrollExtent;

      await _setKeyboard(tester, _keyboardHeight);
      final open = _position(tester).maxScrollExtent;

      expect(closed, 0);
      expect(open, greaterThan(0));

      // The point of the fix. Opening the keyboard should add roughly one
      // keyboard-height of reach. If the inset is counted both by the Scaffold
      // resize and by the scroll view's padding, the extra range comes out near
      // 2x and the page visibly over-scrolls.
      expect(
        open - closed,
        lessThan(_keyboardHeight * 1.5),
        reason:
            'Scroll range grew by ${open - closed}px for a '
            '${_keyboardHeight.toInt()}px keyboard. Near or above 2x means the '
            'inset is being counted twice.',
      );
    });
  });

  group('keyboard dismissal', () {
    testWidgets('a tap on empty space unfocuses the field', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await _openEmailForm(tester);

      await tester.tap(find.byType(TextFormField).first);
      await tester.pumpAndSettle();

      // Raise the keyboard for real. Without this the tap below happens with
      // viewInsets at zero, which is not the situation the bug was reported in.
      await _setKeyboard(tester, _keyboardHeight);
      expect(_anythingFocused(tester), isTrue, reason: 'precondition');

      // Aim inside the page, not behind the keyboard. Scaffold shrinks its body
      // to 812 - 336 = 476pt, so anything below that is covered by the
      // keyboard on device and tapping there cannot reach the app at all.
      // Deriving the coordinate from the body height keeps the test honest if
      // either number changes.
      final bodyHeight = tester.getSize(find.byType(Scrollable).first).height;
      expect(bodyHeight, lessThan(_mini.height), reason: 'precondition');

      await tester.tapAt(Offset(8, bodyHeight - 40));
      await tester.pumpAndSettle();

      expect(
        _anythingFocused(tester),
        isFalse,
        reason:
            'A tap on empty space inside the page must dismiss the '
            'keyboard.',
      );
    });

    testWidgets('a tap on a field still focuses it', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await _openEmailForm(tester);

      // HitTestBehavior.opaque must not let the ancestor detector win the
      // gesture arena against the fields, or typing becomes impossible.
      await tester.tap(find.byType(TextFormField).first);
      await tester.pumpAndSettle();

      expect(_anythingFocused(tester), isTrue);
    });
  });
}
