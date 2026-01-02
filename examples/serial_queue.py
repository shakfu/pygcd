#!/usr/bin/env python3
"""
serial_queue.py - Demonstrates serial queue execution.

Equivalent to serial_queue.c

Serial queues execute tasks one at a time in FIFO order.
"""

import cygcd

counter = 0


def increment():
    global counter
    counter += 1
    print(f"counter = {counter}")


def main():
    # Create a serial queue
    serial = cygcd.Queue("com.example.serial")

    # Submit 5 tasks
    for _ in range(5):
        serial.run_async(increment)

    # Wait until queue drains (safe exit)
    serial.run_sync(lambda: None)


if __name__ == "__main__":
    main()
