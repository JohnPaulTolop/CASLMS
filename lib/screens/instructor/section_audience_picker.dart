import 'package:flutter/material.dart';

import '../../services/section_audience_service.dart';

class SectionAudiencePicker extends StatelessWidget {
  const SectionAudiencePicker({
    super.key,
    required this.sections,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.parentAudience,
  });

  final List<Map<String, dynamic>> sections;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;
  final List<String>? parentAudience;

  bool _insideParent(String id) {
    final parent = parentAudience;
    return parent == null ||
        parent.contains(SectionAudienceService.allSections) ||
        parent.contains(id);
  }

  @override
  Widget build(BuildContext context) {
    final all = value.contains(SectionAudienceService.allSections);
    return Semantics(
      container: true,
      label: 'Assigned sections',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            key: const ValueKey('audience-all-sections'),
            contentPadding: EdgeInsets.zero,
            value: all,
            onChanged:
                !enabled ||
                    parentAudience != null &&
                        !parentAudience!.contains(
                          SectionAudienceService.allSections,
                        )
                ? null
                : (selected) => onChanged(
                    selected == true
                        ? SectionAudienceService.legacySharedAudience
                        : const <String>[],
                  ),
            title: const Text('All sections'),
            subtitle: const Text('Every current section in this course'),
          ),
          for (final section in sections)
            if (_insideParent((section['id'] ?? '').toString()))
              CheckboxListTile(
                key: ValueKey('audience-section-${section['id']}'),
                contentPadding: EdgeInsets.zero,
                value: !all && value.contains(section['id']),
                onChanged: !enabled || all
                    ? null
                    : (selected) {
                        final next = value
                            .where(
                              (id) => id != SectionAudienceService.allSections,
                            )
                            .toSet();
                        final id = (section['id'] ?? '').toString();
                        if (selected == true) {
                          next.add(id);
                        } else {
                          next.remove(id);
                        }
                        onChanged(next.toList());
                      },
                title: Text((section['name'] ?? 'Section').toString()),
                subtitle: Text(
                  (section['identifier'] ?? section['id'] ?? '').toString(),
                ),
              ),
          if (value.isEmpty)
            Text(
              'Choose one or more sections, or explicitly choose All sections.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
