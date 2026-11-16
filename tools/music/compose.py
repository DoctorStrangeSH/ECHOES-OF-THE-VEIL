#!/usr/bin/env python3
"""Composes and renders the Echoes of the Veil soundtrack into assets/music/*.ogg.

Every piece shares one leitmotif, the "echo": a rising A-D-E-F (in D minor),
answered a beat later by a softer voice an octave up, the way the Veil
answers the city. Day themes turn it major; combat compresses it; the
epilogue finally lets it resolve.

    python3 tools/music/compose.py            # all tracks
    python3 tools/music/compose.py title day  # some tracks

Needs numpy, scipy and ffmpeg (libvorbis).
"""
import os
import subprocess
import sys
import tempfile

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from synth import SR, Song, midi  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "music")


def melody(song, track, start_bar, notes, vel=0.75, octave_shift=0, bpb=4):
    """notes: list of (pitch or None, beats)."""
    beat = start_bar * bpb
    for p, d in notes:
        if p is not None:
            m = midi(p) + 12 * octave_shift
            song.note(track, beat, m, d * 0.95, vel)
        beat += d
    return beat


def echo(song, track, start_bar, notes, delay=1.0, vel=0.35, shift=12, bpb=4):
    """The Veil's answer: the same line later, softer, higher."""
    beat = start_bar * bpb + delay
    for p, d in notes:
        if p is not None:
            song.note(track, beat, midi(p) + shift, d * 0.9, vel)
        beat += d


CHORDS = {
    # name: pad voicing (low to high)
    "Dm": ["D3", "A3", "D4", "F4"], "Bb": ["Bb2", "F3", "Bb3", "D4"], "F": ["F2", "C3", "A3", "C4"],
    "C": ["C3", "G3", "C4", "E4"], "Gm": ["G2", "D3", "G3", "Bb3"], "A": ["A2", "E3", "A3", "C#4"],
    "Asus": ["A2", "E3", "A3", "D4"], "Am": ["A2", "E3", "A3", "C4"], "Gm7": ["G2", "D3", "F3", "Bb3"],
    "C7": ["C3", "G3", "Bb3", "E4"], "Dm9": ["D3", "F3", "A3", "C4", "E4"], "Bbmaj7": ["Bb2", "D3", "F3", "A3"],
    "Gm9": ["G2", "Bb2", "D3", "F3", "A3"], "A7sus": ["A2", "D3", "E3", "G3"], "A7": ["A2", "C#3", "E3", "G3"],
    "Eb": ["Eb3", "Bb3", "Eb4", "G4"], "Cm": ["C3", "G3", "C4", "Eb4"], "Fmaj7": ["F2", "C3", "E3", "A3"],
    "Dm/F": ["F2", "A3", "D4", "F4"], "Gm/D": ["D3", "G3", "Bb3", "D4"], "Bbmaj7#11": ["Bb2", "F3", "A3", "E4"],
    "Dmadd9": ["D3", "A3", "E4", "F4"], "Em7b5": ["E3", "Bb3", "D4", "G4"],
}


def root(ch):
    return CHORDS[ch][0]


def arp(song, track, bar, ch, pattern, step, vel=0.45, up=0, bpb=4):
    """Arpeggiate a chord: pattern indexes into its voicing (+12 per extra octave)."""
    v = [midi(p) + 12 * up for p in CHORDS[ch]]
    b = bar * bpb
    for i, idx in enumerate(pattern):
        oct_, k = divmod(idx, len(v))
        song.note(track, b + i * step, v[k] + 12 * oct_, step * 1.6, vel)


# --- Tracks ---------------------------------------------------------------------

