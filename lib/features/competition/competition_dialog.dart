import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/device_id.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../core/utils/link_launcher.dart';
import '../../widgets/app_widgets.dart';
import '../vendors/vendor_details_page.dart';

bool _predicted = false; // user already voted
bool _showing = false; // a dialog is currently open (avoid double-show)
bool _loaded = false; // fetched the competition once
CompetitionModel? _cached;
PredictionModel? _myPrediction; // the user's saved prediction (once voted)

/// Shows the competition popup EVERY time the user lands on the home tab:
///   • hasn't voted yet → the "predict & win" dialog,
///   • already voted     → a recap of their own prediction + follow-us links.
Future<void> maybeShowCompetition(BuildContext context) async {
  if (_showing) return;
  _showing = true;
  try {
    if (!_loaded) {
      final deviceId = await DeviceId.get();
      final res = await CompetitionService().getActive(deviceId: deviceId);
      _cached = res.competition;
      _myPrediction = res.prediction;
      if (res.prediction != null) _predicted = true;
      _loaded = true; // only reached on a successful fetch
    }
    if (_cached == null || !context.mounted) return;

    // Already voted → show them what they predicted, every time.
    if (_predicted) {
      final mine = _myPrediction;
      if (mine == null) return; // voted but nothing to recap
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) =>
            _MyPredictionDialog(competition: _cached!, prediction: mine),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _CompetitionDialog(competition: _cached!),
    );
  } catch (_) {
    // Leave `_loaded` false so it retries next time; never block the app.
  } finally {
    _showing = false;
  }
}

Future<void> _openLink(String? raw, {String? kind}) async {
  if (raw == null || raw.trim().isEmpty) return;
  final v = raw.trim();
  Uri uri;
  if (v.startsWith('http')) {
    uri = Uri.parse(v);
  } else if (kind == 'whatsapp') {
    uri = Uri.parse('https://wa.me/${v.replaceAll(RegExp(r'\D'), '')}');
  } else if (kind == 'instagram') {
    uri = Uri.parse('https://instagram.com/${v.replaceAll('@', '')}');
  } else if (kind == 'facebook') {
    uri = Uri.parse('https://facebook.com/$v');
  } else if (kind == 'tiktok') {
    uri = Uri.parse('https://www.tiktok.com/@${v.replaceAll('@', '')}');
  } else {
    uri = Uri.parse('https://$v');
  }
  await openExternal(uri);
}

(String, String) _splitScore(String? s) {
  if (s == null || s.trim().isEmpty) return ('-', '-');
  final parts = s.split(RegExp(r'[-:xX×]'));
  if (parts.length >= 2) return (parts[0].trim(), parts[1].trim());
  return (s.trim(), '-');
}

const _gold = LinearGradient(colors: [Color(0xFFF4C64B), Color(0xFFC8901E)]);

class _CompetitionDialog extends StatefulWidget {
  const _CompetitionDialog({required this.competition});
  final CompetitionModel competition;

  @override
  State<_CompetitionDialog> createState() => _CompetitionDialogState();
}

