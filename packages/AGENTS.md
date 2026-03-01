# packages/ — Source of Truth

- **Alphabetical Order**: Manifest files must stay sorted alphabetically (case-insensitive).
- **No Duplicates**: Search before adding (`grep -i 'pkg' packages/*`).
- **Config Sync**: If adding/removing a program here, the corresponding configuration in `config/` MUST be updated/pruned in the same plan.
- **Validation**: Sort and check for missing/duplicate packages before committing.
