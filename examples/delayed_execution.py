#!/usr/bin/env python3
"""
delayed_execution.py - Demonstrates delayed task execution.

Equivalent to timers.c

Schedule tasks to execute after a delay.
"""

import time
import cygcd


def main():
    q = cygcd.Queue("com.example.timer")
    start = time.time()

    def report(label):
        elapsed = time.time() - start
        print(f"{label}: executed at {elapsed:.2f}s")

    print("Scheduling tasks...")

    # Schedule tasks at different delays
    q.after(0.5, lambda: report("Task A (0.5s delay)"))
    q.after(1.0, lambda: report("Task B (1.0s delay)"))
    q.after(0.25, lambda: report("Task C (0.25s delay)"))

    # Expected order: C, A, B

    # Wait for all tasks to complete
    time.sleep(1.5)
    q.run_sync(lambda: None)

    print("Done!")


if __name__ == "__main__":
    main()
