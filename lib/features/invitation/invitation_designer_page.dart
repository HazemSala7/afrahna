import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../core/utils/link_launcher.dart';
import '../../widgets/app_widgets.dart';

/// Afrahna's WhatsApp — where the finished invitation order is sent.
const String _kAfrahnaWhatsapp = '972599252493';

// ===========================================================================
// THEMES & FONTS
// ===========================================================================

/// Border / ornament style of the card frame.
enum _Frame { doubleLine, corners, inset, band, minimal }

/// Decorative divider between sections.
enum _Divider { dots, diamond, floral, line, sparkles }

/// Overall arrangement of the content (moves the text around).
enum _Layout { classic, namesTop }

class _CardTheme {
  const _CardTheme({
    required this.name,
    required this.bg,
    required this.ink,
    required this.accent,
    required this.subtle,
    this.frame = _Frame.doubleLine,
    this.divider = _Divider.dots,
    this.motif = '',
    this.layout = _Layout.classic,
  });
  final String name;
  final List<Color> bg; // background gradient (topRight → bottomLeft)
  final Color ink; // primary text colour
  final Color accent; // ornaments / dividers / title
  final Color subtle; // secondary text
  final _Frame frame;
  final _Divider divider;
  final String motif; // emoji shown above the title ('' = none)
  final _Layout layout;
}

const _themes = <_CardTheme>[
  _CardTheme(
    name: 'كلاسيك ذهبي',
    bg: [Color(0xFFFDF7EC), Color(0xFFF3E4C6)],
    ink: Color(0xFF4A3B24),
    accent: Color(0xFFB8860B),
    subtle: Color(0xFF7A6A55),
    frame: _Frame.doubleLine,
    divider: _Divider.dots,
    motif: '💍',
  ),
  _CardTheme(
    name: 'وردي مزهّر',
    bg: [Color(0xFFFFF3F5), Color(0xFFF7DCE3)],
    ink: Color(0xFF6B2740),
    accent: Color(0xFFC77D97),
    subtle: Color(0xFF9C6B79),
    frame: _Frame.corners,
    divider: _Divider.floral,
    motif: '🌸',
  ),
  _CardTheme(
    name: 'أخضر زيتي',
    bg: [Color(0xFFF2F5EC), Color(0xFFDCE6CC)],
    ink: Color(0xFF33422A),
    accent: Color(0xFF8A9A5B),
    subtle: Color(0xFF6B7358),
    frame: _Frame.inset,
    divider: _Divider.line,
    motif: '🌿',
  ),
  _CardTheme(
    name: 'ملكي كحلي',
    bg: [Color(0xFF1F2A44), Color(0xFF141C30)],
    ink: Color(0xFFF3E9D2),
    accent: Color(0xFFD9B45B),
    subtle: Color(0xFFB9C0D0),
    frame: _Frame.band,
    divider: _Divider.diamond,
    motif: '👑',
    layout: _Layout.namesTop,
  ),
  _CardTheme(
    name: 'رخامي مودرن',
    bg: [Color(0xFFF7F6F4), Color(0xFFE7E3DD)],
    ink: Color(0xFF3A3A3A),
    accent: Color(0xFFB89968),
    subtle: Color(0xFF7C7C7C),
    frame: _Frame.minimal,
    divider: _Divider.sparkles,
    motif: '✨',
    layout: _Layout.namesTop,
  ),
  _CardTheme(
    name: 'برونزي دافئ',
    bg: [Color(0xFFF6ECE1), Color(0xFFE4C9A8)],
    ink: Color(0xFF4A2E1C),
    accent: Color(0xFFA9702F),
    subtle: Color(0xFF806250),
    frame: _Frame.doubleLine,
    divider: _Divider.diamond,
    motif: '❦',
  ),
  _CardTheme(
    name: 'أبيض أنيق',
    bg: [Color(0xFFFFFFFF), Color(0xFFF3F0EA)],
    ink: Color(0xFF2C2C2C),
    accent: Color(0xFFC0A46B),
    subtle: Color(0xFF8A8A8A),
    frame: _Frame.corners,
    divider: _Divider.line,
    motif: '🕊️',
  ),
  _CardTheme(
    name: 'ليلكي راقٍ',
    bg: [Color(0xFFF6F1FA), Color(0xFFE6DAF2)],
    ink: Color(0xFF43325C),
    accent: Color(0xFF9B79C7),
    subtle: Color(0xFF7C6B90),
    frame: _Frame.inset,
    divider: _Divider.floral,
    motif: '❀',
  ),
  _CardTheme(
    name: 'أسود فخم',
    bg: [Color(0xFF23211E), Color(0xFF14120F)],
    ink: Color(0xFFF0E6D2),
    accent: Color(0xFFD9B45B),
    subtle: Color(0xFFB6AC97),
    frame: _Frame.band,
    divider: _Divider.sparkles,
    motif: '✦',
    layout: _Layout.namesTop,
  ),
  _CardTheme(
    name: 'فيروزي هادئ',
    bg: [Color(0xFFEDF7F5), Color(0xFFCDE7E1)],
    ink: Color(0xFF1E4A44),
    accent: Color(0xFF3E9B8E),
    subtle: Color(0xFF5E827C),
    frame: _Frame.minimal,
    divider: _Divider.dots,
    motif: '🌊',
  ),
];

