# Retour d'expérience : Build portable Windows d'Anarlog

Ce document capitalise les problèmes rencontrés et les solutions apportées pour compiler Anarlog (application Tauri) en binaire Windows portable via GitHub Actions.

---

## Architecture du projet

Anarlog est un monorepo pnpm avec Turborepo. La structure clé :

```
anarlog/
├── apps/desktop/          # Application Tauri (React + Rust)
│   ├── src-tauri/         # Backend Rust (tauri.conf.json, Cargo.toml)
│   └── package.json       # @hypr/desktop
├── packages/ui/           # Composants React + Tailwind CSS (génère dist/globals.css)
├── packages/*             # Bibliothèques partagées
├── plugins/*              # Plugins Tauri (analytics, todo, calendar, misc, local-stt…)
├── pnpm-workspace.yaml
├── turbo.json
└── Cargo.toml             # Workspace Rust racine
```

Build commande cible : `pnpm -F @hypr/desktop tauri build -- --no-bundle`

---

## Problèmes rencontrés et solutions

### 1. Dépendance workspace `@hypr/ui` non construite

**Erreur :**
```
[vite]: Rolldown failed to resolve import "@hypr/ui/globals.css"
```

**Cause :** Le CSS est généré par Tailwind via le script `build` de `@hypr/ui` :
```json
"build": "tailwindcss -i ./src/styles/globals.css -o ./dist/globals.css --minify"
```
Le fichier `dist/globals.css` n'existe pas tant que `build` n'a pas été exécuté. Or la commande `beforeBuildCommand` de Tauri (`pnpm -F desktop build`) ne compile que `@hypr/desktop`, pas ses dépendances.

**Solution :** Ajouter une étape de build des dépendances avant Tauri :
```yaml
- name: Build workspace dependencies
  run: pnpm exec turbo build --filter=@hypr/desktop^...
```
Le `^...` signifie « dépendances uniquement », pas le package lui-même. Turbo gère automatiquement l'ordre et ignore les packages sans script `build`.

---

### 2. Variables d'environnement Rust manquantes (`env!()`)

**Erreurs successives :**
```
error: environment variable `POSTHOG_API_KEY` not defined at compile time  (plugins/analytics/src/lib.rs)
error: environment variable `VITE_API_URL` not defined at compile time     (plugins/todo/src/lib.rs, plugins/calendar/src/lib.rs)
error: environment variable `AM_API_KEY` not defined at compile time       (plugins/local-stt/src/lib.rs)
error: environment variable `VERGEN_GIT_SHA` not defined at compile time  (plugins/misc/src/ext.rs)
```

**Cause :** Plusieurs plugins Tauri utilisent la macro Rust `env!("NOM_VAR")` qui exige que la variable soit définie **à la compilation** (pas à l'exécution). Ces variables n'ont pas de valeur par défaut dans le code source.

**Solution :** Définir toutes les variables d'environnement dans l'étape de build :
```yaml
env:
  POSTHOG_API_KEY: placeholder
  VITE_API_URL: http://localhost:3001
  AM_API_KEY: placeholder
  VERGEN_GIT_SHA: unknown
```

Note : `option_env!("SENTRY_DSN)` existe aussi mais est déjà géré avec `Option`, donc pas bloquant.

---

### 3. Conflit de symboles SQLite au link (MSVC)

**Erreur :**
```
liblibsqlite3_sys-...rlib : error LNK2005: sqlite3_win32_set_directory already defined
fatal error LNK1169: one or more multiply defined symbols found
```

**Cause :** Deux crates Rust (`libsqlite3-sys` et `libsql_ffi`) intègrent toutes deux SQLite en statique. Sur Linux/macOS, le linker GNU tolère les symboles dupliqués. Sur Windows MSVC, c'est une erreur fatale.

**Solution :** Ajouter le flag MSVC `/FORCE:MULTIPLE` qui autorise les définitions multiples (la première est utilisée) :
```yaml
env:
  RUSTFLAGS: -C target-feature=-crt-static -C link-args=/FORCE:MULTIPLE
```

Note : `-C target-feature=-crt-static` est repris du `.cargo/config.toml` du projet. Il faut le répéter car `RUSTFLAGS` en variable d'environnement **écrase** la config.

---

### 4. Crash silencieux au lancement (console invisible)

**Constats :**
- L'`.exe` se lance mais aucune fenêtre n'apparaît
- Aucun processus visible dans le gestionnaire de tâches
- Aucune entrée dans l'Observateur d'événements Windows

**Cause :** `main.rs` contient :
```rust
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
```
En mode release, la console Windows est supprimée. stdout/stderr sont perdus. Tout `panic!()` ou `.unwrap()` est invisible.

**Solution :** Produire un binaire **debug** (console visible) en plus du binaire release :
```yaml
- name: Build debug binary (console visible)
  working-directory: anarlog/apps/desktop/src-tauri
  run: cargo build
```
Le binaire debug (`target/debug/desktop.exe`) garde la console et affiche l'erreur exacte.

---

## Checklist pour le diagnostic d'un crash

1. Lancer `Anarlog-debug.exe` depuis cmd.exe → la console montre l'erreur
2. Si pas assez d'infos : `set RUST_BACKTRACE=1 && Anarlog-debug.exe`
3. Vérifier le Gestionnaire de tâches après lancement : le processus reste-t-il ?
4. Vérifier l'Observateur d'événements Windows : journaux Application
5. Vérifier les DLL manquantes : [Dependency Walker](https://dependencywalker.com/) ou [Dependencies](https://github.com/lucasg/Dependencies)

---

## Variables d'environnement Rust : tableau récapitulatif

| Variable | Usage | Plugin/Fichier |
|----------|-------|----------------|
| `POSTHOG_API_KEY` | `env!()` | `plugins/analytics/src/lib.rs` |
| `VITE_API_URL` | `env!()` | `plugins/todo/src/lib.rs`, `plugins/calendar/src/lib.rs` |
| `AM_API_KEY` | `env!()` | `plugins/local-stt/src/lib.rs` |
| `VERGEN_GIT_SHA` | `env!()` | `plugins/misc/src/ext.rs` |
| `SENTRY_DSN` | `option_env!()` | `apps/desktop/src-tauri/src/lib.rs` (optionnel) |

---

## Améliorations possibles

- **Publier un release automatique** : le workflow accepte déjà `release_tag` en entrée pour créer une GitHub Release
- **Signer le binaire** : ajouter une étape de signature Authenticode (nécessite un certificat)
- **Inclure les ressources** : le flag `--no-bundle` saute la copie des polices et icônes (définies dans `bundle.resources`). Pour les inclure, supprimer `--no-bundle` et archiver le dossier de bundle.
- **Build cross-platform** : étendre le workflow à macOS et Linux en utilisant `matrix.os`
- **Cibler la config stable** : pour produire un binaire nommé `anarlog.exe` (au lieu de `anarlog-dev.exe`), utiliser la config `tauri.conf.stable.json` via `--config`

---

## Commandes utiles pour le debug local

```bash
# Build release
pnpm -F @hypr/desktop tauri build -- --no-bundle

# Build debug (console visible)
cd apps/desktop/src-tauri && cargo build

# Build des dépendances workspace uniquement
pnpm exec turbo build --filter=@hypr/desktop^...

# Lister tous les packages disponibles
pnpm -r list --depth -1

# Voir les dépendances d'un package
pnpm ls -r --depth 0
```
