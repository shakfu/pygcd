#!/usr/bin/env python3
"""
Example: Workloops

Demonstrates using dispatch workloops for priority-inversion-avoiding execution.
Workloops are specialized queues designed for scenarios where work items
have varying priorities and priority inversion must be avoided.
"""

import cygcd
import time


def main():
    print("=== Workloop Example ===\n")

    # Create a basic workloop
    print("Creating workloop...")
    wl = cygcd.Workloop("com.example.workloop")
    print(f"Workloop created, is_inactive: {wl.is_inactive}")

    # --- Basic Async Execution ---
    print("\n=== Basic Async Execution ===\n")

    results = []

    def task(n):
        results.append(n)
        print(f"  Task {n} executed")

    print("Submitting tasks...")
    for i in range(5):
        wl.run_async(lambda i=i: task(i))

    # Wait for completion using run_sync
    wl.run_sync(lambda: None)

    print(f"\nResults: {results}")

    # --- Synchronous Execution ---
    print("\n=== Synchronous Execution ===\n")

    sync_results = []

    print("Running synchronous tasks...")
    for i in range(3):
        wl.run_sync(lambda i=i: sync_results.append(f"sync_{i}"))
        print(f"  Completed sync task {i}")

    print(f"Results: {sync_results}")

    # --- Inactive Workloop ---
    print("\n=== Inactive Workloop ===\n")

    print("Creating inactive workloop...")
    inactive_wl = cygcd.Workloop("com.example.inactive", inactive=True)
    print(f"Created, is_inactive: {inactive_wl.is_inactive}")

    # Note: Cannot submit work to inactive workloop
    # This would raise RuntimeError:
    # inactive_wl.run_async(lambda: print("This would fail!"))

    print("Attempting to submit work to inactive workloop...")
    try:
        inactive_wl.run_async(lambda: None)
    except RuntimeError as e:
        print(f"  Caught expected error: {e}")

    print("\nActivating workloop...")
    inactive_wl.activate()
    print(f"Activated, is_inactive: {inactive_wl.is_inactive}")

    # Now we can submit work
    inactive_wl.run_sync(lambda: print("  Work executed on activated workloop!"))

    # --- Use Case: Task Processing ---
    print("\n=== Use Case: Task Processing ===\n")

    processor = cygcd.Workloop("com.example.processor")
    processed = []

    def process_item(item):
        # Simulate processing
        time.sleep(0.01)
        processed.append(item.upper())

    items = ["apple", "banana", "cherry", "date", "elderberry"]
    print(f"Processing {len(items)} items...")

    start = time.time()
    for item in items:
        processor.run_async(lambda item=item: process_item(item))

    processor.run_sync(lambda: None)
    elapsed = time.time() - start

    print(f"Processed in {elapsed:.3f}s: {processed}")

    # --- Workloop vs Queue Comparison ---
    print("\n=== Workloop vs Queue ===\n")

    print("Workloops differ from regular queues:")
    print("  - Designed to avoid priority inversion")
    print("  - Work cannot be submitted while inactive")
    print("  - Ideal for priority-sensitive workloads")

    # Regular queue for comparison
    q = cygcd.Queue("com.example.queue")
    q_results = []
    wl_results = []

    work_wl = cygcd.Workloop("com.example.compare")

    print("\nRunning same tasks on queue and workloop...")

    for i in range(3):
        q.run_async(lambda i=i: q_results.append(i))
        work_wl.run_async(lambda i=i: wl_results.append(i))

    q.run_sync(lambda: None)
    work_wl.run_sync(lambda: None)

    print(f"  Queue results: {q_results}")
    print(f"  Workloop results: {wl_results}")

    print("\nDone!")


if __name__ == "__main__":
    main()
