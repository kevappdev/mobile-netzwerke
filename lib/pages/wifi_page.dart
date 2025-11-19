import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/common_widgets.dart';

class WifiPage extends StatefulWidget {
  const WifiPage({super.key});
  @override
  State<WifiPage> createState() => _WifiPageState();
}

class _WifiPageState extends State<WifiPage> {
  static const MethodChannel _channel = MethodChannel('com.example.netzwerk/nav');
  Map<String, dynamic>? _wifi;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (Platform.isAndroid) {
        await Permission.locationWhenInUse.request();
      }
      final res = await _channel.invokeMethod<dynamic>('getWifiInfo');
      if (!mounted) return;
      setState(() {
        _wifi = (res as Map).cast<String, dynamic>();
        _loading = false;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? e.code;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final bands = (_wifi?['bandsSupported'] as Map?)?.cast<String, dynamic>();
    final band24 = bands != null ? bands['2_4GHz'] : null;
    final band5 = bands != null ? bands['5GHz'] : null;
    final band6 = bands != null ? bands['6GHz'] : null;
    final band60 = bands != null ? bands['60GHz'] : null;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Section(
            title: 'Wi‑Fi (WifiManager/WifiInfo)',
            children: [
              KeyValueRow('SSID', _wifi?['ssid']),
              KeyValueRow('Frequenz (MHz)', _wifi?['frequencyMHz']),
              KeyValueRow('Band', _wifi?['band']),
              KeyValueRow('Link-Geschwindigkeit (Mbps)', _wifi?['linkSpeedMbps']),
              KeyValueRow('RSSI (dBm)', _wifi?['rssiDbm']),
              KeyValueRow('BSSID', _wifi?['bssid']),
              KeyValueRow('IP-Adresse', _wifi?['ip']),
              const SizedBox(height: 8),
              Text('Unterstützte Frequenzbänder', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              MonospaceBox(
                text: [
                  '2.4 GHz: ${_fmt(band24)}',
                  '5 GHz:   ${_fmt(band5)}',
                  '6 GHz:   ${_fmt(band6)}',
                  '60 GHz:  ${_fmt(band60)}',
                ].join('\n'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Aktualisieren'),
          ),
        ],
      ),
    );
  }

  String _fmt(Object? v) {
    if (v == null) return '—';
    if (v is bool) return v ? 'Ja' : 'Nein';
    return v.toString();
  }
}


