#!/usr/bin/env python3
"""
semaphore.py - Demonstrates semaphore for limiting concurrent access.

Equivalent to semaphore.c

Semaphores can limit the number of concurrent operations.
A semaphore with value N allows N tasks to proceed concurrently.
"""

import time
import cygcd


def work(task_id, sem):
    # Wait to acquire semaphore (decrement)
    sem.wait()
    print(f"Task {task_id} starting")
    time.sleep(1)
    print(f"Task {task_id} done")
    # Signal semaphore (increment)
    sem.signal()


def main():
    # Create semaphore allowing 2 concurrent tasks
    sem = cygcd.Semaphore(2)

    # Get a global queue
    q = cygcd.Queue.global_queue(cygcd.QOS_CLASS_DEFAULT)

    # Submit 5 tasks - only 2 will run at a time
    for i in range(1, 6):
        q.run_async(lambda i=i: work(i, sem))

    # Allow tasks to finish
    time.sleep(6)


if __name__ == "__main__":
    main()
