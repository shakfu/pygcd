#!/usr/bin/env python3
"""
Example: High-performance async I/O with IOChannel.

IOChannel provides true dispatch_io functionality with:
- Automatic chunking via high/low water marks
- Efficient async read/write operations
- Barrier synchronization
- Cleanup handlers

This example demonstrates reading a file in chunks and writing data.
"""

import os
import tempfile
import cygcd


def example_chunked_read():
    """Read a file in chunks using high water mark."""
    print("=== Chunked Read Example ===")

    # Create a test file with some data
    test_data = b"Hello, IOChannel! " * 1000  # ~18KB
    print(f"Test data size: {len(test_data)} bytes")

    with tempfile.NamedTemporaryFile(delete=False) as f:
        f.write(test_data)
        path = f.name

    try:
        fd = os.open(path, os.O_RDONLY)
        channel = cygcd.IOChannel(fd, cygcd.IO_STREAM)

        # Set high water mark to receive data in chunks
        channel.set_high_water(4096)  # 4KB chunks

        chunks = []
        sem = cygcd.Semaphore(0)

        def on_read(done, data, error):
            if error:
                print(f"  Read error: {error}")
            if data:
                chunks.append(data)
                print(f"  Received chunk: {len(data)} bytes")
            if done:
                print("  Read complete!")
                sem.signal()

        print("Starting chunked read...")
        channel.read(len(test_data), on_read)

        # Wait for completion
        sem.wait()

        channel.close()
        os.close(fd)

        # Verify all data was received
        all_data = b"".join(chunks)
        print(f"Total chunks: {len(chunks)}")
        print(f"Total bytes: {len(all_data)}")
        print(f"Data matches: {all_data == test_data}")
    finally:
        os.unlink(path)

    print()


def example_async_write():
    """Write data asynchronously."""
    print("=== Async Write Example ===")

    test_data = b"Writing via dispatch_io! " * 100

    with tempfile.NamedTemporaryFile(delete=False) as f:
        path = f.name

    try:
        fd = os.open(path, os.O_WRONLY | os.O_TRUNC)
        channel = cygcd.IOChannel(fd, cygcd.IO_STREAM)

        sem = cygcd.Semaphore(0)
        write_results = []

        def on_write(done, remaining, error):
            write_results.append((done, len(remaining), error))
            if error:
                print(f"  Write error: {error}")
            if done:
                print("  Write complete!")
                sem.signal()

        print(f"Writing {len(test_data)} bytes...")
        channel.write(test_data, on_write)

        sem.wait()
        channel.close()
        os.close(fd)

        # Verify
        with open(path, "rb") as f:
            written = f.read()
        print(f"Bytes written: {len(written)}")
        print(f"Data matches: {written == test_data}")
    finally:
        os.unlink(path)

    print()


def example_barrier():
    """Use barrier to synchronize after multiple operations."""
    print("=== Barrier Synchronization Example ===")

    with tempfile.NamedTemporaryFile(delete=False) as f:
        f.write(b"Line 1\nLine 2\nLine 3\n")
        path = f.name

    try:
        fd = os.open(path, os.O_RDONLY)
        channel = cygcd.IOChannel(fd, cygcd.IO_STREAM)

        operations = []
        sem = cygcd.Semaphore(0)

        def on_read(done, data, error):
            if data:
                operations.append(f"read: {len(data)} bytes")

        def on_barrier():
            operations.append("barrier executed")
            print("  Barrier handler called - all reads complete")
            sem.signal()

        # Submit multiple reads
        print("Submitting reads and barrier...")
        channel.read(10, on_read)
        channel.read(10, on_read)
        channel.barrier(on_barrier)

        sem.wait()
        channel.close()
        os.close(fd)

        print(f"Operations in order: {operations}")
    finally:
        os.unlink(path)

    print()


def example_cleanup_handler():
    """Demonstrate cleanup handler."""
    print("=== Cleanup Handler Example ===")

    with tempfile.NamedTemporaryFile(delete=False) as f:
        f.write(b"test")
        path = f.name

    try:
        fd = os.open(path, os.O_RDONLY)
        cleanup_called = [False]

        def on_cleanup(error):
            cleanup_called[0] = True
            print(f"  Cleanup handler called with error={error}")

        channel = cygcd.IOChannel(fd, cygcd.IO_STREAM,
                                  cleanup_handler=on_cleanup)

        print("Closing channel...")
        channel.close()

        # Give cleanup handler time to execute
        import time
        time.sleep(0.1)

        os.close(fd)
        print(f"Cleanup was called: {cleanup_called[0]}")
    finally:
        os.unlink(path)

    print()


def example_random_access():
    """Read from specific offsets using IO_RANDOM."""
    print("=== Random Access Example ===")

    test_data = b"0123456789ABCDEFGHIJ"

    with tempfile.NamedTemporaryFile(delete=False) as f:
        f.write(test_data)
        path = f.name

    try:
        fd = os.open(path, os.O_RDONLY)
        channel = cygcd.IOChannel(fd, cygcd.IO_RANDOM)

        results = {}
        sem = cygcd.Semaphore(0)
        pending = [2]  # Two reads

        def make_handler(offset):
            def on_read(done, data, error):
                if data:
                    results[offset] = data
                if done:
                    pending[0] -= 1
                    if pending[0] == 0:
                        sem.signal()
            return on_read

        print("Reading from offset 0 and 10...")
        channel.read(5, make_handler(0), offset=0)
        channel.read(5, make_handler(10), offset=10)

        sem.wait()
        channel.close()
        os.close(fd)

        print(f"Data at offset 0: {results.get(0)}")
        print(f"Data at offset 10: {results.get(10)}")
    finally:
        os.unlink(path)

    print()


if __name__ == "__main__":
    example_chunked_read()
    example_async_write()
    example_barrier()
    example_cleanup_handler()
    example_random_access()
    print("All examples completed!")
