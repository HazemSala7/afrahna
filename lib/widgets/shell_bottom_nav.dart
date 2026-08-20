import 'package:flutter/material.dart';

import '../features/home/home_page.dart';
import 'app_bottom_nav.dart';

/// The app's bottom bar, for screens that are pushed on top of the shell
/// rather than living inside it.
///
/// «نقاطي», «طلباتي», «العروض», «المفضلة», «مناسباتي» and «الإشعارات» are all
/// reached from somewhere else and used to be dead ends: the only way out was
/// the back arrow, and a reader who wanted الرئيسية or حسابي had to remember
/// how many screens deep they were. The bar gives every one of them the same
/// five exits the rest of the app has.
///
/// No tab is shown as selected — none of these screens *is* a tab — and
/// choosing one returns to the shell on that tab rather than stacking another
/// copy of it on top of the pile.
class ShellBottomNav extends StatelessWidget {
  const ShellBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBottomNav(
      current: -1,
      onTap: (index) => Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomePage(initialTab: index)),
        (route) => false,
      ),
    );
  }
}
