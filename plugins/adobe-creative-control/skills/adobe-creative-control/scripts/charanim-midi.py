#!/usr/bin/env python3
"""Drive Adobe Character Animator live via MIDI.

CharAnim has no scripting/AppleScript/CLI. Its one external control channel is
MIDI: Triggers and behavior parameters can be bound to MIDI notes/CC, and MIDI
is received even when CharAnim is not the focused app.

This creates a system-visible virtual MIDI port and sends notes/CC to it.
One-time GUI step in CharAnim: open a puppet -> Controls panel -> bind a Trigger
to the same note (e.g. 72 = C5). After that, running this fires the trigger.

Deps: pip install --user mido python-rtmidi
Usage:
  charanim-midi.py note 72            # send note_on/off 72
  charanim-midi.py cc 1 64            # control change: controller 1 -> 64
  charanim-midi.py hold 72 30         # hold a virtual port 30s, pulsing note 72/sec
  charanim-midi.py ports              # list current MIDI output ports
"""
import sys
import time
import mido

PORT_NAME = "ClaudeCharAnim"


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd = sys.argv[1]

    if cmd == "ports":
        print("outputs:", mido.get_output_names())
        print("inputs:", mido.get_input_names())
        return

    out = mido.open_output(PORT_NAME, virtual=True)
    print("virtual MIDI port up:", PORT_NAME)

    if cmd == "note":
        n = int(sys.argv[2])
        out.send(mido.Message("note_on", note=n, velocity=100))
        time.sleep(0.15)
        out.send(mido.Message("note_off", note=n))
        print("sent note", n)
    elif cmd == "cc":
        c, v = int(sys.argv[2]), int(sys.argv[3])
        out.send(mido.Message("control_change", control=c, value=v))
        print("sent cc", c, v)
    elif cmd == "hold":
        n = int(sys.argv[2]); secs = float(sys.argv[3])
        t0 = time.time()
        while time.time() - t0 < secs:
            out.send(mido.Message("note_on", note=n, velocity=100))
            time.sleep(0.1)
            out.send(mido.Message("note_off", note=n))
            time.sleep(0.9)
        print("held %ss, pulsed note %d" % (secs, n))
    else:
        out.close()
        sys.exit(__doc__)
    out.close()


if __name__ == "__main__":
    main()
