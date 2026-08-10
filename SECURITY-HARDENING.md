# RoboticsForYouth Hardened Fork

This fork of [faust-machines/fusion360-mcp-server](https://github.com/faust-machines/fusion360-mcp-server)
is used by FTC Team 12096 Absolute Zero and other Robotics For Youth programs
on student machines. It applies one deliberate change:

## `execute_code` is disabled

Upstream ships an `execute_code` MCP tool that runs arbitrary model-supplied
Python inside Fusion 360 with full user privileges — reachable through an
**unauthenticated localhost TCP socket** (port 9876). On a student laptop that
means any local process (or the model itself, via prompt injection) could
execute arbitrary code as the logged-in user.

This fork removes the tool end-to-end:

- `addon/server/command_handler.py` — removed from the dispatch table and
  write-command set; the method now raises with a pointer to this file
- `src/fusion360_mcp/tools.py` — tool definition removed
- `src/fusion360_mcp/mock.py` and tests updated to match

The remaining ~88 purpose-built CAD tools (sketch, features, export,
parameters, CAM, etc.) are untouched and cover all supported operations.

## Operating rules (per team policy)

1. Localhost only — never set the socket host to `0.0.0.0`
2. Run the Fusion add-in only during active sessions (it does not auto-start)
3. Single-user machines only; keep MCP client tool-approval prompts on
4. Re-vet upstream changes before merging them into this fork

## Syncing with upstream

```bash
git remote add upstream https://github.com/faust-machines/fusion360-mcp-server.git
git fetch upstream && git merge upstream/main
# re-verify execute_code is still absent, rerun tests:
grep -rn "execute_code" src/ addon/ tests/   # expect only this file + the disabled stub
pytest -q
```
