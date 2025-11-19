#set page(margin: 2cm)
#set text(size: 11pt, font: "Linux Libertine")
#set heading(numbering: "1.")

= NFC Page - Entwicklungserfahrungen

== Überblick

Die NFC Page ermöglicht das Lesen von NFC-Tags und zeigt sowohl die technischen Details (UID, Technologien) als auch die NDEF-Daten (falls vorhanden) an. Die Implementierung nutzt das `nfc_manager` Package, das eine Flutter-Wrapper für native NFC-Funktionalitäten ist.

== Technische Herausforderungen

=== "Instance of TagPigeon" Problem

*Problem:* Anfangs wurden die Rohdaten als "Instance of TagPigeon" angezeigt statt als strukturierte JSON-Daten. Das `tag.data` Objekt war ein Pigeon-Objekt (ein Code-Generation-Objekt für Platform Channels), das nicht direkt serialisierbar war.

*Lösung:* Es wurde eine `_toSerializable()` Methode erstellt, die Pigeon-Objekte rekursiv in serialisierbare Maps konvertiert:

```dart
String _pretty(Object? obj) {
  try {
    final data = (obj is Map) ? obj.cast<String, dynamic>() : <String, dynamic>{};
    final serializable = _toSerializable(data);
    return const JsonEncoder.withIndent('  ').convert(serializable);
  } catch (e) {
    return obj?.toString() ?? 'null';
  }
}

Object? _toSerializable(Object? obj) {
  if (obj == null) return null;
  if (obj is Map) {
    return obj.map((key, value) => MapEntry(
      key.toString(),
      _toSerializable(value),
    ));
  }
  if (obj is List) {
    return obj.map((e) => _toSerializable(e)).toList();
  }
  if (obj is String || obj is num || obj is bool) {
    return obj;
  }
  return obj.toString();
}
```

*Hinweis:* Pigeon-Objekte sind ein häufiges Problem bei Flutter Platform Channels. Diese Objekte sind nicht direkt JSON-serialisierbar. Eine rekursive Konvertierung ist erforderlich.

=== NDEF-Daten nicht lesbar

*Problem:* Obwohl auf den NFC-Tags Daten vorhanden waren, wurden sie nicht angezeigt. Die NDEF-Daten wurden nicht automatisch gelesen.

*Lösung:* Die NDEF-Daten wurden explizit aus den gecachten Tag-Daten extrahiert:

```dart
final tagData = (tag.data is Map) ? (tag.data as Map).cast<String, dynamic>() : <String, dynamic>{};
final ndef = tagData['ndef'];

if (ndef is Map) {
  final cached = ndef['cachedMessage'];
  if (cached is Map) {
    final records = cached['records'];
    if (records is List && records.isNotEmpty) {
      ndefData = {'records': records};
    }
  }
}
```

*Hinweis:* Nicht alle NFC-Tags haben NDEF-Daten. Manche Tags sind nur für technische Informationen (UID) vorhanden. Es sollte stets geprüft werden, ob NDEF-Daten vorhanden sind, bevor versucht wird, sie zu lesen.

=== NDEF-Record Dekodierung

*Problem:* Die NDEF-Records kamen als Byte-Arrays zurück. Text-Records und URI-Records mussten manuell dekodiert werden.

*Lösung:* Es wurde eine Logik implementiert, die verschiedene Record-Typen erkennt und entsprechend dekodiert:

```dart
if (typeString.startsWith('T')) {
  // Text Record - erstes Byte ist Status-Byte
  final textBytes = payload.length > 1 ? payload.sublist(1) : payload;
  try {
    content = utf8.decode(textBytes);
  } catch (_) {
    content = payload.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }
} else if (typeString.startsWith('U')) {
  // URI Record
  try {
    content = utf8.decode(payload.length > 1 ? payload.sublist(1) : payload);
  } catch (_) {
    content = payload.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }
}
```

*Hinweis:* NDEF-Records haben unterschiedliche Formate. Text-Records haben ein Status-Byte am Anfang, URI-Records haben einen Präfix. Die NDEF-Spezifikation sollte verstanden werden.

=== Verschiedene Record-Formate handhaben

*Problem:* Die NDEF-Records kamen in verschiedenen Formaten zurück - manchmal als Maps mit `typeString`, manchmal nur mit `type` als Byte-Array.

*Lösung:* Es wurde eine robuste Extraktionslogik implementiert, die beide Formate unterstützt:

```dart
String typeString = '';
List<int>? payload;

if (record is Map) {
  typeString = (record['typeString'] as String?) ?? '';
  final payloadList = record['payload'];
  if (payloadList is List) {
    payload = payloadList.cast<int>();
  } else if (payloadList is Uint8List) {
    payload = payloadList.toList();
  }
  
  // Falls typeString leer, versuche type zu dekodieren
  if (typeString.isEmpty) {
    final typeList = record['type'];
    if (typeList is List) {
      final typeBytes = typeList.cast<int>();
      if (typeBytes.isNotEmpty) {
        try {
          typeString = String.fromCharCodes(typeBytes);
        } catch (_) {
          typeString = typeBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
        }
      }
    }
  }
}
```

