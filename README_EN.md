# image-to-perler

Turn images into editable, portable bead projects.

This independent rewrite uses TypeScript, Vite, and three.js. Its delivery target is a single offline HTML workbench with brand palettes, 3D previews, advanced editing, and a Trae Skill entry point. It requires no account or public backend.

**Initial public version.** Includes image conversion, rectangle/lasso selection, move/fill/delete, palette remapping, undo/redo, 3D grid editing, and a visual melting preview. The main agent reviewed the source and ran automated checks and Chromium offline save/reopen verification. See the [verification record](docs/implementation-review.md) for coverage and limitations.

[中文文档](README.md) · [Contributing](CONTRIBUTING.md) · [Development guide](docs/development.md)

## Build the offline workbench

Install Node.js 24. Run these commands from the repository root:

```bash
npm ci
npm run typecheck
npm test
npm run build
```

Open `dist/index.html` in a browser. Dependency installation needs network access. The delivery requirement is an HTML file with embedded runtime resources, without a development server or CDN. Test the built file offline before release.

Use `npm run dev` for development.

## Save a project

Versioned Project JSON is the persistent format. An HTML file can contain a project snapshot, but it does not replace the project file.

- Cells use global project coordinates. Physical boards define layout and assembly sections.
- `null` means no bead. A white bead is a separate, valid color.
- Color IDs belong to a brand and series. Equal RGB values do not make two IDs equivalent.
- Assembly progress is stored per cell, separately from color edits.

Follow the current interface for editing and exports. Export your project before closing the page. Browser state is not a saved file. The [development guide](docs/development.md) describes the data contract.

## Use the Trae Skill

Place the repository in your project's `.trae/skills/image-to-perler` directory, or the personal skills directory supported by your Trae version. Enable it, provide an image you have permission to use, and specify the size and palette requirements.

[SKILL.md](SKILL.md) defines the agent workflow. The new workbench and Python experiment use different output formats.

## Palettes and physical beads

The repository includes 12 MIT-licensed source palettes (1,315 color entries) from `beadcolors`, with its license notice. These are third-party screen-color data, not manufacturer certification or a guarantee of physical color equivalence.

Redistribution permission for MARD tiers and domestic-brand mappings remains unresolved. These data are excluded from the workbench's built-in palettes. The root `data/` directory contains ignored local research materials and is excluded from the public repository and build. Use an authorized JSON palette for custom data. See [palette provenance and the import format](docs/palette-provenance.md). Compare physical color charts before buying beads and allow for loss.

## Run the Python experiment

The independent converter in `scripts/` is retained for experiments. It is not the build entry point for the new workbench. Pillow produces multiple grid sizes, generic color IDs, CSV files, previews, and an experimental HTML editor. Its `boards.json` is not Project v1.

Install Python 3.10 or later. Run from the repository root:

```bash
python -m pip install -r requirements.txt
python -m scripts.cli input.png output/my-pattern --boards 36,52,78 --default-size 52 --max-colors 16
python -m scripts.cli --help
```

The output directory must not exist. Open `output/my-pattern/output/pattern.html` for the experimental editor. IDs such as `C01` are not native brand codes.

Transparent inputs use alpha to identify empty cells. For opaque inputs, the default removes only near-white areas connected to an edge. This is not general-purpose background removal. Use `--background none` to retain all nontransparent pixels.

## License and examples

Code is under the [MIT License](LICENSE). Third-party palettes retain their license notices. Dependencies, including three.js, have their own licenses. The independent rewrite does not copy the old framework, fonts, or icons.

The [cat example notice](examples/cat/README.md) records the maintainer's permission statement. The original permission source has not been reverified during this rewrite and requires confirmation before release. These Python-generated examples do not establish acceptance of the new workbench.
