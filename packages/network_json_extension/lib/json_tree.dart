import 'dart:convert';
import 'package:flutter/material.dart';
import 'theme.dart';

/// Lazy children keep large JSON collections from building thousands of rows.
class JsonTree extends StatefulWidget {
  const JsonTree({super.key, required this.value, this.label = '[root]', this.depth = 0});
  final Object? value;
  final String label;
  final int depth;
  @override
  State<JsonTree> createState() => _JsonTreeState();
}

class _JsonTreeState extends State<JsonTree> {
  bool open = true;
  int visible = 100;
  @override
  void initState() { super.initState(); open = widget.depth < 3; }
  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final collection = value is Map || value is List;
    final count = value is Map ? value.length : value is List ? value.length : 0;
    final summary = collection
        ? '${value is Map ? 'Map' : 'List'} ($count ${count == 1 ? 'item' : 'items'})'
        : jsonEncode(value);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: collection ? () => setState(() => open = !open) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 18, child: collection ? Icon(
              open ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              size: 16, color: muted) : null),
            Flexible(child: Text.rich(TextSpan(
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.6),
              children: [
                TextSpan(text: '${widget.label}${collection ? ': ' : ':  '}',
                  style: TextStyle(color: widget.depth == 0 ? muted : accent)),
                TextSpan(text: summary, style: TextStyle(color: collection ? muted
                    : value is String ? orange : value is num ? const Color(0xff91bfd8) : mint)),
              ]))),
          ]))),
      if (collection && open) Padding(
        padding: const EdgeInsets.only(left: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (value is Map) ...value.entries.take(visible).map((entry) => JsonTree(
            key: ValueKey(entry.key), value: entry.value,
            label: entry.key.toString(), depth: widget.depth + 1)),
          if (value is List) ...List.generate(value.length < visible ? value.length : visible,
            (i) => JsonTree(key: ValueKey(i), value: value[i], label: '[$i]', depth: widget.depth + 1)),
          if (count > visible) TextButton(
            onPressed: () => setState(() => visible += 100),
            child: Text('Mostrar más (${count - visible} restantes)')),
        ])),
    ]);
  }
}
