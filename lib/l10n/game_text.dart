import 'package:flutter/material.dart';
import 'catalog.dart';
import '../theme.dart';

class LanguageScope extends InheritedWidget {
  final String language;
  const LanguageScope(
      {super.key, required this.language, required super.child});
  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()?.language ??
      'es';
  @override
  bool updateShouldNotify(LanguageScope oldWidget) =>
      language != oldWidget.language;
}

extension GameTranslation on BuildContext {
  String tr(String source) => Catalog.translate(source, LanguageScope.of(this));
}

class GameText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextDirection? textDirection;
  final String? semanticsLabel;
  final bool translate;
  const GameText(this.data,
      {super.key,
      this.style,
      this.textAlign,
      this.maxLines,
      this.overflow,
      this.softWrap,
      this.textDirection,
      this.semanticsLabel,
      this.translate = true});
  @override
  Widget build(BuildContext context) {
    final inherited = DefaultTextStyle.of(context).style.merge(style);
    final readable = inherited.copyWith(
      fontFamily: style?.fontFamily ?? SS.readingFamily,
      fontSize: (inherited.fontSize ?? 16).clamp(14, double.infinity),
    );
    return Text(translate ? context.tr(data) : data,
        style: readable,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
        textDirection: textDirection,
        semanticsLabel:
            semanticsLabel == null ? null : context.tr(semanticsLabel!));
  }
}
