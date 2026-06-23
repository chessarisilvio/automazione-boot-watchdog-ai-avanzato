# Boot/Watchdog AI Avanzato

## Descrizione
Questo progetto fornisce un watchdog per il servizio `llama-stack` che monitora:
- Esistenza del processo
- Utilizzo della VRAM (soglia configurabile)
- Token‑per‑secondo dal log delle metriche
- Invio di notifica Telegram in caso di fallimento

## Architettura
- `watchdog.sh`: script principale che esegue i controlli di salute del processo, VRAM e token‑rate.
- `notify_telegram.sh`: script chiamato da watchdog.sh per inviare una notifica tramite bot Telegram.
- `llama-stack.service.modified`: esempio di unit systemd aggiornato per avviare il watchdog all'avvio del servizio.
- `llama-stack.service.backup`: backup dell'unit originale.
- Variabili d'ambiente configurabili tramite file `.env` (non versionato) o esportate.

## Installazione
1. Copiare gli script nella directory desiderata (ad esempio `~/.local/bin/` o nella cartella del progetto).
2. Rendere eseguibili gli script:
   ```bash
   chmod +x watchdog.sh notify_telegram.sh
   ```
3. Creare un file `.env` (non versionato) nella stessa directory con le variabili necessarie:
   ```bash
   LLAMA_PROCESS=llama-stack
   METRICS_LOG=/var/log/llama-stack/metrics.log
   VRAM_THRESHOLD=0.95
   MIN_TOK_PER_SEC=1.0
   TELEGRAM_BOT_TOKEN=tuo_token_bot
   TELEGRAM_CHAT_ID=tuo_chat_id
   ```
4. (Opzionale) Sostituire l'unit systemd esistente con quella modificata:
   ```bash
   sudo cp llama-stack.service.modified /etc/systemd/system/llama-stack.service
   sudo systemctl daemon-reload
   sudo systemctl restart llama-stack.service
   ```
   Conservare il backup originale se necessario.

## Uso
### Esecuzione normale
```bash
./watchdog.sh
```
Lo script restituisce:
- `0` se tutti i controlli passano
- `1` in caso di fallimento, stampando il motivo su stderr

### Test manuale della GPU
Per simulare condizioni di alta VRAM e basso token‑rate:
```bash
./watchdog.sh --test
```
In modalità test lo script:
1. Sovrascrive temporaneamente le soglie per forzare un fallimento:
   - `VRAM_THRESHOLD` a `0.0`
   - `MIN_TOK_PER_SEC` a un valore molto alto (es. `1000.0`)
2. Esegue gli stessi controlli di processo, VRAM e token‑per‑secondo
3. Se il fallimento viene rilevato, tenta di inviare la notifica Telegram (se configurata)
4. Restituisce `1` se il test fallisce come previsto, `0` se qualcosa non funziona

> **Nota**: il test richiede che il servizio `llama-stack` sia in esecuzione e che `nvidia-smi` e il log delle metriche siano accessibili.

## Esempi
- Controllo rapido dello stato:
  ```bash
  ./watchdog.sh && echo "Servizio sano" || echo "Servizio non sano"
  ```
- Integrazione in uno script di monitoraggio più ampio:
  ```bash
  if ! ./watchdog.sh; then
      # azioni di ripristino o alert aggiuntivi
      systemctl restart llama-stack.service
  fi
  ```

## Stato
✅ COMPLETATO — 2026-06-11
Tutte le fasi sono state realizzate e testate:
1. Analisi e backup del servizio esistente
2. Script watchdog di base
3. Integrazione watchdog in systemd
4. Script di notifica Telegram
5. README e istruzioni per test manuali GPU