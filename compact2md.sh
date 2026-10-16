#!/usr/bin/env bash
#
# compact2md — Converte arquivos compactados em documentação Markdown.
#
# Uso:
#   compact2md arquivo.zip
#   compact2md arquivo.tar.gz -o saida.md
#   compact2md pacote.zip --no-content
#   compact2md pacote.zip --stdout | less
#
# Formatos: .zip .tar .tar.gz .tgz .tar.bz2 .tbz2 .tar.xz .txz .7z .rar
#
set -euo pipefail

PROG="$(basename "$0")"
VERSION="1.0"

# ----------------------------- Configuração ------------------------------- #

OUTPUT=""
INCLUDE_CONTENT=1
MAX_BYTES=50000
TO_STDOUT=0

# ------------------------------- Ajuda ------------------------------------ #

usage() {
    cat <<EOF
Uso: $PROG [opções] <arquivo-compactado>

Converte arquivos compactados em Markdown.

Formatos: .zip .tar .tar.gz .tgz .tar.bz2 .tbz2 .tar.xz .txz .7z .rar

Opções:
  -o, --output ARQ    Arquivo Markdown de saída (padrão: <nome>.md)
      --no-content    Não incluir o conteúdo dos arquivos
      --max-bytes N   Tamanho máximo em bytes para embutir conteúdo (padrão: $MAX_BYTES)
      --stdout        Escrever o Markdown na saída padrão
  -h, --help          Mostrar esta ajuda
  -V, --version       Mostrar a versão
EOF
}

# --------------------------- Parse de argumentos -------------------------- #

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)    OUTPUT="$2"; shift 2 ;;
        --no-content)   INCLUDE_CONTENT=0; shift ;;
        --max-bytes)    MAX_BYTES="$2"; shift 2 ;;
        --stdout)       TO_STDOUT=1; shift ;;
        -h|--help)      usage; exit 0 ;;
        -V|--version)   echo "$PROG $VERSION"; exit 0 ;;
        --)             shift; break ;;
        -*)             echo "Opção desconhecida: $1" >&2; usage >&2; exit 1 ;;
        *)              break ;;
    esac
done

if [[ $# -lt 1 ]]; then
    usage >&2
    exit 1
fi

ARCHIVE="$1"

if [[ ! -f "$ARCHIVE" ]]; then
    echo "Erro: arquivo não encontrado: $ARCHIVE" >&2
    exit 1
fi

# --------------------------- Diretório temporário ------------------------- #

TMPDIR="$(mktemp -d -t compact2md.XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

EXTRACT_DIR="$TMPDIR/extract"
mkdir -p "$EXTRACT_DIR"

# ------------------------------ Extração ---------------------------------- #

extract_archive() {
    local arc="$1" dest="$2"
    local lname="${arc,,}"
    case "$lname" in
        *.zip)
            command -v unzip >/dev/null || { echo "Instale 'unzip'." >&2; return 1; }
            unzip -qq -o "$arc" -d "$dest"
            ;;
        *.tar.gz|*.tgz)  tar -xzf "$arc" -C "$dest" ;;
        *.tar.bz2|*.tbz2) tar -xjf "$arc" -C "$dest" ;;
        *.tar.xz|*.txz)  tar -xJf "$arc" -C "$dest" ;;
        *.tar)           tar -xf  "$arc" -C "$dest" ;;
        *.7z)
            command -v 7z >/dev/null || { echo "Instale 'p7zip-full'." >&2; return 1; }
            7z x -y -o"$dest" "$arc" >/dev/null
            ;;
        *.rar)
            command -v unrar >/dev/null || { echo "Instale 'unrar-free'." >&2; return 1; }
            unrar x -o+ "$arc" "$dest/" >/dev/null
            ;;
        *)
            echo "Formato não suportado: $arc" >&2
            return 1
            ;;
    esac
}

echo "→ Extraindo $ARCHIVE ..." >&2
if ! extract_archive "$ARCHIVE" "$EXTRACT_DIR"; then
    echo "Erro ao extrair $ARCHIVE" >&2
    exit 2
