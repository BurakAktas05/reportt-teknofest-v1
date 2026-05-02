import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/report_repository.dart';

final currentLocationProvider = FutureProvider.autoDispose<Position?>((ref) async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return null;
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return null;
  }
  if (permission == LocationPermission.deniedForever) return null;
  return await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
});

/// Canlı İhbar Haritası (V3).
/// Tüm ihbarları pin olarak gösterir, kategoriye göre renklendirir.
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(myReportsProvider);
    final locationAsync = ref.watch(currentLocationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('İhbar Haritası', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: reportsAsync.when(
        data: (reports) {
          final markers = _buildMarkers(context, reports);
          final fallbackCenter = reports.isNotEmpty && reports.first.latitude != null
              ? LatLng(reports.first.latitude!, reports.first.longitude!)
              : const LatLng(39.9334, 32.8597); // Ankara default
          
          final center = locationAsync.when(
            data: (pos) => pos != null ? LatLng(pos.latitude, pos.longitude) : fallbackCenter,
            loading: () => fallbackCenter,
            error: (err, stack) => fallbackCenter,
          );

          return FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 12,
              maxZoom: 18,
              minZoom: 5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.reportt.mobile',
              ),
              MarkerLayer(markers: markers),
              // Alt bilgi
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Hata: $err')),
      ),
      // Kategori legend
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.white,
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _legendItem('Şiddet', Colors.red),
            _legendItem('Güvenlik', Colors.orange),
            _legendItem('Trafik', Colors.blue),
            _legendItem('Park', Colors.purple),
            _legendItem('Çevre', Colors.green),
            _legendItem('Diğer', Colors.grey),
          ],
        ),
      ),
    );
  }

  List<Marker> _buildMarkers(BuildContext context, List<ReportResponse> reports) {
    return reports
        .where((r) => r.latitude != null && r.longitude != null)
        .map((report) {
      final color = _categoryColor(report.category);
      final urgencySize = report.urgencyScore >= 8 ? 48.0 : 36.0;

      return Marker(
        point: LatLng(report.latitude!, report.longitude!),
        width: urgencySize,
        height: urgencySize,
        child: GestureDetector(
          onTap: () => _showReportInfo(context, report),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
              ),
              Icon(
                _categoryIcon(report.category),
                color: color,
                size: urgencySize * 0.5,
              ),
              if (report.urgencyScore >= 8)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('!', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _showReportInfo(BuildContext context, ReportResponse report) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _categoryColor(report.category).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_categoryIcon(report.category), color: _categoryColor(report.category)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(report.addressText, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                if (report.urgencyScore >= 8)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                    child: Text('ACİL ${report.urgencyScore}/10', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(report.description, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  GoRouter.of(context).push('/report_detail/${report.id}');
                },
                child: const Text('Detayları Gör'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'VIOLENCE': return Colors.red;
      case 'SECURITY': return Colors.orange;
      case 'TRAFFIC_OFFENSE': return Colors.blue;
      case 'PARKING_VIOLATION': return Colors.purple;
      case 'ENVIRONMENTAL': return Colors.green;
      case 'VANDALISM': return Colors.brown;
      case 'INFRASTRUCTURE': return Colors.teal;
      default: return Colors.grey;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'VIOLENCE': return Icons.warning_rounded;
      case 'SECURITY': return Icons.shield;
      case 'TRAFFIC_OFFENSE': return Icons.directions_car;
      case 'PARKING_VIOLATION': return Icons.local_parking;
      case 'ENVIRONMENTAL': return Icons.eco;
      case 'VANDALISM': return Icons.broken_image;
      case 'INFRASTRUCTURE': return Icons.construction;
      default: return Icons.report;
    }
  }
}
