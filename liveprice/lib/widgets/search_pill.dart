import 'package:flutter/material.dart';

class SearchPill extends StatelessWidget {
  final ValueChanged<String>? onChanged;
  final String hintText;

  const SearchPill({super.key, this.onChanged, this.hintText = 'Search products...'});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 17, color: Colors.black),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.black45, fontSize: 17),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.black, size: 26),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
