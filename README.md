# Medication App V2

Eine moderne, anpassbare und lokal-first entwickelte Medikamenten-App für
Einnahmeplanung, Bestandsüberwachung, Ärzte, medizinische Dokumente und
Nachbestellungen.

## Projektstatus

**M0–M6: als ausführbarer V2-Funktionsstand implementiert**

- [M0-Analyse](docs/M0_ANALYSE.md)
- [Zielarchitektur](docs/ARCHITEKTUR.md)
- [Implementierungsplan](docs/IMPLEMENTIERUNGSPLAN.md)

Die bestehende App bleibt bis zur geprüften Datenmigration unverändert. V2 wird
schrittweise in diesem Repository aufgebaut.

## Enthaltene Funktionen

- adaptives Smartphone-/Tablet-Layout mit Bottom Navigation bzw. Navigation Rail
- Wischen zwischen den fünf Hauptbereichen
- sofort reaktive Themes, Akzentfarben, Profil- und Hintergrundbilder
- transaktionsbasierter Medikamentenbestand mit Dezimaldosen und Mindestbestand
- Einnahmebestätigung, Reichweite, Auffüllen und gebündelte Nachbestell-E-Mail
- lokale Ärzteverwaltung mit Telefon-, E-Mail-, Website- und Maps-Aktionen
- lokaler Dokumentimport per Kamera oder Datei
- Import vorhandener V1-Medikamenten-Backups
- automatisierte Format-, Analyse- und Testprüfung mit GitHub Actions

## Lokal starten

```bash
flutter pub get
flutter run
```

Die App benötigt eine aktuelle stabile Flutter-Version und Dart 3.4 oder neuer.