*Hinweis:* Bei nativen APIs kommen Daten häufig in verschiedenen Formaten zurück. Eine defensive Programmierung mit vielen Fallbacks ist wichtig.

=== iOS NFC Capabilities

*Problem:* Auf iOS funktioniert NFC nur, wenn die Capability "Near Field Communication Tag Reading" in Xcode aktiviert ist.

*Lösung:* Es wurde ein Hinweis in der UI eingebaut:

```dart
if (Platform.isIOS)
  const Section(
    title: 'Hinweis iOS',
    children: [
      Text('Für echtes NFC-Scannen muss in Xcode die Capability "Near Field Communication Tag Reading" aktiviert werden.'),
    ],
  ),
```

*Hinweis:* iOS hat striktere NFC-Beschränkungen als Android. Die Capabilities in Xcode sollten stets geprüft werden.

== Architektur-Entscheidungen

=== Polling Options

Es wurden mehrere Polling-Optionen aktiviert, um verschiedene NFC-Tag-Typen zu unterstützen:

```dart
pollingOptions: <NfcPollingOption>{
  NfcPollingOption.iso14443,
  NfcPollingOption.iso15693,
  NfcPollingOption.iso18092,
},
```

Dies erhöht die Kompatibilität, kann jedoch auch die Batterie belasten.

=== Session Management

Die NFC-Session wird sofort nach dem Lesen eines Tags beendet:

```dart
await NfcManager.instance.stopSession();
```

Dies ist wichtig, damit die App nicht im Hintergrund weiter scannt.

== Lessons Learned

1. *Pigeon-Objekte sind komplex:* Platform Channel Code-Generation erzeugt Objekte, die nicht direkt serialisierbar sind. Eine Konvertierungsschicht sollte stets eingebaut werden.

2. *NDEF ist komplex:* Die NDEF-Spezifikation hat viele Details (Status-Bytes, Präfixe, etc.). Die Dokumentation ist wichtig.

3. *Defensive Programmierung:* Bei nativen APIs kommen Daten in verschiedenen Formaten. Viele Fallbacks und Type-Checks sind notwendig.

4. *Platform-Unterschiede:* iOS und Android haben unterschiedliche NFC-Implementierungen. Beide Plattformen sollten getestet werden.

5. *Error Handling:* NFC kann aus vielen Gründen fehlschlagen (Tag zu weit weg, kein NFC, etc.). Gutes Error Handling ist wichtig.

== Verbesserungspotenzial

- *NDEF-Schreiben:* Aktuell kann die App nur lesen. Schreiben wäre eine sinnvolle Erweiterung.
- *Tag-Historie:* Gescannte Tags könnten gespeichert werden.
- *Erweiterte NDEF-Typen:* Unterstützung für mehr Record-Typen (z.B. Smart Poster, MIME-Types).
- *QR-Code Integration:* Kombination von NFC und QR-Code Scanning.

== Besondere Herausforderungen

=== NDEF vs. Technische Daten

Nicht alle NFC-Tags haben NDEF-Daten. Manche Tags (z.B. Mifare Classic) haben nur technische Informationen. Die App muss beide Fälle handhaben können.

*Hinweis:* Es sollte stets zuerst geprüft werden, ob NDEF-Daten vorhanden sind. Falls nicht, sollten zumindest die technischen Informationen (UID, Technologien) angezeigt werden.

=== Performance

Das rekursive Konvertieren von großen Tag-Datenstrukturen kann langsam sein. Bei sehr großen Tags könnte über Caching oder Lazy Loading nachgedacht werden.

*Hinweis:* Bei Performance-Problemen sollte zunächst gemessen werden, bevor optimiert wird. Meistens ist es nicht so problematisch wie erwartet.

=== App-Interferenz bei NFC-Scanning

*Problem:* Während der Entwicklung trat wiederholt das Problem auf, dass sich andere NFC-Leser-Apps in den Vordergrund schoben, wenn ein NFC-Tag gelesen wurde. Dies führte dazu, dass die eigene App den Fokus verlor und der Nutzer zu einer anderen App weitergeleitet wurde, obwohl die App aktiv einen Scan durchführte.

*Lösung:* Dieses Verhalten ist Teil des Android NFC-Dispatcher-Systems, das standardmäßig alle Apps mit NFC-Intent-Filtern benachrichtigt, wenn ein Tag erkannt wird. Die Implementierung nutzt `NfcManager.startSession()`, um eine aktive NFC-Session zu etablieren, die Vorrang vor passiven Intent-Filtern haben sollte. Dennoch kann es vorkommen, dass das System andere Apps bevorzugt, insbesondere wenn diese als Standard-App für bestimmte NDEF-Typen registriert sind.

*Hinweis:* Dieses Problem ist systemseitig und kann nicht vollständig durch die App kontrolliert werden. Es empfiehlt sich, Nutzer darauf hinzuweisen, dass andere NFC-Apps deaktiviert oder deren Standard-Einstellungen geändert werden sollten, um eine zuverlässige Funktion zu gewährleisten. Alternativ könnte die App als Standard-Handler für bestimmte NDEF-Typen registriert werden, was jedoch eine komplexere Implementierung erfordert.

