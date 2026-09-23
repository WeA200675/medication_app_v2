# Zielarchitektur

## Leitentscheidungen

- **Flutter bleibt gesetzt:** eine Codebasis für Android und iOS, mit adaptiven
  Oberflächen für Smartphone und Tablet.
- **Local first:** Gesundheitsdaten funktionieren offline und verlassen das Gerät
  nur nach einer ausdrücklichen Nutzeraktion.
- **Feature-orientierte Struktur:** UI, Anwendungsfälle, Domänenmodelle und
  Datenzugriff werden getrennt.
- **Reaktiver Zustand:** Änderungen an Theme, Avatar und Hintergrund werden sofort
  in der gesamten App sichtbar.
- **Ereignisbasierte Einnahmen:** Der aktuelle Bestand wird aus nachvollziehbaren
  Einnahme-, Korrektur- und Nachfüllereignissen aktualisiert.

## Vorgeschlagener Stack

| Aufgabe | Entscheidung |
|---|---|
| UI | Flutter, Material 3 als zugängliche Basis, eigene Design-Tokens |
| Navigation | `go_router` mit Stateful Shell; adaptive Bottom Bar/Navigation Rail |
| State/DI | Riverpod mit codegenerierten Providern |
| Lokale Daten | Drift/SQLite mit versionierten Migrationen |
| Modelle | Immutable Modelle mit Freezed/JSON-Unterstützung |
| Dateien/Bilder | App-Dokumentverzeichnis; DB speichert Referenz und Metadaten |
| Benachrichtigungen | `flutter_local_notifications`, explizite Berechtigungsflüsse |
| Externe Aktionen | `url_launcher` hinter einer testbaren Abstraktion |
| Qualität | `flutter_lints`, Unit-, Widget-, Golden- und Integrationstests |
| CI | GitHub Actions für Format, Analyse und Tests |

Paketversionen werden erst bei M1 gegen die dann aktuelle stabile Flutter-Version
geprüft und festgeschrieben.

## Feature-Struktur

```text
lib/
  app/                 App-Shell, Routing, Theme, Breakpoints
  core/                Datenbank, Dateien, Fehler, gemeinsame Utilities
  features/
    today/              Heute-Dashboard
    medication/         Präparate und Pläne
    intake/             Einnahmen und Historie
    inventory/          Bestand, Schwellen und Nachbestellung
    doctors/            Ärzte, Suche und Aktionen
    documents/          Scan, OCR, Dateien und PDF
    profile/            Stammdaten, Avatar und Personalisierung
    settings/           Darstellung, Datenschutz, Backup
```

Jedes Feature erhält bei Bedarf `domain`, `data`, `application` und
`presentation`. Abhängigkeiten zeigen nach innen zur Domäne.

## Kerndatenmodell

| Entität | Zweck |
|---|---|
| `Medication` | Name, Wirkstoff, Form, Stärke und optionale Produktdaten |
| `MedicationSchedule` | Dosis als Dezimalwert, Einheit, Zeiten, Wochentage, Gültigkeit |
| `IntakeEvent` | geplant/bestätigt/übersprungen/korrigiert mit Zeitstempel |
| `InventoryLot` | Menge, Einheit, optional Charge und Verfallsdatum |
| `InventoryTransaction` | Einnahme, Nachfüllung oder Korrektur; auditierbar |
| `RefillRule` | Mindestbestand oder Mindestreichweite, Empfänger und Aktivierung |
| `RefillRequest` | Status `needed`, `prepared`, `resolved`; verhindert Duplikate |
| `Doctor` | lokale Felder plus bevorzugte Kontakt- und Aktionsdaten |
| `DoctorSourceRecord` | Quellen-ID, Herkunft, Aktualität und Rohzuordnung |
| `MedicalDocument` | Datei, Kategorie, Datum, Arztbezug und OCR-Text |
| `UserProfile` | Stammdaten und Avatarreferenz |
| `AppearanceSettings` | Modus, Akzent, Hintergrund, Kontrast und Dichte |

Mengen werden nicht als Integer modelliert. Intern wird ein Dezimaltyp bzw. eine
skalierte Ganzzahl mit expliziter Einheit verwendet, damit `0,5 Tablette` exakt
bleibt.

## Bestands- und Nachbestellregel

1. Nur eine bestätigte Einnahme erzeugt eine negative Bestandstransaktion.
2. Rücknahme/Korrektur erzeugt eine Gegenbuchung statt bestehende Historie zu löschen.
3. Reichweite wird aus zukünftigen aktiven Dosen berechnet, nicht nur durch
   `Bestand / Tageswert`.
4. Unterschreitet Bestand oder Reichweite den Grenzwert, entsteht genau eine offene
   `RefillRequest` pro Medikament.
5. Mehrere offene Anforderungen können in einer gemeinsamen Bestellliste erscheinen.
6. Die App öffnet einen vorausgefüllten E-Mail-Composer. Das tatsächliche Speichern
   oder Senden bleibt beim Nutzer und hängt vom installierten Mailclient ab.
7. Nach einer Nachfüllung wird die Anforderung als erledigt markiert; bei erneutem
   Unterschreiten darf eine neue entstehen.

## Adaptive UI

| Breite | Navigation | Inhalt |
|---|---|---|
| Kompakt | Bottom Navigation | Einspaltig, Details als eigene Seite/Sheet |
| Mittel | Navigation Rail | Flexible Kartenraster, optional Master/Detail |
| Erweitert | Navigation Rail | Zwei- oder dreispaltige Master/Detail-Ansicht |

Orientierung allein ist kein Layoutkriterium. Entscheidungen basieren auf verfügbarer
Breite und Höhe. Jeder Kernscreen wird zusätzlich mit großer Systemschrift,
Split-Screen und Tastatur getestet. Horizontales Wischen wird nur innerhalb klarer
Tab-Gruppen verwendet; die globale Navigation bleibt stabil und vorhersehbar.

## Datenschutz und externe Arztdaten

- Keine stillen Uploads von Profil-, Medikamenten- oder Dokumentdaten.
- Datenquellen für Arztdetails werden über Provider abstrahiert und kenntlich gemacht.
- OSM-Nutzungsbedingungen, Rate-Limits und Attribution werden eingehalten.
- Kommerzielle Maps-/Places-Daten werden nur mit passender API, Nutzereinwilligung,
  Schlüsselverwaltung und zulässiger Speicherung integriert.
- Website-Ergänzungen sind optional und müssen transparent, begrenzt und fehlerrobust sein.

## Migration aus V1

V2 erhält einen einmaligen Importer für das versionierte V1-Backup. Importierte
Medikamenteneinträge werden in Medikament, Plan und Anfangsbestand aufgeteilt.
`takenToday` wird nicht als Historie interpretiert. Vor dem finalen Import zeigt eine
Vorschau Warnungen und lässt den Nutzer bestätigen; V1-Daten werden nicht verändert.
