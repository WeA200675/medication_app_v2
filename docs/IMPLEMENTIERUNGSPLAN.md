# Implementierungsplan

## Reihenfolge und Abnahme

### M1 – Fundament und Designsystem

- Flutter-Projekt mit Android/iOS, Lints und CI anlegen
- Feature-Struktur, Routing, Riverpod und Drift einrichten
- Design-Tokens für Farbe, Typografie, Abstände, Radien, Bewegung und Kontrast
- Light, Dark und System sowie erste adaptive App-Shell
- Fehler-, Empty-, Loading- und Offline-Zustände definieren

**Fertig, wenn:** CI grün ist, alle Navigationsziele als adaptive Platzhalter laufen
und Theme-Änderungen ohne Neustart sichtbar werden.

### M2 – Adaptive Navigation und Heute-Dashboard

- Ziele: Heute, Medikamente, Ärzte, Dokumente, Profil/Einstellungen
- Navigation Rail ab mittlerer Breite
- Swipe-fähige Untertabs mit erhaltenem Zustand
- Dashboard-Komponenten für nächste Einnahme, kritischen Bestand und Schnellaktionen
- Golden-Tests für Hochformat, Querformat, Tablet und große Schrift

**Fertig, wenn:** kein Overflow in den vereinbarten Testgrößen auftritt und alle
Bereiche per Touch, Tastatur und Screenreader erreichbar sind.

### M3 – Profil und Personalisierung

- Profilmodell und lokale Speicherung
- Avatar aufnehmen/auswählen, ersetzen und entfernen
- Hintergrundbild, Akzentfarbe, Kontrast/Overlay und Darstellungsdichte
- Sofortige Aktualisierung sowie robuste Behandlung gelöschter Dateien

**Fertig, wenn:** Bild- und Theme-Änderungen appweit sofort erscheinen und nach einem
Neustart erhalten bleiben.

### M4 – Medikamente, Einnahmen und Bestand

- Medikamente und flexible Einnahmepläne
- Heute-Ansicht mit bestätigt/übersprungen/korrigiert
- Transaktionsbasierter Bestand mit Dezimalmengen und Einheiten
- Mindestbestand, Restreichweite, Warnstufen und Nachfüllung
- Historie und nachvollziehbare Korrekturen

**Fertig, wenn:** Unit-Tests mehrere Dosen, halbe Tabletten, Wochentage,
Planänderungen, Zeitzonenwechsel und Gegenbuchungen abdecken.

### M5 – Ärzte und externe Aktionen

- Lokale Arztverwaltung und Suche
- Provider-Schicht für externe Such-/Detaildaten
- Zusammenführung mit Quellen- und Aktualitätsanzeige
- Telefon, Website, E-Mail, Maps/Navigation und fehlende Felder
- Caching, Rate-Limits, Timeouts und Fehlerzustände

**Fertig, wenn:** unvollständige Treffer eine saubere UI ergeben und jede externe
Aktion vor Ausführung validiert wird.

### M6 – Dokumente und Migration

- Dateiimport, Kamera, OCR, PDF-Vorschau und Arztzuordnung
- Versioniertes Backup/Restore
- V1-Import mit Vorschau, Mapping-Bericht und Rollback bei Fehlern
- Dateiberechtigungen und verwaiste Dateien behandeln

**Fertig, wenn:** ein anonymisierter V1-Fixture-Datensatz verlustfrei importiert wird
und Originaldokumente unverändert bleiben.

### M7 – Nachbestellung, Härtung und Release

- Gebündelte Nachbestellliste und idempotenter Request-Status
- Vorausgefüllter E-Mail-Composer mit editierbarer Vorschau
- Datenschutztexte, Berechtigungs-UX und Datenexport/-löschung
- Accessibility-, Performance-, Integrations- und Geräte-Tests
- Release-Konfiguration, Signierung, Icons und Store-Checkliste

**Fertig, wenn:** keine kritischen Findings offen sind, alle CI-Gates grün sind und
ein getesteter Release-Build auf mindestens einem Android- und einem iOS-Gerät läuft.

## Querschnittliche Qualitätsgates

Für jeden Meilenstein gelten:

- `dart format` ohne Änderungen
- `flutter analyze` ohne Fehler oder Warnungen
- alle Unit- und Widget-Tests grün
- neue Geschäftsregel besitzt mindestens einen Unit-Test
- neue Kernansicht besitzt Semantics und einen adaptiven Layout-Test
- keine echten Gesundheitsdaten in Fixtures, Logs oder Screenshots
- Architekturentscheidungen und Migrationen werden dokumentiert

## Hauptrisiken und Gegenmaßnahmen

| Risiko | Gegenmaßnahme |
|---|---|
| Unzuverlässige Arztdaten | Mehrere klar getrennte Provider, Quellenanzeige, manuelle Korrektur |
| Mail-Entwurf je nach Client unterschiedlich | Vorschau in der App; Composer öffnen; nie automatisches Senden versprechen |
| Falscher Bestand durch Planänderungen | Ereignisprotokoll, Gegenbuchungen, deterministische Tests |
| Verlust lokaler Dokumente | Transaktionaler Import, versioniertes Backup, Original nie überschreiben |
| Responsive Regressionen | Breakpoint- und Text-Scale-Golden-Tests in CI |
| Zu breiter V2-Umfang | Vertikale, jeweils nutzbare Meilensteine und feste Definition of Done |

## Unmittelbarer Start von M1

1. Stabile Flutter-Version und Mindestplattformen festlegen.
2. Projektgerüst samt CI erzeugen.
3. App-Shell, Breakpoints und Design-Tokens implementieren.
4. Drift-Schema v1 und Migrationstest anlegen.
5. Erste adaptive Heute-Ansicht als vertikalen Funktionsschnitt liefern.