class _CompetitionDialogState extends State<_CompetitionDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  PredictionModel? _prediction;
  bool _saving = false;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final c = widget.competition;
    final a = int.tryParse(_a.text.trim());
    final b = int.tryParse(_b.text.trim());
    if (a == null || b == null) {
      _snack('اكتب توقّعك لنتيجة الفريقين');
      return;
    }
    // Predicting requires an account. Guests get a quick signup dialog.
    if (!context.read<SessionController>().isSignedIn) {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _QuickSignupDialog(),
      );
      if (ok != true || !mounted) return;
    }
    final winner = a > b ? c.teamAName : (b > a ? c.teamBName : 'تعادل');
    final score = '$a-$b';
    setState(() => _saving = true);
    try {
      final deviceId = await DeviceId.get();
      final p = await CompetitionService().predict(
        c.id,
        winner: winner,
        score: score,
        deviceId: deviceId,
        platform: DeviceId.platform(),
      );
      if (!mounted) return;
      // From now on the home popup shows the recap of this prediction instead.
      _predicted = true;
      _myPrediction = p;
      setState(() {
        _prediction = p;
        _saving = false;
      });
      Navigator.of(context).pop();
      await showDialog<void>(
        context: context,
        builder: (_) => _FollowPagesDialog(competition: c),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(e.message);
      }
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final c = widget.competition;
    final voted = _prediction != null;

    return Dialog(
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.86, maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- Header ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: const BoxDecoration(gradient: AppColors.brandDeepGradient),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          color: Color(0xFFF4C64B), size: 30),
                      const SizedBox(height: 4),
                      Text(c.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              shadows: [Shadow(blurRadius: 6, color: Colors.black38)])),
                    ],
                  ),
                  PositionedDirectional(
                    top: -4,
                    end: -4,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.close, size: 17, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Column(
                  children: [
                    if ((c.description ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(c.description!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                                height: 1.6)),
                      ),
                    if (c.sponsor != null) _SponsorCard(vendor: c.sponsor!),
                    const SizedBox(height: 16),

                    // Actual final result (once known).
                    if (c.hasResult) ...[
                      _ScoreCard(
                        label: 'النتيجة النهائية',
                        teamA: c.teamAName,
                        flagA: c.teamAFlag,
                        teamB: c.teamBName,
                        flagB: c.teamBFlag,
                        score: c.resultScore,
                        gold: false,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // The user's prediction (read-only) or the input form.
                    if (voted)
                      _ScoreCard(
                        label: 'توقّعك',
                        teamA: c.teamAName,
                        flagA: c.teamAFlag,
                        teamB: c.teamBName,
                        flagB: c.teamBFlag,
                        score: _prediction!.score,
                        gold: true,
                      )
                    else
                      _EditScoreCard(
                        teamA: c.teamAName,
                        flagA: c.teamAFlag,
                        teamB: c.teamBName,
                        flagB: c.teamBFlag,
                        aCtrl: _a,
                        bCtrl: _b,
                        saving: _saving,
                        onSubmit: _submit,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A team's flag + name.
class _TeamHead extends StatelessWidget {
  const _TeamHead({required this.name, this.flag, this.size = 56});
  final String name;
  final String? flag;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryLight.withValues(alpha: 0.35),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: (flag != null && flag!.isNotEmpty)
              ? AppNetworkImage(url: flag, fit: BoxFit.cover, fallbackIcon: Icons.flag)
              : const Icon(Icons.flag, color: AppColors.primary),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: size + 14,
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 12.5)),
        ),
      ],
    );
  }
}

/// Read-only scoreboard (FIFA-style card): flag  score - score  flag.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.label,
    required this.teamA,
    required this.teamB,
    required this.score,
    this.flagA,
    this.flagB,
    this.gold = false,
  });
  final String label;
  final String teamA;
  final String teamB;
  final String? score;
  final String? flagA;
  final String? flagB;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final (a, b) = _splitScore(score);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: gold
                ? const Color(0xFFF4C64B)
                : Colors.black.withValues(alpha: 0.05),
            width: gold ? 1.6 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              gradient: gold
                  ? _gold
                  : LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _TeamHead(name: teamA, flag: flagA, size: 50)),
              _bigScore(a),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('-',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textMuted)),
              ),
              _bigScore(b),
              Expanded(child: _TeamHead(name: teamB, flag: flagB, size: 50)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bigScore(String s) => Container(
        width: 40,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(s,
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark)),
      );
}

