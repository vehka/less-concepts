*less concepts is rooted in the idea that complexity is just a shit-ton of simplicity, chained together. at its core, less concepts holds 65,536 possible combinations of notes which can be gated, offset, and manipulated to create minimal sequences for improvisation. small changes to a single parameter can bring sweeping or subtle changes.*

*seek. think. discover.* - dan derks

https://llllllll.co/t/less-concepts-3/

## note lengths

the two voices can play notes of different lengths on midi and nb. the other outputs (passersby, crow, just friends, w/syn) play triggers, so lengths don't change them. the settings are in the params menu, under *note lengths*, for each voice:

- **weights**: eight lengths, counted in steps: 1/4, 1/2, 1, 1 1/2, 2, 3, 4 and 8. each has a weight from 0 to 7, and a voice picks a length that much more often. by default all the weight is on 1 step, and every note lasts a step, as before.
- **from**: *seed* picks the length from the seed, so the same seed always gives the same length, and the lengths follow the pattern and come back with snapshots. *random* picks a new one for every note.
- **rotate**: reads the seed's bits from another place, so the two voices can pick different lengths from the same seed.
- **overlap**: a voice plays one note at a time. when it plays again before its note has ended, *cut* ends the old note first, and *legato* ends it just after the new one starts, for mono synths that glide. a repeated pitch is always cut.

the length is set when a note starts, so changing the time division doesn't change the notes that already play.