fi

# ------------------------------ Utilidades -------------------------------- #

human_size() {
    awk -v n="$1" 'BEGIN {
        split("B KB MB GB TB", u, " ");
        i = 1;
        while (n >= 1024 && i < 5) { n /= 1024; i++ }
        if (i == 1) printf "%d %s", n, u[i];
        else        printf "%.1f %s", n, u[i];
    }'
}

is_text_file() {
    local f="$1"
    local out
    out="$(file -b "$f" 2>/dev/null || echo "")"
    case "$out" in
        *text*|*ASCII*|*UTF-8*|*Unicode*|*JSON*|*XML*) return 0 ;;
    esac
    # fallback por extensão
    local base; base="$(basename "$f")"
    local ext="${f##*.}"; ext="${ext,,}"
    case "$base" in
        Dockerfile|Makefile|README|LICENSE|.gitignore) return 0 ;;
    esac
    case "$ext" in
        txt|md|markdown|rst|log|py|js|ts|jsx|tsx|java|kt|c|h|cpp|hpp|\
        cs|go|rs|rb|php|sh|bash|zsh|ps1|bat|html|htm|css|scss|less|\
        json|yaml|yml|toml|ini|cfg|conf|env|xml|csv|tsv|sql) return 0 ;;
    esac
    return 1
}

detect_lang() {
    local f="$1"
    local base; base="$(basename "$f")"
    local ext="${f##*.}"; ext="${ext,,}"
    case "$base" in
        Dockerfile) echo "dockerfile"; return ;;
        Makefile)   echo "makefile";   return ;;
    esac
    case "$ext" in
        py)         echo python ;;
        js)         echo javascript ;;
        ts)         echo typescript ;;
        jsx)        echo jsx ;;
        tsx)        echo tsx ;;
        java)       echo java ;;
        kt)         echo kotlin ;;
        c|h)        echo c ;;
        cpp|hpp|cc) echo cpp ;;
        cs)         echo csharp ;;
        go)         echo go ;;
        rs)         echo rust ;;
        rb)         echo ruby ;;
        php)        echo php ;;
        sh|bash|zsh)echo bash ;;
        ps1)        echo powershell ;;
        bat)        echo batch ;;
        html|htm)   echo html ;;
        css)        echo css ;;
        scss)       echo scss ;;
        less)       echo less ;;
        json)       echo json ;;
        yaml|yml)   echo yaml ;;
        toml)       echo toml ;;
        ini|cfg|conf) echo ini ;;
        xml)        echo xml ;;
        csv)        echo csv ;;
        tsv)        echo tsv ;;
        sql)        echo sql ;;
        md|markdown)echo markdown ;;
        rst)        echo rst ;;
        *)          echo "" ;;
    esac
}

escape_md_cell() {
    local s="$1"
    s="${s//|/\\|}"
    printf '%s' "$s"
}

