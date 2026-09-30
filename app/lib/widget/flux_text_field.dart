import 'package:flutter/material.dart';

/// 居中文本输入框，设置页各输入项共用。
class FluxTextField extends StatelessWidget {
  final String name;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onDelete;

  const FluxTextField({
    required this.name,
    required this.controller,
    this.onChanged,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textAlign: TextAlign.center,
      onChanged: onChanged,
      decoration: InputDecoration(
        suffixIcon: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => onDelete?.call(),
              )
            : null,
      ),
    );
  }
}
