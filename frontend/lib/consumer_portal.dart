import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'usage_history.dart';
import 'profile_screen.dart';
import 'bill_view.dart'; // View Bill screen

enum ChatLanguage { en, ur, both }

// --------------------
// GLASS ACTION CARD (3-column Quick Actions)
// --------------------
class _GlassActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final VoidCallback? onTap;
  const _GlassActionCard({
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.95,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: accentColor.withOpacity(0.30), width: 1.1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: accentColor.withOpacity(0.25)),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------
// GLASS WIDE ACTION TILE — full-width horizontal banner (My Bill etc.)
// --------------------
class _GlassWideActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback? onTap;
  const _GlassWideActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap!();
            },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accentColor.withOpacity(0.30), width: 1.1),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: accentColor.withOpacity(0.25)),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: accentColor.withOpacity(0.7), size: 21),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------
// Shared tag label lookup (bilingual chip text)
// --------------------
String _tagLabel(String key, ChatLanguage lang) {
  const labels = {
    'ALERT': {'en': 'ALERT', 'ur': 'تنبیہ'},
    'GOOD': {'en': 'GOOD', 'ur': 'بہتر'},
    'INFO': {'en': 'INFO', 'ur': 'معلومات'},
    'TIP': {'en': 'TIP', 'ur': 'مشورہ'},
  };
  final entry = labels[key] ?? {'en': key, 'ur': key};
  return lang == ChatLanguage.ur ? entry['ur']! : entry['en']!;
}

// --------------------
// Shared message body (renders per language selection)
// --------------------
class _MessageBody extends StatelessWidget {
  final String en;
  final String ur;
  final ChatLanguage language;
  const _MessageBody({required this.en, required this.ur, required this.language});

  @override
  Widget build(BuildContext context) {
    if (language == ChatLanguage.en) {
      return Text(en,
          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4));
    }
    if (language == ChatLanguage.ur) {
      return Text(
        ur,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.6),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(en,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, height: 1.4)),
        const SizedBox(height: 5),
        Text(
          ur,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          style: const TextStyle(
              color: Colors.white60, fontSize: 13.5, height: 1.55),
        ),
      ],
    );
  }
}

