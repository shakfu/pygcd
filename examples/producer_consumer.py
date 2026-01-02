#!/usr/bin/env python3
"""
producer_consumer.py - Demonstrates producer-consumer pattern.

Equivalent to producer_worker.c

Uses a semaphore to coordinate between producer and consumer tasks.
"""

import time
import cygcd


def main():
    q = cygcd.Queue.global_queue()

    # Semaphore starts at 0 - consumer must wait for producer
    sem = cygcd.Semaphore(0)

    # Shared data
    data = {"value": None}

    def producer():
        print("Producer: creating data...")
        time.sleep(0.5)
        data["value"] = 42
        print("Producer: data ready, signaling consumer")
        sem.signal()

    def consumer():
        print("Consumer: waiting for data...")
        sem.wait()
        print(f"Consumer: received data = {data['value']}")

    # Start consumer first - it will wait
    q.run_async(consumer)

    # Then start producer
    q.run_async(producer)

    # Wait for completion
    time.sleep(2)


if __name__ == "__main__":
    main()
