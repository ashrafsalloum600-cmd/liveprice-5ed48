import 'package:flutter/material.dart';

class SearchPill extends StatelessWidget {
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final ValueChanged<String>? onHistorySelected;
  final List<String> history;

  const SearchPill({
    super.key,
    this.onChanged,
    this.onSearchSubmitted,
    this.onHistorySelected,
    this.history = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Autocomplete<String>(
        optionsBuilder: (textEditingValue) {
          final query = textEditingValue.text.trim().toLowerCase();
          if (query.isEmpty) return history;
          return history.where((entry) => entry.toLowerCase().contains(query));
        },
        onSelected: (value) => onHistorySelected?.call(value),
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onSubmitted: (value) {
            onFieldSubmitted();
            onSearchSubmitted?.call(value);
          },
          style: const TextStyle(fontSize: 17, color: Colors.black),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'ابحث عن مادة ...',
            hintStyle: const TextStyle(color: Colors.black45, fontSize: 17),
            prefixIcon: const Icon(Icons.search_rounded, color: Colors.black, size: 26),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.black54),
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                    },
                  ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 280),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.history_rounded, size: 20),
                      title: Text(option, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => onSelected(option),
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
