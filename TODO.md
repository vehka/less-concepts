# TODO

## LFOs in snapshots

A snapshot stores seed, rule, the bits, low/high, the octaves, the time
division and the cycle length. The LFO settings are parameters, so they are
saved with a PSET and stay the same from one snapshot to the next.

To decide: should a snapshot carry LFO state, and how much of it?

- Nothing (as now).
- The on/off switches of the bits, low/high and octave LFOs, so that a
  snapshot can recall "this pattern with the octave LFO running". Three
  more fields in a snapshot.
- Everything: shape, cycle, depth and target of every LFO, the param LFOs
  included. A much bigger change to the save format, and old sets need a
  default for what they lack.
