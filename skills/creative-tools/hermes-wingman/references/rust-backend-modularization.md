# Rust Backend Modularization Pitfalls

When splitting monolithic main.rs into src/handlers/*.rs modules:

## Axum Extractor Visibility

Any struct used as an Axum route extractor MUST be `pub`:

WRONG: `struct SwitchModelRequest { pub model: String }`
CORRECT: `pub struct SwitchModelRequest { pub model: String }`

Why: Axum's post(handler) macro references the type in main.rs. If private, compiler can't resolve it.

## Affected Types (v1.0.0)

cli.rs: HermesCommandBody
config.rs: SwitchModelRequest, ProbeRequest
files.rs: FileListQuery, FileReadQuery, FileWriteBody, FileQuery, FileRenameBody, FileMkdirBody
gateway.rs: InstallRequest

## Quick Fix

grep -rn "^struct " src/handlers/ | while read line; do
  file=$(echo "$line" | cut -d: -f1)
  sed -i 's/^struct /pub struct /' "$file"
done
cargo check && cargo fix --bin hermes-wingman-backend --allow-dirty

## Dead Code

After modularization, unused structs like SkillToggleParams may remain (5 warnings). Harmless — suppress or remove.