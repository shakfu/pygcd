# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-01-02

### Added

- Initial release of pygcd - Python wrapper for macOS Grand Central Dispatch

#### Core Classes

- `Queue` - Dispatch queue wrapper (serial and concurrent)
  - `run_async(func)` - Asynchronous task execution
  - `run_sync(func)` - Synchronous task execution
  - `barrier_async(func)` - Barrier for concurrent queues (async)
  - `barrier_sync(func)` - Barrier for concurrent queues (sync)
  - `after(delay, func)` - Delayed task execution
  - `global_queue(priority)` - Access to system global queues
  - `main_queue()` - Access to main thread queue
  - `suspend()` / `resume()` - Queue execution control
  - `label` property - Queue label for debugging

- `Group` - Track completion of multiple tasks
  - `run_async(queue, func)` - Submit task to group
  - `wait(timeout)` - Wait for all tasks to complete
  - `notify(queue, func)` - Notification when group completes
  - `enter()` / `leave()` - Manual task tracking

- `Semaphore` - Counting semaphore for resource limiting
  - `wait(timeout)` - Decrement semaphore (block if zero)
  - `signal()` - Increment semaphore

- `Once` - Thread-safe one-time execution

- `Timer` - Dispatch source timer
  - `start()` - Start the timer
  - `cancel()` - Cancel the timer
  - `set_timer(interval, ...)` - Reconfigure timer parameters
  - `is_cancelled` property - Check cancellation status
  - Supports repeating and one-shot timers
  - Configurable leeway for power optimization

#### Functions

- `apply(iterations, func, queue)` - Parallel for loop
- `time_from_now(seconds)` - Create dispatch time (monotonic clock)
- `walltime(timestamp, delta_seconds)` - Create dispatch time (wall clock)

#### Constants

- Time constants: `DISPATCH_TIME_NOW`, `DISPATCH_TIME_FOREVER`, `NSEC_PER_SEC`, etc.
- Queue priorities: `QUEUE_PRIORITY_HIGH`, `QUEUE_PRIORITY_DEFAULT`, `QUEUE_PRIORITY_LOW`, `QUEUE_PRIORITY_BACKGROUND`
- QOS classes: `QOS_CLASS_USER_INTERACTIVE`, `QOS_CLASS_USER_INITIATED`, `QOS_CLASS_DEFAULT`, `QOS_CLASS_UTILITY`, `QOS_CLASS_BACKGROUND`

#### Examples

- `serial_queue.py` - Serial FIFO execution
- `concurrent_queue.py` - Concurrent queue with barriers
- `semaphore.py` - Resource limiting with semaphores
- `dispatch_once.py` - One-time initialization
- `gcd_groups.py` - Task groups and notifications
- `parallel_apply.py` - Parallel loop execution
- `producer_consumer.py` - Semaphore-based coordination
- `delayed_execution.py` - Scheduled delayed tasks

#### Technical

- All GCD operations release the Python GIL via `nogil` for true parallelism
- Proper reference counting for dispatch objects
- Trampoline callbacks that safely acquire GIL for Python execution