# Árvore visual usando find + recursão
print_tree() {
    local dir="$1" prefix="$2"
    local find_root="${dir:-.}"
    local entries=()
    while IFS= read -r -d '' e; do
        entries+=("$e")
    done < <(find "$find_root" -mindepth 1 -maxdepth 1 -print0 2>/dev/null | sort -z)

    local dirs=() files=()
    local e
    for e in "${entries[@]}"; do
        [[ -d "$e" ]] && dirs+=("$e") || files+=("$e")
    done

    local all=("${dirs[@]}" "${files[@]}")
    local count=${#all[@]}
    local i=0
    for e in "${all[@]}"; do
        i=$((i+1))
        local base; base="$(basename "$e")"
        local conn newpref
        if (( i == count )); then
            conn="└── "
            newpref="${prefix}    "
        else
            conn="├── "
            newpref="${prefix}│   "
        fi
        if [[ -d "$e" ]]; then
            printf '%s%s%s/\n' "$prefix" "$conn" "$base"
            print_tree "$e" "$newpref"
        else
            printf '%s%s%s\n' "$prefix" "$conn" "$base"
        fi
    done
}

# ------------------------- Estatísticas do pacote ------------------------- #

cd "$EXTRACT_DIR"

total_files=0
total_dirs=0
total_size=0
while IFS= read -r -d '' f; do
    if [[ -d "$f" ]]; then
        total_dirs=$((total_dirs + 1))
    elif [[ -f "$f" ]]; then
        total_files=$((total_files + 1))
        sz=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
        total_size=$((total_size + sz))
    fi
done < <(find . -print0)

# remove o próprio "./" da contagem de diretórios
total_dirs=$((total_dirs > 0 ? total_dirs - 1 : 0))

# ------------------------- Saída Markdown --------------------------------- #

MD_FILE="$TMPDIR/output.md"
ARC_BASENAME="$(basename "$ARCHIVE")"
NOW="$(date '+%Y-%m-%d %H:%M:%S')"
ARC_ABS="$(readlink -f "$ARCHIVE")"

{
    echo "# Conteúdo de \`$ARC_BASENAME\`"
    echo
    echo "> Gerado em $NOW  "
    echo "> Arquivo: \`$ARC_ABS\`"
    echo

    echo "## Resumo"
    echo
    echo "- **Arquivos:** $total_files"
    echo "- **Diretórios:** $total_dirs"
    echo "- **Tamanho descompactado:** $(human_size "$total_size")"
    echo

    echo "## Estrutura"
    echo
    echo '```'
    echo "$ARC_BASENAME/"
    print_tree "" ""
    echo '```'
    echo

    echo "## Arquivos"
    echo
    echo "| Caminho | Tamanho | Tipo |"
    echo "|---------|---------|------|"

    while IFS= read -r -d '' f; do
        [[ -f "$f" ]] || continue
        rel="${f#./}"
        sz=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
        if is_text_file "$f"; then
            tipo="texto"
        else
            tipo="binário"
        fi
        printf '| `%s` | %s | %s |\n' \
            "$(escape_md_cell "$rel")" \
            "$(human_size "$sz")" \
            "$tipo"
    done < <(find . -type f -print0 | sort -z)
    echo

    # -------- Conteúdos --------
    if (( INCLUDE_CONTENT == 1 )); then
        echo "## Conteúdos"
        echo

        while IFS= read -r -d '' f; do
            [[ -f "$f" ]] || continue
            rel="${f#./}"
            sz=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
            mtime=$(stat -c '%y' "$f" 2>/dev/null | cut -d. -f1 || echo "N/A")

            echo "### \`$rel\`"
            echo
            echo "*$(human_size "$sz")* — modificado em $mtime"
            echo

            if ! is_text_file "$f"; then
                echo "> _Conteúdo binário omitido._"
                echo
                continue
            fi

            if (( sz > MAX_BYTES )); then
                echo "> _Arquivo maior que $(human_size "$MAX_BYTES"); conteúdo omitido._"
                echo
                continue
            fi

            # escolhe fence para não colidir
            fence='```'
            if grep -q '```' "$f" 2>/dev/null; then
                fence='````'
            fi

            lang="$(detect_lang "$f")"
            echo "${fence}${lang}"
            # remove newlines finais
            content="$(cat "$f")"
            printf '%s\n' "$content"
            echo "$fence"
            echo
        done < <(find . -type f -print0 | sort -z)
    fi
} > "$MD_FILE"

# ------------------------------- Saída final ------------------------------ #

if (( TO_STDOUT == 1 )); then
    cat "$MD_FILE"
else
    if [[ -z "$OUTPUT" ]]; then
        # nome padrão: remove extensões do compactado
        name="$(basename "$ARCHIVE")"
        name="${name%.*}"            # remove última extensão
        case "$name" in
            *.tar|*.TAR) name="${name%.*}" ;;   # tar.gz -> tar -> remove
        esac
        OUTPUT="$(dirname "$ARCHIVE")/${name}.md"
    fi
    cp "$MD_FILE" "$OUTPUT"
    echo "✔ Markdown gerado: $OUTPUT"
    echo "  $total_files arquivos, $(human_size "$total_size") descompactados"
fi
