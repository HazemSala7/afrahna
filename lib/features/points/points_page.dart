import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../auth/login_page.dart';

/// "نقاطي" — the user's rewards screen: balance, where the points came from,
/// where they were spent, and an invite section to earn more.
class PointsPage extends StatefulWidget {
  const PointsPage({super.key});

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  Future<PointsSummary>? _future;

  @override
  void initState() {
    super.initState();
    if (context.read<SessionController>().isSignedIn) {
      _future = PointsService().summary();
    }
  }

  void _reload() => setState(() => _future = PointsService().summary());

  IconData _catIcon(String key) {
    switch (key) {
      case 'signup':
        return Icons.person_add_alt_1_rounded;
      case 'invite':
        return Icons.group_add_rounded;
      case 'reel_like':
        return Icons.favorite_rounded;
      case 'reel_comment':
        return Icons.mode_comment_rounded;
      case 'post_like':
        return Icons.thumb_up_rounded;
      case 'post_comment':
        return Icons.comment_rounded;
      case 'review':
        return Icons.star_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (!session.isSignedIn) {
      return AppScaffold(
        appBar: const PinkAppBar(title: 'نقاطي'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded,
                    size: 72, color: AppColors.primary),
                const SizedBox(height: 14),
                const Text('سجّل الدخول لعرض نقاطك ومكافآتك',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LoginPage())),
                  child: const Text('تسجيل الدخول'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppScaffold(
      appBar: const PinkAppBar(title: 'نقاطي'),
      body: FutureBuilder<PointsSummary>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CenteredLoader();
          }
          if (snap.hasError) {
            return ErrorState(
                message: snap.error.toString(), onRetry: _reload);
          }
          final s = snap.data!;
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                _balanceCard(s),
                const SizedBox(height: 16),
                _inviteCard(s),
                const SizedBox(height: 16),
                _earnedSection(s),
                const SizedBox(height: 16),
                _spentSection(s),
                const SizedBox(height: 16),
                _howToRedeem(s),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---- Balance hero ------------------------------------------------------

  Widget _balanceCard(PointsSummary s) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: BoxDecoration(
        gradient: AppColors.brandDeepGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.stars_rounded, color: Colors.white, size: 34),
          const SizedBox(height: 8),
          Text(
            '${s.balance}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 46,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text('نقطة',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('رصيدك من نقاط أفراحنا',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ---- Invite friends ----------------------------------------------------

  Widget _inviteCard(PointsSummary s) {
    final code = s.referralCode ?? '';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group_add_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('ادعُ أصدقاءك',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        fontSize: 16)),
              ),
              if (s.invitesCount > 0)
                Text('${s.invitesCount} صديق',
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('كل 10 دعوات = نقطة. شارك كودك وليُدخله صديقك عند التسجيل.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 12),
          if (code.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _copyCode(code),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: .5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: .3)),
                      ),
                      child: Row(
                        children: [
                          Text(code,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 2,
                                  color: AppColors.primaryDark)),
                          const Spacer(),
                          const Icon(Icons.copy_rounded,
                              size: 18, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _shareCode(code),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('مشاركة'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ---- Earned breakdown --------------------------------------------------

  Widget _earnedSection(PointsSummary s) {
    final entries = s.breakdown.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(icon: Icons.trending_up_rounded, text: 'من أين اكتسبت نقاطك'),
          const SizedBox(height: 4),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('ابدأ بالتفاعل (لايكات، تعليقات، تقييمات) لتجمع النقاط.',
                  style: TextStyle(color: AppColors.textMuted)),
            )
          else
            ...entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Icon(_catIcon(e.key), size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(PointsSummary.categoryLabel(e.key),
                            style: const TextStyle(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w600)),
                      ),
                      Text('${e.value} نقطة',
                          style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // ---- Spend history -----------------------------------------------------

  Widget _spentSection(PointsSummary s) {
    final df = DateFormat('d MMM y', 'ar');
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
              icon: Icons.redeem_rounded, text: 'أين أنفقت نقاطك'),
          const SizedBox(height: 4),
          if (s.redemptions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('لم تستبدل أي نقاط بعد.',
                  style: TextStyle(color: AppColors.textMuted)),
            )
          else
            ...s.redemptions.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded,
                          size: 20, color: AppColors.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.vendorName ?? 'معلن',
                                style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w700)),
                            if (r.createdAt != null)
                              Text(df.format(r.createdAt!),
                                  style: const TextStyle(
                                      color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text('- ${r.points}',
                          style: const TextStyle(
                              color: AppColors.discount,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // ---- How to redeem info ------------------------------------------------

  Widget _howToRedeem(PointsSummary s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_rounded, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'استبدل ${s.redeemCost} نقطة لدى أي معلن للحصول على خصم ${s.redeemDiscount}% — مرة واحدة كل 24 ساعة لكل معلن. اذهب إلى صفحة المعلن واضغط «استبدال النقاط».',
              style: const TextStyle(
                  color: AppColors.textDark, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ---- helpers -----------------------------------------------------------

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: child,
      );

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ كود الدعوة')),
    );
  }

  void _shareCode(String code) {
    // Share a LINK, not just the code: it opens the app straight to sign-up
    // when installed, and otherwise lands on a page that sends the friend to
    // the right store (Android or iPhone) with the code on their clipboard.
    // The code stays in the text as a fallback for anyone who types it by hand.
    final link = 'https://afrahna.co/r/$code';
    Share.share(
      'انضم إلى تطبيق أفراحنا 🎉\n'
      'سجّل من هذا الرابط ليصلنا كلانا نقاط:\n$link\n\n'
      'أو أدخل كود الدعوة عند التسجيل: $code',
      subject: 'دعوة أفراحنا',
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                fontSize: 16)),
      ],
    );
  }
}
