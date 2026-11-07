# reforge Friends

WoW-Addon für World of Warcraft: Forever (Prototyp 0.3.0). Zeigt die Position deiner Community-Freunde auf der Weltkarte, ohne dass ihr in einer Gruppe seid, und auf Wunsch ihre offenen Quests.

## So funktioniert es

- Die Addons tauschen **Addon-Flüstern** (`C_ChatInfo.SendAddonMessage`, Typ `WHISPER`, Präfix `RFFR`) direkt zwischen den Spielern aus. Nichts davon läuft über einen Server, und im Chat ist nichts zu sehen.
- Gesendet und angenommen wird **nur mit Mitgliedern der eigenen Liste**. Nachrichten von anderen werden verworfen.
- **Teilen ist standardmäßig an**, aber nur mit Mitgliedern der eigenen Liste (ohne Einträge geht nichts raus). Die Questliste ist standardmäßig privat. Wer nur zuschauen will, schaltet das Teilen aus und sieht trotzdem die Pins der anderen.
- **Minimap-Symbol:** Linksklick schaltet das Teilen (grau = aus), Rechtsklick die Pins, Ziehen verschiebt es. `/rff minimap off` blendet es aus.
- Position alle 5 Sekunden, aber nur bei Änderung oder alle 30 Sekunden als Herzschlag. Ein Pin verschwindet nach 75 Sekunden ohne Nachricht, beim Ausschalten sofort.
- In Instanzen und Schlachtfeldern liefert das Spiel keine Koordinaten: dann gibt es keinen Pin, `/rff list` zeigt „in einer Instanz“.
- Ist ein Freund offline, erzeugt das Hallo-Flüstern eine Systemmeldung „Kein Spieler namens …“. Das Addon filtert sie für Listenmitglieder aus dem Chat.
- Quests: Shift+Mouseover oder Klick auf einen Pin fragt die Questliste an. Der andere antwortet nur, wenn er `quests on` gesetzt hat; sonst meldet das Addon „teilt keine Quests“. Es gehen nur Quest-IDs über die Leitung, die Titel löst dein eigenes Spiel auf.

## Bedienung

`/rff` oder `/reforgefriends`: `share on|off`, `quests on|off`, `pins on|off`, `minimap on|off`, `add <Name>`, `remove <Name>`, `list`, `status`

**Mitglieder:** Der reforge-Client meldet die Charaktere deines WTF-Ordners an den Server und schreibt die Charaktere der Mitglieder deiner Communities in ein eigenes kleines Addon `ReforgeFriendsRoster` (Tabelle `ReforgeFriendsRoster = { "Name", ... }`, alle 10 Minuten aufgefrischt). Dieses Friends-Addon lädt es als `OptionalDeps` und liest die Liste beim nächsten Login oder `/reload`. Der Client tut das nur, wenn dieses Addon installiert ist; ohne es verlassen Charakternamen den PC nicht. Gesehen werden die Namen nur von Mitgliedern gemeinsamer Communities (angenommene Mitgliedschaft). Zusätzlich lassen sich Namen mit `/rff add` von Hand eintragen.

## Offen / nur im Spiel prüfbar

Die Tests (`tests/friends_test.lua`) prüfen Protokoll, Teilen, Ablauf, Quests und Fremde gegen eine nachgebaute API. Ob Forever das alles so zulässt, zeigt nur der Test im Spiel:

1. Kommt `SendAddonMessage` per `WHISPER` ohne Gruppe durch (gleiche Fraktion/Realm)?
2. Liefert `C_Map.GetPlayerMapPosition` in der offenen Welt Koordinaten?
3. Stimmen die Pins auf der Weltkarte (Position, Größe beim Zoomen), auch wenn ein Freund in einem Unterbereich steht (Umrechnung über Weltkoordinaten)?
4. Wird die Offline-Meldung wirklich ausgefiltert?

Noch nicht gebaut: Pins auf der Minimap, Wegpunkt zum Freund, Community-/Gruppen-Auswahl im Addon.

## Entwickeln

Der Ordner `ReforgeFriends/` ist das Addon.

```sh
docker run --rm -v "$PWD:/w" -w /w --entrypoint lua nickblah/lua:5.1 tests/friends_test.lua
```

## Veröffentlichen

1. `## Version` in `ReforgeFriends/ReforgeFriends.toc` hochzählen. Nach einem Spiel-Patch auch `## Interface`.
2. Committen, pushen und den Tag setzen und pushen (`git tag v0.3.1 && git push origin v0.3.1`). Der Tag muss zur Version passen (`v` plus `## Version`), sonst bricht der Workflow ab; er legt das GitHub-Release an.
3. Fertig. Der Katalog in `reforge.win` steht auf `"ref": "latest"`: das Backend holt das neueste Release spätestens nach 15 Minuten selbst, die Clients bieten das Update in der Bibliothek an. Weder Backend noch Client müssen neu ausgeliefert werden.
