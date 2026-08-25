import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/radar_provider.dart';
import '../../menu/presentation/branch_menu_sheet.dart'; 

class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> {
  final Color colorJagoGreen = const Color(0xFF007A4D);
  final Color colorTextBrown = const Color(0xFF4A3B32);
  final Color colorCreamBg = const Color(0xFFFDFBF7);
  
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(radarProvider.notifier).scanRadar();
    });
  }

  // ==============================================================
  // PERBAIKAN UX: RUTE TIDAK DIHAPUS SAAT MENU DITUTUP
  // ==============================================================
  void _showMenuBottomSheet(BuildContext context, RadarBranch branch) {
    // 1. Gambar rute ke gerobak yang dipilih
    ref.read(radarProvider.notifier).getRouteToBranch(branch.location);

    // 2. Geser kamera ke tengah-tengah antara pelanggan dan gerobak (Zoom sedikit menjauh)
    final myLoc = ref.read(radarProvider).myLocation;
    if (myLoc != null) {
      final centerLat = (myLoc.latitude + branch.location.latitude) / 2;
      final centerLng = (myLoc.longitude + branch.location.longitude) / 2;
      _mapController.move(LatLng(centerLat, centerLng), 14.5); 
    }

    // 3. Tampilkan Menu (Kita hapus .whenComplete agar rute & kamera tidak me-reset)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BranchMenuSheet(branch: branch), 
    );
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  @override
  Widget build(BuildContext context) {
    final radarState = ref.watch(radarProvider);
    final initialMapCenter = radarState.myLocation ?? const LatLng(-7.250445, 112.768845);

    ref.listen<RadarState>(radarProvider, (previous, next) {
      if (previous?.myLocation == null && next.myLocation != null) {
        _mapController.move(next.myLocation!, 15.5);
      }
    });

    List<Marker> mapMarkers = [];
    if (radarState.myLocation != null) {
      mapMarkers.add(Marker(point: radarState.myLocation!, width: 50, height: 50, child: Image.asset('assets/images/pin_user.png')));
    }
    for (var branch in radarState.activeBranches) {
      mapMarkers.add(Marker(point: branch.location, width: 60, height: 60, child: Image.asset('assets/images/pin_gerobak.png')));
    }

    return Scaffold(
      backgroundColor: colorCreamBg,
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0, bottom: MediaQuery.of(context).size.height * 0.4,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialMapCenter, 
                initialZoom: 15.5,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all), 
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                
                PolylineLayer(
                  polylines: [
                    if (radarState.activeRoute.isNotEmpty)
                      Polyline(
                        points: radarState.activeRoute,
                        strokeWidth: 4.5,
                        color: Colors.blue.withOpacity(0.8), 
                        borderStrokeWidth: 2.0,
                        borderColor: Colors.blue.shade900,
                      ),
                  ],
                ),
                MarkerLayer(markers: mapMarkers),
              ],
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: colorTextBrown),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        radarState.isLoading ? 'Memindai radar...' : (radarState.myLocation != null ? 'Lokasi Anda Ditemukan' : 'Gagal melacak lokasi'), 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorTextBrown)
                      )
                    ),
                    if (radarState.isLoading) 
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      InkWell(
                        onTap: () => ref.read(radarProvider.notifier).scanRadar(),
                        child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.refresh)),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ==============================================================
          // TAMBAHAN: TOMBOL "TUTUP RUTE" MUNCUL JIKA ADA RUTE AKTIF
          // ==============================================================
          if (radarState.activeRoute.isNotEmpty)
            Positioned(
              top: 100, // Tampil pas di bawah banner lokasi
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Tutup Rute', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    // 1. Bersihkan garis biru
                    ref.read(radarProvider.notifier).clearRoute();
                    // 2. Kembalikan kamera fokus ke user
                    if (radarState.myLocation != null) {
                      _mapController.move(radarState.myLocation!, 15.5);
                    }
                  },
                ),
              ),
            ),

          Positioned(
            right: 16,
            bottom: (MediaQuery.of(context).size.height * 0.45) + 16, 
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'btn_zoom_in',
                  backgroundColor: Colors.white,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'btn_zoom_out',
                  backgroundColor: Colors.white,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove, color: Colors.black87),
                ),
              ],
            ),
          ),

          DraggableScrollableSheet(
            initialChildSize: 0.45, minChildSize: 0.45, maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]),
                child: ListView(
                  controller: scrollController,
                  children: [
                    Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 24), height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                    const Text('GEROBAK TERDEKAT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    if (radarState.isLoading && radarState.activeBranches.isEmpty)
                      const Padding(padding: EdgeInsets.all(32.0), child: Center(child: CircularProgressIndicator()))
                    else if (radarState.error != null)
                      Padding(padding: const EdgeInsets.all(16.0), child: Text(radarState.error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center))
                    else if (radarState.activeBranches.isEmpty)
                      const Padding(padding: EdgeInsets.all(32.0), child: Text('Belum ada gerobak Kopi SAKO yang buka di sekitar Anda saat ini.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
                    else
                      ...radarState.activeBranches.map((branch) => Column(children: [_buildBranchTile(branch), const Divider(height: 24)])),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBranchTile(RadarBranch branch) {
    return InkWell(
      onTap: () => _showMenuBottomSheet(context, branch),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: colorJagoGreen, shape: BoxShape.circle), child: const Icon(Icons.local_cafe, color: Colors.white, size: 20)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(branch.name, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: colorTextBrown)), const SizedBox(height: 4), Text('${branch.description} · Buka', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${branch.distanceInMeters} m', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: colorTextBrown)), const SizedBox(height: 4), Text('~${branch.estimatedTimeMinutes} mnt', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))]),
        ],
      ),
    );
  }
}