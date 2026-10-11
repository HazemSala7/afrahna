import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/cosmos.dart';

/// «أفراحنا» — ivory & rose gold.
///
/// The app is lit, not darkened: warm ivory paper, rose gold that behaves like
/// light rather than paint, white cards with a hairline of gold, and deep
/// warm-brown type. The shimmer of the earlier night-sky design is all still
/// here — the drifting motes, the rings, the sweep of light across a page —
/// only now it plays on paper instead of space.
///
/// The names are the ones the app has always used — `textDark`, `primaryLight`,
/// `background` — because some two thousand call sites use them, and a name
/// that keeps its *meaning* (the main text colour, a soft brand tint behind a
/// label, the ground of a screen) lets every one of those screens change look
/// without being rewritten. Read each by what it is for, not by the word in
/// its name.
class AppColors {
  // ---- rose gold
  /// Rose gold: fills, icons, the active thing.
  static const Color primary = Color(0xFFC9906B);

  /// Deep rose for *emphasis on ivory*: headings, prices, selected labels.
  static const Color primaryDark = Color(0xFF8E5F4A);

  /// A breath of blush behind a label or an icon.
  static const Color primaryLight = Color(0xFFF4E4DA);

  /// Terracotta rose: highlights, focus, the one thing that should catch the
  /// eye. Deep enough to read as type on ivory, which the champagne it
  /// replaced was not — this colour is an icon and a label far more often
  /// than it is a glow.
  static const Color accent = Color(0xFFB8744F);

  /// Deep burnished rose, for a fill that white text sits on.
  static const Color goldDeep = Color(0xFF7A4B38);

  /// Pale champagne, for the highlight inside a gold gradient and for type on
  /// a dark fill. Nearly invisible *on* ivory — never use it as a colour of
  /// its own on the page.
  static const Color champagne = Color(0xFFF7E3C3);

  // ---- ivory
  /// The top of the sky, and the colour the phone shows while the app starts:
  /// the Android launch window (res/values/colors.xml) and the iOS launch
  /// storyboard are painted with exactly this, so the handover into the intro
  /// cannot be seen. Change all three together.
  static const Color space = Color(0xFFFAF4EF);

  /// The ground of a screen. Mostly hidden behind the sky; used where
  /// something must match it exactly (a ring cut out of a bar).
  static const Color background = Color(0xFFF6EFE8);

  /// A card: white, with a hairline of gold.
  static const Color surface = Color(0xFFFFFFFF);

  /// A raised card, a field, a sheet.
  static const Color surfaceHigh = Color(0xFFF6EFEA);

  /// Deep warm brown, for a dark panel under light text, and for type that
  /// sits on a gold fill.
  static const Color ink = Color(0xFF3A2C26);

  // ---- type
  /// The main text colour.
  static const Color textDark = Color(0xFF3A2C26);
  static const Color textMuted = Color(0xFF9A8880);

  /// Near-white: type and icons that sit on a coloured fill.
  static const Color pearl = Color(0xFFFFFCFA);

  // ---- utility
  static const Color discount = Color(0xFFC1452B);

  /// Warm and soft: a card lifts off ivory, it does not cut a hole in it.
  static const Color cardShadow = Color(0x14C9906B);

  /// The hairline edge of a card. Warm, so it reads on ivory — a translucent
  /// white would not.
  static const Color glass = Color(0x0A3A2C26);
  static const Color hairline = Color(0x2E8E5F4A);

  // ---- holographic
  /// Deeper than the pastels of the dark theme: a pale iridescent edge
  /// disappears on ivory.
  static const Color holoRose = Color(0xFFE0A294);
  static const Color holoLavender = Color(0xFFA68FD8);
  static const Color holoAqua = Color(0xFF5FC3BC);
  static const List<Color> holoStops = [
    champagne,
    holoRose,
    holoLavender,
    holoAqua,
    champagne,
  ];

