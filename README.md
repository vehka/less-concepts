*less concepts is rooted in the idea that complexity is just a shit-ton of simplicity, chained together. at its core, less concepts holds 65,536 possible combinations of notes which can be gated, offset, and manipulated to create minimal sequences for improvisation. small changes to a single parameter can bring sweeping or subtle changes.*

*seek. think. discover.* - dan derks

https://llllllll.co/t/less-concepts-3/

## nb

when the [nb](https://github.com/sixolet/nb) library is installed, on its own or with another script or mod, each voice gets a *vox -> nb* output in *time, midi & outputs*, next to the other outputs. nb plays in the same octave as passersby.

## play/stop

the sequencer can be started and stopped: on the grid at (1,8), or (1,5) on a 64 grid, or with the *play/stop* trigger in the params. play starts the sequence on the next beat. with *send start/stop* on, play and stop also go to the midi out device.

## chord progression

the *chord progression* group holds up to 8 chords, each a degree of the scale and a length in beats. a voice set to *follow* the chords has its notes moved to the nearest tone of the chord that plays. *snap strength* sets how often, so some notes can stay as passing tones.

the chords are built in the scale, so every scale works. *sevenths* adds a fourth tone, and *stride* sets the degrees between the tones: 2 stacks thirds, 1 makes clusters, 3 fourths. the progression counts the beats played since play, and the chord that plays is shown on the screen next to the time division, with its place in the progression (2/4 is the second of four chords).

on a 128 grid the progression is on the left half of row 7, a key per chord: the chords played are dim, the ones to come dimmer, and the one that plays brightens bar by bar. it blinks 4 times before the next chord: on the beats of its last bar, on 1/8 notes when it is shorter than a bar, on 1/16 notes when it is a beat long. while the sequencer is stopped, the screen and grid show the progression waiting on its first chord, where play starts it, unless the chord voice plays it on.

## chord voice

the *chord voice* group adds a third voice that plays chords on passersby or an nb voice: as a block chord, or arpeggiated up, down, up-down or at random, at a rate from a bar to 1/16.

- **follow progression** plays the chords of the progression, for trying one out. it keeps playing while the sequencer is stopped: switch it off to silence it.
- **one-shot** plays the chord on a chosen degree once, right away: a block chord, or one pass of the arpeggio. map *play one-shot* to a midi controller to play chords by hand.

passersby has one voice, shared with the other two voices, so a block chord plays there as an arpeggio.

## lfos

three lfos move the bits, low/high and the octaves around the values that are set, in whole steps. the values that are set stay as they are, so snapshots aren't changed. a target is one voice, both, or both in opposite directions (*contrary*). on the grid, (6,3), (9,3) and (12,3) switch them on and off, next to the randomize buttons of what they move; (3,5) to (5,5) on a 64 grid. shape, cycle, depth and target are in the *lfos* group, with *randomize lfos*.

four more lfos, in *param lfos*, each move a parameter or send a midi cc. a target is picked by group: less concepts, passersby, w/syn, the nb voices in use, or a midi cc. a parameter gets its own value back when the lfo lets go of it.

the cycles are counted in beats since play, so the lfos start over with the sequence and stand still while it is stopped.

## morph

a snapshot can be reached slowly, instead of at once: press one of the morph buttons at (7,8) and (8,8) on the grid, and it blinks, armed. then press a snapshot to start the morph. pressing the armed button again disarms it, and the other button arms its morph instead. the bits, low/high and octaves step from where they are to the snapshot's, spread evenly over the morph. the rule changes a bit at a time, in a random order, so the pattern drifts from one rule to the other. at the end the seed starts over from the snapshot's, and its time division and cycle length come in, as when the snapshot is pressed on its own.

the two morphs have their own length, from 1/4 bar to 32 bars, in the *morph* group. *to chord end* ends the morph with the chord that plays, and *to prog end* with the chord progression, so the snapshot arrives with the next chord, or the first chord of the next pass. with less than a quarter of the chord or progression left, the morph goes on to the end of the next one, so it doesn't jump. with *snap to chords* on, a length in bars ends with a chord instead, when a chord ends no more than a beat after it would: the last such chord end, but not one less than a quarter of the length away. a 1 bar morph started with 3 beats of the chord left takes 3 beats, and one started with 5 beats left takes 5. with no chord end that near, the length stays as it is. holding one morph button and pressing the other arms a morph to the end of the progression, whatever the lengths are: both buttons blink, and pressing either disarms it. the length is counted when the morph starts, so a progression changed while it runs no longer lines up with it. the snapshot blinks while the morph moves to it, faster as it nears the end. a morph counts the beats played, so it stands still while the sequencer is stopped. pressing a snapshot on its own stops a morph, and a new morph starts from where the old one got to. the lfos go on moving the values around the morph. morphs are on 128 grids only.

## z_tuning

with the [z_tuning](https://github.com/catfact/z_tuning) mod on, the voices play in its tuning: passersby, crow, just friends, w/syn and nb.

- **microtune (pitchbend)**, in *time, midi & outputs*, tunes the midi out too: it sends the nearest note and bends it to the tuned pitch, for a synth tuned to A440. set *pitchbend range* to the synth's. a bend is for a whole channel, so give each voice its own.
- **z_tuning root** set to *follow scale* builds the tuning on the scale's root, C, in place of z_tuning's own root note. *global transpose* then transposes the tuning too.
- **z_tuning steps**, at the end of the scale list, puts every step of the tuning in the note pool. an octave is then the tuning's own number of steps, so tunings with more or fewer than 12 steps play as they are meant to. the screen shows degrees of the tuning, and the chords too.
- **vox 1/2 tuning** and the chord voice's *tuning* can keep a voice in 12-TET, for example to double an instrument that can't be retuned.

without z_tuning these params are hidden.

## note lengths

the two voices can play notes of different lengths on midi and nb. the other outputs (passersby, crow, just friends, w/syn) play triggers, so lengths don't change them. the settings are in the params menu, under *note lengths*, for each voice:

- **weights**: eight lengths, counted in steps: 1/4, 1/2, 1, 1 1/2, 2, 3, 4 and 8. each has a weight from 0 to 7, and a voice picks a length that much more often. by default all the weight is on 1 step, and every note lasts a step, as before.
- **from**: *seed* picks the length from the seed, so the same seed always gives the same length, and the lengths follow the pattern and come back with snapshots. *random* picks a new one for every note.
- **rotate**: reads the seed's bits from another place, so the two voices can pick different lengths from the same seed.
- **overlap**: a voice plays one note at a time. when it plays again before its note has ended, *cut* ends the old note first, and *legato* ends it just after the new one starts, for mono synths that glide. a repeated pitch is always cut.

the length is set when a note starts, so changing the time division doesn't change the notes that already play.