def title():
    s = Song(bpm=72, bars=16, seed=11)
    s.track("pad", "pad", gain=0.9, reverb=0.45)
    s.track("lh", "piano", gain=0.75, pan=-0.15, reverb=0.3)
    s.track("rh", "piano", gain=1.0, pan=0.1, reverb=0.35)
    s.track("bell", "bell", gain=0.6, pan=0.35, reverb=0.6)
    s.track("bass", "bass", gain=0.5, reverb=0.1)
    prog = ["Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "A"] * 2
    for i, ch in enumerate(prog):
        s.chord("pad", i * 4, CHORDS[ch], 4, 0.5 if i < 8 else 0.62)
        arp(s, "lh", i, ch, [0, 1, 2, 3, 2, 1, 2, 1], 0.5, 0.33 if i < 8 else 0.4, up=-1 if i in (1, 6) else 0)
        s.note("bass", i * 4, midi(root(ch)) - 12, 3.8, 0.55)
    a = [("A4", 1.5), ("D5", 0.5), ("E5", 1), ("F5", 1),
         ("F5", 2), ("E5", 1), ("D5", 1),
         ("C5", 1.5), ("A4", 0.5), ("C5", 1), ("F5", 1),
         ("E5", 3), ("G4", 1),
         ("A4", 1.5), ("D5", 0.5), ("E5", 1), ("F5", 1),
         ("G5", 2), ("F5", 1), ("D5", 1),
         ("Bb5", 1.5), ("A5", 0.5), ("G5", 1), ("F5", 1),
         ("E5", 2), ("C#5", 1), ("A4", 1)]
    b = [("A5", 1.5), ("D6", 0.5), ("C6", 1), ("A5", 1),
         ("Bb5", 2), ("A5", 1), ("F5", 1),
         ("A5", 1.5), ("G5", 0.5), ("F5", 1), ("C5", 1),
         ("E5", 2), ("D5", 1), ("E5", 1),
         ("F5", 1.5), ("E5", 0.5), ("D5", 1), ("A4", 1),
         ("D5", 2), ("F5", 1), ("Bb5", 1),
         ("A5", 1.5), ("G5", 0.5), ("E5", 1), ("C#5", 1),
         ("D5", 4)]
    melody(s, "rh", 0, a, 0.62)
    melody(s, "rh", 8, b, 0.7)
    echo(s, "bell", 0, a[:4], vel=0.3)
    echo(s, "bell", 4, a[14:18], vel=0.3)
    echo(s, "bell", 8, b[:4], vel=0.28)
    echo(s, "bell", 12, b[14:18], vel=0.3, shift=0)
    return s


def day():
    s = Song(bpm=100, bars=16, seed=21)
    s.track("ep", "epiano", gain=0.7, pan=-0.2, reverb=0.25)
    s.track("gtr", "pluck", gain=1.0, pan=0.2, reverb=0.25)
    s.track("bass", "bass", gain=0.7, reverb=0.05)
    s.track("pad", "pad", gain=0.5, reverb=0.4)
    s.track("brush", "brush", gain=0.55, pan=0.1, reverb=0.15)
    s.track("shk", "shaker", gain=0.35, pan=0.4, reverb=0.1)
    s.track("kick", "kick", gain=0.5, reverb=0.05)
    s.track("bell", "bell", gain=0.45, pan=-0.4, reverb=0.5)
    prog = ["F", "Am", "Bb", "C", "F", "Dm", "Gm7", "C7", "Bb", "C", "Am", "Dm", "Gm", "C", "F", "F"]
    for i, ch in enumerate(prog):
        b = i * 4
        for off in (0.5, 1.5, 2.5, 3.25):
            s.chord("ep", b + off, [p for p in CHORDS[ch][1:]], 0.45, 0.32)
        r = midi(root(ch))
        s.note("bass", b, r - 12, 1.4, 0.7)
        s.note("bass", b + 1.5, r - 12 + 7, 0.45, 0.5)
        s.note("bass", b + 2, r - 12 + (12 if i % 2 else 7), 1.4, 0.6)
        s.chord("pad", b, CHORDS[ch], 4, 0.35)
        s.hit("kick", b, 0.6)
        s.hit("kick", b + 2.5, 0.35)
        s.hit("brush", b + 1, 0.7)
        s.hit("brush", b + 3, 0.7)
        for e in range(8):
            s.hit("shk", b + e * 0.5, 0.5 if e % 2 else 0.8)
    m = [("C5", .5), ("F5", .5), ("G5", .5), ("A5", 1.5), ("G5", .5), ("F5", .5),
         ("E5", 1), ("C5", 1), ("E5", .5), ("G5", 1.5),
         ("F5", .5), ("D5", .5), ("F5", 1), ("Bb5", 1), ("A5", 1),
         ("G5", 3), (None, 1),
         ("C5", .5), ("F5", .5), ("G5", .5), ("A5", 1.5), ("C6", .5), ("A5", .5),
         ("F5", 2), ("D5", 1), ("F5", 1),
         ("Bb5", 1), ("A5", .5), ("G5", .5), ("F5", 1), ("D5", 1),
         ("E5", 2), ("G5", 1), ("C5", 1),
         ("D5", 1), ("F5", 1), ("Bb5", 1.5), ("A5", .5),
         ("G5", 1), ("E5", 1), ("C5", 2),
         ("E5", 1), ("A5", 1), ("C6", 1.5), ("B5", .5),
         ("A5", 2), ("F5", 2),
         ("G5", 1), ("Bb5", 1), ("D6", 1), ("C6", .5), ("Bb5", .5),
         ("A5", 1), ("G5", 1), ("E5", 1), ("C5", 1),
         ("F5", 1.5), ("G5", .5), ("A5", 1), ("C6", 1),
         ("F5", 3), (None, 1)]
    melody(s, "gtr", 0, m, 0.75, octave_shift=-1)
    echo(s, "bell", 0, m[:4], vel=0.25, delay=2, shift=12)
    echo(s, "bell", 4, m[16:20], vel=0.25, delay=2, shift=12)
    return s


def night():
    s = Song(bpm=66, bars=16, seed=31)
    s.track("ep", "epiano", gain=0.9, pan=-0.1, reverb=0.4)
    s.track("pad", "pad", gain=0.7, reverb=0.5)
    s.track("bass", "bass", gain=0.55, reverb=0.1)
    s.track("pn", "piano", gain=0.9, pan=0.2, reverb=0.5)
    s.track("bell", "bell", gain=0.45, pan=-0.35, reverb=0.7)
    s.track("hat", "brush", gain=0.5, pan=0.3, reverb=0.3)
    prog = ["Dm9", "Bbmaj7", "Gm9", "A7sus"] * 4
    for i, ch in enumerate(prog):
        b = i * 4
        voicing = CHORDS["A7"] if (ch == "A7sus" and i % 2 == 1) else CHORDS[ch]
        s.chord("ep", b, voicing, 2.5, 0.42, strum=0.03)
        s.chord("ep", b + 2.5, voicing[1:], 1.4, 0.3, strum=0.02)
        s.chord("pad", b, CHORDS[ch], 4, 0.38)
        s.note("bass", b, midi(CHORDS[ch][0]) - 12, 3.5, 0.5)
        if i >= 4:
            s.hit("hat", b + 1, 0.45)
            s.hit("hat", b + 3, 0.45)
            s.hit("hat", b + 3.5, 0.25)
    m = [(None, 2), ("A5", 1), ("D6", 1),
         ("C6", 3), ("A5", 1),
         ("Bb5", 2), ("A5", 1), ("F5", 1),
         ("E5", 4),
         (None, 1), ("F5", 1), ("A5", 1), ("D6", 1),
         ("E6", 2), ("D6", 1), ("C6", 1),
         ("D6", 1.5), ("Bb5", .5), ("A5", 1), ("G5", 1),
         ("A5", 4)]
    m2 = [(None, 2), ("A5", 1), ("D6", 1),
          ("C6", 2), ("A5", 1), ("G5", 1),
          ("F5", 2), ("E5", 1), ("D5", 1),
          ("E5", 4),
          (None, 1), ("D5", 1), ("E5", 1), ("F5", 1),
          ("A5", 2), ("G5", 1), ("F5", 1),
          ("E5", 1.5), ("D5", .5), ("C#5", 1), ("E5", 1),
          ("D5", 4)]
    melody(s, "pn", 0, m, 0.5, octave_shift=-1)
    melody(s, "pn", 8, m2, 0.52)
    echo(s, "bell", 0, m[:4], vel=0.22, delay=1.5)
    echo(s, "bell", 8, m2[:4], vel=0.22, delay=1.5)
    return s


def interior():
    s = Song(bpm=92, bars=16, beats_per_bar=3, seed=41)
    s.track("box", "musicbox", gain=1.0, pan=0.15, reverb=0.4)
    s.track("pn", "piano", gain=0.7, pan=-0.15, reverb=0.3)
    s.track("pad", "pad", gain=0.45, reverb=0.4)
    prog = ["Bb", "Gm", "Eb", "F", "Bb", "Gm", "Cm", "F", "Eb", "F", "Dm/F", "Gm", "Cm", "F", "Bb", "Bb"]
    for i, ch in enumerate(prog):
        b = i * 3
        v = [midi(p) for p in CHORDS[ch]]
        s.note("pn", b, v[0] - 12 if v[0] > midi("E3") else v[0], 1.0, 0.45)
        s.chord("pn", b + 1, v[1:3], 0.8, 0.25)
        s.chord("pn", b + 2, v[1:3], 0.8, 0.22)
        s.chord("pad", b, CHORDS[ch], 3, 0.3)
    m = [("D5", 1), ("F5", 1), ("Bb5", 1), ("A5", 2), ("G5", 1), ("G5", 1), ("F5", 1), ("Eb5", 1), ("F5", 3),
         ("D5", 1), ("F5", 1), ("D6", 1), ("C6", 2), ("Bb5", 1), ("G5", 1), ("F5", 1), ("Eb5", 1), ("F5", 3),
         ("G5", 1), ("Bb5", 1), ("Eb6", 1), ("D6", 2), ("C6", 1), ("F5", 1), ("A5", 1), ("D6", 1), ("D6", 2), ("Bb5", 1),
         ("C6", 1), ("Eb6", 1), ("C6", 1), ("A5", 2), ("C6", 1), ("Bb5", 3), ("D5", 1), ("F5", 1), ("Bb4", 1)]
    melody(s, "box", 0, m, 0.7, bpb=3)
    return s


def veil():
    s = Song(bpm=56, bars=16, seed=51)
    s.track("pad", "pad", gain=1.0, reverb=0.7)
    s.track("str", "strings", gain=0.7, pan=0.2, reverb=0.7)
    s.track("bell", "bell", gain=0.6, pan=-0.3, reverb=0.85)
    s.track("box", "musicbox", gain=0.35, pan=0.4, reverb=0.9)
    s.track("drone", "bass", gain=0.4, reverb=0.3)
    prog = ["Dmadd9", "Dmadd9", "Bbmaj7#11", "Bbmaj7#11", "Gm/D", "Gm/D", "Asus", "A",
            "Dmadd9", "Dmadd9", "Em7b5", "Em7b5", "Bbmaj7#11", "Bbmaj7#11", "Asus", "Asus"]
    for i in range(0, 16, 2):
        s.chord("pad", i * 4, CHORDS[prog[i]], 8, 0.55)
        s.note("drone", i * 4, "D2", 7.8, 0.35)
        s.note("str", i * 4 + 2, midi(CHORDS[prog[i]][-1]) + 12, 6, 0.4)
    scale = ["D5", "E5", "F5", "A5", "C6", "D6", "E6"]
    rng = np.random.default_rng(7)
    beat = 0.0
    while beat < 16 * 4 - 2:
        s.note("bell", beat, scale[rng.integers(len(scale))], 2, float(rng.uniform(0.15, 0.32)))
        beat += float(rng.choice([1.5, 2, 2.5, 3, 4]))
    motif = [("A4", 1.5), ("D5", .5), ("E5", 1), ("F5", 3)]
    melody(s, "box", 8, motif, 0.4, octave_shift=1)
    echo(s, "bell", 8, motif, delay=2, vel=0.22, shift=0)
    melody(s, "box", 12, [("F5", 1.5), ("E5", .5), ("D5", 1), ("A4", 3)], 0.35, octave_shift=1)
    return s


def combat():
    s = Song(bpm=138, bars=16, seed=61)
    s.track("bass", "bass", gain=0.9, reverb=0.05)
    s.track("str", "strings", gain=0.9, pan=-0.2, reverb=0.2)
    s.track("lead", "lead", gain=0.9, pan=0.15, reverb=0.25)
    s.track("kick", "kick", gain=0.9, reverb=0.05)
    s.track("snare", "snare", gain=0.6, reverb=0.25)
    s.track("hat", "hat", gain=0.45, pan=0.3, reverb=0.05)
    s.track("pad", "pad", gain=0.5, reverb=0.3)
    prog = ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Bb", "A", "Gm", "Gm", "Dm", "Dm", "Bb", "C", "A", "A"]
    for i, ch in enumerate(prog):
        b = i * 4
        r = midi(root(ch)) - 12
        if r > midi("E2"):
            r -= 12
        for e, iv in enumerate([0, 0, 12, 0, 10, 0, 7, 0]):
            s.note("bass", b + e * 0.5, r + iv, 0.42, 0.75 if e % 2 == 0 else 0.55)
        for e in range(8):
            if e % 2:
                s.chord("str", b + e * 0.5, CHORDS[ch][1:], 0.3, 0.5)
            s.hit("hat", b + e * 0.5, 0.6 if e % 2 else 0.35)
        s.hit("kick", b, 0.9)
        s.hit("kick", b + 1.5, 0.6)
        s.hit("kick", b + 2, 0.85)
        s.hit("snare", b + 1, 0.7)
        s.hit("snare", b + 3, 0.75)
        if i % 4 == 3:
            s.hit("snare", b + 3.5, 0.5)
            s.hit("snare", b + 3.75, 0.6)
        s.chord("pad", b, CHORDS[ch], 4, 0.4)
    m = [("A4", 1), ("D5", .5), ("E5", .5), ("F5", 2), ("E5", 1), ("D5", .5), ("C5", .5), ("D5", 2),
         ("A4", 1), ("D5", .5), ("E5", .5), ("F5", 1), ("G5", 1), ("E5", 2), ("C#5", 2)]
    melody(s, "lead", 4, m, 0.7)
    m2 = [("D5", 1), ("G5", .5), ("A5", .5), ("Bb5", 2), ("A5", 1), ("G5", 1), ("F5", 1.5), ("E5", .5), ("D5", 2),
          ("F5", 1), ("G5", 1), ("A5", 2), ("E5", 2), ("C#5", 1), ("E5", 1), ("A5", 4)]
    melody(s, "lead", 8, m2, 0.75)
    return s


def boss():
    s = Song(bpm=146, bars=16, seed=71)
    s.track("bass", "bass", gain=1.0, reverb=0.05)
    s.track("str", "strings", gain=1.0, pan=-0.25, reverb=0.25)
    s.track("lead", "lead", gain=0.8, pan=0.2, reverb=0.3)
    s.track("lead2", "lead", gain=0.5, pan=-0.2, reverb=0.3)
    s.track("kick", "kick", gain=1.0, reverb=0.05)
    s.track("snare", "snare", gain=0.7, reverb=0.3)
    s.track("hat", "hat", gain=0.6, pan=0.3, reverb=0.05)
    s.track("timp", "timpani", gain=0.8, reverb=0.4)
    s.track("pad", "pad", gain=0.7, reverb=0.4)
    s.track("bell", "bell", gain=0.5, reverb=0.6)
    prog = ["Dm", "Bb", "Gm", "A", "Dm", "F", "Gm", "A", "Bb", "Bb", "C", "C", "Dm", "Bb", "A", "A"]
    for i, ch in enumerate(prog):
        b = i * 4
        r = midi(root(ch)) - 12
        if r > midi("E2"):
            r -= 12
        for e in range(8):
            s.note("bass", b + e * 0.5, r + (12 if e in (3, 7) else 0), 0.4, 0.8)
            s.hit("hat", b + e * 0.5, 0.55)
        for e in (0.5, 1.0, 2.5, 3.0):
            s.chord("str", b + e, CHORDS[ch][1:], 0.35, 0.55)
        s.hit("kick", b, 1.0)
        s.hit("kick", b + 0.75, 0.6)
        s.hit("kick", b + 2, 0.9)
        s.hit("snare", b + 1, 0.8)
        s.hit("snare", b + 3, 0.8)
        if i % 2 == 0:
            s.hit("timp", b, 0.8)
        s.chord("pad", b, CHORDS[ch], 4, 0.45)
        if i % 4 == 0:
            s.note("bell", b, midi(root(ch)) + 24, 2, 0.4)
    m = [("A4", 1), ("D5", 1), ("E5", 1), ("F5", 1), ("F5", 2), ("E5", 1), ("D5", 1),
         ("Bb4", 1), ("D5", 1), ("G5", 1), ("F5", 1), ("E5", 2), ("C#5", 2),
         ("A5", 1), ("D6", 1), ("E6", 1), ("F6", 1), ("F6", 2), ("E6", 1), ("D6", 1),
         ("Bb5", 1), ("D6", 1), ("G6", 1.5), ("F6", .5), ("E6", 3), (None, 1)]
    melody(s, "lead", 4, m, 0.75)
    melody(s, "lead2", 4, m, 0.6, octave_shift=-1)
    m2 = [("D5", 2), ("F5", 2), ("Bb5", 2), ("A5", 2), ("G5", 2), ("E5", 2), ("C5", 2), ("E5", 2),
          ("F5", 1), ("E5", 1), ("D5", 1), ("A4", 1), ("Bb4", 2), ("D5", 2), ("C#5", 4), ("E5", 4)]
    melody(s, "lead", 12, m2[:8], 0.7)
    return s


def epilogue():
    s = Song(bpm=70, bars=16, seed=81)
    s.track("pn", "piano", gain=1.0, pan=0.1, reverb=0.4)
    s.track("lh", "piano", gain=0.7, pan=-0.15, reverb=0.35)
    s.track("str", "strings", gain=0.7, reverb=0.6)
    s.track("pad", "pad", gain=0.6, reverb=0.5)
    s.track("bell", "bell", gain=0.5, pan=0.3, reverb=0.7)
    prog = ["F", "C", "Dm", "Bb", "F", "C", "Bb", "C", "Dm", "Bb", "F", "C", "Bb", "C", "F", "F"]
    for i, ch in enumerate(prog):
        s.chord("pad", i * 4, CHORDS[ch], 4, 0.4)
        arp(s, "lh", i, ch, [0, 2, 3, 2, 1, 2, 3, 2], 0.5, 0.3)
        if i >= 8:
            s.note("str", i * 4, midi(CHORDS[ch][-1]) + 12, 4, 0.35)
    m = [("C5", 1.5), ("F5", .5), ("G5", 1), ("A5", 1), ("A5", 2), ("G5", 1), ("E5", 1),
         ("F5", 1.5), ("D5", .5), ("F5", 1), ("A5", 1), ("Bb5", 2), ("A5", 1), ("F5", 1),
         ("C5", 1.5), ("F5", .5), ("G5", 1), ("A5", 1), ("C6", 2), ("Bb5", 1), ("G5", 1),
         ("F5", 1.5), ("G5", .5), ("A5", 1), ("Bb5", 1), ("G5", 4),
         ("A5", 1.5), ("D6", .5), ("C6", 1), ("A5", 1), ("Bb5", 2), ("A5", 1), ("F5", 1),
         ("A5", 1.5), ("G5", .5), ("F5", 1), ("C5", 1), ("E5", 2), ("G5", 2),
         ("F5", 1.5), ("G5", .5), ("A5", 1), ("Bb5", 1), ("C6", 2), ("E5", 2),
         ("F5", 4), (None, 4)]
    melody(s, "pn", 0, m, 0.6)
    echo(s, "bell", 0, m[:4], vel=0.25)
    echo(s, "bell", 14, [("F5", 1), ("A5", 1), ("C6", 2)], delay=0, vel=0.3)
    return s


TRACKS = {"title": title, "day": day, "night": night, "interior": interior, "veil": veil,
          "combat": combat, "boss": boss, "epilogue": epilogue}


def write_ogg(name: str, audio: np.ndarray) -> str:
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".ogg")
    with tempfile.NamedTemporaryFile(suffix=".f32") as tmp:
        audio.astype("<f4").tofile(tmp.name)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "f32le", "-ar", str(SR), "-ac", "2",
                        "-i", tmp.name, "-c:a", "libvorbis", "-q:a", "5", path], check=True)
    return path


if __name__ == "__main__":
    names = sys.argv[1:] or list(TRACKS)
    for n in names:
        song = TRACKS[n]()
        audio = song.render()
        p = write_ogg(n, audio)
        print(f"{n}: {song.length:.1f}s -> {os.path.relpath(p)}")
