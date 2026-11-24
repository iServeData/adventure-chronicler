# Security

## Reporting a problem

Please don't open a public issue for a security problem. Use GitHub's **Report a vulnerability** button on
this repository's Security tab. It opens a private report that only the maintainers can see. Include the
steps you took, what you expected and what happened. Don't include real account details or real exports.
Make a synthetic example instead.

## Scope

- The addon (`addon/AdventureChronicler/`)
- The export format, the reference validator and the scaffold (`schema/`, `reference/`)

## Things to know

- Exports are self-reported. The CRC-32 only catches accidental damage while copying. It isn't a signature and
  doesn't prove anything about gameplay. Compression or encoding wouldn't be encryption either.
- An importer must never run uploaded Lua or SavedVariables files. It must parse exports as data only, and it
  must never award attendance, clears, achievements or XP automatically.

See [docs/security.md](docs/security.md) for the threat model.
