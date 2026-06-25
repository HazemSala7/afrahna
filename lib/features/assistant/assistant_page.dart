import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/models/models.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../vendors/vendor_details_page.dart';
import 'assistant_engine.dart';

/// ===========================================================================
/// MESSAGE MODELS
/// ===========================================================================
enum _Sender { user, bot }

class _ChatMessage {
  _ChatMessage.user(this.text)
      : sender = _Sender.user,
        result = null,
        isThinking = false;
  _ChatMessage.bot(this.text, {this.result, this.isThinking = false})
      : sender = _Sender.bot;

  final String text;
  final _Sender sender;
  final AssistantResult? result;
  final bool isThinking;
}

/// ===========================================================================
/// ASSISTANT PAGE
/// ===========================================================================
class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage>
    with TickerProviderStateMixin {
  final _engine = AssistantEngine();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focus = FocusNode();
  final _stt = stt.SpeechToText();

  final List<_ChatMessage> _messages = [];
  bool _busy = false;
  bool _sttReady = false;
  bool _listening = false;
  String _partial = '';

  /// Best available Arabic locale id for speech recognition (resolved at init).
  String? _arLocaleId;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _engine.preload();
    _messages.add(
      _ChatMessage.bot(
        'أهلاً بك 👋\nأنا مساعد أفراحنا الذكي. اسألني عن أفضل المعلنين، '
        'الأسعار، أو الفئات.\nوإذا كنت مقبلاً على الزواج قل لي ميزانيتك '
        'مثل: «ميزانيتي 50000 وبدي أتجوز» وسأقسّمها لك على كل بنود العرس 💍.',
      ),
    );
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _stt.initialize(
        onError: (e) {
          if (!mounted) return;
          setState(() => _listening = false);
        },
        onStatus: (s) {
          if (!mounted) return;
          if (s == 'notListening' || s == 'done') {
            setState(() => _listening = false);
          }
        },
      );
      if (ok) {
        // Resolve the device's best Arabic locale; fall back to ar_SA.
        try {
          final locales = await _stt.locales();
          final ar = locales.where(
            (l) => l.localeId.toLowerCase().startsWith('ar'),
          );
          if (ar.isNotEmpty) {
            // Prefer Palestinian/Levant variants when present.
            stt.LocaleName pick = ar.first;
            for (final pref in const ['ar_ps', 'ar_jo', 'ar_eg', 'ar_sa']) {
              final m = ar.where((l) => l.localeId.toLowerCase() == pref);
              if (m.isNotEmpty) {
                pick = m.first;
                break;
              }
            }
            _arLocaleId = pick.localeId;
          }
        } catch (_) {
          // locales() not supported → keep default below
        }
        _arLocaleId ??= 'ar_SA';
      }
      if (mounted) setState(() => _sttReady = ok);
    } catch (_) {
      if (mounted) setState(() => _sttReady = false);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _focus.dispose();
    _stt.stop();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      final text = _partial.trim();
      _partial = '';
      if (text.isNotEmpty) {
        _controller.text = text;
        await _send(text);
      }
      return;
    }
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _toast('يلزم السماح باستخدام الميكروفون لتفعيل الإملاء الصوتي');
      return;
    }
    if (!_sttReady) await _initSpeech();
    if (!_sttReady) {
      _toast('تعذّر تشغيل خدمة التعرّف على الكلام على هذا الجهاز');
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _listening = true;
      _partial = '';
    });
    await _stt.listen(
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        localeId: _arLocaleId ?? 'ar_SA',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
      ),
      onResult: (r) {
        if (!mounted) return;
        setState(() {
          _partial = r.recognizedWords;
          _controller.text = _partial;
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        });
        // When the engine marks the phrase final, auto-send immediately.
        if (r.finalResult) {
          final text = r.recognizedWords.trim();
          _partial = '';
          if (mounted) setState(() => _listening = false);
          if (text.isNotEmpty) {
            _controller.text = text;
            _send(text);
          }
        }
      },
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty || _busy) return;
    _controller.clear();
    _focus.unfocus();
    setState(() {
      _messages.add(_ChatMessage.user(t));
      _messages.add(_ChatMessage.bot('', isThinking: true));
      _busy = true;
    });
    _scrollToEnd();
    try {
      final r = await _engine.ask(t);
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _messages.add(_ChatMessage.bot(r.reply, result: r));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _messages.add(_ChatMessage.bot(
          'تعذّر إكمال الطلب: $e\nتأكّد من الاتصال بالإنترنت وحاول مرة أخرى.',
        ));
      });
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const PinkAppBar(
        title: 'المساعد الذكي',
        subtitle: 'مدعوم بذكاء أفراحنا ✨',
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
              itemCount: _messages.length +
                  (_messages.length == 1 ? 1 : 0), // suggestions block
              itemBuilder: (_, i) {
                if (_messages.length == 1 && i == 1) {
                  return _SuggestionsBlock(onTap: _send);
                }
                final m = _messages[i];
                return _Bubble(message: m, onOpenVendor: _openVendor);
              },
            ),
          ),
          if (_listening) _ListeningBar(text: _partial, pulse: _pulse),
          _InputBar(
            controller: _controller,
            focus: _focus,
            busy: _busy,
            listening: _listening,
            onSend: () => _send(_controller.text),
            onMic: _toggleMic,
          ),
        ],
      ),
    );
  }

  void _openVendor(VendorModel v) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VendorDetailsPage(vendorId: v.id)),
    );
  }
}

