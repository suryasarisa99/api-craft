import 'package:flutter/material.dart';

class EnvironmentCreationDialog extends StatefulWidget {
  final Future<void> Function(String name, Color? color, bool isShared)
  onCreate;

  const EnvironmentCreationDialog({super.key, required this.onCreate});

  @override
  State<EnvironmentCreationDialog> createState() =>
      _EnvironmentCreationDialogState();
}

class _EnvironmentCreationDialogState extends State<EnvironmentCreationDialog> {
  final _nameController = TextEditingController();
  Color? _selectedColor;
  bool _isShared = false;

  final List<Color> _colors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.amber,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) return;
    widget
        .onCreate(_nameController.text.trim(), _selectedColor, _isShared)
        .then((_) {
          if (mounted) Navigator.pop(context);
        });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Create Environment"),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name Input
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Name",
                hintText: "e.g., Production, Staging",
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),

            // Color Selection
            const Text("Color Code"),
            const SizedBox(height: 8),
            Row(
              children: [
                // "None" option
                InkWell(
                  onTap: () => setState(() => _selectedColor = null),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColor == null
                            ? Colors.white
                            : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.block,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ..._colors.map((c) {
                  final isSelected = _selectedColor == c;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InkWell(
                      onTap: () => setState(() => _selectedColor = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),

            // Shared Toggle
            Row(
              children: [
                Switch(
                  value: _isShared,
                  onChanged: (val) => setState(() => _isShared = val),
                  // activeColor: Colors.blue,
                ),
                const SizedBox(width: 8),
                const Text("Share this environment"),
              ],
            ),
            const Text(
              "Shared environments are synced with your team (if applicable).",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text("Create"),
        ),
      ],
    );
  }
}
