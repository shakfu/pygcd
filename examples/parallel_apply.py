#!/usr/bin/env python3
"""
parallel_apply.py - Demonstrates parallel apply.

Apply executes a callable N times, potentially in parallel.
Each invocation receives its iteration index.
This is useful for parallelizing loops.
"""

import threading
import time
import pygcd

results = []
lock = threading.Lock()


def process_item(index):
    # Simulate some work
    time.sleep(0.1)
    with lock:
        results.append(index * index)
    print(f"Processed item {index}: {index * index}")


def main():
    print("Processing 10 items in parallel...")
    start = time.time()

    # Execute process_item 10 times in parallel
    pygcd.apply(10, process_item)

    elapsed = time.time() - start
    print(f"\nCompleted in {elapsed:.2f}s")
    print(f"Results: {sorted(results)}")

    # Compare with serial execution time
    serial_time = 10 * 0.1
    print(f"Serial would take ~{serial_time:.1f}s")


if __name__ == "__main__":
    main()
