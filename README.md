# Rubrics · spreekopdrachten

Native SwiftUI-app (Mac en iPad) voor het beoordelen van spreekopdrachten met een rubric.
Nagebouwd volgens de technische beschrijving van de webversie op claude.ai.

## Openen en starten

1. Open `Rubrics.xcodeproj` in Xcode 16 of nieuwer.
2. Kies het target **Rubrics** > tab **Signing & Capabilities** > kies je eigen **Team**
   (een gratis Apple ID volstaat voor de Mac).
3. Kies bovenaan als bestemming **My Mac** en druk op ▶︎ (Cmd+R).
4. Voor de iPad: sluit de iPad aan, kies hem als bestemming en druk op ▶︎.
   Met een gratis Apple ID werkt de app daar 7 dagen; met een betaald
   Developer-account een jaar (of via TestFlight).

Vereist macOS 14 / iPadOS 17 of nieuwer.

## Gegevens

- Alles staat lokaal op het toestel, in de app-map
  (`Application Support/Rubrics/settings.json` en `evals/<id>.json`).
- Er is geen Opslaan-knop: elke wijziging wordt na een halve seconde bewaard.
- **Gegevens uit de oude tool overzetten:** in de oude tool op claude.ai
  "Back-up downloaden", daarna in deze app *Beoordelen > Back-up terugzetten…*.
- Van Mac naar iPad (of omgekeerd) gaat voorlopig ook via het back-upbestand.

## Schoollogo

Sleep het schoollogo (PNG) in `Assets.xcassets` als afbeelding met de naam
`SchoolLogo`. Zonder dat logo gebruikt de app het logo dat je in het tabblad
Rubrics kiest ("Ander logo…"), of geen logo.

## Structuur

| Map | Inhoud |
| --- | --- |
| `Model/` | Datamodel (JSON-compatibel met de back-up), opslag, loting en kernlogica |
| `Views/` | De drie tabbladen: Beoordelen, Rubrics, Klassen |
| `PDF/` | PDF's met Core Graphics: rubricformulier, lege rubric, lotingslijst |
| `Support/` | Kleuren, logo-verwerking, bewaren/delen van bestanden |
