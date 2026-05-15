import 'dart:async';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const BarSourceDevToolsExtension());
}

class BarSourceDevToolsExtension extends StatelessWidget {
  const BarSourceDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(child: _BarSourceDevToolsPage());
  }
}

class _BarSourceDevToolsPage extends StatefulWidget {
  const _BarSourceDevToolsPage();

  @override
  State<_BarSourceDevToolsPage> createState() => _BarSourceDevToolsPageState();
}

class _BarSourceDevToolsPageState extends State<_BarSourceDevToolsPage> {
  static const _statusExtension = 'ext.barsource.status';
  static const _reassembleExtension = 'ext.barsource.reassemble';
  static const _widgetTreeExtension = 'ext.barsource.widgetTree';

  bool _connected = false;
  bool _isBusy = false;
  bool _autoRefresh = true;
  String? _error;
  Map<String, dynamic>? _status;
  _InspectorNode? _rootNode;
  _InspectorNode? _selectedNode;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _connected = serviceManager.connectedState.value.connected;
    serviceManager.connectedState.addListener(_handleConnectionChanged);
    if (_connected) {
      unawaited(_refreshAll());
    }
    _configureStatusPolling();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    serviceManager.connectedState.removeListener(_handleConnectionChanged);
    super.dispose();
  }

  void _handleConnectionChanged() {
    final nextConnected = serviceManager.connectedState.value.connected;
    if (nextConnected == _connected) return;
    setState(() {
      _connected = nextConnected;
      _error = null;
      if (!nextConnected) {
        _status = null;
        _rootNode = null;
        _selectedNode = null;
      }
    });
    if (nextConnected) {
      unawaited(_refreshAll());
    }
    _configureStatusPolling();
  }

  void _configureStatusPolling() {
    _statusTimer?.cancel();
    if (!_connected || !_autoRefresh) return;
    _statusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshStatus(),
    );
  }

  Future<Map<String, dynamic>> _callExtension(String method) async {
    final response = await serviceManager.callServiceExtensionOnMainIsolate(
      method,
    );
    return Map<String, dynamic>.from(response.json ?? const {});
  }

  Future<void> _refreshStatus() async {
    if (!_connected) return;
    try {
      final payload = await _callExtension(_statusExtension);
      if (!mounted) return;
      setState(() {
        _status = payload;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to fetch status: $error';
      });
    }
  }

  Future<void> _refreshWidgetTree() async {
    if (!_connected) return;
    setState(() {
      _isBusy = true;
    });
    try {
      final payload = await _callExtension(_widgetTreeExtension);
      final treeData = payload['tree'];
      _InspectorNode? root;
      if (treeData is Map<String, dynamic>) {
        root = _InspectorNode.fromJson(treeData);
      } else if (treeData is Map) {
        root = _InspectorNode.fromJson(Map<String, dynamic>.from(treeData));
      }
      if (!mounted) return;
      setState(() {
        _rootNode = root;
        _selectedNode = root;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to fetch widget tree: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_refreshStatus(), _refreshWidgetTree()]);
  }

  Future<void> _performHotReload() async {
    if (!_connected) return;
    setState(() {
      _isBusy = true;
    });
    try {
      await _callExtension(_reassembleExtension);
      await _refreshAll();
      if (!mounted) return;
      setState(() {
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Hot reload failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rendering = _status?['rendering'] == true;
    final reassembleInProgress = _status?['reassembleInProgress'] == true;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.movie_filter_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'BarSource DevTools',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 16),
                  _StatusChip(
                    label: _connected ? 'VM Connected' : 'No VM Connection',
                    ok: _connected,
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: rendering ? 'Rendering' : 'Idle',
                    ok: rendering,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh status',
                    onPressed: _connected ? _refreshStatus : null,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: 'Refresh widget tree',
                    onPressed: _connected ? _refreshWidgetTree : null,
                    icon: const Icon(Icons.account_tree_outlined),
                  ),
                  FilledButton.icon(
                    onPressed: (_connected && !_isBusy)
                        ? _performHotReload
                        : null,
                    icon: reassembleInProgress
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bolt),
                    label: Text(
                      reassembleInProgress ? 'Reloading…' : 'Hot Reload',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'Widgets Tree'),
              Tab(text: 'Runtime'),
            ],
          ),
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() => _error = null);
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: TabBarView(
              children: [
                _InspectorTab(
                  rootNode: _rootNode,
                  selectedNode: _selectedNode,
                  onNodeSelected: (node) =>
                      setState(() => _selectedNode = node),
                ),
                _RuntimeTab(
                  status: _status,
                  autoRefresh: _autoRefresh,
                  onAutoRefreshChanged: (value) {
                    setState(() => _autoRefresh = value);
                    _configureStatusPolling();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.ok});
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = ok ? scheme.primaryContainer : scheme.errorContainer;
    final fg = ok ? scheme.onPrimaryContainer : scheme.onErrorContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: TextStyle(color: fg)),
    );
  }
}

class _RuntimeTab extends StatelessWidget {
  const _RuntimeTab({
    required this.status,
    required this.autoRefresh,
    required this.onAutoRefreshChanged,
  });

