# Client working notes

One folder per client, kebab-case: `clients/acme-audiology/`.

What belongs here (committed):

- `notes.md` — the room read, the anchor used, the tolerance, the models considered and why.
- `layout.html` — the to-scale layout Artifact source, if one was built.

What does not (gitignored):

- `plans/` — client-supplied floor plans, photos, PDFs, DWGs
- `renders/` — SketchUp / V-Ray output

Finished client-facing proposal PDFs go to `C:\Users\bento\Desktop\ProposalFiles\<Client>\`,
never into this repo.

Every dimension recorded in `notes.md` carries its tolerance and its scale anchor, and stays
flagged as estimated until someone confirms it with a tape.
