#set page(margin: 2cm)
#set text(size: 11pt, font: "Linux Libertine")
#set heading(numbering: "1.")

= Netzwerk Navigator - Entwicklungsdokumentation

== Überblick

Dieses Projekt ist eine Flutter-App, die verschiedene Netzwerkinformationen sammelt und anzeigt. Die App besteht aus drei Hauptseiten:

1. *Mobile Page* - Telefonie- und Netzwerkinformationen
2. *WiFi Page* - WLAN-Verbindungsdetails
3. *NFC Page* - NFC-Tag Lesen und Anzeigen

== Dokumentation

Für jede Seite gibt es eine detaillierte Dokumentation der Entwicklungserfahrungen:

- Mobile Page Erfahrungen (`mobile_page_erfahrungen.typ`)
- WiFi Page Erfahrungen (`wifi_page_erfahrungen.typ`)
- NFC Page Erfahrungen (`nfc_page_erfahrungen.typ`)

== Technologie-Stack

- *Flutter* - Cross-Platform Framework
- *Platform Channels* - Kommunikation mit nativen Android-Code
- *nfc_manager* - NFC-Funktionalität
- *permission_handler* - Permission Management

== Hauptherausforderungen

1. *Platform Channel Kommunikation* - Typkonvertierung zwischen Dart und Java/Kotlin
2. *Android Permissions* - Komplexe Permission-Strukturen, besonders bei neueren Android-Versionen
3. *NFC NDEF-Daten* - Komplexe Datenstrukturen und verschiedene Record-Formate
4. *State Management* - Asynchrone Operationen und Widget Lifecycle

== Lessons Learned

- Platform Channels sind mächtig, aber die Typkonvertierung ist nicht immer intuitiv
- Android Permissions ändern sich regelmäßig - die neueste Dokumentation sollte stets konsultiert werden
- Defensive Programmierung ist bei nativen APIs essentiell
- Konsistente UI-Patterns verbessern die Benutzerfreundlichkeit

== Weitere Informationen

Siehe die einzelnen Dokumentationsdateien für detaillierte Informationen zu jeder Seite.

