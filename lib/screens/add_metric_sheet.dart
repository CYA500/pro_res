import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sensor_model.dart';
import '../providers/dashboard_provider.dart';
import '../theme.dart';

// ════════════════════════════════════════════════════════════════════════════
//  AddMetricSheet — searchable list of all available PC sensors
// ════════════════════════════════════════════════════════════════════════════

class AddMetricSheet extends StatefulWidget {
  const AddMetricSheet({super.key});

  static Future<void> show(BuildContext context) =>
      showModalBottomSheet(
        context:          context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AddMetricSheet(),
      );

  @override
  State<AddMetricSheet> createState() => _AddMetricSheetState();
}

class _AddMetricSheetState extends State<AddMetricSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final prov    = context.watch<DashboardProvider>();
    final sensors = prov.availableSensors;
    final active  = prov.activeMetrics.map((m) => m.descriptor.id).toSet();

    // Group by category
    final filtered = sensors.where((s) =>
        s.name.toLowerCase().contains(_query.toLowerCase()) ||
        s.category.toLowerCase().contains(_query.toLowerCase())).toList();

    final groups = <String, List<SensorDescriptor>>{};
    for (final s in filtered) {
      (groups[s.category] ??= []).add(s);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize:     0.4,
      maxChildSize:     0.92,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color:        Color(0xFF0D1117),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border:       Border(
            top: BorderSide(color: AuraTheme.cyan, width: 1),
          ),
        ),
        child: Column(
          children: [
            // ── Handle ────────────────────────────────────────────────────
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        AuraTheme.textSec.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('ADD METRIC', style: AuraTheme.orbitron(16)),
            ),
            const SizedBox(height: 14),

            // ── Search ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style:     AuraTheme.inter(14),
                decoration: InputDecoration(
                  hintText:    'Search sensors...',
                  hintStyle:   AuraTheme.inter(14, color: AuraTheme.textSec),
                  prefixIcon:  const Icon(Icons.search, color: AuraTheme.textSec, size: 20),
                  filled:      true,
                  fillColor:   AuraTheme.panelFill,
                  border:      OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:   const BorderSide(color: AuraTheme.cyan, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AuraTheme.cyan.withAlpha(60)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AuraTheme.cyan),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Sensor list ────────────────────────────────────────────────
            Expanded(
              child: sensors.isEmpty
                  ? Center(
                      child: Text('No sensors received yet.',
                          style: AuraTheme.inter(14, color: AuraTheme.textSec)))
                  : ListView(
                      controller: scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        for (final cat in groups.keys) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(cat.toUpperCase(),
                                style: AuraTheme.orbitron(10,
                                    color: AuraTheme.textSec,
                                    weight: FontWeight.w400)),
                          ),
                          for (final sensor in groups[cat]!)
                            _SensorTile(
                              sensor:  sensor,
                              added:   active.contains(sensor.id),
                              onTap:   () {
                                prov.addMetric(sensor);
                                Navigator.pop(context);
                              },
                            ),
                          const Divider(color: Color(0x22FFFFFF), height: 1),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SensorTile extends StatelessWidget {
  final SensorDescriptor sensor;
  final bool             added;
  final VoidCallback     onTap;

  const _SensorTile({required this.sensor, required this.added, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(sensor.name,
        style: AuraTheme.inter(14,
            color: added ? AuraTheme.textSec : AuraTheme.textPrim)),
    subtitle: Text('${sensor.unit}  ·  ${sensor.minVal.toStringAsFixed(0)}–${sensor.maxVal.toStringAsFixed(0)}',
        style: AuraTheme.inter(11, color: AuraTheme.textSec)),
    trailing: added
        ? Icon(Icons.check_circle, color: AuraTheme.success.withAlpha(180), size: 20)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:        AuraTheme.cyan.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: AuraTheme.cyan.withAlpha(100)),
            ),
            child: Text('ADD', style: AuraTheme.orbitron(10, color: AuraTheme.cyan)),
          ),
    onTap: added ? null : onTap,
  );
}