// --------------------
// CHAT BUBBLE — plain informational message
// --------------------
class _ChatBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tagKey;
  final String en;
  final String ur;
  final ChatLanguage language;
  const _ChatBubble({
    required this.icon,
    required this.color,
    required this.tagKey,
    required this.en,
    required this.ur,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(top: 2),
            decoration:
                BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16222E),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _tagLabel(tagKey, language),
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  _MessageBody(en: en, ur: ur, language: language),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------
// ACTION BUBBLE — message + a button (Report Now / Pay Now)
// --------------------
class _ActionBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tagKey;
  final String en;
  final String ur;
  final String actionLabelEn;
  final String actionLabelUr;
  final IconData actionIcon;
  final VoidCallback onAction;
  final ChatLanguage language;
  const _ActionBubble({
    required this.icon,
    required this.color,
    required this.tagKey,
    required this.en,
    required this.ur,
    required this.actionLabelEn,
    required this.actionLabelUr,
    required this.actionIcon,
    required this.onAction,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(top: 2),
            decoration:
                BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16222E),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: color.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _tagLabel(tagKey, language),
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  _MessageBody(en: en, ur: ur, language: language),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: onAction,
                      icon: Icon(actionIcon, size: 16),
                      label: Text(
                        language == ChatLanguage.ur
                            ? actionLabelUr
                            : actionLabelEn,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------
// TYPING INDICATOR BUBBLE
// --------------------
class _TypingBubble extends StatefulWidget {
  final Color color;
  const _TypingBubble({required this.color});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: widget.color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(Icons.smart_toy_rounded, color: widget.color, size: 15),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF16222E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.color.withOpacity(0.2)),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final t = (_ctrl.value + i * 0.2) % 1.0;
                    final scale =
                        0.5 + 0.5 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: widget.color, shape: BoxShape.circle),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------
// GRIDBOT CHAT SHEET — messages stream in one by one, language toggle
// --------------------
class _GridBotChatSheet extends StatefulWidget {
  final Color color;
  final Future<List<Map<String, dynamic>>> future;
  final VoidCallback onReport;
  final VoidCallback onPay;
  const _GridBotChatSheet({
    required this.color,
    required this.future,
    required this.onReport,
    required this.onPay,
  });

  @override
  State<_GridBotChatSheet> createState() => _GridBotChatSheetState();
}

class _GridBotChatSheetState extends State<_GridBotChatSheet> {
  final List<Map<String, dynamic>> _shown = [];
  final ScrollController _scroll = ScrollController();
  bool _typing = true;
  ChatLanguage _lang = ChatLanguage.both;

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final insights = await widget.future;
    for (final insight in insights) {
      if (!mounted) return;
      setState(() => _typing = true);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _typing = false;
        _shown.add(insight);
      });
      await Future.delayed(const Duration(milliseconds: 60));
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 160,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
      await Future.delayed(const Duration(milliseconds: 420));
    }
    if (mounted) setState(() => _typing = false);
  }

  Widget _langChip(String label, ChatLanguage val) {
    final active = _lang == val;
    return GestureDetector(
      onTap: () => setState(() => _lang = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: active
              ? widget.color.withOpacity(0.18)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? widget.color.withOpacity(0.5) : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? widget.color : Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.64,
      decoration: const BoxDecoration(
        color: Color(0xFF0F1D2B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: widget.color.withOpacity(0.15),
                  child: Icon(Icons.smart_toy_rounded,
                      color: widget.color, size: 16),
                ),
                const SizedBox(width: 8),
                Text("GridBot",
                    style: GoogleFonts.orbitron(
                        color: widget.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                _langChip("EN", ChatLanguage.en),
                _langChip("اردو", ChatLanguage.ur),
                _langChip("Both", ChatLanguage.both),
                IconButton(
                  padding: const EdgeInsets.only(left: 6),
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white38, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                for (final i in _shown)
                  i.containsKey('action')
                      ? _ActionBubble(
                          icon: i['icon'] as IconData,
                          color: i['color'] as Color,
                          tagKey: i['tagKey'] as String,
                          en: i['en'] as String,
                          ur: i['ur'] as String,
                          actionLabelEn: i['actionLabelEn'] as String,
                          actionLabelUr: i['actionLabelUr'] as String,
                          actionIcon: i['actionIcon'] as IconData,
                          onAction: i['action'] == 'pay'
                              ? widget.onPay
                              : widget.onReport,
                          language: _lang,
                        )
                      : _ChatBubble(
                          icon: i['icon'] as IconData,
                          color: i['color'] as Color,
                          tagKey: i['tagKey'] as String,
                          en: i['en'] as String,
                          ur: i['ur'] as String,
                          language: _lang,
                        ),
                if (_typing) _TypingBubble(color: widget.color),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// CONSUMER PORTAL — StatefulWidget

class ConsumerPortal extends StatefulWidget {
  final String meterID;
  const ConsumerPortal({super.key, required this.meterID});

  @override
  State<ConsumerPortal> createState() => _ConsumerPortalState();
}

class _ConsumerPortalState extends State<ConsumerPortal> {
  String _resolvedMeterID = '';

  // SHAP feature -> medium-length bilingual phrase
  static const Map<String, Map<String, String>> _featureExplain = {
    'Mean_Consumption': {
      'en': "your average daily usage doesn't match the pattern we'd expect from a normal household",
      'ur': 'آپ کا اوسط روزانہ استعمال ایک عام گھرانے کے متوقع پیٹرن سے میل نہیں کھاتا',
    },
    'Peak_Usage': {
      'en': 'there was an unusually high usage spike on a single day',
      'ur': 'کسی ایک دن غیر معمولی طور پر بہت زیادہ استعمال ریکارڈ ہوا',
    },
    'Min_Usage': {
      'en': 'several days recorded unusually low usage compared to the rest',
      'ur': 'کئی دنوں میں باقی دنوں کے مقابلے میں غیر معمولی طور پر کم استعمال ریکارڈ ہوا',
    },
    'Std_Consumption': {
      'en': 'your daily usage swings up and down more than a typical household',
      'ur': 'آپ کا روزانہ استعمال ایک عام گھرانے کے مقابلے میں زیادہ اتار چڑھاؤ رکھتا ہے',
    },
    'Usage_Range': {
      'en': 'the gap between your highest and lowest usage days is unusually wide',
      'ur': 'آپ کے سب سے زیادہ اور سب سے کم استعمال والے دن کا فرق غیر معمولی حد تک زیادہ ہے',
    },
    'Zero_Day_Count': {
      'en': 'several days show zero recorded consumption, which can point to meter bypass or tampering',
      'ur': 'کئی دنوں میں صفر استعمال ریکارڈ ہوا ہے، جو میٹر بائی پاس یا چھیڑ چھاڑ کی نشاندہی کر سکتا ہے',
    },
    'Missing_Day_Count': {
      'en': 'a number of days are missing readings entirely',
      'ur': 'کچھ دنوں کی ریڈنگز مکمل طور پر غائب ہیں',
    },
  };

  List<double> _loadBand(int hour) {
    if ((hour >= 7 && hour <= 10) || (hour >= 18 && hour <= 23)) {
      return [4.0, 9.5];
    } else if (hour >= 0 && hour <= 5) {
      return [0.5, 2.5];
    } else {
      return [2.0, 5.5];
    }
  }

  // Card color/icon react instantly to live status + load — no waiting.
  Map<String, dynamic> _botSeverity(String status, double load) {
    final band = _loadBand(DateTime.now().hour);
    final lo = band[0], hi = band[1];
    final s = status.toLowerCase();
    if (s == 'theft') {
      return {'color': const Color(0xFFFF5252), 'icon': Icons.gpp_bad_rounded};
    }
    if (s == 'fault') {
      return {
        'color': const Color(0xFFFFB74D),
        'icon': Icons.build_circle_rounded
      };
    }
    if (load > hi * 1.15) {
      return {'color': const Color(0xFFFFB74D), 'icon': Icons.bolt_rounded};
    }
    if (load < lo * 0.5 && load > 0) {
      return {'color': const Color(0xFF69F0AE), 'icon': Icons.eco_rounded};
    }
    return {'color': const Color(0xFF00E5FF), 'icon': Icons.smart_toy_rounded};
  }

  // Dynamic color/icon/label for the "MY BILL" tile
  Map<String, dynamic> _billSeverity(
      bool isPaid, double billEst, DateTime issueDate) {
    final dueDate = issueDate.add(const Duration(days: 15));
    final bool overdue = !isPaid && DateTime.now().isAfter(dueDate);

    if (isPaid) {
      return {
        'color': const Color(0xFF69F0AE),
        'icon': Icons.check_circle_rounded,
        'subtitle': 'Paid — no dues pending',
      };
    }
    if (overdue) {
      return {
        'color': const Color(0xFFFF5252),
        'icon': Icons.warning_rounded,
        'subtitle': 'Overdue — Rs. ${billEst.toStringAsFixed(0)} pending',
      };
    }
    return {
      'color': const Color(0xFFBB86FC),
      'icon': Icons.receipt_long_rounded,
      'subtitle': 'Rs. ${billEst.toStringAsFixed(0)} due',
    };
  }

  Map<String, String>? _flagReasonPhrase(List<dynamic> explanationRaw) {
    if (explanationRaw.isEmpty) return null;
    final top = explanationRaw.first as Map<String, dynamic>;
    final feature = top['feature']?.toString() ?? '';
    return _featureExplain[feature];
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  //  Fault Report Logic
  Future<void> _sendFaultReport(
      BuildContext context, String mID, String faultType) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Faults')
          .where('meterID', isEqualTo: mID)
          .get();

      bool alreadyPending = false;
      for (var doc in snapshot.docs) {
        if (doc['status'] == 'Pending') {
          alreadyPending = true;
          break;
        }
      }

      if (alreadyPending) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("A report is already pending for this meter."),
          backgroundColor: Colors.orangeAccent,
        ));
        return;
      }

      String cleanType = 'POWER_FAULT';
      if (faultType.contains('NO LOAD')) cleanType = 'NO_LOAD';
      if (faultType.contains('HIGH LOAD')) cleanType = 'HIGH_LOAD';

      await FirebaseFirestore.instance.collection('Faults').add({
        'meterID': mID,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Pending',
        'description': 'User reported outage manually.',
        'type': cleanType,
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Fault Reported Successfully!"),
        backgroundColor: Color(0xFF00E5FF),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Firebase Error: $e"),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showReportDialog(
      BuildContext context, String mID, String currentType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "System Alert",
          style: GoogleFonts.orbitron(
              color: const Color(0xFF00E5FF), fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Detected Issue: $currentType",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Reporting this will alert the GridEye Admin with your "
              "Meter ID and current load data for immediate action. "
              "Reports are typically reviewed within 24–48 hours.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL",
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _sendFaultReport(context, mID, currentType);
            },
            child: const Text("PROCEED",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Resolved Confirmation Dialog ──────────────────────
  void _showResolvedDialog(BuildContext context, String faultDocId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF69F0AE), size: 22),
            const SizedBox(width: 10),
            Text(
              "Issue Resolved",
              style: GoogleFonts.orbitron(
                  color: const Color(0xFF69F0AE), fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          "Your reported issue has been resolved by the GridEye Admin "
          "team. If you continue to experience problems, please submit "
          "a new report.",
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF69F0AE),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await FirebaseFirestore.instance
                      .collection('Faults')
                      .doc(faultDocId)
                      .update({'consumerAck': true});
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Couldn't update: $e")),
                  );
                }
              },
              child: const Text("OK",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ── GridBot insights, priority-ranked, capped at 2 cards ──
  //
  // Priority order (higher wins a slot):
  //   100  Bill overdue
  //    95  Bill due within 3 days
  //    90  Flagged meter (why + report/pending — merged into one card)
  //    80  Elevated theft-risk watch (only when not already flagged)
  //    70  Bill rose >10% vs last month
  //    65  Live load — high (alert)
  //    50  Bill dropped >10% vs last month (good news)
  //    45  Live load — low (good)
  //    40  Live load — normal (info)
  //    35  Safe-hours tip (non-flagged only)
  Future<List<Map<String, dynamic>>> _buildAdvisorInsights(
    String mID,
    double currentLoad,
    String meterStatus,
    List<dynamic> explanationRaw,
    bool isReportPending,
    bool isPaid,
    DateTime dueDate,
    double billEst,
  ) async {
    final candidates = <Map<String, dynamic>>[];
    final band = _loadBand(DateTime.now().hour);
    final lo = band[0], hi = band[1];
    final status = meterStatus.toLowerCase();
    final flagged = status == 'theft' || status == 'fault';

    // Bill due warning
    if (!isPaid) {
      final daysLeft = dueDate.difference(DateTime.now()).inDays;
      if (daysLeft < 0) {
        candidates.add({
          'priority': 100,
          'icon': Icons.warning_amber_rounded,
          'color': const Color(0xFFFF5252),
          'tagKey': 'ALERT',
          'en':
              "Your bill of Rs. ${billEst.toStringAsFixed(0)} was due on ${_fmtDate(dueDate)} and is now overdue. Paying soon will help you avoid the late payment surcharge.",
          'ur':
              "آپ کا بل، روپے ${billEst.toStringAsFixed(0)}، ${_fmtDate(dueDate)} کو واجب الادا تھا اور اب مقررہ وقت سے تجاوز کر چکا ہے۔ جلد ادائیگی کرنے سے لیٹ سرچارج سے بچا جا سکتا ہے۔",
          'action': 'pay',
          'actionLabelEn': 'PAY NOW',
          'actionLabelUr': 'ابھی ادا کریں',
          'actionIcon': Icons.payment_rounded,
        });
      } else if (daysLeft <= 3) {
        candidates.add({
          'priority': 95,
          'icon': Icons.event_rounded,
          'color': const Color(0xFFFFD740),
          'tagKey': 'ALERT',
          'en':
              "Your bill of Rs. ${billEst.toStringAsFixed(0)} is due on ${_fmtDate(dueDate)} — only $daysLeft day(s) left. Paying on time keeps you clear of any extra charges.",
          'ur':
              "آپ کا بل، روپے ${billEst.toStringAsFixed(0)}، ${_fmtDate(dueDate)} کو واجب الادا ہے، صرف $daysLeft دن باقی ہیں۔ وقت پر ادائیگی سے اضافی چارجز سے بچا جا سکتا ہے۔",
          'action': 'pay',
          'actionLabelEn': 'PAY NOW',
          'actionLabelUr': 'ابھی ادا کریں',
          'actionIcon': Icons.payment_rounded,
        });
      }
    }

    if (flagged) {
      final flagColor =
          status == 'theft' ? const Color(0xFFFF5252) : const Color(0xFFFFB74D);
      final phrase = _flagReasonPhrase(explanationRaw) ??
          {
            'en':
                "the system's automated analysis flagged unusual activity on this meter",
            'ur': 'سسٹم کے خودکار تجزیے نے اس میٹر میں غیر معمولی سرگرمی کی نشاندہی کی ہے',
          };

      String en = "This meter was flagged because ${phrase['en']}.";
      String ur = "یہ میٹر اس لیے فلیگ ہوا کیونکہ ${phrase['ur']}۔";

      if (isReportPending) {
        en +=
            " Good news — you've already reported this, and our admin team is currently reviewing it.";
        ur +=
            " اچھی خبر — آپ یہ پہلے ہی رپورٹ کر چکے ہیں، اور ہماری ایڈمن ٹیم اس وقت اس کا جائزہ لے رہی ہے۔";
        candidates.add({
          'priority': 90,
          'icon': Icons.psychology_alt_rounded,
          'color': flagColor,
          'tagKey': 'ALERT',
          'en': en,
          'ur': ur,
        });
      } else {
        en +=
            " We'd recommend reporting it so our admin team can take a closer look — reports are usually reviewed within 24–48 hours.";
        ur +=
            " ہماری تجویز ہے کہ اسے رپورٹ کریں تاکہ ایڈمن ٹیم بغور جائزہ لے سکے — رپورٹس عام طور پر 24 سے 48 گھنٹوں میں دیکھ لی جاتی ہیں۔";
        candidates.add({
          'priority': 90,
          'icon': Icons.psychology_alt_rounded,
          'color': flagColor,
          'tagKey': 'ALERT',
          'en': en,
          'ur': ur,
          'action': 'report',
          'actionLabelEn': 'REPORT NOW',
          'actionLabelUr': 'ابھی رپورٹ کریں',
          'actionIcon': Icons.report_problem_rounded,
        });
      }
    } else {
      if (currentLoad > hi * 1.15) {
        candidates.add({
          'priority': 65,
          'icon': Icons.bolt_rounded,
          'color': const Color(0xFFFFB74D),
          'tagKey': 'ALERT',
          'en':
              "Your usage right now (${currentLoad.toStringAsFixed(1)} kW) is higher than what's typical for this time of day. It might be worth checking if a heavy appliance is running unnecessarily.",
          'ur':
              "اس وقت آپ کا استعمال (${currentLoad.toStringAsFixed(1)} کلو واٹ) دن کے اس حصے کے معمول سے زیادہ ہے۔ ایک بار چیک کر لیں کہ کہیں کوئی بھاری آلہ بلا ضرورت تو نہیں چل رہا۔",
        });
      } else if (currentLoad < lo * 0.5 && currentLoad > 0) {
        candidates.add({
          'priority': 45,
          'icon': Icons.eco_rounded,
          'color': const Color(0xFF69F0AE),
          'tagKey': 'GOOD',
          'en':
              "Your usage is running lower than usual right now, which should help keep this month's bill in check.",
          'ur':
              "اس وقت آپ کا استعمال معمول سے کم ہے، جو اس مہینے کے بل کو قابو میں رکھنے میں مددگار ثابت ہوگا۔",
        });
      } else {
        candidates.add({
          'priority': 40,
          'icon': Icons.check_circle_outline_rounded,
          'color': const Color(0xFF00E5FF),
          'tagKey': 'INFO',
          'en':
              "Everything looks normal — your current usage matches the expected pattern for this time of day.",
          'ur':
              "سب کچھ معمول کے مطابق ہے — آپ کا موجودہ استعمال اس وقت کے متوقع پیٹرن سے میل کھاتا ہے۔",
        });
      }

      candidates.add({
        'priority': 35,
        'icon': Icons.nightlight_round,
        'color': const Color(0xFF00E5FF),
        'tagKey': 'TIP',
        'en':
            "If you can, try running heavier appliances like the washing machine or a water motor between 12 AM and 5 AM — that's when demand is lowest and easiest on your bill.",
        'ur':
            "اگر ممکن ہو تو واشنگ مشین یا موٹر جیسے بھاری آلات رات 12 سے صبح 5 بجے کے درمیان چلائیں — اس وقت طلب سب سے کم ہوتی ہے اور بل پر بوجھ بھی کم پڑتا ہے۔",
      });
    }

    // Month-over-month bill trend + a theft-risk watch flag
    try {
      final snap = await FirebaseFirestore.instance
          .collection('meters')
          .doc(mID)
          .collection('usage_history')
          .orderBy('timestamp', descending: true)
          .limit(2)
          .get();

      if (snap.docs.length == 2) {
        final latest = snap.docs[0].data();
        final previous = snap.docs[1].data();
        final double latestAmt = (latest['amount'] ?? 0).toDouble();
        final double previousAmt = (previous['amount'] ?? 0).toDouble();
        final String latestLabel = latest['label'] ?? '';

        if (previousAmt > 0) {
          final diffPct = ((latestAmt - previousAmt) / previousAmt) * 100;
          if (diffPct > 10) {
            candidates.add({
              'priority': 70,
              'icon': Icons.trending_up_rounded,
              'color': const Color(0xFFFFD740),
              'tagKey': 'ALERT',
              'en':
                  "Your bill for $latestLabel came in ${diffPct.toStringAsFixed(0)}% higher than the month before — it might be worth reviewing what changed in your usage.",
              'ur':
                  "$latestLabel کا بل پچھلے مہینے کے مقابلے میں ${diffPct.toStringAsFixed(0)}% زیادہ رہا — دیکھ لیں کہ استعمال میں کیا فرق آیا۔",
            });
          } else if (diffPct < -10) {
            candidates.add({
              'priority': 50,
              'icon': Icons.trending_down_rounded,
              'color': const Color(0xFF69F0AE),
              'tagKey': 'GOOD',
              'en':
                  "Nice — your bill for $latestLabel dropped ${diffPct.abs().toStringAsFixed(0)}% compared to last month. Keep it up.",
              'ur':
                  "بہت خوب — $latestLabel کا بل پچھلے مہینے سے ${diffPct.abs().toStringAsFixed(0)}% کم رہا۔ اسی طرح جاری رکھیں۔",
            });
          }
        }
        if (!flagged && latest['theft_risk'] == 'High') {
          candidates.add({
            'priority': 80,
            'icon': Icons.visibility_rounded,
            'color': const Color(0xFFFF8A65),
            'tagKey': 'ALERT',
            'en':
                "Based on recent history, this meter has shown an elevated risk pattern. There's no need to worry, but an inspection from our team may follow soon.",
            'ur':
                "حالیہ ریکارڈ کی بنیاد پر اس میٹر میں خطرے کا رجحان دیکھا گیا ہے۔ پریشان ہونے کی ضرورت نہیں — لیکن ہماری ٹیم جلد معائنہ کر سکتی ہے۔",
          });
        }
      }
    } catch (_) {
      // history abhi available nahi — trend chupchap skip
    }

    candidates.sort(
        (a, b) => (b['priority'] as int).compareTo(a['priority'] as int));
    return candidates.take(2).toList();
  }

  // Helpers
  String _formatTimestamp(dynamic ts) {
    if (ts == null || ts is! Timestamp) return "—";
    final dt = ts.toDate();
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return "${dt.day}/${dt.month}/${dt.year} | $hour:$min $ampm";
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'fault':
        return const Color(0xFFFFB74D);
      case 'theft':
        return const Color(0xFFFF5252);
      default:
        return const Color(0xFF69F0AE);
    }
  }

  String _displayStatus(String status) {
    switch (status.toLowerCase()) {
      case 'theft':
        return 'LINE ANOMALY DETECTED';
      case 'fault':
        return 'HARDWARE FAULT';
      default:
        return 'NORMAL';
    }
  }

  // BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFF00E5FF), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'GRID',
                style: GoogleFonts.orbitron(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              TextSpan(
                text: 'EYE',
                style: GoogleFonts.orbitron(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF00E5FF),
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined,
                color: Colors.white70),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  meterID: _resolvedMeterID.isEmpty
                      ? widget.meterID
                      : _resolvedMeterID,
                ),
              ),
            ),
          ),
        ],
      ),

      //  Body:
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('meters')
            .doc(widget.meterID)
            .snapshots(),
        builder: (context, meterSnapshot) {
          if (meterSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
          }
          if (!meterSnapshot.hasData || !meterSnapshot.data!.exists) {
            return const Center(
              child: Text(
                "Meter Not Found",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final meterData =
              meterSnapshot.data!.data() as Map<String, dynamic>;

          double currentLoad = (meterData['currentLoad'] ?? 0.0).toDouble();
          double units = (meterData['units'] ?? 0.0).toDouble();
          double billEst = (meterData['billEst'] ?? 0.0).toDouble();
          String mID = meterData['meterId'] ?? widget.meterID;
          String meterStatus = meterData['status'] ?? 'Normal';
          String city = meterData['city'] ?? '—';
          String area = meterData['area'] ?? '—';
          dynamic timestamp = meterData['timestamp'];
          final List<dynamic> explanation =
              (meterData['explanation'] as List<dynamic>?) ?? [];

          // Bill payment status (safe default false if field missing)
          final bool isPaid = meterData['isPaid'] == true;
          DateTime issueDate = DateTime.now();
          if (timestamp is Timestamp) issueDate = timestamp.toDate();
          final DateTime dueDate = issueDate.add(const Duration(days: 15));
          final billSeverity = _billSeverity(isPaid, billEst, issueDate);

          if (_resolvedMeterID != mID) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _resolvedMeterID = mID);
            });
          }

          final botSeverity = _botSeverity(meterStatus, currentLoad);

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Faults')
                .where('meterID', isEqualTo: mID)
                .where('status', whereIn: ['Pending', 'Resolved'])
                .snapshots(),
            builder: (context, faultSnapshot) {
              final faultDocs = faultSnapshot.data?.docs ?? [];

              final pendingDocs = faultDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] == 'Pending';
              }).toList();

              final resolvedUnackedDocs = faultDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] == 'Resolved' &&
                    data['consumerAck'] != true;
              }).toList();

              bool isPending = pendingDocs.isNotEmpty;
              bool isResolved = resolvedUnackedDocs.isNotEmpty;
              final resolvedDoc = isResolved ? resolvedUnackedDocs.first : null;

              Color accentColor = const Color(0xFF00E5FF);
              String alertTitle = "REPORT\nFAULT";
              IconData alertIcon = Icons.report_problem_outlined;

              if (isPending) {
                accentColor = const Color(0xFFBB86FC);
                alertTitle = "PROCESSING";
                alertIcon = Icons.sync_rounded;
              } else if (isResolved) {
                accentColor = const Color(0xFF69F0AE);
                alertTitle = "RESOLVED";
                alertIcon = Icons.check_circle_outline_rounded;
              } else if (currentLoad == 0.0) {
                accentColor = meterStatus.toLowerCase() == 'fault'
                    ? const Color(0xFFFF5252)
                    : const Color(0xFF6B7F99);
                alertTitle =
                    meterStatus.toLowerCase() == 'fault' ? "NO LOAD" : "NO USAGE";
                alertIcon = Icons.power_off_rounded;
              } else if (currentLoad > 8.0) {
                accentColor = const Color(0xFFFFB74D);
                alertTitle = "HIGH LOAD";
                alertIcon = Icons.bolt;
              }

              VoidCallback tileOnTap;
              if (isPending) {
                tileOnTap = () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Processing report...")));
              } else if (isResolved) {
                tileOnTap = () => _showResolvedDialog(context, resolvedDoc!.id);
              } else {
                tileOnTap = () => _showReportDialog(context, mID, alertTitle);
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    const Text(
                      "Welcome Back,",
                      style: TextStyle(
                        color: Color(0xFF8899AA),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Consumer #$mID",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Status Badge
                    _buildStatusBadge(meterStatus),
                    const SizedBox(height: 20),

                    // Usage Card
                    _buildUsageCard(
                        currentLoad, units, billEst, timestamp, meterStatus),
                    const SizedBox(height: 10),

                    // Location Bar
                    _buildLocationSlim(area, city),
                    const SizedBox(height: 12),

                    // MY BILL tile — dynamic color, tight spacing above/below
                    _GlassWideActionTile(
                      icon: billSeverity['icon'],
                      title: "MY BILL",
                      subtitle: billSeverity['subtitle'],
                      accentColor: billSeverity['color'],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => BillViewScreen(meterID: mID)),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Quick Actions — 3-column glass row
                    const Text(
                      "Quick Actions",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _GlassActionCard(
                            icon: alertIcon,
                            title: alertTitle,
                            accentColor: accentColor,
                            onTap: tileOnTap,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _GlassActionCard(
                            icon: botSeverity['icon'],
                            title: "GRIDBOT",
                            accentColor: botSeverity['color'],
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => _GridBotChatSheet(
                                color: botSeverity['color'],
                                future: _buildAdvisorInsights(
                                    mID,
                                    currentLoad,
                                    meterStatus,
                                    explanation,
                                    isPending,
                                    isPaid,
                                    dueDate,
                                    billEst),
                                onReport: () {
                                  Navigator.of(context).pop(); // close sheet
                                  _showReportDialog(context, mID, alertTitle);
                                },
                                onPay: () {
                                  Navigator.of(context).pop(); // close sheet
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          BillViewScreen(meterID: mID),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _GlassActionCard(
                            icon: Icons.analytics_outlined,
                            title: "USAGE\nHISTORY",
                            accentColor: const Color(0xFF00E5FF),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      UsageHistory(meterID: mID)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Status Badge
  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _statusColor(status).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: _statusColor(status), size: 8),
          const SizedBox(width: 6),
          Text(
            _displayStatus(status),
            style: TextStyle(
              color: _statusColor(status),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // Usage Card
  Widget _buildUsageCard(double load, double units, double bill,
      dynamic timestamp, String status) {
    Color primaryNumColor = const Color(0xFF00E5FF);
    if (load == 0.0) {
      primaryNumColor = const Color(0xFFFF5252);
    } else if (status.toLowerCase() == 'fault') {
      primaryNumColor = Colors.orangeAccent;
    }

    const Color unitsColor = Color(0xFF69F0AE);
    const Color billColor = Color(0xFFFFD740);

    const TextStyle labelStyle = TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    );

    TextStyle valueStyle(double size, Color color) => TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: size > 30 ? -1.0 : 0.0,
        );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2137), Color(0xFF0A1A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF00C4D4).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("CURRENT LOAD", style: labelStyle),
                const SizedBox(height: 8),
                Text(
                  "${load.toStringAsFixed(2)} kW",
                  style: valueStyle(46, primaryNumColor),
                ),
                const SizedBox(height: 20),
                Container(height: 1, color: Colors.white.withOpacity(0.07)),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("UNITS", style: labelStyle),
                        const SizedBox(height: 6),
                        Text(units.toStringAsFixed(1),
                            style: valueStyle(24, unitsColor)),
                      ],
                    ),
                    Container(
                        width: 1,
                        height: 44,
                        color: Colors.white.withOpacity(0.07)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("BILL (EST)", style: labelStyle),
                        const SizedBox(height: 6),
                        Text("Rs. ${bill.toStringAsFixed(0)}",
                            style: valueStyle(24, billColor)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sync_rounded,
                    color: Color(0xFF00E5FF), size: 13),
                const SizedBox(width: 7),
                Text(
                  "UPDATED  ${_formatTimestamp(timestamp)}",
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Location Slim Bar
  Widget _buildLocationSlim(String area, String city) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded,
              color: Color(0xFFFF5252), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$area, $city",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}