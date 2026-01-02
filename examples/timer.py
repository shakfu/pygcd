#!/usr/bin/env python3
"""
timer.py - Demonstrates dispatch timer sources.

Timers fire repeatedly at specified intervals or once after a delay.
"""

import time
import cygcd


def main():
    print("=== Repeating Timer ===")
    count = [0]

    def tick():
        count[0] += 1
        print(f"Tick {count[0]} at {time.time():.2f}")

    # Create a repeating timer that fires every 0.3 seconds
    timer = cygcd.Timer(0.3, tick)
    timer.start()

    time.sleep(1.5)
    timer.cancel()
    print(f"Cancelled after {count[0]} ticks\n")

    print("=== One-Shot Timer ===")

    def delayed_action():
        print("One-shot timer fired!")

    # Create a one-shot timer that fires once after 0.5 seconds
    one_shot = cygcd.Timer(0.0, delayed_action, start_delay=0.5, repeating=False)
    one_shot.start()

    time.sleep(1.0)
    one_shot.cancel()

    print("\n=== Timer with Start Delay ===")
    start = time.time()

    def report():
        elapsed = time.time() - start
        print(f"Timer fired at {elapsed:.2f}s")

    # Timer that waits 0.3s before first fire, then fires every 0.2s
    delayed = cygcd.Timer(0.2, report, start_delay=0.3)
    delayed.start()

    time.sleep(1.0)
    delayed.cancel()

    print("\n=== Reconfiguring Timer ===")
    fire_count = [0]

    def counter():
        fire_count[0] += 1
        print(f"Fire {fire_count[0]}")

    # Start slow
    reconfig = cygcd.Timer(0.5, counter)
    reconfig.start()

    time.sleep(0.6)
    print("Speeding up timer...")

    # Make it faster
    reconfig.set_timer(0.1)

    time.sleep(0.5)
    reconfig.cancel()

    print(f"\nTotal fires: {fire_count[0]}")


if __name__ == "__main__":
    main()
