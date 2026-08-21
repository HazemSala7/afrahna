// TEMPORARY diagnostic entry point. Run with:
//   flutter run -t lib/_emoji_probe.dart
// Delete when the tofu question is settled. Touches no app file.
import 'package:flutter/material.dart';
import 'core/theme.dart';

const sample = '📝 ✨ ₪';

void main() => runApp(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SizedBox(height: 40),
              Text('A theme inherit', style: TextStyle(fontSize: 20)),
              Text(sample, style: TextStyle(fontSize: 44)),
              SizedBox(height: 24),
              Text('B inherit:false', style: TextStyle(fontSize: 20)),
              Text(sample,
                  style: TextStyle(
                      inherit: false, fontSize: 44, color: Color(0xFF000000))),
              SizedBox(height: 24),
              Text('C family=AppleColorEmoji', style: TextStyle(fontSize: 20)),
              Text(sample,
                  style:
                      TextStyle(fontSize: 44, fontFamily: 'Apple Color Emoji')),
              SizedBox(height: 24),
              Text('D fallback only', style: TextStyle(fontSize: 20)),
              Text(sample,
                  style: TextStyle(
                      inherit: false,
                      fontSize: 44,
                      color: Color(0xFF000000),
                      fontFamilyFallback: ['Apple Color Emoji'])),
            ],
          ),
        ),
      ),
    ));
