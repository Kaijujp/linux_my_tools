# linux_my_tools

# compact2md

Converte arquivos compactados em documentação Markdown — direto do terminal.

Script em Bash puro que recebe um `.zip`, `.tar.gz`, `.tar.bz2`, `.tar.xz`,
`.7z` ou `.rar` e gera um `.md` com a estrutura de diretórios, tabela de
arquivos e o conteúdo dos arquivos de texto já com *syntax highlight*.

## Instalação

```bash
git clone https://github.com/<usuario>/compact2md.git
cd compact2md
install -Dm755 compact2md ~/.local/bin/compact2md
```

Garanta que `~/.local/bin` está no seu `PATH`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Uso

```bash
compact2md projeto.zip                    # gera projeto.md ao lado do arquivo
compact2md backup.tar.gz -o docs/bkp.md   # escolhe saída
compact2md pacote.zip --no-content        # só estrutura, sem conteúdo
compact2md src.tar.gz --max-bytes 200000  # limite maior por arquivo
compact2md pacote.zip --stdout | less     # direto no terminal
```

## O que é gerado

O Markdown produzido tem cinco seções:

1. **Cabeçalho** — nome, caminho e data de geração.
2. **Resumo** — contagem de arquivos, diretórios e tamanho descompactado.
3. **Estrutura** — árvore visual (`├──`/`└──`).
4. **Arquivos** — tabela com caminho, tamanho e tipo (texto/binário).
5. **Conteúdos** — cada arquivo de texto em bloco de código com
   *syntax highlight*.

Arquivos binários e arquivos acima do limite são omitidos automaticamente,
com aviso em bloco de citação.

## Requisitos

Ferramentas do pacote base de qualquer Debian/MX Linux:

`tar`, `gzip`, `bzip2`, `xz`, `unzip`, `file`, `find`, `awk`, `sed`, `stat`, `mktemp`.

Opcionais: `p7zip-full` (para `.7z`), `unrar-free` (para `.rar`).

## Licença

MIT