typedef _FontApply = TextStyle Function(TextStyle base);

class _CardFont {
  const _CardFont(this.name, this.apply);
  final String name;
  final _FontApply apply;
}

final _fonts = <_CardFont>[
  _CardFont('أميري', (b) => GoogleFonts.amiri(textStyle: b)),
  _CardFont('عارف رقعة', (b) => GoogleFonts.arefRuqaa(textStyle: b)),
  _CardFont('ريم كوفي', (b) => GoogleFonts.reemKufi(textStyle: b)),
  _CardFont('المسيري', (b) => GoogleFonts.elMessiri(textStyle: b)),
  _CardFont('لطيف', (b) => GoogleFonts.lateef(textStyle: b)),
  _CardFont('تجوّل', (b) => GoogleFonts.tajawal(textStyle: b)),
];

// ===========================================================================
// FIELDS
// ===========================================================================

class _FieldSpec {
  const _FieldSpec(this.key, this.label, this.initial, {this.maxLines = 1});
  final String key;
  final String label;
  final String initial;
  final int maxLines;
}

const _specs = <_FieldSpec>[
  _FieldSpec('intro', 'عبارة الافتتاح',
      'ومن آياته أن خلق لكم من أنفسكم أزواجاً لتسكنوا إليها\nيسعدنا ويشرّفنا حضوركم ومشاركتنا فرحتنا',
      maxLines: 3),
  _FieldSpec('title', 'عنوان الفرح', 'أفراح عائلة [العريس] و عائلة [العروس]'),
  _FieldSpec('groom', 'العريس / عائلته', '[اسم والد العريس]'),
  _FieldSpec('bride', 'العروس / عائلتها', '[اسم والد العروس]'),
  _FieldSpec('invite', 'عبارة الدعوة',
      'يتشرّفون بدعوتكم لحضور حفل الزفاف'),
  _FieldSpec('names', 'أسماء العروسين', '[العريس]  &  [العروس]'),
  _FieldSpec('datetime', 'التاريخ والوقت',
      'يوم [اليوم] الموافق [التاريخ] — الساعة [الوقت]'),
  _FieldSpec('venue', 'القاعة والمكان', '[اسم القاعة] — [الموقع]'),
  _FieldSpec('program', 'تفاصيل البرنامج',
      '• استقبال المدعوّين الساعة [الوقت]\n• تقبّل التهاني بعد العشاء\n• حفل الزفاف الساعة [الوقت]',
      maxLines: 4),
  _FieldSpec('footer', 'عبارة ختامية', 'دامت الأفراح حليفة دياركم العامرة'),
];

// ===========================================================================
// PAGE
// ===========================================================================

class InvitationDesignerPage extends StatefulWidget {
  const InvitationDesignerPage({super.key});

  @override
  State<InvitationDesignerPage> createState() => _InvitationDesignerPageState();
}

class _InvitationDesignerPageState extends State<InvitationDesignerPage> {
  final _cardKey = GlobalKey();
  late final Map<String, TextEditingController> _ctrls = {
    for (final s in _specs) s.key: TextEditingController(text: s.initial),
  };

  int _theme = 0;
  int _font = 0;
  bool _sharing = false;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _v(String key) => _ctrls[key]?.text.trim() ?? '';