/// ===========================================================================
/// SUGGESTIONS (shown when conversation is empty)
/// ===========================================================================
class _SuggestionsBlock extends StatelessWidget {
  const _SuggestionsBlock({required this.onTap});
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Text(
              'جرّب أن تسألني:',
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in AssistantEngine.suggestions)
                InkWell(
                  onTap: () => onTap(s),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            size: 15, color: AppColors.primaryDark),
                        const SizedBox(width: 6),
                        Text(
                          s,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ===========================================================================
/// CHAT BUBBLE
/// ===========================================================================
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onOpenVendor});
  final _ChatMessage message;
  final void Function(VendorModel) onOpenVendor;

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == _Sender.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const _BotAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (message.isThinking)
                  const _ThinkingBubble()
                else
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? const LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                            )
                          : const LinearGradient(
                              colors: [Colors.white, Color(0xFFFFF8EE)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft:
                            Radius.circular(isUser ? 18 : 4),
                        bottomRight:
                            Radius.circular(isUser ? 4 : 18),
                      ),
                      border: isUser
                          ? null
                          : Border.all(
                              color: AppColors.primary.withValues(alpha: 0.18),
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withValues(alpha: 0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: isUser ? Colors.white : AppColors.textDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                  ),
                if (message.result != null &&
                    message.result!.vendors.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  if (message.result!.plan.isNotEmpty)
                    for (final item in message.result!.plan)
                      _PlanSlotCard(
                        item: item,
                        onTap: item.vendor == null
                            ? null
                            : () => onOpenVendor(item.vendor!),
                      )
                  else
                    for (final v in message.result!.vendors)
                      _VendorResultCard(
                        vendor: v,
                        minPrice: message.result!.minPriceByVendor[v.id],
                        onTap: () => onOpenVendor(v),
                      ),
                ],
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const _UserAvatar(),
          ],
        ],
      ),
    );
  }
}

class _BotAvatar extends StatelessWidget {
  const _BotAvatar();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFE6B450), AppColors.primaryDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.auto_awesome_rounded,
          color: Colors.white, size: 18),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryLight,
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.45)),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.person_rounded,
          color: AppColors.primaryDark, size: 18),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(delay: 0),
          SizedBox(width: 6),
          _Dot(delay: 200),
          SizedBox(width: 6),
          _Dot(delay: 400),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay});
  final int delay;
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay),
        () => mounted ? _c.repeat(reverse: true) : null);
  }
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

