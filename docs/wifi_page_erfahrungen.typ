#set page(margin: 2cm)
#set text(size: 11pt, font: "Linux Libertine")
#set heading(numbering: "1.")

= WiFi Page - Entwicklungserfahrungen

== Überblick

Die WiFi Page zeigt detaillierte Informationen über die aktuelle WLAN-Verbindung an, inklusive SSID, Frequenz, Signalstärke und unterstützte Frequenzbänder. Die Implementierung nutzt ebenfalls Platform Channels für den Zugriff auf native Android WiFi-APIs.

== Technische Herausforderungen

=== Location Permission für WiFi-Info

*Problem:* Ab Android 10+ ist die Location Permission erforderlich, um WiFi-Informationen abzurufen. Dies war anfangs nicht klar und führte zu leeren Ergebnissen.

*Lösung:* Es wurde explizit die Location Permission angefragt, bevor die WiFi-Daten abgerufen werden:

```dart
if (Platform.isAndroid) {
  await Permission.locationWhenInUse.request();
}
final res = await _channel.invokeMethod<dynamic>('getWifiInfo');
```

*Hinweis:* Dies ist ein typisches Problem bei der Android-Entwicklung. Die Location Permission für WiFi-Info ist nicht intuitiv, aber notwendig. Die Android-Dokumentation für die jeweilige API-Version sollte stets konsultiert werden.

=== Frequenzbänder-Darstellung

*Problem:* Die Frequenzbänder kamen als verschachtelte Map-Struktur zurück. Die direkte Anzeige war unübersichtlich.

*Lösung:* Die Bänder wurden extrahiert und formatiert angezeigt:

```dart
final bands = (_wifi?['bandsSupported'] as Map?)?.cast<String, dynamic>();
final band24 = bands != null ? bands['2_4GHz'] : null;
final band5 = bands != null ? bands['5GHz'] : null;
// ...
```

Anschließend werden sie in einem `MonospaceBox` angezeigt, damit die Formatierung konsistent ist.

*Hinweis:* Bei verschachtelten Datenstrukturen ist es häufig besser, die Daten zunächst zu extrahieren und dann anzuzeigen, statt alles inline zu implementieren. Dies verbessert die Code-Lesbarkeit.

=== Null-Safety und Optionale Werte

*Problem:* Viele WiFi-Werte können `null` sein (z.B. wenn kein WiFi verbunden ist). Die direkte Verwendung führte zu Null-Pointer-Exceptions.

*Lösung:* Der Null-Safety Operator (`?`) wird konsequent verwendet und es wurde eine `_fmt()` Hilfsfunktion für die Formatierung erstellt:

```dart
String _fmt(Object? v) {
  if (v == null) return '—';
  if (v is bool) return v ? 'Ja' : 'Nein';
  return v.toString();
}
```

*Hinweis:* Darts Null-Safety ist hilfreich, muss jedoch korrekt angewendet werden. Optionale Werte sollten stets berücksichtigt werden, insbesondere bei nativen API-Aufrufen.

=== String-Formatierung in MonospaceBox

*Problem:* Anfangs wurde versucht, die Frequenzbänder direkt als String zu formatieren, jedoch wurden die Zeilenumbrüche nicht korrekt angezeigt.

*Lösung:* Es wird nun `join('\\n')` für die Zeilenumbrüche verwendet:

```dart
MonospaceBox(
  text: [
    '2.4 GHz: ${_fmt(band24)}',
    '5 GHz:   ${_fmt(band5)}',
    '6 GHz:   ${_fmt(band6)}',
    '60 GHz:  ${_fmt(band60)}',
  ].join('\\n'),
),
```

*Hinweis:* Bei mehrzeiligen Texten in Widgets muss gelegentlich explizit mit Escape-Sequenzen gearbeitet werden. `\n` vs `\\n` kann einen Unterschied machen, je nachdem wie das Widget den String interpretiert.

== Architektur-Entscheidungen

=== Konsistente UI-Patterns

Es wurden die gleichen Widgets wie auf der Mobile Page verwendet (`Section`, `KeyValueRow`, `MonospaceBox`). Dies macht die App konsistent und reduziert Code-Duplikation.

=== Refresh-Funktionalität

Wie auf der Mobile Page gibt es auch hier einen `RefreshIndicator` und einen Refresh-Button. WiFi-Informationen können sich schnell ändern, daher ist dies wichtig.

== Lessons Learned

1. *Android Permissions sind komplex:* Die Location Permission für WiFi-Info war nicht offensichtlich. Die Android-Version und das API-Level sollten stets berücksichtigt werden.

2. *Null-Safety nutzen:* Darts Null-Safety hilft, muss jedoch korrekt angewendet werden. Optionale Werte sind bei nativen APIs sehr häufig.

3. *Konsistente Formatierung:* Eine kleine Hilfsfunktion wie `_fmt()` verbessert die Code-Qualität und Konsistenz erheblich.

4. *Platform-spezifische Logik:* Nicht alle Features funktionieren auf allen Plattformen gleich. Platform-Checks sollten stets durchgeführt werden.

== Verbesserungspotenzial

- *WiFi-Netzwerk-Liste:* Anzeige aller verfügbaren Netzwerke (nicht nur des verbundenen)
- *Verbindungsqualität:* Visualisierung der Signalstärke (z.B. als Progress Bar)
- *Historische Daten:* Speicherung von WiFi-Verbindungen über die Zeit
- *Erweiterte Informationen:* Mehr technische Details (z.B. Channel, Security Type)

== Besondere Herausforderungen

=== Android 13+ Nearby Devices Permission

Ab Android 13 gibt es eine neue Permission (`NEARBY_WIFI_DEVICES`), die für WiFi-Scanning benötigt wird. Diese wurde in der `AndroidManifest.xml` deklariert, jedoch noch nicht vollständig implementiert. Dies wäre eine sinnvolle Erweiterung für die Zukunft.

*Hinweis:* Bei der Android-Entwicklung sollten die neuesten Permission-Änderungen stets beachtet werden. Google ändert dies regelmäßig.

