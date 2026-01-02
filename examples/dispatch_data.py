#!/usr/bin/env python3
"""
Example: Dispatch Data

Demonstrates using dispatch_data for efficient buffer management.
Data objects are immutable and support zero-copy operations where possible.
"""

import cygcd


def main():
    print("=== Dispatch Data Example ===\n")

    # Create empty data
    print("Creating empty Data:")
    empty = cygcd.Data()
    print(f"  Size: {len(empty)}")
    print(f"  Bytes: {bytes(empty)!r}")

    # Create data from bytes
    print("\nCreating Data from bytes:")
    data1 = cygcd.Data(b"Hello, ")
    data2 = cygcd.Data(b"World!")
    print(f"  data1: {bytes(data1)!r} (size={len(data1)})")
    print(f"  data2: {bytes(data2)!r} (size={len(data2)})")

    # Concatenate data
    print("\nConcatenating data:")
    combined = data1.concat(data2)
    print(f"  combined: {bytes(combined)!r} (size={len(combined)})")

    # Note: Original data is unchanged (immutable)
    print(f"  data1 unchanged: {bytes(data1)!r}")

    # Create subrange
    print("\nExtracting subranges:")
    message = cygcd.Data(b"The quick brown fox jumps over the lazy dog")
    print(f"  Original: {bytes(message)!r}")

    # Extract "quick"
    quick = message.subrange(4, 5)
    print(f"  subrange(4, 5): {bytes(quick)!r}")

    # Extract "fox"
    fox = message.subrange(16, 3)
    print(f"  subrange(16, 3): {bytes(fox)!r}")

    # Extract "lazy dog"
    lazy_dog = message.subrange(35, 8)
    print(f"  subrange(35, 8): {bytes(lazy_dog)!r}")

    # Chaining operations
    print("\nChaining operations:")
    part1 = cygcd.Data(b"[START]")
    part2 = cygcd.Data(b"--MIDDLE--")
    part3 = cygcd.Data(b"[END]")

    result = part1.concat(part2).concat(part3)
    print(f"  Chained: {bytes(result)!r}")

    # Extract middle portion
    middle = result.subrange(7, 10)
    print(f"  Middle extracted: {bytes(middle)!r}")

    # Working with binary data
    print("\nWorking with binary data:")
    binary = cygcd.Data(bytes([0x00, 0x01, 0x02, 0xFF, 0xFE, 0xFD]))
    print(f"  Binary data: {bytes(binary).hex()}")
    print(f"  Size: {binary.size} bytes")

    # Subrange of binary
    subset = binary.subrange(3, 3)
    print(f"  Last 3 bytes: {bytes(subset).hex()}")

    # Use case: Building a packet
    print("\n=== Use Case: Building a Network Packet ===\n")

    header = cygcd.Data(b"\x01\x02")  # Version, flags
    length = cygcd.Data(b"\x00\x0B")  # Payload length (11 bytes)
    payload = cygcd.Data(b"Hello World")
    checksum = cygcd.Data(b"\xFF")  # Dummy checksum

    packet = header.concat(length).concat(payload).concat(checksum)
    print(f"  Packet ({len(packet)} bytes): {bytes(packet).hex()}")

    # Parse packet back
    print("\n  Parsing packet:")
    print(f"    Header: {bytes(packet.subrange(0, 2)).hex()}")
    print(f"    Length: {bytes(packet.subrange(2, 2)).hex()}")
    print(f"    Payload: {bytes(packet.subrange(4, 11))!r}")
    print(f"    Checksum: {bytes(packet.subrange(15, 1)).hex()}")

    print("\nDone!")


if __name__ == "__main__":
    main()
