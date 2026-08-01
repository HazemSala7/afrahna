import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
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
  tint: Color(0xFFDD8A6A), // terracotta
  builder: _invitations,
);
const _tasksTool = PlanningTool(
  icon: Icons.checklist_rtl_rounded,
  label: 'قائمة المهام',
  subtitle: 'نظّمي كل تحضيرات فرحك',
  tint: Color(0xFF8FA97E), // sage
  builder: _tasks,
);
const _calendarTool = PlanningTool(
  icon: Icons.calendar_month_rounded,
  label: 'التقويم الذكي',
  subtitle: 'مواعيدك ومناسباتك بمكان واحد',
  tint: Color(0xFFAF8FC4), // mauve
  builder: _calendar,
);
const _coordinatorTool = PlanningTool(
  icon: Icons.assignment_rounded,
  label: 'منسق المناسبة',
  subtitle: 'خطّطي كل تفاصيل يومك خطوة بخطوة',
  tint: Color(0xFF4FA69C), // dusty teal (hero)
  builder: _coordinator,
);

/// All planning tools, each with its own warm tint so they read as a lively,
/// distinctive set wherever they appear.
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
        backgroundColor: AppColors.primaryDark,
        action: SnackBarAction(
          label: 'تسجيل الدخول',
          textColor: Colors.white,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LoginPage()),
          ),
        ),
      ),
    );
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(builder: tool.builder));
}

Color _darken(Color c, [double amount = 0.28]) =>
    Color.alphaBlend(Colors.black.withValues(alpha: amount), c);

// ===========================================================================
// COORDINATOR HERO BANNER — the prominent, special banner
// ===========================================================================

/// A rich, eye-catching hero banner dedicated to the event-coordinator tool.
class PlanningCoordinatorBanner extends StatelessWidget {
  const PlanningCoordinatorBanner({super.key, this.tool = kCoordinatorTool});
  final PlanningTool tool;

  @override
  Widget build(BuildContext context) {
    final tint = tool.tint;
    return GestureDetector(
      onTap: () => _open(context, tool),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [_darken(tint, 0.08), tint, _darken(tint, 0.34)],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: 0.42),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Oversized faint icon as a decorative watermark (end side / left).
            Positioned(
              left: -18,
              bottom: -22,
              child: Icon(
                tool.icon,
                size: 130,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Positioned(
              top: 14,
              left: 26,
              child: Icon(Icons.auto_awesome_rounded,
                  size: 16, color: Colors.white.withValues(alpha: 0.5)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(tool.icon, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                tool.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 19,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'مميّز',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tool.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ابدأي الآن',
                                style: TextStyle(
                                  color: _darken(tint, 0.1),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_back_rounded,
                                  color: _darken(tint, 0.1), size: 16),
                            ],
                          ),
                        ),
                      ],
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(tint.withValues(alpha: 0.14), Colors.white),
              Color.alphaBlend(tint.withValues(alpha: 0.28), Colors.white),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tint.withValues(alpha: 0.25), width: 1),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconBadge(icon: tool.icon, tint: tint, size: 46, iconSize: 23),
            const SizedBox(height: 9),
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
    );
  }
}

// ===========================================================================
// PLANNING HUB — the tab that replaces "المفضلة"
// ===========================================================================

/// Dedicated tab gathering every planning tool: the coordinator hero banner
/// on top, then the three secondary tools in a single row.
class PlanningHubPage extends StatelessWidget {
  const PlanningHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const PinkAppBar(title: 'خطّطي فرحك', showBack: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: const [
          PlanningCoordinatorBanner(),
          SizedBox(height: 16),
          PlanningToolsRow(),
        ],
      ),
    );
  }
}

/// Rounded gradient badge holding a tool's icon.
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint, _darken(tint)],
        ),
        borderRadius: BorderRadius.circular(size * 0.34),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}
