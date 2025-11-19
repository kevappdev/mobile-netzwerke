= Mobile Page - Entwicklungserfahrungen

== Überblick

Die Mobile Page ist die Hauptseite der App und zeigt Informationen über die Telefonie- und Netzwerkverbindungen an. Die Implementierung nutzt Platform Channels, um native Android-Funktionalitäten aus Flutter heraus aufzurufen.

== Technische Herausforderungen

=== Platform Channel Kommunikation

*Problem:* Zu Beginn traten Schwierigkeiten bei der korrekten Datenübertragung zwischen Flutter und dem nativen Android-Code auf. Die MethodChannel-Aufrufe gaben gelegentlich `null` zurück oder die Typen stimmten nicht überein.

*Lösung:* Es wurde eine Hilfsfunktion `toStrDynMap()` erstellt, die rekursiv alle Maps in `Map<String, dynamic>` konvertiert. Dies war notwendig, da die nativen Android-Methoden gelegentlich `Map<Object?, Object?>` zurückgeben, was in Flutter nicht direkt verwendbar ist.

```dart
final res = await _channel.invokeMethod<dynamic>('getAllInfo');
_data = toStrDynMap(res);
```

*Hinweis:* Die Rückgabetypen sollten stets geprüft und bei Bedarf explizit gecastet werden. Die `toStrDynMap()` Funktion reduziert den Debugging-Aufwand erheblich.

=== Android Permissions

*Problem:* Die App benötigt verschiedene Berechtigungen (Phone, Location), jedoch war die Fehlerbehandlung anfangs nicht optimal. Bei fehlenden Permissions wurde lediglich `null` zurückgegeben, ohne klare Fehlermeldung.

*Lösung:* Es wurde eine explizite Permission-Prüfung implementiert, die vor dem Datenabruf ausgeführt wird. Zusätzlich werden fehlende Permissions nun in der UI angezeigt:

```dart
Future<void> _ensureAndroidPermissions() async {
  await [
    Permission.phone,
    Permission.locationWhenInUse,
  ].request();
}
```

*Hinweis:* Das `permission_handler` Package erfordert, dass die Permissions auch in der `AndroidManifest.xml` deklariert sind. Andernfalls funktioniert die Funktionalität nicht.

=== State Management bei asynchronen Operationen

*Problem:* Anfangs wurde vergessen, `mounted` zu prüfen, bevor `setState()` aufgerufen wurde. Dies führte zu "setState() called after dispose()" Fehlern.

*Lösung:* Es wird nun stets `if (!mounted) return;` nach jedem `await` geprüft:

```dart
final res = await _channel.invokeMethod<dynamic>('getAllInfo');
if (!mounted) return;
setState(() {
  _data = toStrDynMap(res);
  _loading = false;
});
```

*Hinweis:* Dies ist ein häufiger Flutter-Fehler. Es sollte stets berücksichtigt werden, dass Widgets disposed werden können, während asynchrone Operationen laufen.

=== Datenformatierung

*Problem:* Die Zellinformationen kamen als komplexe Listen von Maps zurück. Die direkte Anzeige war unübersichtlich.

*Lösung:* Es wurde eine `_formatCells()` Methode erstellt, die die ersten 10 Zellen anzeigt und bei mehreren Einträgen eine Zusammenfassung zeigt:

```dart
String _formatCells(dynamic cells) {
  if (cells is List) {
    if (cells.isEmpty) return '—';
    final lines = cells.take(10).map((e) => e.toString()).join('\n');
    final more = cells.length > 10 ? '\n… (${cells.length - 10} weitere)' : '';
    return lines + more;
  }
  return '—';
}
```

*Hinweis:* Bei großen Datenmengen sollte stets paginiert oder limitiert werden. Andernfalls wird die UI langsam.

== Architektur-Entscheidungen

=== RefreshIndicator

Es wurde ein `RefreshIndicator` verwendet, damit Nutzer die Daten durch Pull-to-Refresh aktualisieren können. Dies ist ein Standard-Pattern in Flutter und verbessert die Benutzerfreundlichkeit.

=== Error Handling

Die Fehlerbehandlung ist zweistufig implementiert:
1. `PlatformException` für native Fehler (z.B. fehlende Permissions)
2. Generische `catch`-Klausel für andere Fehler

Die Fehler werden in einem `ErrorView` Widget angezeigt, das auch einen Retry-Button enthält.

== Lessons Learned

1. *Platform Channels sind mächtig, aber komplex:* Die Typkonvertierung zwischen Dart und Java/Kotlin ist nicht immer intuitiv. Die Dokumentation sollte stets konsultiert werden.

2. *Permissions sind wichtig:* Ohne die richtigen Permissions funktioniert die Funktionalität nicht. Es empfiehlt sich, alle benötigten Permissions zu Beginn zu dokumentieren.

3. *State Management:* Bei asynchronem Code sollte stets an `mounted` gedacht werden. Dies vermeidet häufige Fehler.

4. *UI/UX:* Ein einfacher Refresh-Button und Pull-to-Refresh verbessern die Benutzerfreundlichkeit erheblich.

== Verbesserungspotenzial

- *Caching:* Die Daten könnten gecacht werden, damit sie auch offline verfügbar sind
- *Auto-Refresh:* Ein Timer könnte die Daten periodisch aktualisieren
- *Mehr Details:* Die Zellinformationen könnten detaillierter angezeigt werden (z.B. als expandable List)

