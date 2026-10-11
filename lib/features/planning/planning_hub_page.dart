import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/cosmos.dart';
import '../auth/login_page.dart';
import '../calendar/calendar_page.dart';
import '../coordinator/coordinator_page.dart';
import '../invitations/invitations_page.dart';
import '../tasks/tasks_page.dart';

/// A single wedding-planning tool surfaced across the app (home page + the
/// dedicated planning tab).
class PlanningTool {
  const PlanningTool({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.tint,
    required this.builder,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color tint;
  final WidgetBuilder builder;
}

// Each tool defined once as a named const so the derived lists below can stay
// compile-time constants (needed for const default parameters).
const _invitationsTool = PlanningTool(
  icon: Icons.mail_rounded,
  label: 'دعوات إلكترونية',
  subtitle: 'صمّمي وأرسلي دعواتك بلمسة',
  tint: AppColors.holoRose,
  builder: _invitations,
);
const _tasksTool = PlanningTool(
  icon: Icons.checklist_rtl_rounded,
  label: 'قائمة المهام',
  subtitle: 'نظّمي كل تحضيرات فرحك',
  tint: AppColors.holoAqua,
  builder: _tasks,
);
const _calendarTool = PlanningTool(
  icon: Icons.calendar_month_rounded,
  label: 'التقويم الذكي',
  subtitle: 'مواعيدك ومناسباتك بمكان واحد',
  tint: AppColors.holoLavender,
  builder: _calendar,
);
const _coordinatorTool = PlanningTool(
  icon: Icons.assignment_rounded,
  label: 'منسق المناسبة',
  subtitle: 'خطّطي كل تفاصيل يومك خطوة بخطوة',
  tint: AppColors.accent,
  builder: _coordinator,
);

/// All planning tools, each lit in one colour of the holographic spectrum so
/// they read as a set and still tell apart at a glance.
const List<PlanningTool> kPlanningTools = [
  _invitationsTool,
  _tasksTool,
  _calendarTool,
  _coordinatorTool,
];

/// The "منسق المناسبة" tool, given its own prominent banner.
const PlanningTool kCoordinatorTool = _coordinatorTool;

/// The three secondary tools shown together in a single row.
const List<PlanningTool> kRowTools = [
  _invitationsTool,
  _tasksTool,
  _calendarTool,
];

// Const tear-offs so kPlanningTools can stay a compile-time constant.
Widget _invitations(BuildContext _) => const InvitationsPage();
Widget _tasks(BuildContext _) => const TasksPage();
Widget _calendar(BuildContext _) => const CalendarPage();
Widget _coordinator(BuildContext _) => const CoordinatorPage();

void _open(BuildContext context, PlanningTool tool) {
  // Planning tools store data per user, so they require an account. Guests are
  // prompted to log in instead of opening a page whose saves silently fail.
  if (!context.read<SessionController>().isSignedIn) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('سجّل الدخول لاستخدام أدوات التخطيط وحفظ بياناتك'),
        action: SnackBarAction(
          label: 'تسجيل الدخول',
          textColor: Colors.white,
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const LoginPage())),
        ),
      ),
    );
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(builder: tool.builder));
}

// ===========================================================================
// COORDINATOR HERO BANNER — the prominent, special banner
// ===========================================================================

/// The event-coordinator tool as the flagship of the planning tab: a pane of
/// deep-space glass with a holographic edge, the icon held in a turning ring,
/// the name in gold foil.
class PlanningCoordinatorBanner extends StatelessWidget {
  const PlanningCoordinatorBanner({super.key, this.tool = kCoordinatorTool});
  final PlanningTool tool;

