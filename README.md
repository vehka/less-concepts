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

the *chord voice* group adds a third voice that plays chords on passersby, an nb voice or midi: as a block chord, arpeggiated up, down, up-down or at random, at a rate from a bar to 1/16, or held (*hold*: each chord sounds until the next one).

- **follow progression** plays the chords of the progression, for trying one out. it keeps playing while the sequencer is stopped: switch it off to silence it.
- **one-shot** plays the chord on a chosen degree once, right away: a block chord, or one pass of the arpeggio. held, it sounds until the next one-shot. map *play one-shot* to a midi controller to play chords by hand.

passersby has one voice, shared with the other two voices, so a block or held chord plays there as an arpeggio.

### voicing

the chord is played in parts, the lowest first:

- **parts**: as many as the chord has tones, or 2 to 4. with fewer parts than tones the 5th is left out first, then the root, so a seventh chord in two parts plays its 3rd and 7th. with more parts, the root is doubled, then the 5th.
- **voicing**: *close* stacks the tones as near as they go, *drop-2* drops the second highest an octave, *open* lifts the second lowest an octave, for a wider chord.
- **voice leading**: picks the inversion that moves the parts the least from the last chord, so each part moves in small steps and a tone the chords share stays where it is. off, every chord is in root position.
- **bass**: *root below* gives the lowest part the root, below the other parts.

held, a part that keeps its note from one chord to the next is tied over instead of played again.

### midi parts

the *midi* output sends each part on its own channel, *part 1 midi ch* to *part 4 midi ch*: part 1 is the lowest. this is for a synth with mono tracks, like the elektron analog four, where each part gets a track and its own sound. a part plays one note at a time, and with *microtune* on, each part bends its own channel. the notes go to the *midi (out)* device. only the channels of the parts that play are shown: set *parts* to 2 or 3 to leave the other tracks free.

### midi channels

on a synth with mono tracks, two sources on one channel cut each other off. a channel setting that shares its channel with another source says so in the params menu: *3 ! h1* is channel 3, where the harmony of vox 1 sends too. the sources are v1 and v2 for the voices (*midi ch A* and *B*), h1 and h2 for their harmonies, and p1 to p4 for the chord voice's parts.

## harmony

the *harmony* group gives each of the two voices a shadow: a second note that plays with each of its notes, on its own midi channel (*harmony -> midi*, *harmony midi ch*) or nb voice. it has the voice's length, octave, legato and tuning.

**vox 1/2 harmony vel** (velocity) is relative to the voice: 0% plays at the voice's velocity, +100% at the loudest, -100% is silent, and in between it goes evenly to each end.

- **3rd / 6th above / below**: two or five degrees away in the scale, so the harmony stays in the key: thirds and sixths in a seven note scale. a note outside the scale keeps its distance from the degree below it.
- **chord tone above / below**: the next tone of the chord that plays, for a harmony that sits in the progression. best with the voice following the chords, so both are chord tones. without a chord it plays a 3rd.
- **contrary**: when the voice goes up, the harmony goes down as many degrees, and the other way round. it stays a 3rd to a 10th below the voice, and goes back to a 6th below when it moves out. it starts over from a 6th below with play.

the *harmony* group of the param lfos moves both voices' harmony modes and velocities. an lfo on a mode steps through the modes in their order, *off* too, so the harmony drops out for a while; the menu keeps showing the mode that is set. an lfo on the velocity fades the harmony in and out.

in olafur the notes of the pool are the scale. in z_tuning steps a degree is a step of the tuning, so a 3rd is two steps.

### four voices on the analog four

for example: vox 1 on *midi ch A* = 1 and vox 2 on *midi ch B* = 2, their harmonies on channels 3 and 4, for a track each. or the chord voice on *midi* with four parts on channels 1 to 4, *hold*, *voice leading* on and *bass* on *root below*, for a four part pad that moves smoothly from chord to chord. or two parts of the chord voice (its 3rd and 7th) on tracks 3 and 4 under the two voices.

## lfos

three lfos move the bits, low/high and the octaves around the values that are set, in whole steps. the values that are set stay as they are, so snapshots aren't changed. a target is one voice, both, or both in opposite directions (*contrary*). on the grid, (6,3), (9,3) and (12,3) switch them on and off, next to the randomize buttons of what they move; (3,5) to (5,5) on a 64 grid. shape, cycle, depth and target are in the *lfos* group, with *randomize lfos*.

four more lfos, in *param lfos*, each move a parameter or send a midi cc. a target is picked by group: less concepts, harmony, passersby, w/syn, the nb voices in use, or a midi cc. a parameter gets its own value back when the lfo lets go of it.

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
