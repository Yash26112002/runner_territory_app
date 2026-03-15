import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/network_log_store.dart';
import '../models/network_log_entry.dart';

/// Wraps the app and provides a floating debug bubble + expandable log panel.
/// Usage: wrap your MaterialApp with this widget.
class NetworkLogOverlay extends StatefulWidget {
  final Widget child;
  const NetworkLogOverlay({super.key, required this.child});

  @override
  State<NetworkLogOverlay> createState() => _NetworkLogOverlayState();
}

class _NetworkLogOverlayState extends State<NetworkLogOverlay>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  Offset _bubbleOffset = const Offset(20, 100);
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  String? _selectedLogId;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      _selectedLogId = null;
      if (_isExpanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  Color _methodColor(String method) {
    switch (method) {
      case 'GET':
      case 'QUERY':
        return const Color(0xFF4CAF50);
      case 'SET':
        return const Color(0xFF2196F3);
      case 'UPDATE':
        return const Color(0xFFFF9800);
      case 'DELETE':
        return const Color(0xFFF44336);
      case 'STREAM':
        return const Color(0xFF9C27B0);
      case 'AUTH':
        return const Color(0xFF00BCD4);
      default:
        return Colors.grey;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'success':
        return const Color(0xFF4CAF50);
      case 'error':
        return const Color(0xFFF44336);
      case 'pending':
        return const Color(0xFFFF9800);
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'success':
        return Icons.check_circle;
      case 'error':
        return Icons.error;
      case 'pending':
        return Icons.hourglass_top;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Expanded panel
        if (_isExpanded) _buildExpandedPanel(),
        // Floating bubble
        if (!_isExpanded) _buildFloatingBubble(),
      ],
    );
  }

  Widget _buildFloatingBubble() {
    return Positioned(
      left: _bubbleOffset.dx,
      top: _bubbleOffset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _bubbleOffset += details.delta;
          });
        },
        onTap: _toggle,
        child: Consumer<NetworkLogStore>(
          builder: (context, store, _) {
            return Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BCD4).withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF00BCD4).withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.wifi_tethering, color: Color(0xFF00BCD4), size: 24),
                  if (store.count > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: store.errorCount > 0
                              ? const Color(0xFFF44336)
                              : const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            store.count > 99 ? '99' : '${store.count}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildExpandedPanel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      top: MediaQuery.of(context).size.height * 0.08,
      child: ScaleTransition(
        scale: _scaleAnim,
        alignment: Alignment.topLeft,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xF01A1A2E),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border.all(
                color: const Color(0xFF00BCD4).withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildPanelHeader(),
                const Divider(color: Color(0xFF2A2A4A), height: 1),
                Expanded(
                  child: _selectedLogId != null
                      ? _buildLogDetail()
                      : _buildLogList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Consumer<NetworkLogStore>(
      builder: (context, store, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF16213E),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.wifi_tethering, color: Color(0xFF00BCD4), size: 20),
              const SizedBox(width: 8),
              Text(
                _selectedLogId != null ? 'Request Detail' : 'Network Inspector',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_selectedLogId != null)
                GestureDetector(
                  onTap: () => setState(() => _selectedLogId = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, color: Colors.white70, size: 14),
                        SizedBox(width: 4),
                        Text('Back', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              if (_selectedLogId == null) ...[
                // Log count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${store.count}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                // Clear button
                GestureDetector(
                  onTap: () => store.clearLogs(),
                  child: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                ),
              ],
              const SizedBox(width: 12),
              // Close button
              GestureDetector(
                onTap: _toggle,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white54, size: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogList() {
    return Consumer<NetworkLogStore>(
      builder: (context, store, _) {
        if (store.logs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_tethering, color: Color(0xFF2A2A4A), size: 48),
                SizedBox(height: 12),
                Text(
                  'No network logs yet',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  'Firebase operations will appear here',
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: store.logs.length,
          separatorBuilder: (_, __) =>
              const Divider(color: Color(0xFF2A2A4A), height: 1),
          itemBuilder: (context, index) {
            final entry = store.logs[index];
            return _buildLogRow(entry);
          },
        );
      },
    );
  }

  Widget _buildLogRow(NetworkLogEntry entry) {
    final methodColor = _methodColor(entry.method);
    return GestureDetector(
      onTap: () => setState(() => _selectedLogId = entry.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: Colors.transparent,
        child: Row(
          children: [
            // Method badge
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: methodColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: methodColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                entry.method,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: methodColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Operation name + path
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.operation,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.path,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Duration
            if (entry.durationMs != null)
              Text(
                '${entry.durationMs}ms',
                style: TextStyle(
                  color: entry.durationMs! > 500
                      ? const Color(0xFFFF9800)
                      : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(width: 8),
            // Status icon
            Icon(
              _statusIcon(entry.status),
              size: 16,
              color: _statusColor(entry.status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogDetail() {
    return Consumer<NetworkLogStore>(
      builder: (context, store, _) {
        final entry = store.logs.firstWhere(
          (e) => e.id == _selectedLogId,
          orElse: () => store.logs.first,
        );

        final methodColor = _methodColor(entry.method);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: methodColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: methodColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      entry.method,
                      style: TextStyle(
                        color: methodColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.operation,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    _statusIcon(entry.status),
                    color: _statusColor(entry.status),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Info rows
              _detailRow('Path', entry.path),
              _detailRow('Status', entry.status.toUpperCase()),
              if (entry.durationMs != null)
                _detailRow('Duration', '${entry.durationMs}ms'),
              _detailRow('Timestamp', _formatTime(entry.timestamp)),

              if (entry.error != null) ...[
                const SizedBox(height: 16),
                _sectionHeader('Error', const Color(0xFFF44336)),
                const SizedBox(height: 6),
                _codeBlock(entry.error!, const Color(0xFFF44336)),
              ],

              if (entry.requestData != null && entry.requestData!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionHeader('Request', const Color(0xFF2196F3)),
                const SizedBox(height: 6),
                _codeBlock(_prettyJson(entry.requestData!), Colors.white70),
              ],

              if (entry.responseData != null && entry.responseData!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionHeader('Response', const Color(0xFF4CAF50)),
                const SizedBox(height: 6),
                _codeBlock(_prettyJson(entry.responseData!), Colors.white70),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(width: 3, height: 14, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _codeBlock(String content, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: SelectableText(
        content,
        style: TextStyle(
          fontFamily: 'monospace',
          color: textColor,
          fontSize: 11,
          height: 1.5,
        ),
      ),
    );
  }

  String _prettyJson(Map<String, dynamic> json) {
    final buffer = StringBuffer();
    _formatMap(json, buffer, 0);
    return buffer.toString();
  }

  void _formatMap(Map<String, dynamic> map, StringBuffer buffer, int indent) {
    final pad = '  ' * indent;
    buffer.writeln('{');
    final entries = map.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      buffer.write('$pad  "${e.key}": ');
      _formatValue(e.value, buffer, indent + 1);
      if (i < entries.length - 1) {
        buffer.writeln(',');
      } else {
        buffer.writeln();
      }
    }
    buffer.write('$pad}');
  }

  void _formatValue(dynamic value, StringBuffer buffer, int indent) {
    if (value is Map<String, dynamic>) {
      _formatMap(value, buffer, indent);
    } else if (value is List) {
      buffer.write('[');
      for (var i = 0; i < value.length; i++) {
        _formatValue(value[i], buffer, indent);
        if (i < value.length - 1) buffer.write(', ');
      }
      buffer.write(']');
    } else if (value is String) {
      buffer.write('"$value"');
    } else {
      buffer.write('$value');
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}.'
        '${dt.millisecond.toString().padLeft(3, '0')}';
  }
}
