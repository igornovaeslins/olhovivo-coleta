# olhovivo-coleta

Coleta automatizada do AVL (*Automatic Vehicle Location*) do transporte público de
São Paulo via API **Olho Vivo / SPTrans**: posição dos ônibus a cada ~1 min e o mapa
de fluidez (velocidade média por trecho, KMZ) a cada ~30 min.

Roda sozinho no **GitHub Actions**, sem servidor próprio e sem depender de um computador
ligado: a cada 5 min um job coleta em loop de 1 min e commita os snapshots em
`data-raw/olhovivo/`.

## Estrutura
- `R/16_olhovivo_coleta.R` — um snapshot de posição (CSV.gz).
- `R/17_olhovivo_velocidade.R` — KMZ de velocidade média por trecho.
- `.github/workflows/coleta.yml` — agenda (cron `*/5`), loop de 1 min, e alerta.
- `data-raw/olhovivo/` — a série coletada.

## Token
A coleta autentica na API com `SPTRANS_TOKEN`, lido do ambiente. No GitHub Actions ele
vem de um *secret* cifrado (`Settings → Secrets and variables → Actions`); localmente, de
um `.Renviron` não versionado.

## Alerta
Se um ciclo coleta nada (token expirado / API fora) ou o workflow falha, um aviso é
publicado num tópico **ntfy** (`NTFY_TOPIC`, também em secret).

---
Elaboração: **Igor Novaes Lins**.