/// ===========================================================================
/// VENDOR RESULT CARD
/// ===========================================================================
class _VendorResultCard extends StatelessWidget {
  const _VendorResultCard({
    required this.vendor,
    required this.onTap,
    this.minPrice,
  });
  final VendorModel vendor;
  final double? minPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: AppNetworkImage(
                      url: vendor.logo ?? vendor.cover,
                      fallbackIcon: Icons.storefront_rounded,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendor.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (vendor.rating != null) ...[
                            const Icon(Icons.star_rounded,
                                size: 15, color: Color(0xFFE6B450)),
                            const SizedBox(width: 2),
                            Text(
                              vendor.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (vendor.city != null)
                            Flexible(
                              child: Text(
                                vendor.city!.nameAr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (minPrice != null) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'يبدأ من ${minPrice!.toStringAsFixed(0)} ₪',
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left_rounded,
                    color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ===========================================================================
/// WEDDING PLAN SLOT CARD — one budget line in a wedding breakdown.
/// ===========================================================================
class _PlanSlotCard extends StatelessWidget {
  const _PlanSlotCard({required this.item, this.onTap});
  final WeddingPlanItem item;
  final VoidCallback? onTap;

  String _money(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final v = item.vendor;
    final pct = (item.percent * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: emoji + label + allocated budget
                Row(
                  children: [
                    Text(item.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (item.allocated > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD4A373), AppColors.primary],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_money(item.allocated)} ₪ · $pct٪',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (v == null)
                  Row(
                    children: [
                      const Icon(Icons.search_off_rounded,
                          size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'لا يوجد معلن مناسب لهذا البند حالياً',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: AppNetworkImage(
                            url: v.logo ?? v.cover,
                            fallbackIcon: Icons.storefront_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (v.rating != null) ...[
                                  const Icon(Icons.star_rounded,
                                      size: 14, color: Color(0xFFE6B450)),
                                  const SizedBox(width: 2),
                                  Text(
                                    v.rating!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (item.startingPrice != null)
                                  Flexible(
                                    child: Text(
                                      'يبدأ من ${_money(item.startingPrice!)} ₪',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.primaryDark,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_left_rounded,
                          color: AppColors.primary),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ===========================================================================
/// LISTENING BAR (visible while STT is active)
/// ===========================================================================
class _ListeningBar extends StatelessWidget {
  const _ListeningBar({required this.text, required this.pulse});
  final String text;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE9C9), Color(0xFFFFD9A8)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (_, _) {
              final v = pulse.value;
              return Container(
                width: 12 + v * 6,
                height: 12 + v * 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent,
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text.isEmpty ? 'يستمع… تكلّم الآن' : text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===========================================================================
/// INPUT BAR
/// ===========================================================================
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focus,
    required this.busy,
    required this.listening,
    required this.onSend,
    required this.onMic,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool busy;
  final bool listening;
  final VoidCallback onSend;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 10 + bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          _CircleButton(
            icon: listening ? Icons.stop_rounded : Icons.mic_rounded,
            color: listening ? Colors.redAccent : AppColors.primaryDark,
            background: listening
                ? Colors.redAccent.withValues(alpha: 0.12)
                : AppColors.primaryLight,
            onTap: onMic,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.20)),
              ),
              child: TextField(
                controller: controller,
                focusNode: focus,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  hintText: 'اكتب سؤالك… مثل: أفضل تصوير بـ 3000 شيكل',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13.5,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CircleButton(
            icon: busy ? Icons.hourglass_top_rounded : Icons.send_rounded,
            color: Colors.white,
            background: AppColors.primary,
            onTap: busy ? () {} : onSend,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
    this.gradient,
  });
  final IconData icon;
  final Color color;
  final Color background;
  final Gradient? gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: gradient == null ? background : null,
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}
