# M0 – Bestandsaufnahme

Stand: 22. September 2026

## Ergebnis

Die vorhandene Flutter-App ist als Funktionsreferenz brauchbar, sollte aber nicht
als technische Basis kopiert werden. Daten, Regeln und bewährte Abläufe werden
gezielt übernommen; UI, Zustandsverwaltung, Datenmodell und Navigation werden für
V2 neu strukturiert.

## Inventar der bestehenden App

| Bereich | Vorhanden | Bewertung für V2 |
|---|---|---|
| Medikationsplan | Einträge, Dosierung, Uhrzeit, Wochentage, Hinweise | Fachlich übernehmen, Modell normalisieren |
| Einnahme | `takenToday` und pauschaler Abzug von 1 Stück | Durch Ereignisprotokoll ersetzen |
| Bestand | Ganzzahliger `stockCount` | Um Einheit, Verbrauch, Mindestbestand, Reichweite und Nachfüllungen erweitern |
| Erinnerungen | Lokale Benachrichtigung zur nächsten Uhrzeit | Wiederholungen, Berechtigungen, Zeitzone und Wochentage neu implementieren |
| Ärzte | Lokale CRUD-Verwaltung und OSM/Nominatim-Suche | Datenquellen kapseln, Treffer zusammenführen, Herkunft anzeigen |
| Arztaktionen | Telefon, E-Mail, Website/Terminlink, Maps | Beibehalten und fehlertolerant vereinheitlichen |
| Dokumente | Kamera, Dateiauswahl, OCR, Arztzuordnung, PDF-Ansicht | Übernehmen, Dateispeicherung und Berechtigungen härten |
| Profil | Stammdaten in SharedPreferences | In typisierte lokale Speicherung migrieren und Avatar ergänzen |
| Backup | JSON-/Datei-Backup vorhanden | Format versionieren und Restore testen |
| Navigation | Vier Bottom-Navigation-Ziele; Tabs teilweise wischbar | Adaptive Navigation plus konsistentes Swipe-Verhalten |
| Design | Einzelne Material-Widgets mit hart codiertem Teal | Vollständig durch Design-Tokens und adaptive Komponenten ersetzen |

## Verifizierte Schwachstellen

### 1. Medikamentenbestand

- `stockCount` ist eine Ganzzahl; halbe Tabletten und andere Einheiten sind nicht abbildbar.
- Jede bestätigte Einnahme zieht exakt ein Stück ab, unabhängig von der Dosierung.
- `takenToday` ist nur ein Boolean am Medikament. Mehrere Dosen pro Tag, Historie,
  Korrekturen und zuverlässige Tageswechsel fehlen.
- Mindestbestand, Resttage, Nachbestellstatus und eine idempotente Auslösung existieren nicht.
- Der vorhandene E-Mail-Dienst öffnet `mailto:`. Er kann eine vorausgefüllte Nachricht
  öffnen, aber plattformübergreifend nicht garantieren, dass der Mailanbieter sie
  ohne Nutzerinteraktion als Entwurf speichert.

### 2. Unvollständige Arztdaten

- Die Suche nutzt Nominatim und liest nur OSM-`extratags` aus.
- Maps-Daten anderer Anbieter werden nicht abgefragt und können daher nicht einfach
  übernommen werden.
- Die Aktualisierung ergänzt lediglich eine per Regex gefundene E-Mail-Adresse von
  Startseite oder `/impressum`; Weiterleitungen, strukturierte Daten, Unterseiten und
  abweichende Impressum-URLs werden nicht robust behandelt.
- Ein Platzhalter-User-Agent mit Beispielkontakt sollte vor produktiver Nutzung
  ersetzt werden; Rate-Limits, Caching und Quellenhinweise fehlen.

### 3. Profil- und Hintergrundbild

- Weder `UserProfile` noch der Profildienst besitzen Felder für Avatar oder Hintergrund.
- Es existiert kein zentraler reaktiver App-Zustand für Darstellungseinstellungen.
- Eine sofortige Aktualisierung ist deshalb in der aktuellen Architektur nicht
  verlässlich möglich. V2 speichert nur Dateiverweise/Metadaten und publiziert
  Änderungen über einen zentralen Settings-State.

### 4. Hoch- und Querformat

- Große Screens enthalten viele lokal aufgebaute `Row`-, `DataTable`- und feste
  Dialogstrukturen ohne gemeinsame Breakpoints.
- Die Hauptnavigation bleibt in jeder Breite eine BottomNavigationBar.
- Es gibt kein einheitliches Layout-System für kompakt, mittel und erweitert.
- Große Schrift und Split-Screen sind nicht systematisch berücksichtigt.

### 5. Wartbarkeit und Qualität

- UI, Datenzugriff und Geschäftslogik sind häufig direkt in großen Screen-Dateien gekoppelt.
- Mehrere ähnliche Medikations-Screens erhöhen das Risiko divergierender Logik.
- Persistenz ist zwischen SQLite und SharedPreferences verteilt.
- Der vorhandene Testbestand umfasst nur den generierten Widget-Test; fachliche Tests fehlen.
- Automatisierte statische Analyse konnte in der Prüfungsumgebung nicht ausgeführt
  werden, da das Flutter-SDK dort nicht installiert ist. Die Quellcode- und
  Konfigurationsprüfung wurde vollständig durchgeführt; CI übernimmt künftig diesen Check.

## Übernahmeentscheidung

| Entscheidung | Umfang |
|---|---|
| Fachlich übernehmen | Profilfelder, Medikamente, Zeitpläne, Ärzte, Dokumentmetadaten |
| Neu implementieren | App-Shell, Navigation, UI, State, Bestands- und Einnahmelogik |
| Gezielt portieren | OCR, PDF, Backup, Benachrichtigungen, externe Aktionen |
| Nicht übernehmen | Hart codierte Styles, Screen-lokale Geschäftslogik, `takenToday` als Wahrheitsquelle |

## Abnahmekriterien M0

- Funktionsumfang der Alt-App inventarisiert: **erfüllt**
- Ursachen der gemeldeten Probleme identifiziert: **erfüllt**
- Zielarchitektur und Datenverantwortung festgelegt: **erfüllt**
- Datenmigration und Risiken beschrieben: **erfüllt**
- Implementierbare Meilensteine mit Definition of Done erstellt: **erfüllt**

M0 ist damit fachlich abgeschlossen. Der nächste ausführbare Schritt ist M1.
