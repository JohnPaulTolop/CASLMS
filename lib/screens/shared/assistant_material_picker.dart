import 'package:flutter/material.dart';

import '../../services/assistant_attachment_service.dart';

class AssistantMaterialPicker extends StatefulWidget {
  const AssistantMaterialPicker({super.key, required this.service, this.initialCourseId});
  final AssistantAttachmentService service;
  final String? initialCourseId;
  @override
  State<AssistantMaterialPicker> createState() =>
      _AssistantMaterialPickerState();
}

class _AssistantMaterialPickerState extends State<AssistantMaterialPicker> {
  String? _courseId, _moduleId, _error;
  String _query = '';
  bool _busy = false;
  late Future<List<Map<String, dynamic>>> _rows;
  @override
  void initState() {
    super.initState();
    _courseId = widget.initialCourseId;
    _load();
  }

  void _load() {
    _rows = _moduleId != null
        ? widget.service.materials(_courseId!, _moduleId!)
        : _courseId != null
        ? widget.service.modules(_courseId!)
        : widget.service.courses();
  }

  Future<void> _select(Map<String, dynamic> row) async {
    if (_busy) return;
    if (_moduleId == null) {
      setState(() {
        if (_courseId == null) {
          _courseId = row['id'];
        } else {
          _moduleId = row['id'];
        }
        _query = '';
        _error = null;
        _load();
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final item = await widget.service.fromMaterial(
        _courseId!,
        _moduleId!,
        row['id'].toString(),
      );
      if (mounted) Navigator.pop(context, item);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Unable to attach this material. Use a readable PDF, text or Office file under 5 MB, or a module link.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (_courseId != null)
                  IconButton(
                    tooltip:
                        'Back to ${_moduleId == null ? 'courses' : 'modules'}',
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            if (_moduleId != null) {
                              _moduleId = null;
                            } else {
                              _courseId = null;
                            }
                            _query = '';
                            _error = null;
                            _load();
                          }),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Expanded(
                  child: Text(
                    _moduleId != null
                        ? 'Choose a material'
                        : _courseId != null
                        ? 'Choose a module'
                        : 'Your course materials',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close materials',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: ValueKey('$_courseId:$_moduleId'),
              onChanged: (value) =>
                  setState(() => _query = value.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _rows,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: TextButton.icon(
                        onPressed: () => setState(_load),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Could not load materials. Retry'),
                      ),
                    );
                  }
                  final rows = (snapshot.data ?? [])
                      .where(
                        (row) =>
                            '${row['title']} ${row['code']} ${row['fileName']}'
                                .toLowerCase()
                                .contains(_query),
                      )
                      .toList();
                  if (rows.isEmpty) {
                    return const Center(
                      child: Text('No published materials found.'),
                    );
                  }
                  return ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return ListTile(
                        enabled: !_busy,
                        leading: Icon(
                          _moduleId == null
                              ? Icons.folder_outlined
                              : row['deliveryType'] == 'external_link'
                              ? Icons.link_rounded
                              : Icons.description_outlined,
                        ),
                        title: Text(
                          (row['title'] ?? row['fileName'] ?? 'Untitled')
                              .toString(),
                        ),
                        subtitle: row['code'] != null
                            ? Text(row['code'].toString())
                            : null,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _select(row),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
