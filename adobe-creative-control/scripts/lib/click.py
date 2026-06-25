#!/usr/bin/env python3
"""Post a hardware mouse click at absolute screen coordinates (points).
Usage: click.py X Y
Requires: pyobjc-framework-Quartz  (pip install --user pyobjc-framework-Quartz)
Needs the controlling terminal to have Accessibility permission.
"""
import sys
import time
import Quartz


def click(x, y):
    for ev in (Quartz.kCGEventMouseMoved,
               Quartz.kCGEventLeftMouseDown,
               Quartz.kCGEventLeftMouseUp):
        e = Quartz.CGEventCreateMouseEvent(
            None, ev, (x, y), Quartz.kCGMouseButtonLeft)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, e)
        time.sleep(0.08)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: click.py X Y")
    click(float(sys.argv[1]), float(sys.argv[2]))
    print("clicked", sys.argv[1], sys.argv[2])
