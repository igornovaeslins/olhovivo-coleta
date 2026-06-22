#!/usr/bin/env Rscript
# =============================================================================
# 17_olhovivo_velocidade.R — baixa o "mapa de fluidez" (KMZ) do Olho Vivo:
# velocidade média e tempo de percurso REALIZADOS por trecho (cidade / corredor /
# outras vias). Complementa o AVL de posição (R/16). Feito para cron a cada ~30 min
# (a fluidez muda devagar). Tolerante: só loga.
# NOTA: o servidor manda o KMZ com content-encoding não-padrão -> http_content_decoding=0.
# =============================================================================
suppressPackageStartupMessages(library(httr))
REPO <- Sys.getenv("OLHOVIVO_DIR", "/Users/igornovaeslins/consultoria-miis-sp/miis-sp-mobilidade")
DIR  <- file.path(REPO, "data-raw", "olhovivo", "velocidade")
dir.create(DIR, recursive = TRUE, showWarnings = FALSE)
if (file.exists(file.path(REPO, ".Renviron"))) readRenviron(file.path(REPO, ".Renviron"))
TOKEN <- Sys.getenv("SPTRANS_TOKEN")
log_msg <- function(...) cat(format(Sys.time(), "%Y-%m-%dT%H:%M:%S"), "|", ..., "\n")
if (!nzchar(TOKEN)) { log_msg("sem token"); quit(save = "no", status = 0) }

OV <- "https://api.olhovivo.sptrans.com.br/v2.1"
a <- tryCatch(POST(file.path(OV, "Login/Autenticar"), query = list(token = TOKEN), timeout(60)), error = function(e) NULL)
if (is.null(a) || !identical(tolower(trimws(content(a, "text", encoding = "UTF-8"))), "true")) {
  log_msg("auth falhou"); quit(save = "no", status = 0) }
ts <- format(Sys.time(), "%Y%m%dT%H%M%S"); ok <- 0L
for (ep in c("KMZ", "KMZ/Corredor", "KMZ/OutrasVias")) {
  f <- file.path(DIR, sprintf("vel_%s_%s.kmz", gsub("/", "_", ep), ts))
  r <- tryCatch(GET(file.path(OV, ep), config(http_content_decoding = 0L),
                    write_disk(f, overwrite = TRUE), timeout(180)), error = function(e) NULL)
  if (!is.null(r) && status_code(r) == 200 && file.exists(f) && file.info(f)$size > 0) {
    ok <- ok + 1L; log_msg(sprintf("OK %s (%d bytes)", basename(f), file.info(f)$size))
  } else log_msg(sprintf("FALHOU %s (HTTP %s)", ep, if (is.null(r)) "NA" else status_code(r)))
}
log_msg(sprintf("velocidade: %d/3 KMZ salvos", ok))
