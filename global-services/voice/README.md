# global-services/voice

**Runtime:** un sidecar **kai-voice** por host (TTS para Kai Board).  
**Código:** [`kai-suite/services/kai-voice`](https://github.com/felipechandiadev/kai-suite) — Python + edge-tts (`.venv`; **no** npm workspace).

## Compartido

TTS es stateless: **un solo proceso** alcanza para todos los tenants. Todos los backends / Board apuntan a `KAI_VOICE_URL` (`sharedServices.voice` en el registry), tipicamente `http://localhost:5041`.

Alias legacy en Core: `LIRA_VOICE_URL`.

No hace falta modo dedicated salvo requisito raro de aislamiento; el default es siempre shared.

## Contrato

- `POST /voice/speak` — `{ "text": "...", "voice?": "es-CL-CatalinaNeural" }` → audio
- `GET /health`

## Cómo levantarlo

```bash
# en kai-suite
cd services/kai-voice
npm run install:py
npm run start:dev
```

Docs: `kai-suite/docs/apps/SERVICES-SIDECARS.md`, `services/kai-voice/README.md`.

## Puerto

**5041** (`sharedServices.voice.port` / URL).