  /// Order summary sent to Afrahna (WhatsApp text + image caption).
  String _orderMessage() {
    final b = StringBuffer()
      ..writeln('🎉 طلب تصميم كرت فرح من تطبيق أفراحنا')
      ..writeln('— — — — —')
      ..writeln('🎨 القالب: ${_themes[_theme].name}')
      ..writeln('✍️ الخط: ${_fonts[_font].name}')
      ..writeln('— — — — —');
    for (final s in _specs) {
      final val = _v(s.key);
      if (val.isNotEmpty) b.writeln('${s.label}:\n$val\n');
    }
    return b.toString().trim();
  }

  Future<void> _orderViaWhatsapp() async {
    final msg = Uri.encodeComponent(_orderMessage());
    final ok = await openExternal(
        Uri.parse('https://wa.me/$_kAfrahnaWhatsapp?text=$msg'));
    if (!ok && mounted) {
      _snack('تعذّر فتح واتساب');
    }
  }

  Future<void> _shareAsImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      // Let the off-screen copy finish painting before we grab it.
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('no boundary');
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw Exception('no bytes');
      final bytes = data.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/afrahna_card_${DateTime.now().microsecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: _orderMessage());
    } catch (_) {
      if (mounted) _snack('تعذّر إنشاء صورة الكرت');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final theme = _themes[_theme];
    final font = _fonts[_font];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PinkAppBar(title: 'صمّم كرت فرحك'),
      body: Stack(
        children: [
          Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                // ---- Live preview (visible; the export copy lives off-screen
                // below so image capture works even when this scrolls away) ----
                Center(
                  child: _CardPreview(
                    theme: theme,
                    font: font,
                    values: {for (final s in _specs) s.key: _v(s.key)},
                  ),
                ),
                const SizedBox(height: 20),

                // ---- Theme picker ----
                const _MiniHeader(icon: Icons.palette_rounded, text: 'القالب'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _themes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _ChoiceChip(
                      label: _themes[i].name,
                      selected: i == _theme,
                      swatch: _themes[i].bg.first,
                      onTap: () => setState(() => _theme = i),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ---- Font picker ----
                const _MiniHeader(icon: Icons.text_fields_rounded, text: 'الخط'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _fonts.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _ChoiceChip(
                      label: _fonts[i].name,
                      selected: i == _font,
                      labelStyle: _fonts[i].apply(const TextStyle(fontSize: 14)),
                      onTap: () => setState(() => _font = i),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ---- Text fields ----
                const _MiniHeader(
                    icon: Icons.edit_rounded, text: 'محتوى الكرت'),
                const SizedBox(height: 10),
                for (final s in _specs) ...[
                  _FieldEditor(
                    label: s.label,
                    controller: _ctrls[s.key]!,
                    maxLines: s.maxLines,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),

          // ---- Bottom action bar ----
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
                14, 10, 14, 10 + MediaQuery.of(context).padding.bottom),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sharing ? null : _shareAsImage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _sharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.ios_share_rounded, size: 19),
                    label: const Text('صورة',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _orderViaWhatsapp,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 20),
                    label: const Text('اطلب عبر أفراحنا',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14.5)),
                  ),
                ),
              ],
            ),
          ),
        ],
          ),
          // Off-screen export copy — always laid out & painted, so the image
          // capture works no matter where the editor is scrolled.
          Positioned(
            left: -3000,
            top: 0,
            child: RepaintBoundary(
              key: _cardKey,
              child: _CardPreview(
                theme: theme,
                font: font,
                values: {for (final s in _specs) s.key: _v(s.key)},
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// CARD PREVIEW
// ===========================================================================

class _CardPreview extends StatelessWidget {
  const _CardPreview({
    required this.theme,
    required this.font,
    required this.values,
  });
  final _CardTheme theme;
  final _CardFont font;
  final Map<String, String> values;

  TextStyle _s({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.4,
    double spacing = 0,
  }) =>
      font.apply(TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color ?? theme.ink,
        height: height,
        letterSpacing: spacing,
      ));

  String _g(String k) => values[k] ?? '';

  /// Section divider — its ornament depends on the theme's divider style.
  Widget _divider() {
    final a = theme.accent;
    Widget centre;
    switch (theme.divider) {
      case _Divider.diamond:
        centre = Transform.rotate(
            angle: 0.785,
            child: Container(width: 6, height: 6, color: a));
        break;
      case _Divider.floral:
        centre = Text('❀', style: TextStyle(fontSize: 12, color: a));
        break;
      case _Divider.sparkles:
        centre = Text('✦', style: TextStyle(fontSize: 11, color: a));
        break;
      case _Divider.line:
        centre = const SizedBox.shrink();
        break;
      case _Divider.dots:
        centre = Icon(Icons.brightness_1, size: 5, color: a);
        break;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 40, height: 1, color: a),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8), child: centre),
          Container(width: 40, height: 1, color: a),
        ],
      ),
    );
  }

  Widget _titleBlock() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (theme.motif.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(theme.motif, style: const TextStyle(fontSize: 20)),
            ),
          if (_g('title').isNotEmpty)
            Text(_g('title'),
                textAlign: TextAlign.center,
                style: _s(
                    size: 22,
                    weight: FontWeight.w700,
                    color: theme.accent,
                    height: 1.4)),
        ],
      );

  Widget _couple() => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(_g('groom'),
                textAlign: TextAlign.center,
                style: _s(size: 14, weight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.favorite, size: 16, color: theme.accent),
          ),
          Expanded(
            child: Text(_g('bride'),
                textAlign: TextAlign.center,
                style: _s(size: 14, weight: FontWeight.w700)),
          ),
        ],
      );

  Widget _names() => Text(_g('names'),
      textAlign: TextAlign.center,
      style: _s(size: 22, weight: FontWeight.w700, color: theme.accent));

  Widget _dateVenue() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_g('datetime').isNotEmpty)
            Text(_g('datetime'),
                textAlign: TextAlign.center,
                style: _s(size: 13, weight: FontWeight.w600)),
          if (_g('venue').isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 14, color: theme.accent),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(_g('venue'),
                      textAlign: TextAlign.center,
                      style: _s(size: 12.5, color: theme.subtle)),
                ),
              ],
            ),
          ],
        ],
      );

  Widget _program() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(_g('program'),
            textAlign: TextAlign.center,
            style: _s(size: 11.5, color: theme.subtle, height: 1.9)),
      );

  @override
  Widget build(BuildContext context) {
    // Content arrangement — "namesTop" leads with the couple's names.
    final content = <Widget>[];
    void add(Widget w) => content.add(w);

    if (theme.layout == _Layout.namesTop) {
      if (theme.motif.isNotEmpty) {
        add(Text(theme.motif, style: const TextStyle(fontSize: 22)));
        add(const SizedBox(height: 6));
      }
      if (_g('names').isNotEmpty) add(_names());
      add(_divider());
      add(_couple());
      if (_g('invite').isNotEmpty) {
        add(const SizedBox(height: 10));
        add(Text(_g('invite'),
            textAlign: TextAlign.center,
            style: _s(size: 13, color: theme.subtle)));
      }
      if (_g('title').isNotEmpty) {
        add(const SizedBox(height: 10));
        add(Text(_g('title'),
            textAlign: TextAlign.center,
            style: _s(size: 15, weight: FontWeight.w700, color: theme.accent)));
      }
      add(_divider());
      add(_dateVenue());
      if (_g('program').isNotEmpty) {
        add(const SizedBox(height: 12));
        add(_program());
      }
      if (_g('intro').isNotEmpty) {
        add(const SizedBox(height: 12));
        add(Text(_g('intro'),
            textAlign: TextAlign.center,
            style: _s(size: 11.5, color: theme.subtle, height: 1.7)));
      }
    } else {
      // classic
      if (_g('intro').isNotEmpty) {
        add(Text(_g('intro'),
            textAlign: TextAlign.center,
            style: _s(size: 12.5, color: theme.subtle, height: 1.7)));
      }
      add(_divider());
      add(_titleBlock());
      add(const SizedBox(height: 12));
      add(_couple());
      if (_g('invite').isNotEmpty) {
        add(const SizedBox(height: 12));
        add(Text(_g('invite'),
            textAlign: TextAlign.center,
            style: _s(size: 13, color: theme.subtle)));
      }
      if (_g('names').isNotEmpty) {
        add(const SizedBox(height: 8));
        add(Text(_g('names'),
            textAlign: TextAlign.center,
            style: _s(size: 19, weight: FontWeight.w700, color: theme.accent)));
      }
      add(_divider());
      add(_dateVenue());
      if (_g('program').isNotEmpty) {
        add(const SizedBox(height: 12));
        add(_program());
      }
    }

    if (_g('footer').isNotEmpty) {
      add(const SizedBox(height: 12));
      add(Text(_g('footer'),
          textAlign: TextAlign.center,
          style: _s(size: 12.5, weight: FontWeight.w600, color: theme.accent)));
    }
    add(const SizedBox(height: 16));
    // Afrahna signature (bottom corner watermark).
    add(Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.diamond_rounded,
              size: 11, color: theme.accent.withValues(alpha: 0.75)),
          const SizedBox(width: 4),
          Text('أفراحنا',
              style: _s(
                  size: 11,
                  weight: FontWeight.w700,
                  color: theme.accent.withValues(alpha: 0.75))),
        ],
      ),
    ));

    return Container(
      width: 320,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: theme.bg,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _FramePainter(frame: theme.frame, accent: theme.accent),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              22, theme.frame == _Frame.band ? 30 : 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: content,
          ),
        ),
      ),
    );
  }
}

