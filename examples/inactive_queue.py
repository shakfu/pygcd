#!/usr/bin/env python3
"""
Example: Inactive Queues

Demonstrates creating queues in an inactive state, configuring them,
and then activating them to begin processing work.
"""

import pygcd
import time


def main():
    print("=== Inactive Queue Example ===\n")

    # Create an inactive queue
    print("Creating inactive queue...")
    q = pygcd.Queue("com.example.inactive", inactive=True)
    print(f"Queue created, is_inactive: {q.is_inactive}")

    # Submit work to the inactive queue
    # Work will be queued but not executed until activation
    results = []

    print("\nSubmitting 5 tasks to inactive queue...")
    for i in range(5):
        q.run_async(lambda i=i: results.append(f"Task {i} executed"))
        print(f"  Submitted task {i}")

    # Verify nothing has executed yet
    time.sleep(0.1)
    print(f"\nResults before activation: {results}")
    print(f"(Queue is still inactive: {q.is_inactive})")

    # Activate the queue
    print("\nActivating queue...")
    q.activate()
    print(f"Queue activated, is_inactive: {q.is_inactive}")

    # Wait for all tasks to complete
    q.run_sync(lambda: None)

    print(f"\nResults after activation: {results}")

    # --- Inactive Concurrent Queue ---
    print("\n=== Inactive Concurrent Queue ===\n")

    cq = pygcd.Queue("com.example.inactive.concurrent", concurrent=True, inactive=True)
    print(f"Concurrent queue created, is_inactive: {cq.is_inactive}")

    concurrent_results = []

    print("Submitting tasks...")
    for i in range(3):
        cq.run_async(lambda i=i: concurrent_results.append(i))

    time.sleep(0.1)
    print(f"Results before activation: {concurrent_results}")

    cq.activate()
    cq.barrier_sync(lambda: None)

    print(f"Results after activation: {sorted(concurrent_results)}")

    # --- Use Case: Batch Configuration ---
    print("\n=== Use Case: Batch Configuration ===\n")

    # Create inactive queue with QOS
    batch_q = pygcd.Queue(
        "com.example.batch",
        qos=pygcd.QOS_CLASS_UTILITY,
        inactive=True
    )

    # Set up target queue hierarchy while inactive
    parent = pygcd.Queue("com.example.parent")
    batch_q.set_target_queue(parent)

    print("Configured queue with QOS and target while inactive")
    print(f"Activating...")
    batch_q.activate()

    batch_q.run_sync(lambda: print("Batch queue is now processing!"))

    print("\nDone!")


if __name__ == "__main__":
    main()
