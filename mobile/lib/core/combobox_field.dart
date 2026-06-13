import "package:flutter/material.dart";

import "app_input_field.dart";
import "app_text_styles.dart";

/// Text field with type-ahead suggestions and a dropdown list of all options.
///
/// Users can pick from existing values or type a new one.
class ComboboxField extends StatelessWidget {
  const ComboboxField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.options,
    this.helperText,
    this.trailing,
  });

  final TextEditingController controller;
  final String labelText;
  final List<String> options;
  final String? helperText;
  final Widget? trailing;

  Iterable<String> _matchingOptions(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return options;
    }
    return options.where((option) => option.toLowerCase().contains(needle));
  }

  Future<void> _showAllOptions(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        if (options.isEmpty) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(labelText, style: context.screenTitle),
                  const SizedBox(height: 12),
                  Text(
                    "No saved values yet. Type in the field to add a new one.",
                    style: context.listSecondary(),
                  ),
                ],
              ),
            ),
          );
        }

        final maxHeight = MediaQuery.sizeOf(context).height * 0.55;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(labelText, style: context.screenTitle),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.4),
                  ),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final selected =
                        controller.text.trim().toLowerCase() ==
                            option.toLowerCase();
                    return ListTile(
                      title: Text(option, style: context.listSecondary()),
                      trailing: selected
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, option),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null) {
      controller.text = picked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dropdownButton = IconButton(
      tooltip: options.isEmpty
          ? "No saved $labelText options yet"
          : "Show all $labelText options",
      onPressed: () => _showAllOptions(context),
      icon: Icon(
        Icons.arrow_drop_down,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      ),
    );

    Widget? suffix;
    if (trailing != null) {
      suffix = Row(
        mainAxisSize: MainAxisSize.min,
        children: [trailing!, dropdownButton],
      );
    } else {
      suffix = dropdownButton;
    }

    return Autocomplete<String>(
      displayStringForOption: (option) => option,
      optionsBuilder: (value) => _matchingOptions(value.text),
      onSelected: (option) {
        controller.text = option;
      },
      fieldViewBuilder: (context, _, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: fieldTextStyle(context),
          cursorColor: fieldCursorColor(context),
          decoration: labeledInputDecoration(
            context,
            labelText: labelText,
            helperText: helperText,
            suffixIcon: suffix,
          ),
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, rawOptions) {
        final items = rawOptions.toList();
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHighest,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 400),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                itemBuilder: (context, index) {
                  final option = items[index];
                  return ListTile(
                    title: Text(option, style: context.listSecondary()),
                    dense: true,
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

List<String> mergeComboboxOptions(
  Iterable<String> options, {
  String? currentValue,
}) {
  final merged = <String>{
    for (final option in options)
      if (option.trim().isNotEmpty) option.trim(),
  };
  final current = currentValue?.trim();
  if (current != null && current.isNotEmpty) {
    merged.add(current);
  }
  final sorted = merged.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return sorted;
}
