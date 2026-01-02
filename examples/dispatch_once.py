#!/usr/bin/env python3
"""
dispatch_once.py - Demonstrates one-time initialization.

Equivalent to dispatch_once.c

Once ensures a callable is executed exactly once, even when
called from multiple threads simultaneously.
"""

import time
import pygcd

once = pygcd.Once()
expensive_resource = None


def init_resource():
    global expensive_resource
    expensive_resource = 42
    print("Initialized resource")


def use_resource():
    # Initialize once, even if called from multiple threads
    once(init_resource)
    print(f"Resource value = {expensive_resource}")


def main():
    q = pygcd.Queue.global_queue(pygcd.QOS_CLASS_DEFAULT)

    # Submit multiple tasks that all try to initialize
    for _ in range(3):
        q.run_async(use_resource)

    time.sleep(1)


if __name__ == "__main__":
    main()
