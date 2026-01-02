#!/usr/bin/env python3
"""
concurrent_queue.py - Demonstrates concurrent queue with barriers.

Equivalent to concurrent_queue.c

Concurrent queues can execute multiple tasks simultaneously.
Barrier tasks wait for all previous tasks to complete before executing,
and block subsequent tasks until the barrier completes.
"""

import time
import cygcd

value = 0


def reader():
    print(f"read: {value}")


def writer():
    global value
    value += 1
    print(f"write: {value}")


def main():
    # Create a concurrent queue
    q = cygcd.Queue("com.example.concurrent", concurrent=True)

    # Submit reader tasks (may run concurrently)
    q.run_async(reader)
    q.run_async(reader)

    # Barrier write - waits for readers, runs exclusively
    q.barrier_async(writer)

    # More readers (will run after barrier completes)
    q.run_async(reader)

    # Wait for all tasks to complete
    time.sleep(0.5)


if __name__ == "__main__":
    main()