  @override
  Widget build(BuildContext context) {
    const radius = 26.0;
    return GestureDetector(
      onTap: () => _open(context, tool),
      child: CustomPaint(
        foregroundPainter: const HoloBorderPainter(radius: radius, width: 1.3),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF8E5F4A), Color(0xFF4F2F27), Color(0xFF7E4440)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.18),
                blurRadius: 30,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Stack(
            children: [
              // A gold nebula behind the ring, and the orbit it sits on.
              const Positioned.fill(child: CustomPaint(painter: _BannerSky())),
              Positioned(
                left: -18,
                bottom: -26,
                child: Icon(
                  tool.icon,
                  size: 130,
                  color: AppColors.accent.withValues(alpha: 0.05),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                child: Row(
                  children: [
                    HoloRing(
                      size: 78,
                      stroke: 2,
                      gap: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFF8E5F4A), Color(0xFF4A2C24)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.35),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            tool.icon,
                            color: AppColors.accent,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: GoldFoilText(
                                  tool.label,
                                  maxLines: 1,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const _HoloChip(label: 'مميّز'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tool.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.champagne.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const GoldPill(label: 'ابدأي الآن'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerSky extends CustomPainter {
  const _BannerSky();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width - 58, size.height / 2);
    final glow = Rect.fromCircle(center: c, radius: size.height * 0.95);
    canvas.drawCircle(
      c,
      glow.width / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.20),
            AppColors.holoLavender.withValues(alpha: 0.06),
            Colors.transparent,
          ],
          stops: const [0, 0.45, 1],
        ).createShader(glow),
    );
    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = AppColors.holoLavender.withValues(alpha: 0.16);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.32);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 250, height: 74),
      orbit,
    );
    canvas.restore();
    // A few fixed stars — this pane covers the sky, so it brings its own.
    final dot = Paint();
    for (final (dx, dy, r, a) in const [
      (0.18, 0.2, 1.1, 0.7),
      (0.42, 0.12, 0.8, 0.5),
      (0.3, 0.82, 0.9, 0.45),
      (0.08, 0.6, 0.7, 0.4),
      (0.55, 0.9, 1.0, 0.35),
    ]) {
      dot.color = AppColors.pearl.withValues(alpha: a);
      canvas.drawCircle(Offset(dx * size.width, dy * size.height), r, dot);
    }
  }

  @override
  bool shouldRepaint(_BannerSky oldDelegate) => false;
}

class _HoloChip extends StatelessWidget {
  const _HoloChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppColors.holoLavender.withValues(alpha: 0.22),
            AppColors.holoAqua.withValues(alpha: 0.14),
          ],
        ),
        border: Border.all(
          color: AppColors.holoLavender.withValues(alpha: 0.45),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.pearl,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ===========================================================================
// TOOLS ROW — three compact cards in one row
// ===========================================================================

/// A row of three compact planning-tool cards.
class PlanningToolsRow extends StatelessWidget {
  const PlanningToolsRow({super.key, this.tools = kRowTools});
  final List<PlanningTool> tools;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tools.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _MiniToolCard(tool: tools[i])),
          ],
        ],
      ),
    );
  }
}

class _MiniToolCard extends StatelessWidget {
  const _MiniToolCard({required this.tool});
  final PlanningTool tool;

  @override
  Widget build(BuildContext context) {
    final tint = tool.tint;
    return GestureDetector(
      onTap: () => _open(context, tool),
      child: CustomPaint(
        foregroundPainter: const HoloBorderPainter(radius: 20, strength: 0.8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.alphaBlend(
                  tint.withValues(alpha: 0.12),
                  AppColors.surfaceHigh,
                ),
                AppColors.surface,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _IconBadge(icon: tool.icon, tint: tint, size: 48, iconSize: 23),
              const SizedBox(height: 10),
              Text(
                tool.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tool as a full-width row on the planning tab, where there is room to
/// say what it does.
class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.tool});
  final PlanningTool tool;

  @override
  Widget build(BuildContext context) {
    final tint = tool.tint;
    return GlassPanel(
      tint: tint,
      onTap: () => _open(context, tool),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _IconBadge(icon: tool.icon, tint: tint, size: 52, iconSize: 25),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tool.label,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tool.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint.withValues(alpha: 0.10),
              border: Border.all(color: tint.withValues(alpha: 0.35)),
            ),
            child: Icon(Icons.chevron_left_rounded, color: tint, size: 22),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// PLANNING HUB — the tab that replaces "المفضلة"
// ===========================================================================

/// Dedicated tab gathering every planning tool: a short title, the coordinator
/// as the flagship, then every other tool with room to say what it does.
class PlanningHubPage extends StatelessWidget {
  const PlanningHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      // Already a tab inside the shell, which draws the bar itself — a second
      // one here would stack two bars on top of each other.
      showShellNav: false,
      appBar: const PinkAppBar(title: 'خطّطي فرحك', showBack: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GoldFoilText(
                  'مركز تخطيط فرحك',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'كل أدوات يومك الكبير في مكان واحد — من أول فكرة لآخر ضيف.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const NeonDivider(margin: EdgeInsets.only(top: 14)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const PlanningCoordinatorBanner(),
          const SizedBox(height: 14),
          for (final tool in kRowTools) ...[
            _ToolRow(tool: tool),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// A tool's icon in a glowing orb of its own colour.
class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.tint,
    required this.size,
    required this.iconSize,
  });

  final IconData icon;
  final Color tint;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [tint.withValues(alpha: 0.34), tint.withValues(alpha: 0.08)],
        ),
        border: Border.all(color: tint.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.28),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Color.lerp(tint, Colors.white, 0.25),
        size: iconSize,
        shadows: [Shadow(color: tint, blurRadius: 10)],
      ),
    );
  }
}
