import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netzwerk Navigator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const RootScaffold(),
    );
  }
}

class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const <Widget>[
    HomePage(),
    WifiPage(),
    NfcPage(),
  ];

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Netzwerk Navigator'),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wifi_outlined),
            activeIcon: Icon(Icons.wifi),
            label: 'Wi‑Fi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.nfc),
            activeIcon: Icon(Icons.nfc),
            label: 'NFC',
          ),
        ],
      ),
    );
  }
}

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
        _data = _toStrDynMap(res);
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

  // Hilfsfunktion: beliebige Map in Map<String, dynamic> kopieren
  Map<String, dynamic>? _toStrDynMap(Object? o) {
    if (o is Map) {
      final out = <String, dynamic>{};
      o.forEach((k, v) {
        out[k.toString()] = v;
      });
      return out;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _init);
    }
    final telephony = _toStrDynMap(_data?["telephony"]);
    final network = _toStrDynMap(_data?["network"]);

    return RefreshIndicator(
      onRefresh: _init,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Section(
            title: 'TelephonyManager',
            children: [
              _kv('SIM Operator', telephony?["simOperatorName"]),
              _kv('Ländercode', telephony?["simCountryIso"]),
              _kv('Daten-Netztyp', telephony?["dataNetworkType"]),
              const SizedBox(height: 8),
              Text('Zellen (Signalstärke)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              _MonospaceBox(text: _formatCells(telephony?["cells"])),
              _kv('Notrufnummern', (telephony?["emergencyNumbers"] as List?)?.join(', ')),
              if (telephony?["missingPermissions"] != null)
                _kv('Fehlende Berechtigungen', (telephony?["missingPermissions"] as List).join(', ')),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Connectivity / NetworkCapabilities',
            children: [
              _kv('WLAN aktiv', network?["wifi"]),
              _kv('Mobilfunk aktiv', network?["cellular"]),
              _kv('Bluetooth aktiv', network?["bluetooth"]),
              _kv('Satellit aktiv', network?["satellite"]),
              _kv('Roaming', network?["roaming"]),
              _kv('Volumenbasiert (metered)', network?["metered"]),
              _kv('Downstream (kbps)', network?["downKbps"]),
              _kv('Upstream (kbps)', network?["upKbps"]),
              _kv('VPN', network?["vpn"]),
              _kv('Validiert', network?["validated"]),
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
      final lines = cells.take(10).map((e) => e.toString()).join("\n");
      final more = cells.length > 10 ? "\n… (${cells.length - 10} weitere)" : '';
      return lines + more;
    }
    return '—';
  }

  Widget _kv(String label, Object? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(_fmt(value), style: const TextStyle(fontWeight: FontWeight.w600)),
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

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _MonospaceBox extends StatelessWidget {
  final String text;
  const _MonospaceBox({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
        const Icon(Icons.error_outline, size: 40),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        FilledButton(onPressed: onRetry, child: const Text('Erneut versuchen')),
          ],
        ),
      ),
    );
  }
}

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
        // Für SSID/Frequenz braucht Android ggf. Location-Rechte
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }

    final bands = (_wifi?["bandsSupported"] as Map?)?.cast<String, dynamic>();
    final band24 = bands != null ? bands['2_4GHz'] : null;
    final band5 = bands != null ? bands['5GHz'] : null;
    final band6 = bands != null ? bands['6GHz'] : null;
    final band60 = bands != null ? bands['60GHz'] : null;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Section(
            title: 'Wi‑Fi (WifiManager/WifiInfo)',
            children: [
              _kv('SSID', _wifi?["ssid"]),
              _kv('Frequenz (MHz)', _wifi?["frequencyMHz"]),
              _kv('Band', _wifi?["band"]),
              _kv('Link-Geschwindigkeit (Mbps)', _wifi?["linkSpeedMbps"]),
              _kv('RSSI (dBm)', _wifi?["rssiDbm"]),
              _kv('BSSID', _wifi?["bssid"]),
              _kv('IP-Adresse', _wifi?["ip"]),
              const SizedBox(height: 8),
              Text('Unterstützte Frequenzbänder', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              _MonospaceBox(
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

  Widget _kv(String label, Object? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(_fmt(value), style: const TextStyle(fontWeight: FontWeight.w600)),
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

class NfcPage extends StatefulWidget {
  const NfcPage({super.key});

  @override
  State<NfcPage> createState() => _NfcPageState();
}

class _NfcPageState extends State<NfcPage> {
  bool _available = false;
  bool _scanning = false;
  String? _error;
  Map<String, Object?>? _tagSummary;
  String? _rawTag; // pretty JSON

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    try {
      // ignore: deprecated_member_use
      final ok = await NfcManager.instance.isAvailable();
      if (!mounted) return;
      setState(() => _available = ok);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _available = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _tagSummary = null;
      _rawTag = null;
    });
    try {
      await NfcManager.instance.startSession(
        pollingOptions: <NfcPollingOption>{
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (tag) async {
          final summary = _extractSummary(tag);
          // ignore: invalid_use_of_protected_member
          final raw = _pretty(tag.data);
          if (!mounted) return;
          setState(() {
            _tagSummary = summary;
            _rawTag = raw;
            _scanning = false;
          });
          await NfcManager.instance.stopSession();
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _scanning = false;
      });
      try { await NfcManager.instance.stopSession(); } catch (_) {}
    }
  }

  Map<String, Object?> _extractSummary(NfcTag tag) {
    // ignore: invalid_use_of_protected_member
    final data = (tag.data is Map) ? (tag.data as Map).cast<String, dynamic>() : <String, dynamic>{};

    String? idHex;
    try {
      final mifare = data['mifareclassic'] ?? data['mifareultralight'];
      final nfcA = data['nfca'];
      final nfcB = data['nfcb'];
      final nfcF = data['nfcf'];
      final nfcV = data['nfcv'];
      final isoDep = data['isodep'];
      final techWithId = (mifare ?? nfcA ?? nfcB ?? nfcF ?? nfcV ?? isoDep);
      final idBytesDyn = (techWithId is Map) ? techWithId['identifier'] : null;
      final idBytes = (idBytesDyn is List) ? idBytesDyn.cast<int>() : null;
      if (idBytes != null) {
        idHex = idBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
      }
    } catch (_) {}

    int? ndefRecords;
    String? ndefType;
    try {
      final ndef = (data['ndef'] is Map) ? data['ndef'] as Map : null;
      if (ndef != null) {
        final cached = (ndef['cachedMessage'] is Map) ? ndef['cachedMessage'] as Map : null;
        final recordsDyn = (cached != null) ? cached['records'] : null;
        final records = (recordsDyn is List) ? recordsDyn : null;
        ndefRecords = records?.length;
        ndefType = ndef['type']?.toString();
      }
    } catch (_) {}

    final techs = <String>[];
    try { techs.addAll(data.keys.map((e) => e.toString())); } catch (_) {}

    return {
      'UID': idHex ?? '—',
      'NDEF Records': ndefRecords ?? 0,
      'NDEF Type': ndefType ?? '—',
      'Technologien': techs.join(', '),
    };
  }

  String _pretty(Object? obj) {
    try {
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (_) {
      return obj.toString();
    }
  }

  Widget _kv(String label, Object? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _Section(
          title: 'NFC Verfügbarkeit',
          children: [
            _kv('Unterstützt', _available),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Tag lesen',
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (!_available || _scanning) ? null : _startScan,
                    icon: const Icon(Icons.nfc),
                    label: Text(_scanning ? 'Warte auf Tag…' : 'Scan starten'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_tagSummary != null) ...[
              _kv('UID', _tagSummary!['UID']),
              _kv('NDEF Records', _tagSummary!['NDEF Records']),
              _kv('NDEF Type', _tagSummary!['NDEF Type']),
              _kv('Technologien', _tagSummary!['Technologien']),
              const SizedBox(height: 8),
              Text('Rohdaten', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              _MonospaceBox(text: _rawTag ?? '—'),
            ],
            if (_tagSummary == null)
              const Text('Kein Tag gelesen. Starte einen Scan und halte ein Tag an das Gerät.'),
          ],
        ),
        const SizedBox(height: 12),
        if (Platform.isIOS)
          _Section(
            title: 'Hinweis iOS',
            children: const [
              Text('Für echtes NFC-Scannen muss in Xcode die Capability "Near Field Communication Tag Reading" aktiviert werden. Ohne diese Capability funktioniert NFC auf iOS nicht.'),
            ],
          ),
      ],
    );
  }
}
