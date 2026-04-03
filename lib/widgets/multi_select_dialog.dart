import 'package:flutter/material.dart';

class MultiSelectDialog<T> extends StatefulWidget {
  final List<T> items;
  final List<T> initialSelected;
  final String Function(T) labelBuilder;
  final String title;
  final Color brandColor;
  final Color chipColor;

  const MultiSelectDialog({
    Key? key,
    required this.items,
    required this.initialSelected,
    required this.labelBuilder,
    required this.title,
    required this.brandColor,
    required this.chipColor,
  }) : super(key: key);

  @override
  State<MultiSelectDialog<T>> createState() => _MultiSelectDialogState<T>();
}

class _MultiSelectDialogState<T> extends State<MultiSelectDialog<T>> {
  late List<T> _selected;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = List<T>.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where(
          (item) => widget
              .labelBuilder(item)
              .toLowerCase()
              .contains(_search.toLowerCase()),
        )
        .toList();
    return Dialog(
      backgroundColor: const Color(0xFFf6f6d7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: widget.brandColor,
                ),
              ),
            ),
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: _selected
                      .map(
                        (item) => Chip(
                          label: Text(
                            widget.labelBuilder(item),
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: widget.chipColor,
                          onDeleted: () {
                            setState(() => _selected.remove(item));
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search, color: widget.brandColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 12,
                  ),
                ),
                style: TextStyle(color: widget.brandColor),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            Expanded(
              child: Scrollbar(
                child: ListView(
                  children: filtered
                      .map(
                        (item) => CheckboxListTile(
                          value: _selected.contains(item),
                          title: Text(
                            widget.labelBuilder(item),
                            style: TextStyle(color: widget.brandColor),
                          ),
                          activeColor: widget.chipColor,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selected.add(item);
                              } else {
                                _selected.remove(item);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: TextButton.styleFrom(
                      foregroundColor: widget.brandColor,
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.chipColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
