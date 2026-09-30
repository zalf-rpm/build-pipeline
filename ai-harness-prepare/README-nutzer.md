# KI-Assistent auf dem Cluster

Ein Assistent im Terminal, der Ihnen beim Schreiben von Code und SLURM-Skripten hilft.
Er kann Dateien in Ihrem Projektordner lesen und ändern und fragt, bevor er etwas Wichtiges tut
(z. B. einen Job starten).

## Schnellstart

```bash
cd /beegfs/$USER/mein_projekt     # ein Projektordner, nicht Ihr ganzes Home
ai-harness                        # startet den Assistenten auf einem Rechenknoten
```

Beim ersten Start dauert es einen Moment, weil ein Knoten für Sie reserviert wird.
Beenden mit `Strg+C` oder `/exit`. Danach ist die Reservierung wieder frei.

Was Sie fragen können, zum Beispiel:

- "Schreibe ein SLURM-Skript, das `analyse.py` für alle Dateien in `daten/` als Array-Job ausführt."
- "Warum ist mein Job `842076` abgebrochen?" (er schaut mit `sacct` nach)
- "Prüfe `job.sh` auf typische Fehler."

## Welches Modell?

| | Internes Modell (Standard) | Eigener Zugang (`--own`) |
|---|---|---|
| Kosten | keine | Ihr eigener API-Key |
| Ihre Daten | bleiben auf dem Cluster | gehen an den Anbieter |
| Qualität | gut für Skripte und kleinere Aufgaben | stärker bei komplexen Aufgaben |

```bash
ai-harness status       # ist das interne Modell verfügbar?
ai-harness --own        # mit eigenem Key
```

Für `--own` legen Sie einmalig eine Datei `~/.config/ai-harness/env` an (nur für Sie lesbar):

```bash
mkdir -p ~/.config/ai-harness
echo 'ANTHROPIC_API_KEY=...' > ~/.config/ai-harness/env
chmod 600 ~/.config/ai-harness/env
```

**Keine sensiblen oder unveröffentlichten Daten mit `--own`.**

## Was der Assistent darf

- Sehen und ändern: nur den Ordner, in dem Sie ihn gestartet haben. Dazu lesend `/beegfs/common/data`.
- Ohne Rückfrage: Dateien lesen und bearbeiten, `sinfo`, `squeue`, `sacct`, `sbatch --test-only`.
- Nur nach Ihrer Bestätigung: Jobs starten (`sbatch`), Jobs abbrechen, alle anderen Befehle.
- Der Assistent kann sich irren. Lesen Sie Skripte, bevor Sie Jobs bestätigen. Vor allem `--mem`, `--time` und die Partition.

## Optionen

```bash
ai-harness --time 08:00:00 --mem 8G     # längere Sitzung / mehr Speicher
ai-harness doctor                       # prüft die Umgebung, falls etwas nicht funktioniert
```

Probleme? Melden Sie sich beim HPC-Team (MAS-Arbeitsgruppe).
