import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CashierLocationState {
  final bool isBroadcasting;
  final bool isLoading;

  CashierLocationState({this.isBroadcasting = false, this.isLoading = false});
  
  CashierLocationState copyWith({bool? isBroadcasting, bool? isLoading}) {
    return CashierLocationState(
      isBroadcasting: isBroadcasting ?? this.isBroadcasting,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CashierLocationNotifier extends StateNotifier<CashierLocationState> {
  CashierLocationNotifier() : super(CashierLocationState());

  StreamSubscription<Position>? _positionStream;
  final _supabase = Supabase.instance.client;

  // Sekarang menerima parameter branchId dari UI Dasbor
  Future<String?> toggleBroadcasting(bool turnOn, String? branchId) async {
    state = state.copyWith(isLoading: true);

    try {
      if (branchId == null) throw Exception('Cabang tidak valid. Harap pilih cabang aktif di pojok kanan atas.');

      if (turnOn) {
        // Cek izin GPS Kasir
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) throw Exception('GPS HP Kasir belum dinyalakan. Nyalakan lokasi di pengaturan.');

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) throw Exception('Izin akses GPS ditolak.');
        }
        if (permission == LocationPermission.deniedForever) {
          throw Exception('Izin GPS diblokir permanen. Harap izinkan melalui pengaturan browser/HP.');
        }

        // Ambil posisi pertama kali
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

        // Update database: Buka Gerobak
        await _supabase.from('branches').update({
          'is_broadcasting': true,
          'current_latitude': position.latitude,
          'current_longitude': position.longitude,
        }).eq('id', branchId);

        // Pantau pergerakan gerobak
        _positionStream = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20),
        ).listen((Position newPos) async {
          await _supabase.from('branches').update({
            'current_latitude': newPos.latitude,
            'current_longitude': newPos.longitude,
          }).eq('id', branchId);
        });

        state = state.copyWith(isBroadcasting: true, isLoading: false);
        return null; // Tidak ada error
      } else {
        // Matikan Gerobak
        _positionStream?.cancel();
        await _supabase.from('branches').update({'is_broadcasting': false}).eq('id', branchId);
        state = state.copyWith(isBroadcasting: false, isLoading: false);
        return null;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return e.toString().replaceAll('Exception: ', ''); // Kembalikan pesan error
    }
  }
  
  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }
}

final cashierLocationProvider = StateNotifierProvider<CashierLocationNotifier, CashierLocationState>((ref) {
  return CashierLocationNotifier();
});