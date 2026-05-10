import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../services/bluetooth_service.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  final _ble = IcomBleService.instance;

  ScannerConnectionState _connState = ScannerConnectionState.disconnected;
  ScannerState _scanner = const ScannerState();
  List<ScannerDevice> _devices = [];

  StreamSubscription? _connSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _devicesSub;

  final _freqController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _connSub    = _ble.connectionState.listen((s) => setState(() => _connState = s));
    _stateSub   = _ble.scannerState.listen((s)    => setState(() => _scanner = s));
    _devicesSub = _ble.devices.listen((d)          => setState(() => _devices = d));
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _stateSub?.cancel();
    _devicesSub?.cancel();
    _freqController.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _startScan() => _ble.startScan();
  Future<void> _stopScan()  => _ble.stopScan();

  Future<void> _connect(ScannerDevice d) async {
    final ok = await _ble.connect(d);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not connect — unsupported device or UART service not found.')),
      );
    }
  }

  Future<void> _disconnect() => _ble.disconnect();

  Future<void> _tuneFrequency() async {
    final text = _freqController.text.trim().replaceAll(' ', '');
    final mhz = double.tryParse(text);
    if (mhz == null || mhz < 108 || mhz > 137) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid VHF airband frequency (108–137 MHz)')),
      );
      return;
    }
    final hz = (mhz * 1e6).round();
    await _ble.setFrequency(hz);
    _freqController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _readFrequency() => _ble.readFrequency();

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Scanner Control'),
            const SizedBox(width: 8),
            _BetaBadge(),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoBanner(),
          const SizedBox(height: 16),

          if (_connState == ScannerConnectionState.connected) ...[
            _ConnectedPanel(
              scanner: _scanner,
              freqController: _freqController,
              onReadFreq: _readFrequency,
              onTune: _tuneFrequency,
              onDisconnect: _disconnect,
            ),
          ] else ...[
            _ScanPanel(
              state: _connState,
              devices: _devices,
              onScan: _startScan,
              onStop: _stopScan,
              onConnect: _connect,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Beta badge ────────────────────────────────────────────────────────────────

class _BetaBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF7043).withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFFF7043).withAlpha(120)),
      ),
      child: const Text(
        'BETA',
        style: TextStyle(
          color: Color(0xFFFF7043),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Info banner ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kAccent.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAccent.withAlpha(40)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bluetooth_rounded, color: kAccent, size: 16),
              SizedBox(width: 6),
              Text('Icom CI-V BLE Control',
                  style: TextStyle(
                      color: kAccent, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Compatible with Icom IC-R15, IC-R30, IC-705, IC-9700 and other radios '
            'with built-in Bluetooth. Ensure Bluetooth is enabled and your radio is '
            'in BLE pairing mode.',
            style: TextStyle(color: kTextSecondary, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── Scan panel ────────────────────────────────────────────────────────────────

class _ScanPanel extends StatelessWidget {
  const _ScanPanel({
    required this.state,
    required this.devices,
    required this.onScan,
    required this.onStop,
    required this.onConnect,
  });

  final ScannerConnectionState state;
  final List<ScannerDevice> devices;
  final VoidCallback onScan;
  final VoidCallback onStop;
  final ValueChanged<ScannerDevice> onConnect;

  @override
  Widget build(BuildContext context) {
    final scanning  = state == ScannerConnectionState.scanning;
    final connecting = state == ScannerConnectionState.connecting;
    final hasError  = state == ScannerConnectionState.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Scan / stop button
        ElevatedButton.icon(
          onPressed: scanning ? onStop : (connecting ? null : onScan),
          icon: scanning
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Icon(Icons.bluetooth_searching_rounded),
          label: Text(scanning ? 'Scanning…' : connecting ? 'Connecting…' : 'Scan for Icom Radios'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

        if (hasError) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350).withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Color(0xFFEF5350), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Connection failed. Check the radio is in BLE mode and try again.',
                    style: TextStyle(color: Color(0xFFEF5350), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (devices.isEmpty && !scanning) ...[
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'No Icom radios found.\nMake sure Bluetooth is on and the radio is discoverable.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextMuted, fontSize: 13, height: 1.5),
            ),
          ),
        ],

        if (devices.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('FOUND DEVICES',
              style: TextStyle(
                  color: kAccent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ...devices.map((d) => _DeviceTile(device: d, onConnect: onConnect)),
        ],
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onConnect});
  final ScannerDevice device;
  final ValueChanged<ScannerDevice> onConnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder, width: 0.5),
      ),
      child: ListTile(
        leading: const Icon(Icons.radio_rounded, color: kAccent),
        title: Text(device.name,
            style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text('RSSI: ${device.rssi} dBm',
            style: const TextStyle(color: kTextMuted, fontSize: 12)),
        trailing: TextButton(
          onPressed: () => onConnect(device),
          style: TextButton.styleFrom(foregroundColor: kAccent),
          child: const Text('Connect'),
        ),
      ),
    );
  }
}

// ── Connected panel ───────────────────────────────────────────────────────────

class _ConnectedPanel extends StatelessWidget {
  const _ConnectedPanel({
    required this.scanner,
    required this.freqController,
    required this.onReadFreq,
    required this.onTune,
    required this.onDisconnect,
  });

  final ScannerState scanner;
  final TextEditingController freqController;
  final VoidCallback onReadFreq;
  final VoidCallback onTune;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Connection status
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF9CCC65).withAlpha(20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF9CCC65).withAlpha(80)),
          ),
          child: Row(
            children: [
              const Icon(Icons.bluetooth_connected_rounded,
                  color: Color(0xFF9CCC65), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Radio connected',
                    style: TextStyle(
                        color: Color(0xFF9CCC65),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
              TextButton(
                onPressed: onDisconnect,
                style: TextButton.styleFrom(foregroundColor: kTextMuted),
                child: const Text('Disconnect', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Current frequency display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CURRENT FREQUENCY',
                  style: TextStyle(
                      color: kTextMuted, fontSize: 11, letterSpacing: 1.0)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: scanner.frequencyMhz != null
                        ? GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                  text: scanner.frequencyMhz!.toStringAsFixed(3)));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Frequency copied')),
                              );
                            },
                            child: Text(
                              '${scanner.frequencyMhz!.toStringAsFixed(3)} MHz',
                              style: const TextStyle(
                                color: kAccent,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                              ),
                            ),
                          )
                        : const Text('—',
                            style: TextStyle(color: kTextMuted, fontSize: 32)),
                  ),
                  IconButton(
                    onPressed: onReadFreq,
                    icon: const Icon(Icons.refresh_rounded, color: kAccent),
                    tooltip: 'Read frequency from radio',
                  ),
                ],
              ),
              if (scanner.squelchOpen != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      scanner.squelchOpen!
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: scanner.squelchOpen!
                          ? const Color(0xFF9CCC65)
                          : kTextMuted,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      scanner.squelchOpen! ? 'Squelch open' : 'Squelch closed',
                      style: TextStyle(
                        color: scanner.squelchOpen!
                            ? const Color(0xFF9CCC65)
                            : kTextMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tune to frequency
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TUNE TO FREQUENCY',
                  style: TextStyle(
                      color: kTextMuted, fontSize: 11, letterSpacing: 1.0)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: freqController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: kTextPrimary, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        hintText: '121.500',
                        suffixText: 'MHz',
                        suffixStyle: TextStyle(color: kTextMuted),
                      ),
                      onSubmitted: (_) => onTune(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: onTune,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    child: const Text('Tune'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'VHF airband: 108–137 MHz',
                style: TextStyle(color: kTextMuted, fontSize: 11),
              ),
            ],
          ),
        ),

        if (scanner.rawResponse != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LAST CI-V RESPONSE',
                    style: TextStyle(color: kTextMuted, fontSize: 10, letterSpacing: 1.0)),
                const SizedBox(height: 4),
                Text(
                  scanner.rawResponse!,
                  style: const TextStyle(
                      color: kTextSecondary, fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
