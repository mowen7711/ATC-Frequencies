import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ── Icom CI-V over BLE ────────────────────────────────────────────────────────
//
// Icom exposes a BLE UART bridge on supported radios (IC-R15, IC-R30, IC-705,
// IC-9700 etc.). The UART service uses two characteristics:
//   TX (write) : 49535343-8841-43F4-A8D4-ECBE34729BB3
//   RX (notify): 49535343-1E4D-4BD9-BA61-23C647249616
//
// CI-V frame format:
//   FE FE <to> <from> <cmd> [sub] [data...] FD
//
// We use device address 00 (broadcast to first radio found) and controller
// address E0 (default PC address).
//
// Supported commands used here:
//   03        — read operating frequency
//   05 [freq] — set operating frequency (5 BCD bytes, 10Hz resolution)
//   14 01     — read squelch level
//   00        — read transceiver status (split/simplex)

// BLE UART service UUIDs (Icom standard)
// Service : 49535343-0257-4a9e-8ef3-745a97ba3fb0
// TX (write)  : 49535343-8841-43f4-a8d4-ecbe34729bb3  (matched by '8841' substring)
// RX (notify) : 49535343-1e4d-4bd9-ba61-23c647249616  (matched by '1e4d' substring)

const int _civBroadcast = 0x00;
const int _civController = 0xE0;
const int _civPreamble = 0xFE;
const int _civEOF = 0xFD;

enum ScannerConnectionState { disconnected, scanning, connecting, connected, error }

class ScannerDevice {
  final BluetoothDevice device;
  final String name;
  final int rssi;
  ScannerDevice({required this.device, required this.name, required this.rssi});
}

class ScannerState {
  final double? frequencyMhz;
  final bool? squelchOpen;
  final String? rawResponse;

  const ScannerState({this.frequencyMhz, this.squelchOpen, this.rawResponse});

  ScannerState copyWith({double? frequencyMhz, bool? squelchOpen, String? rawResponse}) {
    return ScannerState(
      frequencyMhz: frequencyMhz ?? this.frequencyMhz,
      squelchOpen: squelchOpen ?? this.squelchOpen,
      rawResponse: rawResponse ?? this.rawResponse,
    );
  }
}

class IcomBleService {
  IcomBleService._();
  static final IcomBleService instance = IcomBleService._();

  final _connectionStateCtrl = StreamController<ScannerConnectionState>.broadcast();
  final _scannerStateCtrl    = StreamController<ScannerState>.broadcast();
  final _devicesCtrl         = StreamController<List<ScannerDevice>>.broadcast();

  Stream<ScannerConnectionState> get connectionState => _connectionStateCtrl.stream;
  Stream<ScannerState>           get scannerState    => _scannerStateCtrl.stream;
  Stream<List<ScannerDevice>>    get devices         => _devicesCtrl.stream;

  ScannerConnectionState _state = ScannerConnectionState.disconnected;
  ScannerState _scanner = const ScannerState();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _txChar;
  StreamSubscription? _rxSub;
  StreamSubscription? _connSub;
  final List<int> _rxBuffer = [];
  final List<ScannerDevice> _found = [];

  // ── Scanning ───────────────────────────────────────────────────────────────

  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    _found.clear();
    _emit(ScannerConnectionState.scanning);

    await FlutterBluePlus.startScan(
      timeout: timeout,
      withServices: [], // don't filter by service — Icom may not advertise it
    );

    FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.device.platformName;
        // Icom BLE radios advertise names starting with "IC-"
        if (name.toUpperCase().startsWith('IC-') ||
            name.toUpperCase().contains('ICOM')) {
          final already = _found.any((d) => d.device.remoteId == r.device.remoteId);
          if (!already) {
            _found.add(ScannerDevice(
              device: r.device,
              name: name,
              rssi: r.rssi,
            ));
            _devicesCtrl.add(List.unmodifiable(_found));
          }
        }
      }
    });

    await Future.delayed(timeout);
    await FlutterBluePlus.stopScan();

    if (_state == ScannerConnectionState.scanning) {
      _emit(ScannerConnectionState.disconnected);
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    if (_state == ScannerConnectionState.scanning) {
      _emit(ScannerConnectionState.disconnected);
    }
  }

  // ── Connection ─────────────────────────────────────────────────────────────

  Future<bool> connect(ScannerDevice scanner) async {
    _emit(ScannerConnectionState.connecting);
    _device = scanner.device;

    try {
      await _device!.connect(timeout: const Duration(seconds: 10));
    } catch (_) {
      _emit(ScannerConnectionState.error);
      return false;
    }

    _connSub = _device!.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) {
        _cleanup();
        _emit(ScannerConnectionState.disconnected);
      }
    });

    // Discover services and find the UART TX/RX characteristics
    final services = await _device!.discoverServices();
    BluetoothCharacteristic? rxChar;

    for (final svc in services) {
      final svcUuid = svc.serviceUuid.toString().toLowerCase();
      if (!svcUuid.contains('49535343')) continue;
      for (final c in svc.characteristics) {
        final cUuid = c.characteristicUuid.toString().toLowerCase();
        if (cUuid.contains('8841')) _txChar = c;
        if (cUuid.contains('1e4d')) rxChar = c;
      }
    }

    if (_txChar == null || rxChar == null) {
      // UART service not found — not a supported Icom BLE device
      await _device!.disconnect();
      _emit(ScannerConnectionState.error);
      return false;
    }

    // Subscribe to RX notifications
    await rxChar.setNotifyValue(true);
    _rxSub = rxChar.onValueReceived.listen(_onRxData);

    _emit(ScannerConnectionState.connected);
    return true;
  }

  Future<void> disconnect() async {
    await _device?.disconnect();
    _cleanup();
    _emit(ScannerConnectionState.disconnected);
  }

  // ── Commands ───────────────────────────────────────────────────────────────

  /// Read current VFO frequency from radio.
  Future<void> readFrequency() => _send([0x03]);

  /// Set VFO frequency. [frequencyHz] must be in Hz (e.g. 121500000 for 121.5 MHz).
  Future<void> setFrequency(int frequencyHz) {
    // CI-V encodes frequency as 5 BCD bytes, LSB first, 10 Hz resolution.
    // e.g. 121.500 MHz → 121500000 Hz → 0 12 15 00 00 (BCD) → 00 00 51 21 00
    final bcd = _freqToBcd(frequencyHz);
    return _send([0x05, ...bcd]);
  }

  /// Read squelch level (0x14 0x01).
  Future<void> readSquelch() => _send([0x14, 0x01]);

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _send(List<int> payload) async {
    if (_txChar == null) return;
    // Build CI-V frame: FE FE <to> <from> <payload...> FD
    final frame = [
      _civPreamble, _civPreamble,
      _civBroadcast, _civController,
      ...payload,
      _civEOF,
    ];
    await _txChar!.write(frame, withoutResponse: false);
  }

  void _onRxData(List<int> data) {
    _rxBuffer.addAll(data);

    // Extract complete CI-V frames (FE FE ... FD)
    while (true) {
      final start = _findPreamble(_rxBuffer);
      if (start < 0) { _rxBuffer.clear(); break; }
      final end = _rxBuffer.indexOf(_civEOF, start + 4);
      if (end < 0) break;

      final frame = _rxBuffer.sublist(start, end + 1);
      _rxBuffer.removeRange(0, end + 1);
      _parseFrame(frame);
    }
  }

  void _parseFrame(List<int> frame) {
    // frame: FE FE <to> <from> <cmd> [sub] [data...] FD
    if (frame.length < 6) return;
    final cmd = frame[4];

    if (cmd == 0x00) return; // transceiver ID response — ignore

    if (cmd == 0x03 || cmd == 0x05) {
      // Frequency response: data bytes starting at index 5
      if (frame.length >= 10) {
        final hz = _bcdToFreq(frame.sublist(5, 10));
        _scanner = _scanner.copyWith(frequencyMhz: hz / 1e6);
        _scannerStateCtrl.add(_scanner);
      }
    } else if (cmd == 0x14 && frame.length >= 8) {
      // Squelch: 0x00=closed, non-zero=open (simplified)
      _scanner = _scanner.copyWith(squelchOpen: frame[6] > 0);
      _scannerStateCtrl.add(_scanner);
    }

    _scanner = _scanner.copyWith(
      rawResponse: frame.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase(),
    );
    _scannerStateCtrl.add(_scanner);
  }

  int _findPreamble(List<int> buf) {
    for (var i = 0; i < buf.length - 1; i++) {
      if (buf[i] == _civPreamble && buf[i + 1] == _civPreamble) return i;
    }
    return -1;
  }

  /// Encode frequency in Hz to 5 BCD bytes (LSB first, 10 Hz resolution).
  List<int> _freqToBcd(int hz) {
    // Truncate to 10 Hz resolution
    final tenHz = hz ~/ 10;
    final digits = tenHz.toString().padLeft(10, '0');
    // Pack pairs of decimal digits into bytes, LSB first
    final bytes = <int>[];
    for (var i = digits.length - 2; i >= 0; i -= 2) {
      final hi = int.parse(digits[i]);
      final lo = int.parse(digits[i + 1]);
      bytes.add((hi << 4) | lo);
    }
    return bytes.take(5).toList();
  }

  /// Decode 5 BCD bytes (LSB first) to frequency in Hz.
  int _bcdToFreq(List<int> bcd) {
    var hz = 0;
    var multiplier = 10; // starts at 10 Hz (LSB)
    for (final byte in bcd) {
      hz += ((byte & 0x0F)) * multiplier;
      multiplier *= 10;
      hz += ((byte >> 4) & 0x0F) * multiplier;
      multiplier *= 10;
    }
    return hz;
  }

  void _cleanup() {
    _rxSub?.cancel();
    _connSub?.cancel();
    _rxSub = null;
    _connSub = null;
    _txChar = null;
    _device = null;
    _rxBuffer.clear();
  }

  void _emit(ScannerConnectionState s) {
    _state = s;
    _connectionStateCtrl.add(s);
  }

  void dispose() {
    _connectionStateCtrl.close();
    _scannerStateCtrl.close();
    _devicesCtrl.close();
  }
}
