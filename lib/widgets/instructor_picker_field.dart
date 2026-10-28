import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/instructor.dart';
import '../theme/app_design_tokens.dart';

/// Searchable dropdown field for selecting a teaching-capable instructor.
/// Follows the anchored search-menu pattern used by the reservation member
/// picker so it stays responsive on narrow screens.
class InstructorPickerField extends StatefulWidget {
  final List<Instructor> instructors;
  final int? selectedInstructorId;
  final ValueChanged<int> onSelected;
  final bool enabled;

  const InstructorPickerField({
    super.key,
    required this.instructors,
    required this.selectedInstructorId,
    required this.onSelected,
    this.enabled = true,
  });

  @override
  State<InstructorPickerField> createState() => _InstructorPickerFieldState();
}

class _InstructorPickerFieldState extends State<InstructorPickerField> {
  final GlobalKey _fieldKey = GlobalKey();

  Instructor? get _selectedInstructor {
    for (final instructor in widget.instructors) {
      if (int.tryParse(instructor.id) == widget.selectedInstructorId) {
        return instructor;
      }
    }
    return null;
  }

  Future<void> _openMenu() async {
    final fieldContext = _fieldKey.currentContext;
    if (fieldContext == null) return;

    final renderBox = fieldContext.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final fieldSize = renderBox.size;
    final fieldOffset = renderBox.localToGlobal(Offset.zero);

    final selectedId = await showMenu<int>(
      context: context,
      color: AppDesignTokens.surface,
      elevation: 6,
      menuPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      constraints: BoxConstraints.tightFor(width: fieldSize.width),
      position: RelativeRect.fromLTRB(
        fieldOffset.dx,
        fieldOffset.dy + fieldSize.height,
        overlay.size.width - (fieldOffset.dx + fieldSize.width),
        0,
      ),
      items: [
        PopupMenuItem<int>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _InstructorDropdownSearchContent(
            instructors: widget.instructors,
            width: fieldSize.width,
            selectedInstructorId: widget.selectedInstructorId,
          ),
        ),
      ],
    );

    if (!mounted || selectedId == null) return;
    widget.onSelected(selectedId);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final selected = _selectedInstructor;
    return InkWell(
      key: _fieldKey,
      onTap: widget.enabled ? _openMenu : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: loc?.translate('instructor') ?? 'Instructor',
          labelStyle: AppTypography.label,
          filled: true,
          fillColor: AppDesignTokens.backgroundSecondary,
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: AppDesignTokens.border),
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppDesignTokens.border),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppDesignTokens.textPrimary),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected?.username ??
                    (loc?.translate('selectInstructor') ??
                        'Select an instructor'),
                style: selected != null
                    ? AppTypography.body
                    : AppTypography.body.copyWith(
                        color: AppDesignTokens.textMuted,
                      ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: AppDesignTokens.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructorDropdownSearchContent extends StatefulWidget {
  final List<Instructor> instructors;
  final double width;
  final int? selectedInstructorId;

  const _InstructorDropdownSearchContent({
    required this.instructors,
    required this.width,
    required this.selectedInstructorId,
  });

  @override
  State<_InstructorDropdownSearchContent> createState() =>
      _InstructorDropdownSearchContentState();
}

class _InstructorDropdownSearchContentState
    extends State<_InstructorDropdownSearchContent> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeSearchText(String value) {
    const replacements = {
      'I': 'i',
      'İ': 'i',
      'ı': 'i',
      'Ş': 's',
      'ş': 's',
      'Ğ': 'g',
      'ğ': 'g',
      'Ü': 'u',
      'ü': 'u',
      'Ö': 'o',
      'ö': 'o',
      'Ç': 'c',
      'ç': 'c',
    };

    final normalized = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      normalized.write(replacements[char] ?? char.toLowerCase());
    }
    return normalized.toString();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final normalizedQuery = _normalizeSearchText(_searchText.trim());
    final filteredInstructors = widget.instructors.where((instructor) {
      if (normalizedQuery.isEmpty) return true;
      return _normalizeSearchText(
        instructor.username,
      ).contains(normalizedQuery);
    }).toList();

    return SizedBox(
      width: widget.width,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
                style: AppTypography.body,
                decoration: InputDecoration(
                  isDense: true,
                  hintText:
                      loc?.translate('searchInstructors') ??
                      'Search instructors...',
                  hintStyle: AppTypography.caption,
                  prefixIcon: const Icon(AppIcons.search, size: 18),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchText = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppDesignTokens.backgroundSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            Flexible(
              child: filteredInstructors.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        loc?.translate('noInstructorsFound') ??
                            'No instructors found',
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      shrinkWrap: true,
                      itemCount: filteredInstructors.length,
                      itemBuilder: (context, index) {
                        final instructor = filteredInstructors[index];
                        final instructorId = int.tryParse(instructor.id);
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          visualDensity: const VisualDensity(
                            vertical: -2,
                            horizontal: 0,
                          ),
                          title: Text(
                            instructor.username,
                            style: AppTypography.body,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing:
                              instructorId != null &&
                                  instructorId == widget.selectedInstructorId
                              ? const Icon(
                                  Icons.check,
                                  color: AppDesignTokens.textPrimary,
                                  size: 18,
                                )
                              : null,
                          onTap: instructorId == null
                              ? null
                              : () => Navigator.of(context).pop(instructorId),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
