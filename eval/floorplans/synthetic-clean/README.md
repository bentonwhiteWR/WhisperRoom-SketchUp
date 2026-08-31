# synthetic-clean — the base case

A 12' x 10' rectangle with one door at a measured position (36" from the
corner, 36" wide, height stated) and a stated 8'-6" ceiling. Everything is
`stated`; nothing is assumed, so the ASSUMED inventory must be empty and no
note may appear in the model.

Truth is exact by construction (authored, no plan exists), tolerance 0.1" —
the deterministic tier-1 floor. This case runs on every change to
`scripts/takeoff-check.py` / `scripts/build-takeoff.rb`:

    python scripts/eval-floorplan.py synthetic-clean

Pass: max vertex error, jamb error and ceiling delta all <= 0.1", exit 0.
