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
    "G": ["G2", "D3", "G3", "B3"], "Dsus": ["D3", "A3", "D4", "G4"],
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
    """The main theme (R10b): the echo grows from one bell into the whole town.

    0-3   intro: a bell counts the echo (A-D-E-F) over a held D, the choir hums
    4-11  theme A on the piano, harp-like arpeggios, strings underneath
    12-19 theme B: strings carry the tune, flute answers, choir and timpani
    20-23 the echo, full: strings, choir and organ, timpani on every bar
    24-27 coda: the piano alone, the bell once more, back to the start
    """
    s = Song(bpm=72, bars=28, seed=11)
    s.track("pad", "pad", gain=0.8, reverb=0.5)
    s.track("ch", "choir", gain=0.75, reverb=0.8)
    s.track("org", "organ", gain=0.45, reverb=0.7)
    s.track("lh", "piano", gain=0.7, pan=-0.15, reverb=0.35)
    s.track("rh", "piano", gain=1.0, pan=0.1, reverb=0.4)
    s.track("harp", "pluck", gain=0.55, pan=-0.3, reverb=0.5)
    s.track("str", "strings", gain=0.9, pan=0.15, reverb=0.55)
    s.track("str2", "strings", gain=0.55, pan=-0.2, reverb=0.55)
    s.track("fl", "flute", gain=0.6, pan=0.35, reverb=0.5)
    s.track("bell", "bell", gain=0.6, pan=0.35, reverb=0.7)
    s.track("timp", "timpani", gain=0.75, reverb=0.5)
    s.track("bass", "bass", gain=0.55, reverb=0.15)
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
    prog_a = ["Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "A"]
    prog_b = ["Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "A"]
    # Intro (bars 0-3): a held D, the choir hums, the bell counts the echo.
    for i in range(4):
        s.chord("pad", i * 4, CHORDS["Dm"], 4, 0.35 + 0.05 * i)
        s.note("bass", i * 4, "D2", 4, 0.4)
    s.chord("ch", 4, ["D4", "A4"], 8, 0.3)
    melody(s, "bell", 0, [("A5", 2), ("D6", 2), ("E6", 2), ("F6", 6), (None, 4)], 0.4)
    melody(s, "fl", 2, [(None, 2), ("A5", 1), ("D6", 1), ("E6", 1), ("F6", 3)], 0.35)
    # Theme A (bars 4-11): piano.
    for k, ch in enumerate(prog_a):
        i = 4 + k
        s.chord("pad", i * 4, CHORDS[ch], 4, 0.45)
        arp(s, "lh", i, ch, [0, 1, 2, 3, 2, 1, 2, 1], 0.5, 0.33, up=-1 if ch in ("Bb", "Gm") else 0)
        arp(s, "harp", i, ch, [0, 1, 2, 3], 1.0, 0.25, up=1)
        s.note("bass", i * 4, midi(root(ch)) - 12, 3.8, 0.5)
        if k >= 4:
            s.note("str2", i * 4, midi(CHORDS[ch][1]), 4, 0.3)
    melody(s, "rh", 4, a, 0.6)
    echo(s, "bell", 4, a[:4], vel=0.26)
    # Theme B (bars 12-19): strings take the tune, the flute answers.
    for k, ch in enumerate(prog_b):
        i = 12 + k
        s.chord("pad", i * 4, CHORDS[ch], 4, 0.5)
        s.chord("ch", i * 4, CHORDS[ch][1:], 4, 0.3)
        arp(s, "lh", i, ch, [0, 1, 2, 3, 2, 1, 2, 1], 0.5, 0.36)
        s.note("bass", i * 4, midi(root(ch)) - 12, 3.8, 0.6)
        s.note("str2", i * 4, midi(CHORDS[ch][0]), 4, 0.35)
        if k in (0, 4):
            s.hit("timp", i * 4, 0.55)
    melody(s, "str", 12, b, 0.55)
    melody(s, "rh", 12, b, 0.35, octave_shift=1)
    echo(s, "fl", 12, b[:4], delay=2, vel=0.35, shift=0)
    echo(s, "fl", 16, b[14:18], delay=2, vel=0.35, shift=0)
    # The echo, full (bars 20-23).
    climax = [("A5", 2), ("D6", 1), ("E6", 1), ("F6", 3), ("E6", 1),
              ("D6", 2), ("Bb5", 2), ("C6", 2), ("A5", 2),
              ("Bb5", 1.5), ("A5", 0.5), ("G5", 1), ("Bb5", 1), ("A5", 4)]
    for k, ch in enumerate(["Dm", "Bb", "Gm", "A"]):
        i = 20 + k
        s.chord("pad", i * 4, CHORDS[ch], 4, 0.62)
        s.chord("ch", i * 4, CHORDS[ch], 4, 0.45)
        s.chord("org", i * 4, CHORDS[ch][:3], 4, 0.4)
        s.note("bass", i * 4, midi(root(ch)) - 12, 4, 0.7)
        s.note("str2", i * 4, midi(CHORDS[ch][-1]), 4, 0.45)
        s.hit("timp", i * 4, 0.75)
        s.hit("timp", i * 4 + 3.5, 0.4)
    melody(s, "str", 20, climax, 0.72, octave_shift=-1)
    melody(s, "fl", 20, climax, 0.4)
    # Coda (bars 24-27): the piano alone, back to the beginning.
    for k, ch in enumerate(["Dm", "Bb", "Asus", "Dm"]):
        i = 24 + k
        s.chord("pad", i * 4, CHORDS[ch], 4, 0.35 - 0.05 * k)
        arp(s, "lh", i, ch, [0, 1, 2, 3], 1.0, 0.28)
    melody(s, "rh", 24, [("A4", 1.5), ("D5", 0.5), ("E5", 1), ("F5", 1), ("E5", 2), ("D5", 2), ("C#5", 3), ("E5", 1), ("D5", 4)], 0.45)
    s.note("bell", 27 * 4 + 1, "D6", 2, 0.25)
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


# --- Places and people (R10a) ---------------------------------------------------
# Each keeps the echo (A-D-E-F, or its major-key shape 5-1-2-3) somewhere in
# its tune, so the whole soundtrack still sounds like one town.

def farm():
    """Brook Farm: a fiddle-and-accordion waltz, the echo turned rustic."""
    s = Song(bpm=138, bars=32, beats_per_bar=3, seed=91)
    s.track("acc", "accordion", gain=0.9, pan=0.1, reverb=0.25)
    s.track("gtr", "pluck", gain=0.9, pan=-0.25, reverb=0.2)
    s.track("bass", "bass", gain=0.7, reverb=0.05)
    s.track("fid", "strings", gain=0.55, pan=0.3, reverb=0.35)
    s.track("bell", "bell", gain=0.35, pan=-0.4, reverb=0.6)
    s.track("shk", "shaker", gain=0.3, pan=0.4, reverb=0.1)
    prog = ["F", "F", "C", "C", "Dm", "Dm", "Bb", "C", "F", "F", "C", "C", "Bb", "C", "F", "F",
            "Dm", "Dm", "Bb", "Bb", "F", "F", "C", "C", "Dm", "Bb", "F", "C", "Bb", "C", "F", "F"]
    for i, ch in enumerate(prog):
        b = i * 3
        v = CHORDS[ch]
        s.note("bass", b, midi(v[0]) - 12 + (7 if i % 2 else 0), 0.9, 0.7)
        s.chord("gtr", b + 1, v[2:], 0.45, 0.4)
        s.chord("gtr", b + 2, v[2:], 0.45, 0.35)
        for e in range(3):
            s.hit("shk", b + e, 0.6 if e == 0 else 0.35)
    m = [("A4", 1), ("D5", 1), ("E5", 1), ("F5", 2), ("E5", 1), ("D5", 1), ("C5", 1), ("E5", 1), ("G5", 3),
         ("F5", 1), ("A5", 1), ("G5", 1), ("F5", 1), ("D5", 2), ("D5", 1), ("E5", 1), ("F5", 1), ("E5", 2), ("C5", 1),
         ("A4", 1), ("D5", 1), ("E5", 1), ("F5", 2), ("G5", 1), ("A5", 1), ("G5", 1), ("E5", 1), ("C5", 3),
         ("D5", 1), ("F5", 1), ("Bb5", 1), ("A5", 2), ("G5", 1), ("F5", 3), ("F5", 2), (None, 1)]
    b2 = [("D5", 1), ("F5", 1), ("A5", 1), ("D6", 2), ("C6", 1), ("Bb5", 1), ("A5", 1), ("G5", 1), ("F5", 3),
          ("A5", 1), ("C6", 1), ("A5", 1), ("F5", 2), ("A5", 1), ("G5", 1), ("E5", 1), ("C5", 1), ("E5", 2), ("G5", 1),
          ("F5", 1), ("E5", 1), ("D5", 1), ("D5", 2), ("F5", 1), ("C5", 1), ("F5", 1), ("A5", 1), ("G5", 2), ("E5", 1),
          ("D5", 1), ("F5", 1), ("Bb5", 1), ("A5", 1), ("G5", 1), ("E5", 1), ("F5", 3), (None, 3)]
    melody(s, "acc", 0, m, 0.7, bpb=3)
    melody(s, "acc", 16, b2, 0.72, bpb=3)
    melody(s, "fid", 16, b2, 0.4, octave_shift=-1, bpb=3)
    echo(s, "bell", 0, m[:3], delay=1.5, vel=0.25, bpb=3)
    echo(s, "bell", 8, m[:3], delay=1.5, vel=0.25, bpb=3)
    return s


def harbour():
    """The quay: a slow shanty in 6/8, the echo on the squeezebox."""
    s = Song(bpm=220, bars=16, beats_per_bar=6, seed=101)
    s.track("acc", "accordion", gain=0.95, pan=0.15, reverb=0.3)
    s.track("acc2", "accordion", gain=0.45, pan=-0.3, reverb=0.3)
    s.track("bass", "bass", gain=0.75, reverb=0.05)
    s.track("gtr", "pluck", gain=0.6, pan=-0.2, reverb=0.25)
    s.track("kick", "kick", gain=0.55, reverb=0.1)
    s.track("brush", "brush", gain=0.5, pan=0.2, reverb=0.2)
    s.track("bell", "bell", gain=0.3, pan=0.4, reverb=0.8)
    prog = ["Dm", "Dm", "C", "C", "Bb", "Bb", "A", "A", "Dm", "Dm", "C", "C", "Bb", "A", "Dm", "Dm"]
    for i, ch in enumerate(prog):
        b = i * 6
        v = CHORDS[ch]
        s.note("bass", b, midi(v[0]) - 12, 2.5, 0.75)
        s.note("bass", b + 3, midi(v[0]) - 12 + 7, 2.5, 0.6)
        s.chord("acc2", b, v[1:], 2.6, 0.35)
        s.chord("acc2", b + 3, v[1:], 2.6, 0.3)
        s.chord("gtr", b + 1, v[1:], 0.9, 0.3, strum=0.05)
        s.chord("gtr", b + 4, v[1:], 0.9, 0.3, strum=0.05)
        s.hit("kick", b, 0.7)
        s.hit("brush", b + 3, 0.7)
    m = [("A4", 2), ("D5", 1), ("E5", 2), ("F5", 1), ("F5", 3), ("E5", 2), ("D5", 1),
         ("E5", 2), ("G5", 1), ("E5", 2), ("C5", 1), ("C5", 6),
         ("D5", 2), ("F5", 1), ("Bb5", 2), ("A5", 1), ("G5", 2), ("F5", 1), ("D5", 3),
         ("E5", 2), ("C#5", 1), ("E5", 2), ("A5", 1), ("A5", 6),
         ("A5", 2), ("F5", 1), ("D5", 2), ("F5", 1), ("A5", 3), ("D6", 3),
         ("C6", 2), ("A5", 1), ("G5", 2), ("E5", 1), ("C5", 3), ("E5", 3),
         ("D5", 2), ("F5", 1), ("Bb5", 2), ("D6", 1), ("C#6", 2), ("A5", 1), ("E5", 3),
         ("D5", 2), ("E5", 1), ("F5", 2), ("E5", 1), ("D5", 6)]
    melody(s, "acc", 0, m, 0.75, bpb=6)
    echo(s, "bell", 0, m[:4], delay=3, vel=0.22, bpb=6)
    echo(s, "bell", 8, m[24:28], delay=3, vel=0.22, bpb=6)
    return s


def village():
    """Mill Hill: flute over a nylon guitar, a Sunday afternoon."""
    s = Song(bpm=84, bars=16, seed=111)
    s.track("fl", "flute", gain=1.0, pan=0.1, reverb=0.35)
    s.track("gtr", "pluck", gain=0.8, pan=-0.2, reverb=0.25)
    s.track("bass", "bass", gain=0.55, reverb=0.05)
    s.track("pad", "pad", gain=0.45, reverb=0.5)
    s.track("bell", "bell", gain=0.3, pan=0.35, reverb=0.7)
    prog = ["F", "C", "Dm", "Bb", "F", "C", "Bb", "C", "Dm", "Am", "Bb", "F", "Gm7", "C", "F", "F"]
    for i, ch in enumerate(prog):
        arp(s, "gtr", i, ch, [0, 2, 3, 1, 2, 3, 1, 2], 0.5, 0.35)
        s.note("bass", i * 4, midi(root(ch)) - 12, 3.6, 0.5)
        s.chord("pad", i * 4, CHORDS[ch], 4, 0.3)
    m = [("A4", 1), ("D5", .5), ("E5", .5), ("F5", 2), ("G5", 1.5), ("E5", .5), ("C5", 2),
         ("D5", 1), ("F5", 1), ("A5", 2), ("G5", 1), ("F5", 1), ("D5", 2),
         ("C5", 1), ("F5", 1), ("A5", 1.5), ("G5", .5), ("E5", 3), (None, 1),
         ("D5", 1), ("F5", 1), ("Bb5", 1), ("A5", 1), ("G5", 4),
         ("A5", 1.5), ("D6", .5), ("C6", 1), ("A5", 1), ("C6", 2), ("E5", 2),
         ("F5", 1), ("Bb5", 1), ("A5", 1), ("G5", 1), ("A5", 3), (None, 1),
         ("Bb5", 1), ("A5", 1), ("G5", 1), ("F5", 1), ("E5", 1), ("G5", 1), ("C6", 2),
         ("A5", 1.5), ("G5", .5), ("F5", 2), ("F5", 3), (None, 1)]
    melody(s, "fl", 0, m, 0.6)
    echo(s, "bell", 0, m[:4], delay=2, vel=0.22)
    echo(s, "bell", 8, m[22:26], delay=2, vel=0.22)
    return s


def abbey():
    """St Brigid's: the echo as plainchant over an organ pedal."""
    s = Song(bpm=56, bars=12, seed=121)
    s.track("ch", "choir", gain=0.9, reverb=0.8)
    s.track("solo", "choir", gain=0.8, pan=0.1, reverb=0.85)
    s.track("org", "organ", gain=0.6, pan=-0.1, reverb=0.7)
    s.track("bell", "bell", gain=0.5, pan=-0.3, reverb=0.9)
    prog = ["Dm", "Dm", "C", "Dm", "F", "C", "G", "Dm", "F", "Am", "C", "Dm"]
    for i, ch in enumerate(prog):
        s.chord("ch", i * 4, CHORDS[ch][1:], 4, 0.35)
        s.note("org", i * 4, "D2", 4, 0.5)
        s.chord("org", i * 4, CHORDS[ch][:3], 4, 0.3)
        if i % 2 == 0:
            s.note("bell", i * 4, "D3", 3, 0.45)
    m = [("A4", 2), ("D5", 1), ("E5", 1), ("F5", 3), ("E5", 1), ("D5", 2), ("C5", 1), ("D5", 1), ("A4", 4),
         ("F5", 1), ("G5", 1), ("A5", 2), ("G5", 1), ("F5", 1), ("E5", 2), ("D5", 1), ("E5", 1), ("F5", 1), ("E5", 1),
         ("D5", 4), ("A5", 2), ("G5", 2), ("F5", 2), ("E5", 2), ("D5", 2), ("E5", 1), ("C5", 1), ("D5", 4)]
    melody(s, "solo", 0, m, 0.55, octave_shift=-1)
    return s


def tunnels():
    """The salt tunnels: drone, drips, and the echo very far away."""
    s = Song(bpm=70, bars=16, seed=131)
    s.track("drone", "bass", gain=0.6, reverb=0.4)
    s.track("pad", "pad", gain=0.8, reverb=0.8)
    s.track("str", "strings", gain=0.55, pan=-0.2, reverb=0.7)
    s.track("box", "musicbox", gain=0.55, pan=0.3, reverb=0.9)
    s.track("drip", "bell", gain=0.35, pan=0.0, reverb=0.9)
    s.track("timp", "timpani", gain=0.7, reverb=0.6)
    prog = ["Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "A", "A"] * 2
    for i, ch in enumerate(prog):
        b = i * 4
        s.note("drone", b, midi(root(ch)) - 12, 4, 0.55)
        s.chord("pad", b, CHORDS[ch][:3], 4, 0.3)
        if i % 2 == 0:
            s.hit("timp", b, 0.55)
        if i >= 8:
            s.note("str", b, midi(CHORDS[ch][-1]), 4, 0.3)
    drips = ["D6", "A6", "F6", "E6", "C6", "D7", "A5"]
    for k in range(22):
        b = float(s.rng.uniform(0, 16 * 4 - 1))
        s.note("drip", b, drips[int(s.rng.integers(0, len(drips)))], 0.4, float(s.rng.uniform(0.12, 0.3)))
    m = [("A4", 2), ("D5", 2), ("E5", 2), ("F5", 6), (None, 4), ("E5", 2), ("D5", 2), ("C#5", 4), (None, 8)]
    melody(s, "box", 2, m, 0.45)
    melody(s, "box", 10, m, 0.4, octave_shift=1)
    return s


def jonah():
    """Jonah Rook: warm, a little swung, a valve set humming in a back room."""
    s = Song(bpm=88, bars=16, seed=141)
    s.track("ep", "epiano", gain=0.85, pan=-0.15, reverb=0.3)
    s.track("mel", "epiano", gain=1.0, pan=0.15, reverb=0.35)
    s.track("bass", "bass", gain=0.65, reverb=0.05)
    s.track("brush", "brush", gain=0.45, pan=0.25, reverb=0.2)
    s.track("bell", "bell", gain=0.3, pan=-0.35, reverb=0.6)
    prog = ["Bb", "Gm", "Eb", "F", "Bb", "Gm", "Cm", "F", "Eb", "F", "Dm", "Gm", "Cm", "F", "Bb", "Bb"]
    for i, ch in enumerate(prog):
        b = i * 4
        s.chord("ep", b, CHORDS[ch][1:], 1.6, 0.32, strum=0.02)
        s.chord("ep", b + 2.66, CHORDS[ch][1:], 1.2, 0.26, strum=0.02)
        r = midi(root(ch)) - 12
        for k, iv in enumerate((0, 7, 12, 7)):
            s.note("bass", b + k, r + iv, 0.9, 0.55)
        s.hit("brush", b + 1, 0.55)
        s.hit("brush", b + 3, 0.55)
        s.hit("brush", b + 3.66, 0.3)
    m = [("F4", 1), ("Bb4", .5), ("C5", .5), ("D5", 2), ("D5", 1), ("Bb4", 1), ("G4", 2),
         ("G4", 1), ("Bb4", 1), ("Eb5", 1.5), ("D5", .5), ("C5", 4),
         ("F4", 1), ("Bb4", .5), ("C5", .5), ("D5", 1.5), ("F5", .5), ("G5", 2), ("F5", 1), ("D5", 1),
         ("Eb5", 1), ("D5", 1), ("C5", 1), ("Bb4", 1), ("C5", 3), (None, 1),
         ("G5", 1.5), ("F5", .5), ("Eb5", 1), ("G5", 1), ("F5", 2), ("C5", 2),
         ("D5", 1), ("F5", 1), ("A5", 1.5), ("F5", .5), ("G5", 2), ("D5", 2),
         ("Eb5", 1), ("G5", 1), ("C5", 1.5), ("D5", .5), ("C5", 1), ("F5", 1), ("A4", 2),
         ("Bb4", 1), ("D5", 1), ("F5", 2), ("Bb5", 3), (None, 1)]
    melody(s, "mel", 0, m, 0.55)
    echo(s, "bell", 0, m[:4], delay=2, vel=0.2)
    return s


def mara():
    """Mara Venn: a music-box waltz, every note filed in its place."""
    s = Song(bpm=104, bars=16, beats_per_bar=3, seed=151)
    s.track("box", "musicbox", gain=1.0, pan=0.2, reverb=0.4)
    s.track("pn", "piano", gain=0.7, pan=-0.15, reverb=0.3)
    s.track("tick", "pluck", gain=0.35, pan=0.4, reverb=0.15)
    s.track("str", "strings", gain=0.4, reverb=0.5)
    prog = ["Dm", "Gm", "C", "F", "Bb", "Gm", "A7", "Dm", "F", "C", "Dm", "Bb", "Gm", "C", "A", "Dm"]
    for i, ch in enumerate(prog):
        b = i * 3
        v = CHORDS[ch]
        s.note("pn", b, midi(v[0]) - 12, 2.8, 0.45)
        s.chord("pn", b + 1, v[1:], 0.8, 0.25)
        s.chord("pn", b + 2, v[1:], 0.8, 0.22)
        for e in range(3):
            s.note("tick", b + e, midi(v[-1]) + 12, 0.15, 0.25)
        if i >= 8:
            s.note("str", b, midi(v[-1]), 3, 0.28)
    m = [("A4", 1), ("D5", 1), ("E5", 1), ("F5", 1.5), ("E5", .5), ("D5", 1), ("E5", 1), ("G5", 1), ("C5", 1),
         ("F5", 2), ("A5", 1), ("Bb5", 1), ("A5", .5), ("G5", .5), ("F5", 1), ("G5", 1), ("D5", 2),
         ("C#5", 1), ("E5", 1), ("G5", 1), ("F5", 1), ("E5", 1), ("D5", 1),
         ("A5", 1), ("C6", 1), ("A5", 1), ("G5", 2), ("E5", 1), ("F5", 1), ("A5", 1), ("D6", 1),
         ("D6", 1.5), ("C6", .5), ("Bb5", 1), ("Bb5", 1), ("G5", 1), ("D5", 1), ("E5", 1), ("G5", 1), ("C6", 1),
         ("C#6", 1), ("A5", 1), ("E5", 1), ("D5", 3)]
    melody(s, "box", 0, m, 0.6, bpb=3)
    return s


def hester():
    """Hester Ashby: the lighthouse counts eight; for a long time, only seven."""
    s = Song(bpm=60, bars=16, seed=161)
    s.track("org", "organ", gain=0.6, reverb=0.6)
    s.track("fl", "flute", gain=0.9, pan=0.15, reverb=0.5)
    s.track("count", "bell", gain=0.5, pan=-0.3, reverb=0.7)
    s.track("bass", "bass", gain=0.5, reverb=0.2)
    prog = ["Dm", "Bb", "Asus", "Dm", "F", "C", "Am", "Dm", "Dm", "F", "Gm", "Dm", "F", "F", "Gm", "Dm"]
    for i, ch in enumerate(prog):
        s.chord("org", i * 4, CHORDS[ch][1:], 4, 0.3)
        s.note("bass", i * 4, midi(root(ch)) - 12, 4, 0.45)
    for start, full in ((0, False), (4, False), (8, True), (12, True)):
        for k in range(8):
            if k == 7 and not full:
                continue
            s.note("count", start * 4 + k, "A5" if k < 7 else "D6", 0.8, 0.3 if k < 7 else 0.4)
    m = [("A4", 2), ("D5", 2), ("E5", 2), ("F5", 2), ("E5", 4), ("D5", 4),
         ("F5", 2), ("A5", 2), ("G5", 2), ("F5", 2), ("E5", 3), ("C5", 1), ("D5", 4),
         ("A5", 2), ("D6", 2), ("C6", 2), ("A5", 2), ("Bb5", 2), ("G5", 2), ("A5", 4),
         ("F5", 2), ("G5", 2), ("A5", 2), ("C6", 2), ("Bb5", 2), ("A5", 2), ("A5", 4)]
    melody(s, "fl", 0, m, 0.55)
    return s


TRACKS = {"title": title, "day": day, "night": night, "interior": interior, "veil": veil,
          "combat": combat, "boss": boss, "epilogue": epilogue,
          "farm": farm, "harbour": harbour, "village": village, "abbey": abbey, "tunnels": tunnels,
          "jonah": jonah, "mara": mara, "hester": hester}


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
