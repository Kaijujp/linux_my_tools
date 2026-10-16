# Manual do Desenvolvedor — compact2md

Documento interno com decisões de projeto, arquitetura e pontos de extensão.

## Filosofia

- **Zero dependências exóticas.** Só ferramentas do pacote base Debian/MX Linux.
- **Um arquivo, executável direto.** Sem build, sem instalação de runtime.
- **Fail-safe.** Sempre limpa o temporário, mesmo interrompido (`trap`).
- **Saída idempotente.** Mesma entrada → mesmo Markdown (exceto timestamp).

## Fluxo de execução

```
parse args → valida entrada → mktemp -d → extrai → percorre → gera MD → escreve saída
```

Toda a lógica vive dentro de `main` implícito (script linear), mas as funções
puras estão isoladas por responsabilidade:

| Função              | Responsabilidade |
|---------------------|------------------|
| `extract_archive`   | Detecta formato e extrai para o tmpdir |
| `human_size`        | Formata bytes legíveis (awk) |
| `is_text_file`      | Heurística `file -b` + fallback por extensão |
| `detect_lang`       | Mapeia extensão → linguagem do highlight |
| `escape_md_cell`    | Escapa `\|` em tabelas markdown |
| `print_tree`        | Recursão para árvore visual |
| `usage`             | Texto de ajuda |

## Decisões notáveis

- **Extração para tmpdir, não em memória.** Simplifica suporte a todos os
  formatos e permite usar `find`, `stat` e `file` diretamente.
- **`set -euo pipefail`** no topo. Qualquer falha silenciosa vira erro.
- **`trap ... EXIT`** para limpar `mktemp -d` mesmo em `Ctrl+C`.
- **Fence adaptativo.** Se o arquivo contém ` ``` `, usamos ` ```` ` para o
  bloco — evita corromper o markdown.
- **Detecção de texto em duas camadas.** `file -b` primeiro, extensão como
  fallback (por causa de arquivos sem MIME claro como `Makefile`).
- **Contagem de diretórios** desconta o `./` raiz do `find`.
- **Escrita atômica.** Todo o Markdown é montado em `$TMPDIR/output.md` e só
  depois copiado para o destino.

## Como estender

### Adicionar um novo formato

1. Acrescente o padrão em `extract_archive` (case) **e** em `usage()`.
2. Se o extrator não for do pacote base, cheque com `command -v` e devolva
   erro amigável com sugestão de pacote.

### Adicionar uma nova linguagem no highlight

Edite o `case` de `detect_lang`. Mantenha o identificador em minúsculas,
conforme o padrão do Prism/Highlight.js.

### Adicionar um filtro de arquivos

Sugestão de implementação: acumular padrões `--include`/`--exclude` num
array e aplicá-los dentro dos dois `while ... find -print0`. Como `find` já
suporta `-path`, o mais barato é passar os padrões direto para o `find`.

### Modo diff entre dois compactados

Ideia: extrair cada um em `$TMPDIR/a` e `$TMPDIR/b`, rodar `diff -rq`, e
gerar um Markdown com três seções (adicionados / removidos / modificados),
embutindo o `diff -u` de cada arquivo alterado.

## Convenções de código

- `[[ ... ]]` em vez de `[ ... ]`.
- Sempre `local` dentro de funções.
- `printf` em vez de `echo` quando há formatação.
- `while IFS= read -r -d ''` para iterar sobre `find -print0` — nomes com
  espaço, newline ou unicode são suportados.
- Nada de `eval`, `$*`, ou expansões sem quotes.

## Testes manuais

Antes de abrir PR, verifique:

```bash
# 1. Arquivo com espaço e acento no nome
compact2md "meu projeto.zip"

# 2. Tarball com subdiretórios profundos
compact2md src.tar.gz --stdout | head -50

# 3. Binário puro (deve marcar "binário" e omitir conteúdo)
compact2md imagens.zip --no-content

# 4. Arquivo grande (deve avisar e pular)
compact2md logs.tar.gz --max-bytes 100

# 5. Interromper no meio (Ctrl+C) e conferir que /tmp está limpo
ls /tmp | grep compact2md
```

## Roadmap

- [ ] `--include` / `--exclude` com globs
- [ ] Modo `--diff <outro.zip>`
- [ ] Sumário com links âncora no topo do Markdown
- [ ] Saída HTML opcional
- [ ] Testes automatizados com `bats`

## Licença

MIT — veja `LICENSE`.
