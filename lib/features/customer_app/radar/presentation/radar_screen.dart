import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // TAMBAHAN IMPORT SUPABASE

import '../logic/radar_provider.dart';
import '../../menu/presentation/branch_menu_sheet.dart';

// ==============================================================
// PENARIK DATA POIN PELANGGAN DARI SUPABASE
// ==============================================================
final customerPointsProvider = FutureProvider.autoDispose<int>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return 0;

  try {
    final response = await supabase
        .from('customers')
        .select('points')
        .eq('id', user.id)
        .maybeSingle();

    if (response != null && response['points'] != null) {
      return response['points'] as int;
    }
    return 0;
  } catch (e) {
    return 0; // Jika error/gagal tarik, tampilkan 0
  }
});

class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> {
  final Color colorJagoGreen = const Color(0xFF007A4D);
  final Color colorTextBrown = const Color(0xFF4A3B32);
  final Color colorCreamBg = const Color(0xFFFDFBF7);
  final Color colorSakoOrange = const Color(0xFFF28F27);

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(radarProvider.notifier).startLiveTracking();
    });
  }

  void _showMenuBottomSheet(BuildContext context, RadarBranch branch) {
    ref.read(radarProvider.notifier).getRouteToBranch(branch);

    final myLoc = ref.read(radarProvider).myLocation;
    if (myLoc != null) {
      final centerLat = (myLoc.latitude + branch.location.latitude) / 2;
      final centerLng = (myLoc.longitude + branch.location.longitude) / 2;
      _mapController.move(LatLng(centerLat, centerLng), 14.5);
    }

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
    final initialMapCenter =
        radarState.myLocation ?? const LatLng(-7.250445, 112.768845);

    // Memantau poin asli dari Supabase
    final pointsAsync = ref.watch(customerPointsProvider);
    // GANTI MENJADI INI:
    final int currentPoints = pointsAsync.value ?? 0;

    ref.listen<RadarState>(radarProvider, (previous, next) {
      if (previous?.myLocation == null && next.myLocation != null) {
        _mapController.move(next.myLocation!, 15.5);
      }
    });

    List<Marker> mapMarkers = [];
    if (radarState.myLocation != null) {
      mapMarkers.add(
        Marker(
          point: radarState.myLocation!,
          width: 50,
          height: 50,
          child: Image.asset('assets/images/pin_user.png'),
        ),
      );
    }
    for (var branch in radarState.activeBranches) {
      mapMarkers.add(
        Marker(
          point: branch.location,
          width: 60,
          height: 60,
          child: Image.asset('assets/images/pin_gerobak.png'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorCreamBg,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialMapCenter,
                initialZoom: 15.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),

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
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorSakoOrange.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.stars_rounded,
                                    color: colorSakoOrange,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'SAKO Poin',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    // ---> DATA POIN DINAMIS <---
                                    Text(
                                      pointsAsync.isLoading
                                          ? '...'
                                          : '$currentPoints',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: colorTextBrown,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Container(
                            height: 35,
                            width: 1,
                            color: Colors.grey.shade200,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                          ),

                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Voucher',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    // Voucher saya set hardcode 0 karena belum ada tabelnya di Supabase
                                    Text(
                                      '0',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: colorTextBrown,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorJagoGreen.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.local_activity_rounded,
                                    color: colorJagoGreen,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey.shade100,
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            color: colorTextBrown.withOpacity(0.7),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              radarState.isLoading
                                  ? 'Memindai radar...'
                                  : (radarState.myLocation != null
                                        ? 'Lokasi Anda Ditemukan'
                                        : 'Gagal melacak lokasi'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: colorTextBrown.withOpacity(0.8),
                              ),
                            ),
                          ),
                          if (radarState.isLoading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            InkWell(
                              onTap: () {
                                ref
                                    .read(radarProvider.notifier)
                                    .startLiveTracking();
                                ref.invalidate(
                                  customerPointsProvider,
                                ); // Refresh poin juga jika ditekan
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.refresh,
                                  size: 16,
                                  color: colorTextBrown,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (radarState.activeRoute.isNotEmpty)
            Positioned(
              top: 170,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade500,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: Colors.red.withOpacity(0.4),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text(
                    'Tutup Rute',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  onPressed: () {
                    ref.read(radarProvider.notifier).clearRoute();
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
            initialChildSize: 0.45, 
            minChildSize: 0.1, // ---> UBAH JADI 0.1 (Bisa ditarik turun hingga sisa 10% layar)
            maxChildSize: 0.9,
            snap: true, // ---> TAMBAHAN: Efek magnet ala Gojek/Google Maps
            snapSizes: const [0.1, 0.45, 0.9], // ---> TAMBAHAN: Titik henti magnetnya
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: const BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)), 
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]
                ),
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Garis abu-abu penanda (Handle)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 24), 
                        height: 4, 
                        width: 40, 
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text(
                      'GEROBAK TERDEKAT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (radarState.isLoading &&
                        radarState.activeBranches.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (radarState.error != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          radarState.error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else if (radarState.activeBranches.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'Belum ada gerobak Kopi SAKO yang buka di sekitar Anda saat ini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ...radarState.activeBranches.map(
                        (branch) => Column(
                          children: [
                            _buildBranchTile(branch),
                            const Divider(height: 24),
                          ],
                        ),
                      ),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorJagoGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_cafe, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: colorTextBrown,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${branch.description} · Buka',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${branch.distanceInMeters} m',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: colorTextBrown,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '~${branch.estimatedTimeMinutes} mnt',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
