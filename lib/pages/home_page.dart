import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/map_utils.dart';
import '../widgets/common_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const MethodChannel _channel = MethodChannel('com.example.netzwerk/nav');

  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (Platform.isAndroid) {
        await _ensureAndroidPermissions();
      }
      final res = await _channel.invokeMethod<dynamic>('getAllInfo');
      if (!mounted) return;
      setState(() {
        _data = toStrDynMap(res);
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

  Future<void> _ensureAndroidPermissions() async {
    await [
      Permission.phone,
      Permission.locationWhenInUse,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(message: _error!, onRetry: _init);

    final telephony = toStrDynMap(_data?['telephony']);
    final network = toStrDynMap(_data?['network']);

    return RefreshIndicator(
      onRefresh: _init,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Section(
            title: 'TelephonyManager',
            children: [
              KeyValueRow('SIM Operator', telephony?['simOperatorName']),
              KeyValueRow('Ländercode', telephony?['simCountryIso']),
              KeyValueRow('Daten-Netztyp', telephony?['dataNetworkType']),
              const SizedBox(height: 8),
              Text('Zellen (Signalstärke)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              MonospaceBox(text: _formatCells(telephony?['cells'])),
              KeyValueRow('Notrufnummern', (telephony?['emergencyNumbers'] as List?)?.join(', ')),
              if (telephony?['missingPermissions'] != null)
                KeyValueRow('Fehlende Berechtigungen', (telephony?['missingPermissions'] as List).join(', ')),
            ],
          ),
          const SizedBox(height: 12),
          Section(
            title: 'Connectivity / NetworkCapabilities',
            children: [
              KeyValueRow('WLAN aktiv', network?['wifi']),
              KeyValueRow('Mobilfunk aktiv', network?['cellular']),
              KeyValueRow('Bluetooth aktiv', network?['bluetooth']),
              KeyValueRow('Satellit aktiv', network?['satellite']),
              KeyValueRow('Roaming', network?['roaming']),
              KeyValueRow('Volumenbasiert (metered)', network?['metered']),
              KeyValueRow('Downstream (kbps)', network?['downKbps']),
              KeyValueRow('Upstream (kbps)', network?['upKbps']),
              KeyValueRow('VPN', network?['vpn']),
              KeyValueRow('Validiert', network?['validated']),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _init,
            icon: const Icon(Icons.refresh),
            label: const Text('Aktualisieren'),
          ),
        ],
      ),
    );
  }

  String _formatCells(dynamic cells) {
    if (cells is List) {
      if (cells.isEmpty) return '—';
      final lines = cells.take(10).map((e) => e.toString()).join('\n');
      final more = cells.length > 10 ? '\n… (${cells.length - 10} weitere)' : '';
      return lines + more;
    }
    return '—';
  }
}


