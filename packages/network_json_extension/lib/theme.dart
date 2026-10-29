import 'package:flutter/material.dart';

const background = Color(0xff282828);
const panel = Color(0xff2d2d2d);
const lineColor = Color(0xff444444);
const muted = Color(0xffa2a2aa);
const accent = Color(0xffb9a7ee);
const mint = Color(0xff91c9ac);
const orange = Color(0xffdba483);

ThemeData inspectorTheme() => ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  scaffoldBackgroundColor: background,
  colorScheme: const ColorScheme.dark(
    primary: accent, surface: panel, secondary: mint,
    onSurface: Color(0xffdedee3), outline: lineColor,
  ),
  fontFamily: 'Arial',
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 12), bodySmall: TextStyle(fontSize: 11, color: muted),
    titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  ),
  tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 400)),
  iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(
    foregroundColor: muted, iconSize: 17,
    minimumSize: const Size(30, 30), padding: const EdgeInsets.all(6))),
  inputDecorationTheme: InputDecorationTheme(
    isDense: true,
    filled: true,
    fillColor: const Color(0xff252525),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
      borderSide: const BorderSide(color: lineColor)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
      borderSide: const BorderSide(color: lineColor)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
      borderSide: const BorderSide(color: accent)),
    hintStyle: const TextStyle(color: muted, fontSize: 12),
  ),
  dividerTheme: const DividerThemeData(color: lineColor, thickness: 1, space: 1),
);

class SmallTag extends StatelessWidget {
  const SmallTag(this.text, {super.key, this.color = accent});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: .09),
      border: Border.all(color: color.withValues(alpha: .25)),
      borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );
}
