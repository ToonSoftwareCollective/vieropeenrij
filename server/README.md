# Vier op een rij: tegen een mens spelen

De app kent drie tegenstanders (Instellingen, knop rechtsboven op het spelscherm):

| Tegenstander      | Wat is nodig                                                         |
|-------------------|----------------------------------------------------------------------|
| Toon (computer)   | niets                                                                |
| Andere Toon       | twee Toons in hetzelfde netwerk, elkaars IP adres                    |
| Server            | dit script op een webserver, bereikbaar voor alle Toons              |

## Andere Toon (thuisnetwerk)

Geen extra software. Elke Toon schrijft het spel naar `/qmf/www/vieropeenrij.json`; dat bestand
wordt door de webserver van de Toon zelf (lighttpd, poort 80) uitgeleverd als
`http://<ip-van-de-toon>/vieropeenrij.json`. De andere Toon haalt het elke 2 seconden op zolang het
spelscherm open staat (elke 15 seconden daarbuiten).

Instellen: op Toon A het IP adres van Toon B invullen en omgekeerd. Het instellingenscherm toont het
eigen IP adres. Wie op "Nieuw spel" drukt speelt rood; de ander doet automatisch mee als geel.

## Server (internet)

Zet een van deze twee op een machine die alle Toons kunnen bereiken en vul het adres in bij
"Server adres". Spelers die dezelfde "Kamer" kiezen spelen tegen elkaar.

**PHP** (gewone webhosting): kopieer `vieropeenrij.php` naar de webserver. Het script maakt naast
zich een map `rooms/` aan, de webserver moet daar mogen schrijven. Adres in de app bijvoorbeeld
`https://mijnsite.nl/toon/vieropeenrij.php`.

**Python 3** (Raspberry Pi, NAS, Home Assistant host):

    python3 vieropeenrij_server.py --port 8642

Adres in de app: `http://<ip>:8642/`. Om het als dienst te draaien, bijvoorbeeld met systemd:

    [Unit]
    Description=Vier op een rij relay
    After=network.target

    [Service]
    ExecStart=/usr/bin/python3 /opt/vieropeenrij/vieropeenrij_server.py --port 8642 --dir /var/lib/vieropeenrij
    Restart=always

    [Install]
    WantedBy=multi-user.target

## Protocol

Een spel is een klein JSON object dat beide kanten volledig kunnen naspelen:

    {"v":1, "id":"1725970000000-4f2a", "ts":1725970000000,
     "red":{"id":"a1b2c3d4","name":"Toon woonkamer"}, "yellow":{"id":"e5f6a7b8","name":"Toon zolder"},
     "first":"red", "moves":"3341"}

`moves` is de kolom van elke gespeelde schijf, op volgorde. Wie aan de beurt is volgt uit de lengte
van `moves` en `first`. Bij het samenvoegen van twee versies geldt overal dezelfde regel:

1. een spel met een nieuwere `ts` vervangt een ouder spel (iemand drukte op "Nieuw spel");
2. binnen hetzelfde spel wordt een langere zettenlijst die de eigen lijst voortzet overgenomen;
3. de vrije gele stoel gaat naar de eerste die hem claimt.

Server: `GET ?room=<kamer>` geeft het spel van de kamer (`{}` als er nog niets is),
`POST ?room=<kamer>` met het spel als body voegt het samen en antwoordt met het resultaat.
Kamers die een maand niet zijn gebruikt worden opgeruimd.
