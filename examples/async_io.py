#!/usr/bin/env python3
"""
Example: Asynchronous I/O

Demonstrates using read_async and write_async for non-blocking file operations.
"""

import cygcd
import os
import tempfile


def main():
    print("=== Async I/O Example ===\n")

    # Create a temporary file for testing
    with tempfile.NamedTemporaryFile(delete=False) as f:
        temp_path = f.name
        f.write(b"Hello from async I/O!\nLine 2\nLine 3\n")

    try:
        # --- Async Read Example ---
        print("=== Async Read ===\n")

        fd = os.open(temp_path, os.O_RDONLY)
        read_results = []
        sem = cygcd.Semaphore(0)

        def on_read_complete(data, error):
            if error == 0:
                read_results.append(data)
                print(f"  Read completed: {len(data)} bytes")
            else:
                print(f"  Read error: {error}")
            sem.signal()

        print(f"Reading from file: {temp_path}")
        cygcd.read_async(fd, 1024, on_read_complete)

        # Wait for completion
        sem.wait()
        os.close(fd)

        print(f"  Data read: {read_results[0]!r}")

        # --- Async Write Example ---
        print("\n=== Async Write ===\n")

        # Create new temp file for writing
        with tempfile.NamedTemporaryFile(delete=False) as f:
            write_path = f.name

        fd = os.open(write_path, os.O_WRONLY | os.O_TRUNC)
        write_sem = cygcd.Semaphore(0)
        bytes_written = [0]

        def on_write_complete(data, error):
            if error == 0:
                # data contains any unwritten portion (empty if all written)
                bytes_written[0] = 26 - len(data) if data else 26
                print(f"  Write completed")
            else:
                print(f"  Write error: {error}")
            write_sem.signal()

        message = b"Written asynchronously!\n"
        print(f"Writing {len(message)} bytes to file...")
        cygcd.write_async(fd, message, on_write_complete)

        # Wait for completion
        write_sem.wait()
        os.close(fd)

        # Verify the write
        with open(write_path, 'rb') as f:
            content = f.read()
        print(f"  File contents: {content!r}")

        os.unlink(write_path)

        # --- Async I/O with Custom Queue ---
        print("\n=== Async I/O with Custom Queue ===\n")

        q = cygcd.Queue("com.example.io", qos=cygcd.QOS_CLASS_UTILITY)
        fd = os.open(temp_path, os.O_RDONLY)
        queue_sem = cygcd.Semaphore(0)

        def on_read_with_queue(data, error):
            print(f"  Callback on queue (data={len(data)} bytes)")
            queue_sem.signal()

        print("Reading with custom queue...")
        cygcd.read_async(fd, 100, on_read_with_queue, queue=q)

        queue_sem.wait()
        os.close(fd)

        # --- Multiple Concurrent Reads ---
        print("\n=== Multiple Concurrent Reads ===\n")

        # Create multiple files
        paths = []
        for i in range(3):
            with tempfile.NamedTemporaryFile(delete=False, mode='w') as f:
                f.write(f"Content of file {i}")
                paths.append(f.name)

        fds = [os.open(p, os.O_RDONLY) for p in paths]
        results = {}
        count_sem = cygcd.Semaphore(0)

        def make_handler(idx):
            def handler(data, error):
                results[idx] = data if error == 0 else f"error:{error}"
                count_sem.signal()
            return handler

        print("Starting 3 concurrent reads...")
        for i, fd in enumerate(fds):
            cygcd.read_async(fd, 100, make_handler(i))

        # Wait for all reads
        for _ in range(3):
            count_sem.wait()

        for fd in fds:
            os.close(fd)

        print("Results:")
        for i in sorted(results.keys()):
            print(f"  File {i}: {results[i]!r}")

        # Cleanup
        for p in paths:
            os.unlink(p)

    finally:
        os.unlink(temp_path)

    print("\nDone!")


if __name__ == "__main__":
    main()
