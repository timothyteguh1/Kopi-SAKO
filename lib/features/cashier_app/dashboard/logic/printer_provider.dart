import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // IMPORT BARU UNTUK CEK WEB

class PrinterState {
  final List<BluetoothDevice> devices;
  final BluetoothDevice? selectedDevice;
  final bool isConnected;

  PrinterState({
    this.devices = const [],
    this.selectedDevice,
    this.isConnected = false,
  });

  PrinterState copyWith({
    List<BluetoothDevice>? devices,
    BluetoothDevice? selectedDevice,
    bool? isConnected,
  }) {
    return PrinterState(
      devices: devices ?? this.devices,
      selectedDevice: selectedDevice ?? this.selectedDevice,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

class PrinterNotifier extends StateNotifier<PrinterState> {
  PrinterNotifier() : super(PrinterState()) {
    _initPrinter();
  }

  // JIKA DI WEB, KITA TIDAK INISIALISASI PLUGINNYA AGAR TIDAK ERROR
  final BlueThermalPrinter? bluetooth = kIsWeb ? null : BlueThermalPrinter.instance;

  Future<void> _initPrinter() async {
    if (kIsWeb) return; // Hentikan proses jika di Web

    bool? isConnected = await bluetooth?.isConnected;
    List<BluetoothDevice> devices = [];
    try {
      devices = await bluetooth!.getBondedDevices();
    } catch (e) {
      print("Error mengambil perangkat bluetooth: $e");
    }
    state = state.copyWith(devices: devices, isConnected: isConnected ?? false);
  }

  Future<bool> connect(BluetoothDevice device) async {
    if (kIsWeb) return false;
    
    try {
      await bluetooth!.connect(device);
      state = state.copyWith(selectedDevice: device, isConnected: true);
      return true;
    } catch (e) {
      state = state.copyWith(isConnected: false);
      return false;
    }
  }

  Future<void> disconnect() async {
    if (kIsWeb) return;
    await bluetooth!.disconnect();
    state = state.copyWith(isConnected: false);
  }

  Future<void> printReceipt({
    required String branchName,
    required List<Map<String, dynamic>> cartItems,
    required int total,
    required String paymentMethod,
    required String customerName,
    required String orderId,
  }) async {
    if (kIsWeb) {
       print("Simulasi Cetak Struk di Web: Struk $orderId untuk $customerName dari $branchName");
       return; // Hentikan proses eksekusi ESC/POS jika di Web
    }

    bool? isConnected = await bluetooth?.isConnected;
    if (isConnected != true) throw Exception('Printer belum terhubung!');

    final String dateStr = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());
    final String formatTotal = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(total);

    String methodLabel = 'Tunai';
    if (paymentMethod == 'qris') methodLabel = 'QRIS';
    if (paymentMethod == 'transfer') methodLabel = 'Transfer';

    // TAMBAHKAN TANDA ! DI SETIAP PEMANGGILAN BLUETOOTH
    bluetooth!.printCustom("KOPI SAKO", 3, 1);
    bluetooth!.printCustom(branchName, 1, 1);
    bluetooth!.printCustom("--------------------------------", 0, 1);
    
    bluetooth!.printLeftRight("Tgl:", dateStr, 0);
    bluetooth!.printLeftRight("Nota:", orderId, 0);
    bluetooth!.printLeftRight("Pelanggan:", customerName, 0);
    bluetooth!.printLeftRight("Metode:", methodLabel, 0);
    bluetooth!.printCustom("--------------------------------", 0, 1);

    for (var item in cartItems) {
      String qtyStr = "${item['qty']}x";
      String nameStr = item['name'].toString();
      String priceStr = NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(item['price'] * item['qty']);
      bluetooth!.printLeftRight("$qtyStr $nameStr", priceStr, 0);
    }
    
    bluetooth!.printCustom("--------------------------------", 0, 1);
    bluetooth!.printLeftRight("TOTAL", formatTotal, 1);
    bluetooth!.printCustom("--------------------------------", 0, 1);
    
    bluetooth!.printCustom("Terima kasih orang baik!", 1, 1);
    bluetooth!.printCustom(" ", 0, 1);
    bluetooth!.printCustom(" ", 0, 1);
    bluetooth!.printCustom(" ", 0, 1); 
  }
}

final printerProvider = StateNotifierProvider<PrinterNotifier, PrinterState>((ref) => PrinterNotifier());