import 'package:flutter/material.dart';

class TextWidget extends StatelessWidget {
  final String text;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final String fontFamily;
  final TextAlign textAlign;
  final EdgeInsetsGeometry padding;
  final TextStyle? style;

  const TextWidget({
    super.key,
    required this.text,
    this.fontSize,
    this.padding = EdgeInsets.zero,
    this.fontFamily = "lato",
    this.textAlign = TextAlign.left,
    this.fontWeight,
    this.color = Colors.white,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        textAlign: textAlign,
        style: style ??
            TextStyle(
              color: color ?? Theme.of(context).primaryColor,
              fontSize: fontSize,
              fontFamily: fontFamily,
              fontWeight: fontWeight,
            ),
      ),
    );
  }
}
