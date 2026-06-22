#!/usr/bin/env Rscript
# =============================================================================
# 16_olhovivo_coleta.R — coleta UM snapshot da posição do Olho Vivo (SPTrans).
# Feito para AGENDAMENTO (cron) a cada ~1 min: acumula a série de AVL realizado
# (velocidade/headway realizados). Enxuto e TOLERANTE: nunca aborta nem gera
# pendência; só loga e segue. Lê SPTRANS_TOKEN do ambiente (no GitHub Actions,
# de um secret cifrado; localmente, de um .Renviron não versionado).
# =============================================================================
suppressPackageStartupMessages({ library(httr); library(jsonlite); library(data.table) })
REPO <- Sys.getenv("OLHOVIVO_DIR", "/Users/igornovaeslins/consultoria-miis-sp/miis-sp-mobilidade")
DIR  <- file.path(REPO, "data-raw", "olhovivo")
dir.create(DIR, recursive = TRUE, showWarnings = FALSE)
if (file.exists(file.path(REPO, ".Renviron"))) readRenviron(file.path(REPO, ".Renviron"))
TOKEN <- Sys.getenv("SPTRANS_TOKEN")
log_msg <- function(...) cat(format(Sys.time(), "%Y-%m-%dT%H:%M:%S"), "|", ..., "\n")
if (!nzchar(TOKEN)) { log_msg("SEM SPTRANS_TOKEN — coleta nao iniciada"); quit(save = "no", status = 0) }

OV <- "https://api.olhovivo.sptrans.com.br/v2.1"
auth <- tryCatch(POST(file.path(OV, "Login/Autenticar"), query = list(token = TOKEN), timeout(60)),
                 error = function(e) NULL)
if (is.null(auth) || !identical(tolower(trimws(content(auth, "text", encoding = "UTF-8"))), "true")) {
  log_msg("AUTH falhou (token invalido/expirado ou API fora)"); quit(save = "no", status = 0) }
r <- tryCatch(GET(file.path(OV, "Posicao"), timeout(90)), error = function(e) NULL)
if (is.null(r) || status_code(r) != 200) {
  log_msg("Posicao HTTP", if (is.null(r)) "NA" else status_code(r)); quit(save = "no", status = 0) }
pos <- tryCatch(fromJSON(content(r, "text", encoding = "UTF-8"), simplifyVector = FALSE),
                error = function(e) NULL)
if (is.null(pos) || is.null(pos$l)) { log_msg("JSON vazio/invalido"); quit(save = "no", status = 0) }

ts <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S"); rows <- list()
for (L in pos$l) {
  if (length(L$vs) == 0) next
  for (v in L$vs) rows[[length(rows) + 1L]] <- list(
    ts_coleta = ts, hr_api = pos$hr, cod_linha = L$cl, letreiro = L$c, sentido = L$sl,
    prefixo = v$p, acessivel = v$a, ts_veiculo = v$ta, lat = v$py, lon = v$px)
}
if (!length(rows)) { log_msg("snapshot sem veiculos"); quit(save = "no", status = 0) }
df <- data.table::rbindlist(rows, fill = TRUE)
f <- file.path(DIR, sprintf("posicao_%s.csv.gz", format(Sys.time(), "%Y%m%dT%H%M%S")))
data.table::fwrite(df, f)
log_msg(sprintf("OK %s -> %d veiculos", basename(f), nrow(df)))