  final Map<String, dynamic>? status;
  final bool autoRefresh;
  final ValueChanged<bool> onAutoRefreshChanged;

  @override
  Widget build(BuildContext context) {
    final frameDurationMs = status?['frameDurationMs'];
    final currentTimeMicros = status?['currentTimeMicros'];
    final fps = frameDurationMs is num && frameDurationMs > 0
        ? (1000 / frameDurationMs).toStringAsFixed(2)
        : '—';

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SwitchListTile(
          title: const Text('Auto refresh runtime status'),
          value: autoRefresh,
          onChanged: onAutoRefreshChanged,
        ),
        _KeyValueTile(
          label: 'Rendering',
          value: '${status?['rendering'] ?? false}',
        ),
        _KeyValueTile(
          label: 'DevTools enabled',
          value: '${status?['devtoolsEnabled'] ?? false}',
        ),
        _KeyValueTile(
          label: 'Reassemble in progress',
          value: '${status?['reassembleInProgress'] ?? false}',
        ),
        _KeyValueTile(label: 'Current time (us)', value: '$currentTimeMicros'),
        _KeyValueTile(label: 'Frame duration (ms)', value: '$frameDurationMs'),
        _KeyValueTile(label: 'Approx FPS', value: fps),
      ],
    );
  }
}

class _KeyValueTile extends StatelessWidget {
  const _KeyValueTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _InspectorTab extends StatelessWidget {
  const _InspectorTab({
    required this.rootNode,
    required this.selectedNode,
    required this.onNodeSelected,
  });

  final _InspectorNode? rootNode;
  final _InspectorNode? selectedNode;
  final ValueChanged<_InspectorNode> onNodeSelected;

  @override
  Widget build(BuildContext context) {
    if (rootNode == null) {
      return const Center(
        child: Text(
          'No widget tree available yet. Start rendering and refresh.',
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              _TreeNodeTile(
                node: rootNode!,
                selectedId: selectedNode?.id,
                onSelected: onNodeSelected,
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: _InspectorDetailsPane(node: selectedNode ?? rootNode!),
        ),
      ],
    );
  }
}

class _TreeNodeTile extends StatelessWidget {
  const _TreeNodeTile({
    required this.node,
    required this.selectedId,
    required this.onSelected,
  });

  final _InspectorNode node;
  final String? selectedId;
  final ValueChanged<_InspectorNode> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedId == node.id;
    final hasChildren = node.children.isNotEmpty;
    final title = '${node.widgetType} (${node.elementType})';
    if (!hasChildren) {
      return ListTile(
        dense: true,
        selected: isSelected,
        title: Text(title),
        subtitle: Text(node.renderObjectType ?? 'no RenderObject'),
        onTap: () => onSelected(node),
      );
    }
    return ExpansionTile(
      title: Text(title),
      subtitle: Text(node.renderObjectType ?? 'no RenderObject'),
      initiallyExpanded: true,
      children: [
        for (final child in node.children)
          _TreeNodeTile(
            node: child,
            selectedId: selectedId,
            onSelected: onSelected,
          ),
      ],
      onExpansionChanged: (_) => onSelected(node),
    );
  }
}

class _InspectorDetailsPane extends StatelessWidget {
  const _InspectorDetailsPane({required this.node});
  final _InspectorNode node;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Selected Node', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _KeyValueTile(label: 'Widget', value: node.widgetType),
        _KeyValueTile(label: 'Element', value: node.elementType),
        _KeyValueTile(
          label: 'RenderObject',
          value: node.renderObjectType ?? 'none',
        ),
        _KeyValueTile(label: 'Key', value: node.key ?? 'none'),
        _KeyValueTile(label: 'Slot', value: node.slot ?? 'none'),
        _KeyValueTile(label: 'Children', value: '${node.children.length}'),
      ],
    );
  }
}

class _InspectorNode {
  const _InspectorNode({
    required this.id,
    required this.widgetType,
    required this.elementType,
    required this.renderObjectType,
    required this.slot,
    required this.key,
    required this.children,
  });

  factory _InspectorNode.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'];
    final children = <_InspectorNode>[];
    if (rawChildren is List) {
      for (final child in rawChildren) {
        if (child is Map<String, dynamic>) {
          children.add(_InspectorNode.fromJson(child));
        } else if (child is Map) {
          children.add(
            _InspectorNode.fromJson(Map<String, dynamic>.from(child)),
          );
        }
      }
    }
    return _InspectorNode(
      id: '${json['id'] ?? ''}',
      widgetType: '${json['widgetType'] ?? 'UnknownWidget'}',
      elementType: '${json['elementType'] ?? 'UnknownElement'}',
      renderObjectType: json['renderObjectType']?.toString(),
      slot: json['slot']?.toString(),
      key: json['key']?.toString(),
      children: children,
    );
  }

  final String id;
  final String widgetType;
  final String elementType;
  final String? renderObjectType;
  final String? slot;
  final String? key;
  final List<_InspectorNode> children;
}
