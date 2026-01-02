#!/usr/bin/env python3
"""
gcd_groups.py - Demonstrates dispatch groups.

Equivalent to gcd_noblocks.c

Groups allow you to aggregate multiple tasks and wait for all
of them to complete, or be notified when they complete.
"""

import random
import time
import cygcd


def do_work(task_id):
    # Simulate variable work time
    sleep_time = 0.2 + random.random() * 0.6
    time.sleep(sleep_time)
    print(f"Task {task_id} done (work: {sleep_time:.3f}s)")


def all_done():
    print("All tasks completed!")


def main():
    # Get a global queue with high priority
    q = cygcd.Queue.global_queue(cygcd.QOS_CLASS_USER_INITIATED)

    # Create a group to track tasks
    g = cygcd.Group()

    print("Scheduling tasks...")

    # Submit 5 tasks to the group
    for i in range(1, 6):
        g.run_async(q, lambda i=i: do_work(i))

    # Set up notification when all tasks complete
    notify_queue = cygcd.Queue("com.example.notify")
    g.notify(notify_queue, all_done)

    # Wait for all tasks to complete
    g.wait()

    # Ensure notification runs
    notify_queue.run_sync(lambda: None)


if __name__ == "__main__":
    main()
