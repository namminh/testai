import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Cho HapticFeedback
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/my_app_colors.dart';

class CommonTextFormField extends StatefulWidget {
  final void Function()? onEditingComplete;
  final void Function()? onTap;
  final TextEditingController? controller;
  final Widget? prefixIconWidget;
  final Widget? suffixIconWidget;
  final String? hintTextWidget;
  final String? obsocuringCharacter;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final String? labelTextWidget;

  const CommonTextFormField({
    super.key,
    this.suffixIconWidget,
    this.prefixIconWidget,
    this.hintTextWidget,
    this.onEditingComplete,
    this.onTap,
    this.controller,
    this.obsocuringCharacter,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines = 1,
    this.labelTextWidget,
  });

  @override
  State<CommonTextFormField> createState() => _CommonTextFormFieldState();
}

class _CommonTextFormFieldState extends State<CommonTextFormField>
    with TickerProviderStateMixin {
  late FocusNode _focusNode;
  int explorationXP = 0;
  int tapCount = 0;
  DateTime? lastTapTime;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
    _loadXP();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadXP() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      explorationXP = prefs.getInt('explorationXP') ?? 0;
    });
  }

  Future<void> _saveXP(int newXP) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('explorationXP', newXP);
    setState(() {
      explorationXP = newXP;
    });
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      HapticFeedback.selectionClick(); // Rung khi focus
    }
    setState(() {});
  }

  void _handlePrefixTap() {
    final now = DateTime.now();
    if (lastTapTime != null && now.difference(lastTapTime!).inSeconds < 2) {
      tapCount++;
    } else {
      tapCount = 1;
    }
    lastTapTime = now;

    if (tapCount == 3) {
      setState(() {
        tapCount = 0;
        _saveXP(explorationXP + 10); // Rương ẩn
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rương ẩn mở: +10 XP!')),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _focusNode.hasFocus ? Colors.yellow[700]! : Colors.green[700]!,
              _focusNode.hasFocus ? Colors.green[700]! : Colors.blue[700]!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focusNode.hasFocus
                ? Colors.yellow
                : Colors.white.withOpacity(0.5),
            width: 2,
          ),
          image: const DecorationImage(
            image: AssetImage('assets/images/rune_border.png'), // Viền rune
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
          boxShadow: [
            if (_focusNode.hasFocus)
              BoxShadow(
                color: Colors.yellow.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
          ],
        ),
        child: TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          onEditingComplete: () {
            widget.onEditingComplete?.call();
            if (widget.controller?.text.isNotEmpty ?? false) {
              _saveXP(explorationXP + 5); // Thưởng XP khi hoàn thành
              HapticFeedback.lightImpact();
            }
          },
          onTap: widget.onTap,
          obscureText: widget.obscureText,
          obscuringCharacter: widget.obsocuringCharacter ?? '•',
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.all(16),
            hintText: widget.hintTextWidget,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            labelText: widget.labelTextWidget,
            labelStyle: const TextStyle(color: Colors.white),
            prefixIcon: widget.prefixIconWidget != null
                ? GestureDetector(
                    onTap: _handlePrefixTap, // Rương ẩn khi nhấn icon
                    child: widget.prefixIconWidget,
                  )
                : null,
            suffixIcon: widget.suffixIconWidget,
            border: InputBorder
                .none, // Loại border mặc định để dùng AnimatedContainer
          ),
        ),
      ),
    );
  }
}
