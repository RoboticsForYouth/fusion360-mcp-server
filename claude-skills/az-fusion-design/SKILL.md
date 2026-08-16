---
name: az-fusion-design
description: Build FTC robot designs in Fusion 360 via the fusion360 MCP using Absolute Zero's part libraries (LayerOne DECODE kit, AZ Printed Telescope, Offset slide references). Use when designing, importing, or modifying CAD parts for team 12096's BIOBUZZ robots.
---

# AZ Fusion Design — using the team part libraries via the fusion360 MCP

You are driving Fusion 360 through the fusion360 MCP (RoboticsForYouth hardened fork). Follow these conventions — they encode a week of live-tested lessons.

## Part libraries (where everything lives)

| Library | Location | Contents |
|---|---|---|
| **LayerOne (DECODE starter bot, CM Robotics)** | `~/Downloads/231513_LayerOne_Recources/STL_Parts/*.stl` (19 parts, mm units) | Modular truss structure: `1x1_Base_Unit`, `2x1_Base_5side_Unit`, `2x1_Motor_Ends_Unit` (chassis blocks that bolt together); DECODE launcher: `Launching_Ramp`, `Verticle_Storage`, `Storage_Ramp`, flywheel motor mounts L/R, `Artifact_*` guides; hardware: `Shaft_Collar`, `Shaft_Coupler`, `Servo_Arm`, `Flat_Servo_Mount`, `REV_Hub_Mount_Plate`, `Horizontal_Track` |
| **AZ Printed Telescope** | `~/Downloads/AZ-Printed-Telescope-STLs/*.stl` + Fusion doc "AZ Printed Telescope" (layer1 folder) | 12-part printable belt-driven slide: stages 40→31→22mm sq, 3mm walls, 300-320mm long, 500mm stroke; README-ASSEMBLY.md alongside |
| **Offset slide references** | Fusion docs "Offset Powering Examples" (3 motor-mount variants) + "LayerOne Kit"/"LayerOne Parts" (layer1 folder); STEPs in `~/Downloads/OffsetRobotics/` | Commercial benchmark: 40/30/20mm tubes, cascade GT2 belts — measure, don't clone |
| **Practice pollen** | MakerWorld "FTC 2026-2027 BIOBUZZ Pollen" model | ~3" ball prints for intake testing |

## Non-negotiable conventions

1. **Units are cm** in every MCP call (Fusion API internal units). 40mm = 4.0. STL/mesh imports: pass `units: "mm"`.
2. **Verify the active document first**: `get_scene_info` → check `design_name` before ANY modification. The add-in drives whichever Fusion tab is active. Refuse batch work against "Untitled" unless the user confirms.
3. **Part vs Assembly docs**: `create_component` fails in Part-type docs ("Part Design documents can only contain one component"). Multi-component work needs an Assembly doc (user creates + SAVES it first). Multiple *bodies* in a Part doc are fine.
4. **Check every response** — tools return `"ok": false` inside a success envelope. Never assume; read the result. `rename_body` uses `body_name`/`new_name`.
5. **Verify by arithmetic**: after building, compare `get_physical_properties` volume against a hand calculation. A mismatch >2% means a modeling bug (this caught a rib-through-floor bug that would have wasted a print). PETG mass = volume_cm3 × 1.27 g.
6. **Render to confirm**: `render_view` after each milestone; save and view the PNG. Watch for underside-view confusion.
7. **Credit**: AI-assisted parts get a notebook line (2026-27 manual AI-credit rule). LayerOne/Offset/Pratt derivations get credited by name.

## Tool quirks (live-tested)

- **Sketch plane mappings**: XY sketch → extrude +Z. **XZ sketch: local y maps to global −Z**, and positive extrude goes +Y (into the body above the plane) — probe with a `new_body` test extrude + bbox check before committing cuts.
- **Cuts hit ALL intersecting bodies.** In multi-body docs, either build additively (solid extrudes + `boolean_operation` join) or cut before other bodies occupy the space.
- **Disjoint joins may leave a stray body** (e.g., `Name (1)`) — check the bodies list after boolean chains; merge strays with another `boolean_operation`.
- `rectangular_pattern` only patterns along X/Y construction axes — for Z-repeats, draw multiple profiles in one sketch and extrude each `profile_index` (indices persist; loop 0..n-1).
- `fillet` selects edges by class: `"vertical"` = edges parallel to Z. Radius in cm.
- **Two rectangles in one sketch** → ring + inner profiles; extrude the ring by testing volume (extrude index 0, check volume vs expected; undo and try index 1 if wrong).
- `move_body` is BRep-only; **`move_component`** (fork tool) moves occurrences incl. mesh components — offsets in cm, `absolute: true` to place.
- `import_mesh` → named mesh bodies (reference-only; no mesh→solid). `import_step` (fork tool) may fall back to a NEW document — check `mode` in the response; large STEPs take minutes (bridge timeout is 300s).
- `measure_distance` returns `distance` (cm); points may be omitted on current Fusion builds.
- `create_parameter`: value in cm regardless of unit label; parameters are documentation + Fusion-dialog editability (tools take numerics, not expressions).

## Design recipes

### Bracket/mount against a LayerOne unit
1. `import_mesh` the unit STL (`units: "mm"`) → `get_bounding_box` for envelope
2. Design the new part in a clean zone (offset coordinates away from existing bodies)
3. Match goBILDA hole patterns (8mm spacing conventions) so plastic→metal swaps stay bolt-up
4. `export_stl` per body; print PLA+ (rigid) / PETG (loaded) / TPU 95A (compliant)

### Printed structural channel (the telescope house style)
Outer rect → extrude → cavity rect → cut → `fillet` vertical 1mm → ribs as multi-profile sketch, extrude-join each. Walls ≥3mm; ribs 3×6mm at 40mm pitch beat thicker walls on stiffness-per-gram. Stage interfaces: 1.5mm/side (1mm PTFE pad + 0.5mm clearance). Print channels flat-diagonal (A1 bed diagonal ≈360mm, parts ≤330mm); tubes in 45° diamond orientation self-support.

### Intake wheel variants
Cylinder + hex bore + spokes; make 68/72/76mm OD variants, export all, let the test rig decide. TPU 95A default.

### Design review data
`get_physical_properties` per body → mass table (correct density if material is steel-default); `get_bounding_box` for envelope checks vs 18" limits and this season's expansion rules (sealed until Sept 12 — flag extension-dependent designs).

## Standard finishing moves

Every session that creates parts ends with: volume sanity check → render shown to user → `export_stl` to the agreed folder → remind the user to Cmd+S (the MCP cannot save documents) → notebook/credit reminder.
