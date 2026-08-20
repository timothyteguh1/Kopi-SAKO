import 'package:flutter_riverpod/legacy.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

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
  final bool isLoading;
  final String? error;

  RadarState({this.myLocation, this.activeBranches = const [], this.isLoading = false, this.error});

  RadarState copyWith({LatLng? myLocation, List<RadarBranch>? activeBranches, bool? isLoading, String? error}) {
    return RadarState(
      myLocation: myLocation ?? this.myLocation,
      activeBranches: activeBranches ?? this.activeBranches,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class RadarNotifier extends StateNotifier<RadarState> {
  RadarNotifier() : super(RadarState()) {
    _initRealtimeSubscription(); // Aktifkan pendengar live
  }
  
  final _supabase = Supabase.instance.client;
  final Distance _distanceCalc = const Distance(); 
  RealtimeChannel? _realtimeChannel;

  // Mendengarkan perubahan tabel branches secara real-time
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
    state = state.copyWith(isLoading: true, error: null);

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
      // Menggunakan 'whatsapp_number' sesuai dengan skema tabel Supabase Anda[cite: 14]
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
              phone: b['whatsapp_number'] ?? '', // Mengambil data dari whatsapp_number[cite: 14]
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
}

final radarProvider = StateNotifierProvider<RadarNotifier, RadarState>((ref) {
  return RadarNotifier();
});