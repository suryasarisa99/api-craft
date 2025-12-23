import 'package:api_craft/core/widgets/ui/custom_dialog.dart';
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
    return CustomDialog(
      width: 400,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          const Text(
            "Create New Environment",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              // labelText: "Name",
              hintText: "Name",
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),

          // Color Selection
          const Padding(padding: .only(left: 10), child: Text("Color Code")),
          const SizedBox(height: 8),
          Padding(
            padding: const .only(left: 10),
            child: Row(
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
                      borderRadius: BorderRadius.circular(16),
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
          ),
          const SizedBox(height: 16),

          // Shared Toggle
          Row(
            children: [
              Transform.scale(
                scale: 0.6,
                child: Switch(
                  value: _isShared,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: .zero,
                  onChanged: (val) => setState(() => _isShared = val),
                  // activeColor: Colors.blue,
                ),
              ),
              const Text("Share this environment"),
              const SizedBox(width: 16),
              Tooltip(
                message: "Shared environments are synced with your team",
                child: Icon(Icons.info_outline, color: Colors.grey, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Spacer(),
              // TextButton(
              //   onPressed: () => Navigator.pop(context),
              //   child: Text(
              //     "Cancel",
              //     style: TextStyle(color: Colors.grey[350]),
              //   ),
              // ),
              const SizedBox(width: 16),
              FilledButton(onPressed: _submit, child: const Text("Create")),
            ],
          ),
        ],
      ),
    );
  }
}
