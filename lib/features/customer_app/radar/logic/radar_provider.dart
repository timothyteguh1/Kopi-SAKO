import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http; // IMPORT BARU

class RadarBranch {
  final String id;
  final String name;
  final String description;
  final String phone; 
  final LatLng location;
  final int distanceInMeters;
  final int estimatedTimeMinutes;

  RadarBranch({
    required this.id, required this.name, required this.description, required this.phone,
    required this.location, required this.distanceInMeters, required this.estimatedTimeMinutes,
  });
}

class RadarState {
  final LatLng? myLocation;
  final List<RadarBranch> activeBranches;
  final List<LatLng> activeRoute; // TAMBAHAN: Menyimpan garis rute jalan
  final bool isLoading;
  final String? error;

  RadarState({
    this.myLocation, 
    this.activeBranches = const [], 
    this.activeRoute = const [], 
    this.isLoading = false, 
    this.error
  });

  RadarState copyWith({
    LatLng? myLocation, 
    List<RadarBranch>? activeBranches, 
    List<LatLng>? activeRoute,
    bool? isLoading, 
    String? error
  }) {
    return RadarState(
      myLocation: myLocation ?? this.myLocation,
      activeBranches: activeBranches ?? this.activeBranches,
      activeRoute: activeRoute ?? this.activeRoute,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class RadarNotifier extends StateNotifier<RadarState> {
  RadarNotifier() : super(RadarState()) {
    _initRealtimeSubscription(); 
  }
  
  final _supabase = Supabase.instance.client;
  final Distance _distanceCalc = const Distance(); 
  RealtimeChannel? _realtimeChannel;

  void _initRealtimeSubscription() {
    _realtimeChannel = _supabase.channel('public:branches').onPostgresChanges(
      event: PostgresChangeEvent.all, 
      schema: 'public',
      table: 'branches',
      callback: (payload) {
         _fetchActiveBranchesOnly();
      }
    ).subscribe();
  }

  @override
  void dispose() {
    _supabase.removeChannel(_realtimeChannel!);
    super.dispose();
  }

  Future<void> scanRadar() async {
    state = state.copyWith(isLoading: true, error: null, activeRoute: []); // Bersihkan rute saat refresh

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Mohon nyalakan GPS di HP Anda.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Izin lokasi ditolak.');
      }

      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final LatLng customerPos = LatLng(pos.latitude, pos.longitude);

      state = state.copyWith(myLocation: customerPos);
      await _fetchActiveBranchesOnly();

    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _fetchActiveBranchesOnly() async {
    if (state.myLocation == null) return;
    
    try {
      final List<dynamic> rawBranches = await _supabase
          .from('branches')
          .select('id, name, address, whatsapp_number, current_latitude, current_longitude') 
          .eq('is_broadcasting', true)
          .eq('is_active', true);

      List<RadarBranch> processedBranches = [];
      for (var b in rawBranches) {
        if (b['current_latitude'] != null && b['current_longitude'] != null) {
          final branchPos = LatLng(b['current_latitude'], b['current_longitude']);
          final meter = _distanceCalc.as(LengthUnit.Meter, state.myLocation!, branchPos).toInt();
          final time = (meter / 80).ceil(); 

          processedBranches.add(
            RadarBranch(
              id: b['id'],
              name: b['name'],
              description: b['address'] ?? 'Kopi SAKO',
              phone: b['whatsapp_number'] ?? '', 
              location: branchPos,
              distanceInMeters: meter,
              estimatedTimeMinutes: time == 0 ? 1 : time,
            )
          );
        }
      }

      processedBranches.sort((a, b) => a.distanceInMeters.compareTo(b.distanceInMeters));
      state = state.copyWith(activeBranches: processedBranches, isLoading: false);

    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ==============================================================
  // FUNGSI BARU: MENGAMBIL RUTE JALAN DARI OSRM API (GRATIS)
  // ==============================================================
  Future<void> getRouteToBranch(LatLng destination) async {
    if (state.myLocation == null) return;

    try {
      final start = state.myLocation!;
      // Panggil OSRM API untuk profil mobil/motor (driving)
      final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}?geometries=geojson';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        
        // OSRM mengembalikan [Longitude, Latitude], FlutterMap butuh [Latitude, Longitude]
        final routePoints = coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
        
        state = state.copyWith(activeRoute: routePoints);
      }
    } catch (e) {
      // Jika gagal menarik rute, diamkan saja agar tidak mengganggu (fail-safe)
      print('Gagal menarik rute: $e');
    }
  }

  // Menghapus rute saat bottom sheet ditutup
  void clearRoute() {
    state = state.copyWith(activeRoute: []);
  }
}

final radarProvider = StateNotifierProvider<RadarNotifier, RadarState>((ref) {
  return RadarNotifier();
});