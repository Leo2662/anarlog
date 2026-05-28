# Anarlog Portable Windows Builder

This repository builds a **portable Windows executable** of [Anarlog](https://github.com/fastrepl/anarlog), an open-source Tauri desktop application, directly from source.

The result is a ZIP file containing the compiled `.exe` — no installer required.

## How it works

1. Clones the upstream [fastrepl/anarlog](https://github.com/fastrepl/anarlog) repository.
2. Installs Node.js, pnpm, and Rust.
3. Builds the application with `pnpm -F @hypr/desktop tauri build -- --no-bundle`.
4. Locates the compiled `.exe` (the binary name varies due to upstream rename history — see below).
5. Packages it into `anarlog-windows-portable-x64.zip` with a README.

## Triggering a build

Go to the **Actions** tab of this repository and select the **Build Windows Portable** workflow. Click **Run workflow**.

You can optionally provide a `release_tag` input (e.g., `v1.0.0`) to create a GitHub Release and attach the ZIP.

## Downloading the artifact

After the workflow completes, the ZIP is uploaded as a workflow artifact named `anarlog-windows-portable-x64`. You can download it from the workflow run page.

If a `release_tag` was provided, the ZIP is also attached to the corresponding GitHub Release.

## Known limitations

- A raw Tauri `.exe` requires **Microsoft Edge WebView2 Runtime** on the target machine. Most Windows 11 systems have this pre-installed. On older systems, download it from: https://developer.microsoft.com/en-us/microsoft-edge/webview2/
- The portable build skips the Tauri bundling step (`--no-bundle`), so no MSI/NSIS installer is generated. This means sidecar resources (e.g., bundled fonts) may not be included.
- This repository does **not** modify the Anarlog source code unless patches are explicitly added.

## Binary name detection

Anarlog has been renamed multiple times during development (hyprnote → anarlog/char). The `mainBinaryName` in `tauri.conf.json` may still reference older names. The build workflow automatically searches for the compiled `.exe` rather than hardcoding a name.
