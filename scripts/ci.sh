#!/bin/sh
# Executa os comandos de verificação configurados em docs/PROCESSO.md (Configuração, bloco comandos).
#
# Uso: sh scripts/ci.sh [chave ...]
#   Sem argumento: roda todas as chaves configuradas, na ordem lint, typecheck, test, integracao, build, smoke.
#                  Valor vazio ou com placeholder (<!--) é pulado.
#   Com argumentos: roda só as chaves informadas, na ordem acima. Chave pedida e não configurada é erro,
#                  para que um job nunca passe sem verificar nada.
#
# e2e não entra: os casos E2E rodam antes da PR, nos casos que o ticket ativa (ver docs/PROCESSO.md).
# Sai com código diferente de zero se algum comando falhar, se uma chave pedida não estiver configurada,
# ou se nenhum comando for executado.
set -u

PROCESSO="${CI_PROCESSO:-docs/PROCESSO.md}"
CHAVES="lint typecheck test integracao build smoke"

if [ ! -f "$PROCESSO" ]; then
  echo "ERRO: $PROCESSO não encontrado" >&2
  exit 1
fi

# Imprime chave<TAB>valor do bloco comandos (primeiro bloco yaml da Configuração).
extrair_comandos() {
  awk '
    /^```yaml/ { em_yaml = 1; next }
    /^```/ && em_yaml { em_yaml = 0; em_comandos = 0; next }
    em_yaml && /^comandos:/ { em_comandos = 1; next }
    em_yaml && em_comandos && /^[^ #]/ { em_comandos = 0 }
    em_yaml && em_comandos && /^  [A-Za-z_]+:/ {
      linha = $0
      sub(/^  /, "", linha)
      chave = linha
      sub(/:.*/, "", chave)
      valor = linha
      sub(/^[^:]*:[ \t]*/, "", valor)
      sub(/[ \t]+#.*$/, "", valor)
      print chave "\t" valor
    }
  ' "$PROCESSO"
}

# Monta a lista de chaves a rodar, na ordem fixa de CHAVES.
selecionadas=""
if [ "$#" -eq 0 ]; then
  selecionadas="$CHAVES"
else
  for pedida in "$@"; do
    case " $CHAVES " in
      *" $pedida "*) ;;
      *)
        echo "ERRO: chave desconhecida: $pedida (válidas: $CHAVES)" >&2
        exit 1
        ;;
    esac
  done
  # Cada chave entra uma vez, mesmo que seja pedida mais de uma vez (ex.: lint lint).
  for chave in $CHAVES; do
    for pedida in "$@"; do
      if [ "$pedida" = "$chave" ]; then
        selecionadas="$selecionadas $chave"
        break
      fi
    done
  done
fi

comandos=$(extrair_comandos)
executados=0
falhas=0

for chave in $selecionadas; do
  valor=$(printf '%s\n' "$comandos" | awk -F '\t' -v k="$chave" '$1 == k { print $2; exit }')
  case "$valor" in
    ""|"<!--"*|pendente)
      if [ "$#" -eq 0 ]; then
        echo "PULADO $chave: sem comando configurado"
        continue
      fi
      echo "ERRO: $chave foi pedida, mas não tem comando configurado em $PROCESSO" >&2
      falhas=$((falhas + 1))
      continue
      ;;
  esac
  executados=$((executados + 1))
  echo "==> $chave: $valor"
  if ! sh -c "$valor"; then
    echo "FALHOU $chave" >&2
    falhas=$((falhas + 1))
  fi
done

if [ "$falhas" -gt 0 ]; then
  echo "ERRO: $falhas comando(s) falharam ou não estão configurados" >&2
  exit 1
fi

if [ "$executados" -eq 0 ]; then
  echo "ERRO: nenhum comando de verificação configurado em $PROCESSO" >&2
  exit 1
fi

echo "OK: $executados comando(s) executados sem falha"