  /// A soft wash of ivory into blush.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFFFFFBF8), Color(0xFFF4E4DA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Cocoa → rose — for hero panels with white text on them. It stays dark on
  /// purpose: these panels carry pearl type, and lightening them would leave
  /// that type unreadable.
  static const LinearGradient brandDeepGradient = LinearGradient(
    colors: [Color(0xFF5E3A33), Color(0xFFA25D45), Color(0xFFD08B63)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Liquid rose gold. Deep enough that dark type reads on it and that it
  /// stands off ivory.
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF6DFBE), Color(0xFFD7A078), Color(0xFFB87E5C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient holoGradient = LinearGradient(
    colors: holoStops,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// The original cream palette, kept for the few screens that are the
/// customer's own design rather than the app's chrome: an invitation is drawn
/// in the colours its couple chose and must not drift when the app's own
/// colours change. Close to [AppColors] again now that the app is light —
/// deliberately separate all the same.
class AppLightColors {
  static const Color primary = Color(0xFFB8835A);
  static const Color primaryDark = Color(0xFF8B5A3C);
  static const Color primaryLight = Color(0xFFF0DDC8);
  static const Color accent = Color(0xFFD4A373);
  static const Color background = Color(0xFFFAF3EC);
  static const Color surface = Color(0xFFFFFBF6);
  static const Color textDark = Color(0xFF3D2817);
  static const Color textMuted = Color(0xFF9C8273);
  static const Color discount = Color(0xFFC1452B);
  static const Color cardShadow = Color(0x1AB8835A);
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFFFAF3EC), Color(0xFFEBD7BF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient brandDeepGradient = LinearGradient(
    colors: [Color(0xFF3D2817), Color(0xFF6B4226), Color(0xFFB8835A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// How a card sits on the page.
///
/// Every card in the app is the same piece of paper: white, no outline, and
/// lifted by two shadows rather than one. A single shadow has to choose
/// between seating the card and floating it — a tight one looks printed on,
/// a wide one looks like it is drifting. Two do both: a short dark one right
/// under the edge, and a wide warm one beneath that.
///
/// An outline is how a card is separated from a DARK ground. On ivory it reads
/// as a drawn box, so there is none; the lift does the separating.
class AppDecor {
  /// The shadow pair every card carries.
  static const List<BoxShadow> lift = [
    BoxShadow(color: Color(0x1A8E5F4A), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x2EC9906B), blurRadius: 28, offset: Offset(0, 12)),
  ];

  /// A whole card, for the places that want it in one line.
  static BoxDecoration card({double radius = 26, Color? color}) =>
      BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: lift,
      );
}

class AppAssets {
  static const String logo = 'assets/images/logo.png';

  /// Full-bleed artwork behind an invitation's opening screen. Used whenever a
  /// theme has no background image of its own.
  static const String invitationCover = 'assets/images/invitation_cover.jpg';
}

class AppTheme {
  /// Status bar and system navigation bar, dark on the ivory sky.
  static const SystemUiOverlayStyle overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  /// Kept for anything that still asks for the theme by its old name.
  static ThemeData light() => cosmic();

  /// «أفراحنا» as a wordmark: Reem Kufi, geometric, drawn like an engraved
  /// plate. For the name alone — the intro, the home bar — not for sentences.
  static TextStyle wordmark(double size) =>
      GoogleFonts.reemKufi(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ).copyWith(
        fontFamilyFallback: const ['Apple Color Emoji', 'Noto Color Emoji'],
      );

  static ThemeData cosmic() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

    // google_fonts hands every style fontFamily 'Tajawal_regular' with
    // fontFamilyFallback ['Tajawal'] — both the same face, neither carrying
    // emoji glyphs, so the shaper has nothing to fall back to and every emoji
    // in the UI (the section-header 📝 / ✨) shapes as tofu. Keep 'Tajawal' at
    // the head of the chain and append the platform emoji faces behind it; a
    // family the platform lacks is skipped, so naming both is safe.
    const fallback = ['Tajawal', 'Apple Color Emoji', 'Noto Color Emoji'];
    final body = GoogleFonts.tajawalTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
      fontFamilyFallback: fallback,
    );
    // Headings stay in Tajawal, heavy. Reem Kufi was tried for them and is
    // beautiful for one word and tiring for a sentence — its geometric joins
    // run «أهلاً بعودتك» together — so it is kept for the wordmark alone
    // (see [wordmark]).
    final textTheme = body;

    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.pearl,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.accent,
      secondary: AppColors.accent,
      onSecondary: AppColors.pearl,
      secondaryContainer: Color(0xFFF1E4DC),
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.holoLavender,
      onTertiary: AppColors.pearl,
      error: AppColors.discount,
      onError: AppColors.pearl,
      surface: AppColors.surface,
      onSurface: AppColors.textDark,
      onSurfaceVariant: AppColors.textMuted,
      // Lowest → highest now runs white → blush, not near-black → violet.
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFFFFBF8),
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceHigh,
      surfaceContainerHighest: Color(0xFFEFE3DB),
      outline: Color(0x668E5F4A),
      outlineVariant: Color(0x1F3A2C26),
      shadow: AppColors.cardShadow,
      scrim: Color(0x66000000),
      // Inverse is the dark one now.
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.pearl,
      inversePrimary: AppColors.goldDeep,
      surfaceTint: Colors.transparent,
    );

    OutlineInputBorder field(Color color, [double width = 1.2]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    WidgetStateProperty<T> when<T>(
      T selected,
      T otherwise, {
      T? disabled,
      WidgetState state = WidgetState.selected,
    }) => WidgetStateProperty.resolveWith((s) {
      if (disabled != null && s.contains(WidgetState.disabled)) {
        return disabled;
      }
      return s.contains(state) ? selected : otherwise;
    });

    final goldButton = ButtonStyle(
      backgroundColor: when<Color>(
        AppColors.primary,
        AppColors.primary,
        disabled: AppColors.surfaceHigh,
        state: WidgetState.hovered,
      ),
      foregroundColor: when<Color>(
        AppColors.pearl,
        AppColors.pearl,
        disabled: AppColors.textMuted,
      ),
      overlayColor: WidgetStatePropertyAll(
        AppColors.champagne.withValues(alpha: 0.16),
      ),
      // Flat. A Material shadow under a rose-gold button draws a muddy ring
      // rather than lift, and the colour carries the button on its own.
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      textStyle: WidgetStatePropertyAll(
        textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );

    final title = textTheme.titleMedium!.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: 19,
      color: AppColors.textDark,
    );

    const edge = BorderSide(color: AppColors.hairline);

    return base.copyWith(
      colorScheme: scheme,
      // Every screen shows the sky behind it; see CosmicPage.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppColors.surface,
      cardColor: AppColors.surface,
      dividerColor: AppColors.hairline,
      splashColor: AppColors.primary.withValues(alpha: 0.16),
      highlightColor: AppColors.primary.withValues(alpha: 0.06),
      hoverColor: AppColors.primary.withValues(alpha: 0.08),
      focusColor: AppColors.accent.withValues(alpha: 0.14),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: const IconThemeData(color: AppColors.textDark),
      primaryIconTheme: const IconThemeData(color: AppColors.accent),
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.accent,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CosmicPageTransitionsBuilder(),
          TargetPlatform.iOS: CosmicPageTransitionsBuilder(),
          TargetPlatform.macOS: CosmicPageTransitionsBuilder(),
          TargetPlatform.windows: CosmicPageTransitionsBuilder(),
          TargetPlatform.linux: CosmicPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CosmicPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: overlay,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        actionsIconTheme: const IconThemeData(color: AppColors.accent),
        titleTextStyle: title,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.cardShadow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: edge,
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: edge,
        ),
        titleTextStyle: title,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textMuted,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceHigh,
        modalBackgroundColor: AppColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: AppColors.hairline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: edge,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: edge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.accent,
        ),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        border: field(AppColors.hairline),
        enabledBorder: field(AppColors.hairline),
        focusedBorder: field(AppColors.accent, 1.6),
        disabledBorder: field(AppColors.hairline.withValues(alpha: 0.12), 1),
        errorBorder: field(AppColors.discount),
        focusedErrorBorder: field(AppColors.discount, 1.6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: goldButton),
      filledButtonTheme: FilledButtonThemeData(style: goldButton),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.7),
            width: 1.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textDark),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.pearl,
        // Flat: the rose gold stands out on ivory without a shadow, and a
        // Material one draws a muddy rim.
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.surfaceHigh,
        circularTrackColor: Colors.transparent,
        refreshBackgroundColor: AppColors.surfaceHigh,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceHigh,
        selectedColor: AppColors.primary.withValues(alpha: 0.30),
        disabledColor: AppColors.surface,
        side: edge,
        checkmarkColor: AppColors.accent,
        labelStyle: textTheme.labelLarge?.copyWith(
          color: AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
        ),
        shape: const StadiumBorder(side: edge),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.accent,
        dividerColor: AppColors.hairline,
        labelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        overlayColor: WidgetStatePropertyAll(
          AppColors.primary.withValues(alpha: 0.10),
        ),
      ),
      // On: a pearl thumb on a gold track. Off: a muted thumb on glass.
      switchTheme: SwitchThemeData(
        thumbColor: when<Color>(AppColors.pearl, AppColors.textMuted),
        trackColor: when<Color>(AppColors.primary, AppColors.surfaceHigh),
        thumbIcon: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? const Icon(Icons.check_rounded, color: AppColors.pearl)
              : null,
        ),
        trackOutlineColor: when<Color>(Colors.transparent, AppColors.hairline),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: when<Color>(AppColors.primary, Colors.transparent),
        checkColor: const WidgetStatePropertyAll(AppColors.ink),
        side: const BorderSide(color: AppColors.textMuted, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: when<Color>(AppColors.accent, AppColors.textMuted),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.surfaceHigh,
        thumbColor: AppColors.pearl,
        overlayColor: AppColors.primary.withValues(alpha: 0.2),
        valueIndicatorColor: AppColors.surfaceHigh,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 0.8,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.accent,
        textColor: AppColors.textDark,
        selectedColor: AppColors.accent,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: AppColors.accent,
        collapsedIconColor: AppColors.textMuted,
        textColor: AppColors.textDark,
        collapsedTextColor: AppColors.textDark,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: AppColors.cardShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: edge,
        ),
        textStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textDark),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.hairline),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: AppColors.textDark),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.surface,
        headerForegroundColor: AppColors.accent,
        dividerColor: AppColors.hairline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: edge,
        ),
        dayForegroundColor: when<Color>(
          AppColors.pearl,
          AppColors.textDark,
          disabled: AppColors.textMuted.withValues(alpha: 0.4),
        ),
        dayBackgroundColor: when<Color>(AppColors.accent, Colors.transparent),
        todayForegroundColor: when<Color>(AppColors.pearl, AppColors.accent),
        todayBackgroundColor: when<Color>(AppColors.accent, Colors.transparent),
        todayBorder: const BorderSide(color: AppColors.accent),
        yearForegroundColor: when<Color>(AppColors.pearl, AppColors.textDark),
        yearBackgroundColor: when<Color>(AppColors.accent, Colors.transparent),
        rangeSelectionBackgroundColor: AppColors.primary.withValues(
          alpha: 0.22,
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surfaceHigh,
        dialBackgroundColor: AppColors.surface,
        dialHandColor: AppColors.primary,
        dialTextColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.pearl
              : AppColors.textDark,
        ),
        hourMinuteColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary.withValues(alpha: 0.28)
              : AppColors.surface,
        ),
        hourMinuteTextColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.textDark,
        ),
        dayPeriodColor: AppColors.primary.withValues(alpha: 0.28),
        dayPeriodTextColor: AppColors.textDark,
        entryModeIconColor: AppColors.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: edge,
        ),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.discount,
        textColor: AppColors.pearl,
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: AppColors.surface),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.primary.withValues(alpha: 0.35),
        selectionHandleColor: AppColors.accent,
      ),
    );
  }
}
