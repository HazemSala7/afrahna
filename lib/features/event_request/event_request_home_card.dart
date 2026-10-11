import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'event_request_models.dart';
import 'event_request_page.dart';
import 'event_request_status_page.dart';
import 'event_request_storage.dart';

/// The home card that opens «نظّم مناسبتك».
///
/// This used to be "أعلن معنا", which jumped straight into WhatsApp with one
/// canned sentence: the customer had to describe their whole event by hand, and
/// got nothing back afterwards. Now it opens a six-question brief — and once a
/// request exists this card becomes the way back to it, showing how far along
/// it is, so the home page carries the customer's own progress.
class EventRequestHomeCard extends StatefulWidget {
  const EventRequestHomeCard({super.key});

  @override
  State<EventRequestHomeCard> createState() => _EventRequestHomeCardState();
}

class _EventRequestHomeCardState extends State<EventRequestHomeCard> {
  EventRequest? _existing;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final r = await EventRequestStorage.instance.load();
    if (!mounted) return;
    setState(() => _existing = r);
  }

  Future<void> _open() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _existing == null
          ? const EventRequestPage()
          : const EventRequestStatusPage(),
    ));
    // The request may have been created, advanced or cleared while away, so the
    // card is re-read rather than left showing a stale percentage.
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    // Scale the text relative to the screen width so it reads correctly on
    // every device — small phones (iPhone SE) through tablets — instead of the
    // fixed sizes that only looked right on one screen. 375 = baseline width.
    final width = MediaQuery.of(context).size.width;
    final scale = (width / 375).clamp(0.9, 1.25);
    final r = _existing;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _open,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            // Deep space into orchid, edged in gold: the copper it used to be
            // read as brown against the night sky.
            gradient: AppColors.brandDeepGradient,
            border: Border.all(color: AppColors.hairline),
            boxShadow: [
              BoxShadow(
                color: AppColors.holoLavender.withValues(alpha: 0.18),
                blurRadius: 22,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Column(
            // Sizes to its content. Inside the home ListView the height is
            // unbounded so this never showed, but anywhere with a bounded
            // height the card would stretch to fill it.
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      r == null
                          ? Icons.celebration_rounded
                          : Icons.assignment_turned_in_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r == null
                              ? 'نظّم مناسبتك معنا 🎉'
                              : 'طلب ${r.kind.label} — ${r.progress}%',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5 * scale,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          r == null
                              ? 'جاوب ٦ أسئلة وفريقنا برتّبلك كل إشي'
                              : 'الرقم المرجعي ${r.reference} · ${r.dateLabel}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5 * scale,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _open,
                    icon: Icon(
                      r == null
                          ? Icons.arrow_back_rounded
                          : Icons.timeline_rounded,
                      size: 18,
                    ),
                    label: Text(
                      r == null ? 'ابدأ' : 'تابع',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5 * scale,
                      ),
                    ),
                  ),
                ],
              ),
              // Only a submitted request has progress worth drawing.
              if (r != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: r.progress / 100),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, child) => LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFFFFD9A0)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