/// Draws the decorative border of the card — a different look per [_Frame].
class _FramePainter extends CustomPainter {
  _FramePainter({required this.frame, required this.accent});
  final _Frame frame;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = accent.withValues(alpha: 0.75);
    final r = Offset.zero & size;

    switch (frame) {
      case _Frame.doubleLine:
        final outer = r.deflate(10);
        canvas.drawRRect(
            RRect.fromRectAndRadius(outer, const Radius.circular(8)), p);
        final inner = r.deflate(15);
        canvas.drawRRect(
            RRect.fromRectAndRadius(inner, const Radius.circular(6)),
            p..strokeWidth = 0.7);
        break;
      case _Frame.inset:
        final rect = r.deflate(12);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)), p);
        break;
      case _Frame.corners:
        // Only ornamental L-shapes at the four corners.
        const m = 14.0, len = 26.0;
        void corner(double x, double y, double dx, double dy) {
          canvas.drawLine(Offset(x, y), Offset(x + dx * len, y), p);
          canvas.drawLine(Offset(x, y), Offset(x, y + dy * len), p);
          canvas.drawCircle(Offset(x, y), 2.2, Paint()..color = accent);
        }

        corner(m, m, 1, 1);
        corner(size.width - m, m, -1, 1);
        corner(m, size.height - m, 1, -1);
        corner(size.width - m, size.height - m, -1, -1);
        break;
      case _Frame.band:
        // Filled accent bands top & bottom + a hairline frame.
        final band = Paint()..color = accent.withValues(alpha: 0.16);
        canvas.drawRect(
            Rect.fromLTWH(0, 0, size.width, 14), band);
        canvas.drawRect(
            Rect.fromLTWH(0, size.height - 14, size.width, 14), band);
        canvas.drawRRect(
            RRect.fromRectAndRadius(r.deflate(6), const Radius.circular(6)),
            p..strokeWidth = 0.8);
        break;
      case _Frame.minimal:
        // A single thin baseline accent under the top area — airy look.
        canvas.drawLine(Offset(size.width * 0.32, 16),
            Offset(size.width * 0.68, 16), p..strokeWidth = 1);
        break;
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.frame != frame || old.accent != accent;
}

// ===========================================================================
// SMALL WIDGETS
// ===========================================================================

class _MiniHeader extends StatelessWidget {
  const _MiniHeader({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: AppColors.textDark)),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.swatch,
    this.labelStyle,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? swatch;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.primaryLight,
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (swatch != null) ...[
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12),
                ),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: (labelStyle ?? const TextStyle()).copyWith(
                color: selected ? Colors.white : AppColors.textDark,
                fontWeight: FontWeight.w800,
                fontSize: labelStyle?.fontSize ?? 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldEditor extends StatelessWidget {
  const _FieldEditor({
    required this.label,
    required this.controller,
    required this.maxLines,
    required this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: AppColors.textMuted)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          maxLines: maxLines,
          minLines: 1,
          onChanged: (_) => onChanged(),
          style: const TextStyle(fontSize: 14, color: AppColors.textDark),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