/// Editable scoreboard — the user types each team's score.
class _EditScoreCard extends StatelessWidget {
  const _EditScoreCard({
    required this.teamA,
    required this.teamB,
    required this.aCtrl,
    required this.bCtrl,
    required this.saving,
    required this.onSubmit,
    this.flagA,
    this.flagB,
  });
  final String teamA;
  final String teamB;
  final String? flagA;
  final String? flagB;
  final TextEditingController aCtrl;
  final TextEditingController bCtrl;
  final bool saving;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          const Text('توقّع النتيجة',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: AppColors.textDark)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _TeamHead(name: teamA, flag: flagA, size: 52)),
              _scoreInput(aCtrl),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('-',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textMuted)),
              ),
              _scoreInput(bCtrl),
              Expanded(child: _TeamHead(name: teamB, flag: flagB, size: 52)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: saving ? null : onSubmit,
              child: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('اعتمد',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreInput(TextEditingController ctrl) => SizedBox(
        width: 44,
        child: TextField(
          controller: ctrl,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 2,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          decoration: InputDecoration(
            counterText: '',
            hintText: '-',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );
}

class _SponsorCard extends StatelessWidget {
  const _SponsorCard({required this.vendor});
  final VendorModel vendor;

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VendorDetailsPage(vendorId: vendor.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                gradient: _gold, borderRadius: BorderRadius.circular(20)),
            child: const Text('الراعي الحصري والمميّز 👑',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12)),
          ),
          const SizedBox(height: 10),
          if ((vendor.cover ?? '').isNotEmpty)
            GestureDetector(
              onTap: () => _openProfile(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 7,
                  child: AppNetworkImage(
                      url: vendor.cover,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.storefront),
                ),
              ),
            ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _openProfile(context),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: AppNetworkImage(
                        url: vendor.logo ?? vendor.cover,
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.storefront),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(vendor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 15)),
                      if ((vendor.address ?? '').isNotEmpty)
                        Text(vendor.address!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left_rounded,
                    color: AppColors.textMuted, size: 22),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // The sponsor's OWN social accounts (the "أفراحنا" pages are shown
          // in the follow-us dialog after the user submits a prediction).
          Wrap(
            spacing: 8,
            children: [
              if ((vendor.facebook ?? '').isNotEmpty)
                _Social(
                    icon: FontAwesomeIcons.facebookF,
                    color: const Color(0xFF1877F2),
                    onTap: () => _openLink(vendor.facebook, kind: 'facebook')),
              if ((vendor.instagram ?? '').isNotEmpty)
                _Social(
                    icon: FontAwesomeIcons.instagram,
                    color: const Color(0xFFE1306C),
                    onTap: () => _openLink(vendor.instagram, kind: 'instagram')),
              if ((vendor.tiktok ?? '').isNotEmpty)
                _Social(
                    icon: FontAwesomeIcons.tiktok,
                    color: Colors.black,
                    onTap: () => _openLink(vendor.tiktok, kind: 'tiktok')),
              if ((vendor.whatsapp ?? '').isNotEmpty)
                _Social(
                    icon: FontAwesomeIcons.whatsapp,
                    color: const Color(0xFF25D366),
                    onTap: () => _openLink(vendor.whatsapp, kind: 'whatsapp')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Social extends StatelessWidget {
  const _Social({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, size: 18, color: color)),
    );
  }
}

/// Fast in-place signup so a guest can vote without leaving the competition.
class _QuickSignupDialog extends StatefulWidget {
  const _QuickSignupDialog();
  @override
  State<_QuickSignupDialog> createState() => _QuickSignupDialogState();
}

class _QuickSignupDialogState extends State<_QuickSignupDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final pass = _pass.text.trim();
    if (name.isEmpty || phone.length < 6 || pass.length < 3) {
      _snack('أدخل الاسم ورقمًا صحيحًا وكلمة مرور (3 أحرف على الأقل)');
      return;
    }
    setState(() => _busy = true);
    final session = context.read<SessionController>();
    final ok = await session.register(name: name, phone: phone, password: pass);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      _snack(session.error != null && session.error!.contains('phone')
          ? 'رقم الهاتف مستخدم مسبقًا'
          : 'تعذّر إنشاء الحساب — تأكّد من البيانات أو أنّ الرقم غير مستخدم');
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: 18 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('إنشاء حساب سريع 🎉',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                ),
                GestureDetector(
                  onTap: _busy ? null : () => Navigator.pop(context, false),
                  child: const Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('سجّل بسرعة لتشارك في التوقّع والفوز',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pass,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(48)),
                onPressed: _busy ? null : _create,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('إنشاء الحساب والمتابعة',
                        style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Follow our pages to know the winner" popup — shown after voting.
/// Shown on every home entry once the user has voted: a recap of their own
/// prediction (and the real result when it's known) plus the follow-us links.
class _MyPredictionDialog extends StatelessWidget {
  const _MyPredictionDialog({
    required this.competition,
    required this.prediction,
  });
  final CompetitionModel competition;
  final PredictionModel prediction;

  /// Did their pick match the announced result? (null while unknown)
  bool? get _isCorrect {
    if (!competition.hasResult) return null;
    return competition.resultWinner!.trim() == prediction.winner.trim();
  }

  @override
  Widget build(BuildContext context) {
    final c = competition;
    final correct = _isCorrect;
    final hasPages = (c.pageFacebook ?? '').isNotEmpty ||
        (c.pageInstagram ?? '').isNotEmpty ||
        (c.pageTiktok ?? '').isNotEmpty;

    return Dialog(
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- Gradient header ----
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                  gradient: AppColors.brandDeepGradient),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  const Text('🏆', style: TextStyle(fontSize: 30)),
                  const SizedBox(height: 6),
                  const Text(
                    'توقّعك محفوظ',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 19),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ---- Sponsor (same card as the vote dialog: tap the cover
                  // or the logo/name to open the sponsor's full profile) ----
                  if (c.sponsor != null) ...[
                    _SponsorCard(vendor: c.sponsor!),
                    const SizedBox(height: 14),
                  ],
                  // ---- Their prediction ----
                  _ScoreCard(
                    label: 'توقّعك',
                    teamA: c.teamAName,
                    teamB: c.teamBName,
                    score: prediction.score,
                    flagA: c.teamAFlag,
                    flagB: c.teamBFlag,
                    gold: true,
                  ),
                  const SizedBox(height: 10),
                  // Winner pick
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.emoji_events_rounded,
                            color: Color(0xFFC8901E), size: 17),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'توقّعت فوز ${prediction.winner}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ---- Real result, once announced ----
                  if (c.hasResult) ...[
                    const SizedBox(height: 12),
                    _ScoreCard(
                      label: 'النتيجة الفعلية',
                      teamA: c.teamAName,
                      teamB: c.teamBName,
                      score: c.resultScore,
                      flagA: c.teamAFlag,
                      flagB: c.teamBFlag,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: (correct == true
                                ? const Color(0xFF2E9E5B)
                                : const Color(0xFFC1452B))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        correct == true
                            ? '🎉 توقّعك صحيح! مبروك'
                            : '😔 توقّعك لم يكن صحيحاً هذه المرة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: correct == true
                              ? const Color(0xFF1E7A43)
                              : const Color(0xFFC1452B),
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    Text(
                      'بانتظار النتيجة النهائية… تابع صفحاتنا لمعرفة الفائز',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          height: 1.5),
                    ),
                  ],

                  // ---- Follow us ----
                  if (hasPages) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider(height: 1)),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'تابعنا على',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w800,
                                fontSize: 12),
                          ),
                        ),
                        const Expanded(child: Divider(height: 1)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if ((c.pageFacebook ?? '').isNotEmpty)
                          _Social(
                              icon: FontAwesomeIcons.facebookF,
                              color: const Color(0xFF1877F2),
                              onTap: () => _openLink(c.pageFacebook)),
                        if ((c.pageInstagram ?? '').isNotEmpty) ...[
                          const SizedBox(width: 14),
                          _Social(
                              icon: FontAwesomeIcons.instagram,
                              color: const Color(0xFFE1306C),
                              onTap: () => _openLink(c.pageInstagram)),
                        ],
                        if ((c.pageTiktok ?? '').isNotEmpty) ...[
                          const SizedBox(width: 14),
                          _Social(
                              icon: FontAwesomeIcons.tiktok,
                              color: Colors.black,
                              onTap: () => _openLink(c.pageTiktok)),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('تم',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowPagesDialog extends StatelessWidget {
  const _FollowPagesDialog({required this.competition});
  final CompetitionModel competition;

  @override
  Widget build(BuildContext context) {
    final c = competition;
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: const BoxDecoration(
                  gradient: AppColors.brandDeepGradient, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Text('💍', style: TextStyle(fontSize: 30)),
            ),
            const SizedBox(height: 14),
            const Text('تابع صفحات تطبيق أفراحنا لمعرفة الفائز',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 16, height: 1.5)),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if ((c.pageFacebook ?? '').isNotEmpty)
                  _Social(
                      icon: FontAwesomeIcons.facebookF,
                      color: const Color(0xFF1877F2),
                      onTap: () => _openLink(c.pageFacebook)),
                if ((c.pageInstagram ?? '').isNotEmpty) ...[
                  const SizedBox(width: 14),
                  _Social(
                      icon: FontAwesomeIcons.instagram,
                      color: const Color(0xFFE1306C),
                      onTap: () => _openLink(c.pageInstagram)),
                ],
                if ((c.pageTiktok ?? '').isNotEmpty) ...[
                  const SizedBox(width: 14),
                  _Social(
                      icon: FontAwesomeIcons.tiktok,
                      color: Colors.black,
                      onTap: () => _openLink(c.pageTiktok)),
                ],
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(46)),
                onPressed: () => Navigator.pop(context),
                child: const Text('تم',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
