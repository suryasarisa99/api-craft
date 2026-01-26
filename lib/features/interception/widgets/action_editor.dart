import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mockhttp/ui/rule_config.dart';

class ActionEditor extends StatefulWidget {
  final RuleActionConfig config;
  final ValueChanged<RuleActionConfig> onChanged;

  const ActionEditor({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  State<ActionEditor> createState() => _ActionEditorState();
}

class _ActionEditorState extends State<ActionEditor> {
  late RuleActionConfig _config;
  late TextEditingController _bodyController;
  late TextEditingController _headersController;
  late TextEditingController _statusCodeController;
  late TextEditingController _timeoutController;
  late TextEditingController _filePathController;
  late TextEditingController _forwardUrlController;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _bodyController = TextEditingController(text: _getBodyText());
    _headersController = TextEditingController(text: _getHeadersText());
    _statusCodeController = TextEditingController(
      text: _config.statusCode?.toString() ?? '200',
    );
    _timeoutController = TextEditingController(
      text: _config.timeoutMs?.toString() ?? '',
    );
    _filePathController = TextEditingController(text: _config.filePath ?? '');
    _forwardUrlController = TextEditingController(
      text: _config.forwardToUrl ?? '',
    );
  }

  @override
  void didUpdateWidget(ActionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config != oldWidget.config) {
      _config = widget.config;
      // Ideally update controllers if outer config changed not via internal edit
    }
  }

  String _getBodyText() {
    if (_config.type == 'json' && _config.jsonData != null) {
      return const JsonEncoder.withIndent('  ').convert(_config.jsonData);
    }
    return _config.body ?? '';
  }

  String _getHeadersText() {
    if (_config.headers == null) return '';
    return _config.headers!.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() {
        _filePathController.text = path;
        _config.filePath = path;
      });
      _updateConfig();
    }
  }

  void _updateConfig() {
    widget.onChanged(_config);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<String>(
          value: _config.type,
          underline: SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: 'passthrough', child: Text('Passthrough')),
            DropdownMenuItem(value: 'reply', child: Text('Reply (Text/HTML)')),
            DropdownMenuItem(value: 'json', child: Text('Reply (JSON)')),
            DropdownMenuItem(value: 'file', child: Text('Reply (File)')),
            DropdownMenuItem(value: 'pauseReq', child: Text('Pause Request')),
            DropdownMenuItem(value: 'pauseRes', child: Text('Pause Response')),
            DropdownMenuItem(
              value: 'pauseReqRes',
              child: Text('Pause Req/Res'),
            ),
            DropdownMenuItem(value: 'editReq', child: Text('Edit Request')),
            DropdownMenuItem(value: 'editRes', child: Text('Edit Response')),
            DropdownMenuItem(value: 'close', child: Text('Close Connection')),
            DropdownMenuItem(value: 'timeout', child: Text('Timeout')),
          ],
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              _config.type = val;
            });
            _updateConfig();
          },
        ),
        const SizedBox(height: 16),
        ..._buildSpecificFields(),
      ],
    );
  }

  List<Widget> _buildSpecificFields() {
    switch (_config.type) {
      case 'passthrough':
        return [
          TextField(
            controller: _forwardUrlController,
            decoration: const InputDecoration(
              labelText: 'Forward To URL (Optional)',
            ),
            onChanged: (val) {
              _config.forwardToUrl = val.isEmpty ? null : val;
              _updateConfig();
            },
          ),
          CheckboxListTile(
            title: const Text('Ignore Host Certificate Errors'),
            value: _config.ignoreHostCertificateErrors,
            onChanged: (val) {
              setState(() {
                _config.ignoreHostCertificateErrors = val ?? true;
              });
              _updateConfig();
            },
          ),
        ];
      case 'reply':
      case 'json':
        return [
          TextField(
            controller: _statusCodeController,
            decoration: const InputDecoration(labelText: 'Status Code'),
            keyboardType: TextInputType.number,
            onChanged: (val) {
              _config.statusCode = int.tryParse(val) ?? 200;
              _updateConfig();
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyController,
            decoration: InputDecoration(
              labelText: _config.type == 'json' ? 'JSON Data' : 'Body',
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            onChanged: (val) {
              if (_config.type == 'json') {
                try {
                  _config.jsonData = jsonDecode(val);
                } catch (_) {
                  // invalid json, ignore update or show error
                }
              } else {
                _config.body = val;
              }
              _updateConfig();
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _headersController,
            decoration: const InputDecoration(
              labelText: 'Headers (Key: Value)',
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            onChanged: (val) {
              final Map<String, String> headers = {};
              for (var line in val.split('\n')) {
                final parts = line.split(':');
                if (parts.length >= 2) {
                  headers[parts[0].trim()] = parts.sublist(1).join(':').trim();
                }
              }
              _config.headers = headers.isEmpty ? null : headers;
              _updateConfig();
            },
          ),
        ];
      case 'editReq':
      case 'editRes':
        return [
          Text(
            "Write a JS function 'edit(req/res)' that returns modified object.",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: _config.script)
              ..selection = TextSelection.collapsed(
                offset: (_config.script ?? '').length,
              ),
            decoration: const InputDecoration(
              labelText: 'Script',
              hintText:
                  "function edit(obj) { obj.headers['new']='val'; return obj; }",
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            maxLines: 10,
            onChanged: (val) {
              _config.script = val;
              _updateConfig();
            },
          ),
          if (_config.type == 'editRes')
            CheckboxListTile(
              title: const Text('Ignore Host Certificate Errors'),
              value: _config.ignoreHostCertificateErrors,
              onChanged: (val) {
                setState(() {
                  _config.ignoreHostCertificateErrors = val ?? true;
                });
                _updateConfig();
              },
            ),
        ];
      case 'file':
        return [
          TextField(
            controller: _statusCodeController,
            decoration: const InputDecoration(labelText: 'Status Code'),
            keyboardType: TextInputType.number,
            onChanged: (val) {
              _config.statusCode = int.tryParse(val) ?? 200;
              _updateConfig();
            },
          ),
          TextField(
            controller: _filePathController,
            decoration: InputDecoration(
              labelText: 'File Path',
              suffixIcon: IconButton(
                icon: const Icon(Icons.folder_open),
                onPressed: _pickFile,
                tooltip: 'Pick File',
              ),
            ),
            onChanged: (val) {
              _config.filePath = val;
              _updateConfig();
            },
          ),
        ];
      case 'timeout':
        return [
          TextField(
            controller: _timeoutController,
            decoration: const InputDecoration(labelText: 'Timeout (ms)'),
            keyboardType: TextInputType.number,
            onChanged: (val) {
              _config.timeoutMs = int.tryParse(val);
              _updateConfig();
            },
          ),
        ];
      default:
        return [];
    }
  }
}
