# casa/ — a linha do Luciano em cima do FineTune (GPL-3)

Fork rastreando o upstream (`ronitsingh10/FineTune`) com nossos patches empilhados na branch **`casa`**.
Não é hard fork: cada versão nova do mantenedor entra por rebase; nossos commits ficam por cima.

- `atualizar.sh` — fetch upstream + rebase + build + instalar (1 comando, ~1-2 min). `--so-build` pula o rebase.
- `build-sem-xcode.sh <clone> <saída>` — compila só com Command Line Tools e monta o `.app` (o repo só tem
  `.xcodeproj`; `../Package.swift` espelha as build settings; `strip-previews.py` tira `#Preview`).
- `harness-popover/` — teste de regressão do `PopoverHost` (4 cenários / 14 checks):
  `cd casa/harness-popover && cp ../../FineTune/Views/Components/PopoverHost.swift . && swiftc -O -target arm64-apple-macosx15.4 -swift-version 6 -o harness main.swift PopoverHost.swift && ./harness`

Patches na pilha (ver `git log upstream/main..casa`):
1. `fix(PopoverHost): keep dropdown panels on screen` — PR upstream #446 (se entrar, `git rebase` some com ele sozinho).
2. `casa: build sem Xcode + ferramentas` — este diretório + `Package.swift`.

Regras: não copiar código de outros forks GPL sem manter a licença; patch novo = commit próprio em cima de `casa`
+ rodar o harness quando tocar em posicionamento; `git push origin casa` depois de cada mudança (o fork é o backup).
