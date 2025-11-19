import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/common_widgets.dart';

class NfcPage extends StatefulWidget {
  const NfcPage({super.key});
  @override
  State<NfcPage> createState() => _NfcPageState();
}

class _NfcPageState extends State<NfcPage> {
  static const MethodChannel _channel = MethodChannel('com.example.netzwerk/nav');

  bool _available = false;
  bool _scanning = false;
  String? _error;
  Map<String, Object?>? _tagSummary;
  String? _rawTag;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }

  Future<void> _checkAvailability() async {
    try {
      final ok = await _channel.invokeMethod<bool>('isNfcAvailable');
      if (!mounted) return;
      setState(() => _available = ok ?? false);
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _available = false;
        _error = Platform.isIOS
            ? 'NFC ist auf dieser Plattform nicht implementiert.'
            : 'NFC nicht verfügbar.';
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _available = false;
        _error = e.message ?? e.code;
      });
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
      final raw = await _channel.invokeMethod<dynamic>('startNfcScan');
      final data = _coerceMap(raw);
      final summary = _extractSummary(data);
      final pretty = _pretty(data);
      if (!mounted) return;
      setState(() {
        _tagSummary = summary;
        _rawTag = pretty;
        _scanning = false;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _error = 'NFC ist auf dieser Plattform nicht verfügbar.';
        _scanning = false;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? e.code;
        _scanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _scanning = false;
      });
    }
  }

  Future<void> _stopScan() async {
    try {
      await _channel.invokeMethod<void>('stopNfcScan');
    } on MissingPluginException {
      // Ignorieren – Plattform unterstützt NFC nicht
    } catch (_) {}
  }

  Map<String, Object?> _extractSummary(Map<String, dynamic>? data) {
    final uid = (data?['idHex'] ?? data?['id'] ?? data?['uid'] ?? '—').toString();
    final techs = (data?['techList'] as List?)
            ?.map((e) => e.toString().replaceFirst('android.nfc.tech.', ''))
            .toList() ??
        const <String>[];

    final ndef = _asMap(data?['ndef']);
    final records = (ndef?['records'] as List?)
        ?.whereType<Map>()
        .map((raw) => raw.cast<String, dynamic>())
        .toList();
    final ndefContents = <String>[];

    if (records != null) {
      for (final record in records) {
        final type = _decodeType(record['type']);
        final payload = _asIntList(record['payload']);
        final content = _decodePayload(type, payload);
        final label = (type?.isNotEmpty ?? false) ? type : 'Record';
        ndefContents.add('$label: $content');
      }
    }

    return {
      'UID': uid.isNotEmpty ? uid : '—',
      'NDEF Records': records?.length ?? 0,
      'NDEF Type': ndef?['type']?.toString() ?? '—',
      'NDEF Inhalt': ndefContents.isNotEmpty ? ndefContents.join('\n') : '—',
      'Technologien': techs.isNotEmpty ? techs.join(', ') : '—',
    };
  }

  String _pretty(Map<String, dynamic>? data) {
    if (data == null) return '—';
    try {
      return const JsonEncoder.withIndent('  ').convert(_toSerializable(data));
    } catch (e) {
      return data.toString();
    }
  }

  Object? _toSerializable(Object? obj) {
    if (obj == null) return null;
    
    // Wenn es bereits eine Map ist, konvertiere rekursiv
    if (obj is Map) {
      return obj.map((key, value) => MapEntry(
        key.toString(),
        _toSerializable(value),
      ));
    }
    
    // Wenn es eine List ist, konvertiere rekursiv
    if (obj is List) {
      return obj.map((e) => _toSerializable(e)).toList();
    }
    
    // Wenn es ein primitiver Typ ist, gib es zurück
    if (obj is String || obj is num || obj is bool) {
      return obj;
    }
    
    // Fallback: toString() für andere Objekte
    return obj.toString();
  }

  Map<String, dynamic>? _coerceMap(Object? value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  List<int>? _asIntList(Object? value) {
    if (value is List) {
      return value.whereType<num>().map((e) => e.toInt() & 0xFF).toList();
    }
    return null;
  }

  String? _decodeType(Object? typeSource) {
    final bytes = _asIntList(typeSource);
    if (bytes == null || bytes.isEmpty) return null;
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    }
  }

  String _decodePayload(String? type, List<int>? payload) {
    if (payload == null || payload.isEmpty) return '—';
    try {
      if (type != null && type.startsWith('U') && payload.length > 1) {
        return utf8.decode(payload.sublist(1));
      }
      if (type != null && type.startsWith('T') && payload.length > 1) {
        final textBytes = payload.sublist(1);
        return utf8.decode(textBytes);
      }
      return utf8.decode(payload);
    } catch (_) {
      return payload.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Section(
          title: 'NFC Verfügbarkeit',
          children: [
            KeyValueRow('Unterstützt', _available),
          ],
        ),
        const SizedBox(height: 12),
        Section(
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
              KeyValueRow('UID', _tagSummary!['UID']),
              KeyValueRow('NDEF Records', _tagSummary!['NDEF Records']),
              KeyValueRow('NDEF Type', _tagSummary!['NDEF Type']),
              if (_tagSummary!['NDEF Inhalt'] != null && _tagSummary!['NDEF Inhalt'] != '—')
                KeyValueRow('NDEF Inhalt', _tagSummary!['NDEF Inhalt']),
              KeyValueRow('Technologien', _tagSummary!['Technologien']),
              const SizedBox(height: 8),
              Text('Rohdaten', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              MonospaceBox(text: _rawTag ?? '—'),
            ],
            if (_tagSummary == null)
              const Text('Kein Tag gelesen. Starte einen Scan und halte ein Tag an das Gerät.'),
          ],
        ),
        const SizedBox(height: 12),
        if (Platform.isIOS)
          const Section(
            title: 'Hinweis iOS',
            children: [
              Text('Für echtes NFC-Scannen muss in Xcode die Capability "Near Field Communication Tag Reading" aktiviert werden. Ohne diese Capability funktioniert NFC auf iOS nicht.'),
            ],
          ),
      ],
    );
  }
}


