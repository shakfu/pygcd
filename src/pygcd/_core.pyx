# cython: language_level=3
"""
pygcd - Python wrapper for macOS Grand Central Dispatch (GCD).

Provides Python bindings to Apple's GCD framework for concurrent programming.
"""

from libc.stdint cimport uint64_t, int64_t, intptr_t, uintptr_t
from posix.types cimport off_t
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
from cpython.exc cimport PyErr_Occurred, PyErr_Print

# Time constants
DEF NSEC_PER_SEC = 1000000000
DEF NSEC_PER_MSEC = 1000000
DEF NSEC_PER_USEC = 1000
DEF USEC_PER_SEC = 1000000
DEF MSEC_PER_SEC = 1000

# Export time constants to Python
NSEC_PER_SEC_PY = NSEC_PER_SEC
NSEC_PER_MSEC_PY = NSEC_PER_MSEC
NSEC_PER_USEC_PY = NSEC_PER_USEC
USEC_PER_SEC_PY = USEC_PER_SEC
MSEC_PER_SEC_PY = MSEC_PER_SEC

# Time special values (DISPATCH_TIME_FOREVER is ~0ULL = 0xFFFFFFFFFFFFFFFF)
DEF _DISPATCH_TIME_NOW = 0
DEF _DISPATCH_TIME_FOREVER = 0xFFFFFFFFFFFFFFFF

DISPATCH_TIME_NOW = _DISPATCH_TIME_NOW
DISPATCH_TIME_FOREVER = _DISPATCH_TIME_FOREVER

# Queue priority constants
DEF _DISPATCH_QUEUE_PRIORITY_HIGH = 2
DEF _DISPATCH_QUEUE_PRIORITY_DEFAULT = 0
DEF _DISPATCH_QUEUE_PRIORITY_LOW = -2
DEF _DISPATCH_QUEUE_PRIORITY_BACKGROUND = -32768  # INT16_MIN

QUEUE_PRIORITY_HIGH = _DISPATCH_QUEUE_PRIORITY_HIGH
QUEUE_PRIORITY_DEFAULT = _DISPATCH_QUEUE_PRIORITY_DEFAULT
QUEUE_PRIORITY_LOW = _DISPATCH_QUEUE_PRIORITY_LOW
QUEUE_PRIORITY_BACKGROUND = _DISPATCH_QUEUE_PRIORITY_BACKGROUND

# QOS class constants (from sys/qos.h)
DEF _QOS_CLASS_USER_INTERACTIVE = 0x21
DEF _QOS_CLASS_USER_INITIATED = 0x19
DEF _QOS_CLASS_DEFAULT = 0x15
DEF _QOS_CLASS_UTILITY = 0x11
DEF _QOS_CLASS_BACKGROUND = 0x09
DEF _QOS_CLASS_UNSPECIFIED = 0x00

QOS_CLASS_USER_INTERACTIVE = _QOS_CLASS_USER_INTERACTIVE
QOS_CLASS_USER_INITIATED = _QOS_CLASS_USER_INITIATED
QOS_CLASS_DEFAULT = _QOS_CLASS_DEFAULT
QOS_CLASS_UTILITY = _QOS_CLASS_UTILITY
QOS_CLASS_BACKGROUND = _QOS_CLASS_BACKGROUND
QOS_CLASS_UNSPECIFIED = _QOS_CLASS_UNSPECIFIED

# Process event flags (from dispatch/source.h)
DEF _DISPATCH_PROC_EXIT = 0x80000000
DEF _DISPATCH_PROC_FORK = 0x40000000
DEF _DISPATCH_PROC_EXEC = 0x20000000
DEF _DISPATCH_PROC_SIGNAL = 0x08000000

PROC_EXIT = _DISPATCH_PROC_EXIT
PROC_FORK = _DISPATCH_PROC_FORK
PROC_EXEC = _DISPATCH_PROC_EXEC
PROC_SIGNAL = _DISPATCH_PROC_SIGNAL


cdef extern from "time.h" nogil:
    ctypedef long time_t
    struct timespec:
        time_t tv_sec
        long tv_nsec


cdef extern from "dispatch/dispatch.h" nogil:
    # Opaque types
    ctypedef struct dispatch_queue_s:
        pass
    ctypedef dispatch_queue_s* dispatch_queue_t

    ctypedef struct dispatch_group_s:
        pass
    ctypedef dispatch_group_s* dispatch_group_t

    ctypedef struct dispatch_semaphore_s:
        pass
    ctypedef dispatch_semaphore_s* dispatch_semaphore_t

    ctypedef struct dispatch_queue_attr_s:
        pass
    ctypedef dispatch_queue_attr_s* dispatch_queue_attr_t

    ctypedef struct dispatch_source_s:
        pass
    ctypedef dispatch_source_s* dispatch_source_t

    ctypedef struct dispatch_source_type_s:
        pass
    ctypedef const dispatch_source_type_s* dispatch_source_type_t

    # Time type
    ctypedef uint64_t dispatch_time_t

    # Function pointer type
    ctypedef void (*dispatch_function_t)(void*)

    # Once predicate
    ctypedef intptr_t dispatch_once_t

    # Queue attribute constants
    dispatch_queue_attr_t _dispatch_queue_attr_concurrent "DISPATCH_GLOBAL_OBJECT(dispatch_queue_attr_t, _dispatch_queue_attr_concurrent)"

    # Source type constants
    dispatch_source_type_t _dispatch_source_type_timer "DISPATCH_SOURCE_TYPE_TIMER"
    dispatch_source_type_t _dispatch_source_type_signal "DISPATCH_SOURCE_TYPE_SIGNAL"
    dispatch_source_type_t _dispatch_source_type_read "DISPATCH_SOURCE_TYPE_READ"
    dispatch_source_type_t _dispatch_source_type_write "DISPATCH_SOURCE_TYPE_WRITE"
    dispatch_source_type_t _dispatch_source_type_proc "DISPATCH_SOURCE_TYPE_PROC"

    # Main queue
    dispatch_queue_t dispatch_get_main_queue()

    # Queue creation and management
    dispatch_queue_t dispatch_queue_create(const char* label, dispatch_queue_attr_t attr)
    dispatch_queue_t dispatch_get_global_queue(intptr_t identifier, uintptr_t flags)
    const char* dispatch_queue_get_label(dispatch_queue_t queue)

    # Reference counting
    void dispatch_retain(dispatch_queue_t obj)
    void dispatch_release(dispatch_queue_t obj)

    # Suspend/Resume
    void dispatch_suspend(dispatch_queue_t obj)
    void dispatch_resume(dispatch_queue_t obj)

    # Async/sync execution with function pointers
    void dispatch_async_f(dispatch_queue_t queue, void* context, dispatch_function_t work)
    void dispatch_sync_f(dispatch_queue_t queue, void* context, dispatch_function_t work)

    # Barrier operations
    void dispatch_barrier_async_f(dispatch_queue_t queue, void* context, dispatch_function_t work)
    void dispatch_barrier_sync_f(dispatch_queue_t queue, void* context, dispatch_function_t work)

    # Apply (parallel for)
    void dispatch_apply_f(size_t iterations, dispatch_queue_t queue,
                          void* context, void (*work)(void*, size_t))

    # After (delayed execution)
    void dispatch_after_f(dispatch_time_t when, dispatch_queue_t queue,
                          void* context, dispatch_function_t work)

    # Groups
    dispatch_group_t dispatch_group_create()
    void dispatch_group_async_f(dispatch_group_t group, dispatch_queue_t queue,
                                void* context, dispatch_function_t work)
    intptr_t dispatch_group_wait(dispatch_group_t group, dispatch_time_t timeout)
    void dispatch_group_notify_f(dispatch_group_t group, dispatch_queue_t queue,
                                 void* context, dispatch_function_t work)
    void dispatch_group_enter(dispatch_group_t group)
    void dispatch_group_leave(dispatch_group_t group)

    # Semaphores
    dispatch_semaphore_t dispatch_semaphore_create(intptr_t value)
    intptr_t dispatch_semaphore_wait(dispatch_semaphore_t dsema, dispatch_time_t timeout)
    intptr_t dispatch_semaphore_signal(dispatch_semaphore_t dsema)

    # Once
    void dispatch_once_f(dispatch_once_t* predicate, void* context, dispatch_function_t function)

    # Time functions
    dispatch_time_t dispatch_time(dispatch_time_t when, int64_t delta)
    dispatch_time_t dispatch_walltime(const timespec* when, int64_t delta)

    # Source functions
    dispatch_source_t dispatch_source_create(dispatch_source_type_t type,
                                             uintptr_t handle,
                                             uintptr_t mask,
                                             dispatch_queue_t queue)
    void dispatch_source_set_event_handler_f(dispatch_source_t source,
                                             dispatch_function_t handler)
    void dispatch_source_set_cancel_handler_f(dispatch_source_t source,
                                              dispatch_function_t handler)
    void dispatch_source_cancel(dispatch_source_t source)
    intptr_t dispatch_source_testcancel(dispatch_source_t source)
    void dispatch_source_set_timer(dispatch_source_t source,
                                   dispatch_time_t start,
                                   uint64_t interval,
                                   uint64_t leeway)
    uintptr_t dispatch_source_get_data(dispatch_source_t source)
    uintptr_t dispatch_source_get_handle(dispatch_source_t source)
    uintptr_t dispatch_source_get_mask(dispatch_source_t source)
    void dispatch_set_context(dispatch_source_t obj, void* context)

    # Queue hierarchy
    void dispatch_set_target_queue(dispatch_queue_t object, dispatch_queue_t queue)

    # QOS attributes
    dispatch_queue_attr_t dispatch_queue_attr_make_with_qos_class(
        dispatch_queue_attr_t attr, unsigned int qos_class, int relative_priority)

    # Inactive queues
    dispatch_queue_attr_t dispatch_queue_attr_make_initially_inactive(
        dispatch_queue_attr_t attr)
    void dispatch_activate(dispatch_queue_t object)

    # Queue-specific data
    ctypedef const void* dispatch_queue_key_t
    void dispatch_queue_set_specific(dispatch_queue_t queue, const void* key,
                                     void* context, dispatch_function_t destructor)
    void* dispatch_queue_get_specific(dispatch_queue_t queue, const void* key)
    void* dispatch_get_specific(const void* key)

    # Dispatch I/O types
    ctypedef struct dispatch_io_s:
        pass
    ctypedef dispatch_io_s* dispatch_io_t

    ctypedef struct dispatch_data_s:
        pass
    ctypedef dispatch_data_s* dispatch_data_t

    # Dispatch data empty constant
    dispatch_data_t _dispatch_data_empty "DISPATCH_DATA_DESTRUCTOR_DEFAULT"

    # Dispatch I/O type constants
    unsigned int DISPATCH_IO_STREAM
    unsigned int DISPATCH_IO_RANDOM

    # Dispatch I/O close flags
    unsigned int DISPATCH_IO_STOP

    # Dispatch I/O functions
    dispatch_io_t dispatch_io_create(unsigned int type, int fd,
                                     dispatch_queue_t queue,
                                     void (*cleanup_handler)(int error))
    dispatch_io_t dispatch_io_create_with_path(unsigned int type, const char* path,
                                               int oflag, unsigned short mode,
                                               dispatch_queue_t queue,
                                               void (*cleanup_handler)(int error))
    void dispatch_io_read(dispatch_io_t channel, off_t offset, size_t length,
                          dispatch_queue_t queue,
                          void (*handler)(bint done, dispatch_data_t data, int error))
    void dispatch_io_write(dispatch_io_t channel, off_t offset, dispatch_data_t data,
                           dispatch_queue_t queue,
                           void (*handler)(bint done, dispatch_data_t data, int error))
    void dispatch_io_close(dispatch_io_t channel, unsigned int flags)
    void dispatch_io_set_high_water(dispatch_io_t channel, size_t high_water)
    void dispatch_io_set_low_water(dispatch_io_t channel, size_t low_water)
    void dispatch_io_set_interval(dispatch_io_t channel, uint64_t interval,
                                  unsigned int flags)
    void dispatch_io_barrier(dispatch_io_t channel, void (*barrier)())

    # Dispatch Data functions
    dispatch_data_t dispatch_data_create(const void* buffer, size_t size,
                                         dispatch_queue_t queue,
                                         void (*destructor)())
    size_t dispatch_data_get_size(dispatch_data_t data)
    dispatch_data_t dispatch_data_create_concat(dispatch_data_t data1,
                                                dispatch_data_t data2)
    dispatch_data_t dispatch_data_create_subrange(dispatch_data_t data,
                                                  size_t offset, size_t length)
    dispatch_data_t dispatch_data_create_map(dispatch_data_t data,
                                             const void** buffer_ptr,
                                             size_t* size_ptr)
    bint dispatch_data_apply(dispatch_data_t data,
                             bint (*applier)(dispatch_data_t region,
                                            size_t offset,
                                            const void* buffer,
                                            size_t size))

    # Simple async I/O
    void dispatch_read(int fd, size_t length, dispatch_queue_t queue,
                       void (*handler)(dispatch_data_t data, int error))
    void dispatch_write(int fd, dispatch_data_t data, dispatch_queue_t queue,
                        void (*handler)(dispatch_data_t data, int error))

    # Workloop
    ctypedef struct dispatch_workloop_s:
        pass
    ctypedef dispatch_workloop_s* dispatch_workloop_t

    dispatch_workloop_t dispatch_workloop_create(const char* label)
    dispatch_workloop_t dispatch_workloop_create_inactive(const char* label)


# Trampoline function that acquires GIL and calls Python callable
cdef void _python_callback(void* context) noexcept with gil:
    """Trampoline function to call Python callables from GCD."""
    cdef object func
    if context == NULL:
        return
    func = <object>context
    try:
        func()
    except BaseException:
        PyErr_Print()
    finally:
        Py_DECREF(func)


# Trampoline for dispatch_apply with iteration index
cdef void _python_apply_callback(void* context, size_t iteration) noexcept with gil:
    """Trampoline function for dispatch_apply that passes iteration index."""
    cdef object func
    if context == NULL:
        return
    func = <object>context
    try:
        func(iteration)
    except BaseException:
        PyErr_Print()


# Trampoline for timer events - does NOT decref since timer fires repeatedly
cdef void _python_timer_callback(void* context) noexcept with gil:
    """Trampoline function for timer events."""
    cdef object func
    if context == NULL:
        return
    func = <object>context
    try:
        func()
    except BaseException:
        PyErr_Print()


# Trampoline for timer cancel handler - decrefs the callback
cdef void _python_timer_cancel_callback(void* context) noexcept with gil:
    """Trampoline function for timer cancel - releases the callback reference."""
    cdef object func
    if context == NULL:
        return
    func = <object>context
    Py_DECREF(func)


cdef class Queue:
    """
    Dispatch queue wrapper.

    Queues can be serial (execute one task at a time in FIFO order) or
    concurrent (execute multiple tasks simultaneously).
    """
    cdef dispatch_queue_t _queue
    cdef bint _owned
    cdef bint _inactive
    cdef bytes _label_bytes

    def __cinit__(self):
        self._queue = NULL
        self._owned = False
        self._inactive = False

    def __init__(self, str label=None, bint concurrent=False,
                 int qos=_QOS_CLASS_UNSPECIFIED, int relative_priority=0,
                 target=None, bint inactive=False):
        """
        Create a new dispatch queue.

        Args:
            label: Optional string label for debugging.
            concurrent: If True, create a concurrent queue. Default is serial.
            qos: Quality of Service class (QOS_CLASS_* constants). Default is unspecified.
            relative_priority: Priority offset within QOS class (-15 to 0). Default is 0.
            target: Optional target queue for queue hierarchy. Tasks submitted to this
                    queue will ultimately execute on the target queue.
            inactive: If True, create queue in inactive state. Must call activate()
                      before the queue will process tasks. Default is False.
        """
        cdef dispatch_queue_attr_t attr
        cdef const char* c_label = NULL

        if label is not None:
            self._label_bytes = label.encode('utf-8')
            c_label = self._label_bytes

        if concurrent:
            attr = _dispatch_queue_attr_concurrent
        else:
            attr = NULL  # DISPATCH_QUEUE_SERIAL

        # Apply QOS if specified
        if qos != _QOS_CLASS_UNSPECIFIED:
            with nogil:
                attr = dispatch_queue_attr_make_with_qos_class(
                    attr, <unsigned int>qos, relative_priority)

        # Make inactive if specified
        if inactive:
            with nogil:
                attr = dispatch_queue_attr_make_initially_inactive(attr)
            self._inactive = True

        with nogil:
            self._queue = dispatch_queue_create(c_label, attr)
        self._owned = True

        # Set target queue if specified
        if target is not None:
            self.set_target_queue(target)

    def __dealloc__(self):
        if self._queue != NULL and self._owned:
            # Must activate inactive queues before releasing
            # otherwise dispatch_release will block forever
            if self._inactive:
                dispatch_activate(self._queue)
            dispatch_release(self._queue)
            self._queue = NULL

    @staticmethod
    def global_queue(int priority=_DISPATCH_QUEUE_PRIORITY_DEFAULT):
        """
        Get a global concurrent queue with the specified priority.

        Args:
            priority: Queue priority (QUEUE_PRIORITY_* or QOS_CLASS_* constants).

        Returns:
            A Queue instance wrapping the global queue.
        """
        cdef Queue q = Queue.__new__(Queue)
        with nogil:
            q._queue = dispatch_get_global_queue(priority, 0)
        q._owned = False  # Global queues are not owned
        return q

    @staticmethod
    def main_queue():
        """
        Get the main queue.

        The main queue is a serial queue associated with the main thread.
        Tasks submitted to the main queue execute on the main thread.

        Note: In a Python application without a running CFRunLoop or NSRunLoop,
        the main queue will not process tasks automatically. Use this primarily
        when integrating with macOS GUI frameworks.

        Returns:
            A Queue instance wrapping the main queue.
        """
        cdef Queue q = Queue.__new__(Queue)
        q._queue = dispatch_get_main_queue()
        q._owned = False  # Main queue is not owned
        return q

    @property
    def label(self):
        """Get the queue's label."""
        cdef const char* c_label
        with nogil:
            c_label = dispatch_queue_get_label(self._queue)
        if c_label == NULL:
            return None
        return c_label.decode('utf-8')

    def set_target_queue(self, Queue target):
        """
        Set the target queue for this queue.

        Tasks submitted to this queue will ultimately execute on the target queue.
        This creates a queue hierarchy that can be used for priority management.

        Note: The target queue should be set before any tasks are submitted.
        Changing the target queue after tasks have been submitted may result
        in undefined behavior.

        Args:
            target: The target queue, or None to reset to default.
        """
        cdef dispatch_queue_t target_q = NULL
        if target is not None:
            target_q = target._queue
        with nogil:
            dispatch_set_target_queue(self._queue, target_q)

    def run_async(self, func):
        """
        Submit a callable for asynchronous execution.

        The callable will be executed on this queue at some point in the future.
        This method returns immediately.

        Args:
            func: A callable taking no arguments.
        """
        if not callable(func):
            raise TypeError("func must be callable")
        Py_INCREF(func)
        cdef PyObject* ctx = <PyObject*>func
        with nogil:
            dispatch_async_f(self._queue, <void*>ctx, _python_callback)

    def run_sync(self, func):
        """
        Submit a callable for synchronous execution.

        This method blocks until the callable has completed execution.

        Warning: Do not call run_sync() on a serial queue from within a task
        already running on that queue - this will deadlock.

        Args:
            func: A callable taking no arguments.
        """
        if not callable(func):
            raise TypeError("func must be callable")
        Py_INCREF(func)
        cdef PyObject* ctx = <PyObject*>func
        with nogil:
            dispatch_sync_f(self._queue, <void*>ctx, _python_callback)

    def barrier_async(self, func):
        """
        Submit a barrier callable for asynchronous execution.

        On a concurrent queue, barrier tasks wait for all previously submitted
        tasks to complete, then execute exclusively (no other tasks run
        concurrently), then allow subsequent tasks to proceed.

        On a serial queue, this behaves identically to async_().

        Args:
            func: A callable taking no arguments.
        """
        if not callable(func):
            raise TypeError("func must be callable")
        Py_INCREF(func)
        cdef PyObject* ctx = <PyObject*>func
        with nogil:
            dispatch_barrier_async_f(self._queue, <void*>ctx, _python_callback)

    def barrier_sync(self, func):
        """
        Submit a barrier callable for synchronous execution.

        Combines the semantics of barrier_async() and sync().

        Args:
            func: A callable taking no arguments.
        """
        if not callable(func):
            raise TypeError("func must be callable")
        Py_INCREF(func)
        cdef PyObject* ctx = <PyObject*>func
        with nogil:
            dispatch_barrier_sync_f(self._queue, <void*>ctx, _python_callback)

    def after(self, double delay_seconds, func):
        """
        Schedule a callable for execution after a delay.

        Args:
            delay_seconds: Delay in seconds before execution.
            func: A callable taking no arguments.
        """
        if not callable(func):
            raise TypeError("func must be callable")
        cdef int64_t delta_ns = <int64_t>(delay_seconds * NSEC_PER_SEC)
        cdef dispatch_time_t when
        with nogil:
            when = dispatch_time(_DISPATCH_TIME_NOW, delta_ns)
        Py_INCREF(func)
        cdef PyObject* ctx = <PyObject*>func
        with nogil:
            dispatch_after_f(when, self._queue, <void*>ctx, _python_callback)

    def suspend(self):
        """
        Suspend the queue.

        Suspending a queue prevents it from executing any tasks.
        Calls to suspend must be balanced with calls to resume.

        Note: Suspending a queue does not interrupt a task that is
        currently executing.
        """
        cdef dispatch_queue_t q = self._queue
        with nogil:
            dispatch_suspend(q)

    def resume(self):
        """
        Resume the queue.

        Resumes a suspended queue, allowing it to execute tasks again.
        Calls to resume must balance previous calls to suspend.
        """
        cdef dispatch_queue_t q = self._queue
        with nogil:
            dispatch_resume(q)

    def activate(self):
        """
        Activate an inactive queue.

        Queues created with inactive=True must be activated before they will
        process any tasks. Once activated, a queue cannot be made inactive again.

        Raises:
            RuntimeError: If the queue was not created as inactive.
        """
        if not self._inactive:
            raise RuntimeError("Queue was not created as inactive")
        cdef dispatch_queue_t q = self._queue
        with nogil:
            dispatch_activate(q)
        self._inactive = False

    @property
    def is_inactive(self):
        """Check if the queue is currently inactive."""
        return self._inactive


def apply(size_t iterations, func, Queue queue=None):
    """
    Execute a callable multiple times in parallel.

    The callable is invoked `iterations` times, potentially concurrently.
    Each invocation receives its iteration index (0 to iterations-1).
    This function blocks until all iterations complete.

    Args:
        iterations: Number of times to invoke the callable.
        func: A callable taking one argument (the iteration index).
        queue: Optional queue to use. If None, uses an appropriate global queue.
    """
    if not callable(func):
        raise TypeError("func must be callable")

    cdef dispatch_queue_t q
    if queue is not None:
        q = queue._queue
    else:
        q = NULL  # DISPATCH_APPLY_AUTO

    # For apply, we don't need to manage reference counting per-iteration
    # because dispatch_apply_f is synchronous
    cdef PyObject* ctx = <PyObject*>func
    with nogil:
        dispatch_apply_f(iterations, q, <void*>ctx, _python_apply_callback)


cdef class Group:
    """
    Dispatch group for tracking completion of multiple tasks.

    Groups allow you to aggregate multiple tasks and wait for all of them
    to complete, or be notified when they complete.
    """
    cdef dispatch_group_t _group

    def __cinit__(self):
        self._group = NULL

    def __init__(self):
        """Create a new dispatch group."""
        with nogil:
            self._group = dispatch_group_create()

    def __dealloc__(self):
        if self._group != NULL:
            dispatch_release(<dispatch_queue_t>self._group)
            self._group = NULL

    def run_async(self, Queue queue, func):
        """
        Submit a callable to a queue and associate it with this group.

        Args:
            queue: The queue to submit to.
            func: A callable taking no arguments.
        """
        if not callable(func):
            raise TypeError("func must be callable")
        Py_INCREF(func)
        cdef PyObject* ctx = <PyObject*>func
        cdef dispatch_queue_t q = queue._queue
        cdef dispatch_group_t g = self._group
        with nogil:
            dispatch_group_async_f(g, q, <void*>ctx, _python_callback)

    def wait(self, double timeout_seconds=-1.0):
        """
        Wait for all tasks in the group to complete.

        Args:
            timeout_seconds: Maximum time to wait. Use -1 for infinite wait.

        Returns:
            True if all tasks completed, False if timeout occurred.
        """
        cdef dispatch_time_t timeout
        cdef intptr_t result
        cdef int64_t delta_ns

        if timeout_seconds < 0:
            timeout = _DISPATCH_TIME_FOREVER
        else:
            delta_ns = <int64_t>(timeout_seconds * NSEC_PER_SEC)
            with nogil:
                timeout = dispatch_time(_DISPATCH_TIME_NOW, delta_ns)

        cdef dispatch_group_t g = self._group
        with nogil:
            result = dispatch_group_wait(g, timeout)
        return result == 0

    def notify(self, Queue queue, func):
        """
        Schedule a callable to run when all current tasks in the group complete.

        Args:
            queue: The queue to submit the notification callable to.
            func: A callable taking no arguments.
        """
        if not callable(func):
            raise TypeError("func must be callable")
        Py_INCREF(func)
        cdef PyObject* ctx = <PyObject*>func
        cdef dispatch_queue_t q = queue._queue
        cdef dispatch_group_t g = self._group
        with nogil:
            dispatch_group_notify_f(g, q, <void*>ctx, _python_callback)

    def enter(self):
        """
        Manually increment the group's task count.

        Must be balanced with a call to leave().
        """
        cdef dispatch_group_t g = self._group
        with nogil:
            dispatch_group_enter(g)

    def leave(self):
        """
        Manually decrement the group's task count.

        Must balance a previous call to enter().
        """
        cdef dispatch_group_t g = self._group
        with nogil:
            dispatch_group_leave(g)


cdef class Semaphore:
    """
    Counting semaphore for controlling access to resources.

    A semaphore with initial value N allows N concurrent accesses.
    """
    cdef dispatch_semaphore_t _semaphore

    def __cinit__(self):
        self._semaphore = NULL

    def __init__(self, intptr_t value=0):
        """
        Create a new semaphore.

        Args:
            value: Initial value. Use 0 for signaling, >0 for resource counting.
        """
        with nogil:
            self._semaphore = dispatch_semaphore_create(value)

    def __dealloc__(self):
        if self._semaphore != NULL:
            dispatch_release(<dispatch_queue_t>self._semaphore)
            self._semaphore = NULL

    def wait(self, double timeout_seconds=-1.0):
        """
        Decrement the semaphore, blocking if necessary.

        If the semaphore value is greater than zero, decrements it and returns
        immediately. Otherwise, blocks until another thread signals.

        Args:
            timeout_seconds: Maximum time to wait. Use -1 for infinite wait.

        Returns:
            True if the semaphore was successfully decremented,
            False if timeout occurred.
        """
        cdef dispatch_time_t timeout
        cdef intptr_t result
        cdef int64_t delta_ns

        if timeout_seconds < 0:
            timeout = _DISPATCH_TIME_FOREVER
        else:
            delta_ns = <int64_t>(timeout_seconds * NSEC_PER_SEC)
            with nogil:
                timeout = dispatch_time(_DISPATCH_TIME_NOW, delta_ns)

        cdef dispatch_semaphore_t s = self._semaphore
        with nogil:
            result = dispatch_semaphore_wait(s, timeout)
        return result == 0

    def signal(self):
        """
        Increment the semaphore, potentially waking a waiting thread.

        Returns:
            True if a thread was woken, False otherwise.
        """
        cdef intptr_t result
        cdef dispatch_semaphore_t s = self._semaphore
        with nogil:
            result = dispatch_semaphore_signal(s)
        return result != 0


cdef class Once:
    """
    Execute a callable exactly once, thread-safely.

    Multiple threads can call the once instance simultaneously;
    only one will execute the callable, and all will wait for completion.
    """
    cdef dispatch_once_t _predicate

    def __cinit__(self):
        self._predicate = 0

    def __call__(self, func):
        """
        Execute the callable if not already executed.

        Args:
            func: A callable taking no arguments. Will only be called once.
        """
        if not callable(func):
            raise TypeError("func must be callable")

        # For once, we need special handling because the function should only
        # be called once, but we always increment the reference
        # We'll use a simple check - if predicate is already set, don't call
        if self._predicate != 0:
            return

        Py_INCREF(func)
        cdef PyObject* ctx = <PyObject*>func
        cdef dispatch_once_t* pred = &self._predicate
        with nogil:
            dispatch_once_f(pred, <void*>ctx, _python_callback)


def time_from_now(double seconds):
    """
    Create a dispatch time relative to now.

    Args:
        seconds: Number of seconds from now.

    Returns:
        A dispatch time value.
    """
    cdef int64_t delta_ns = <int64_t>(seconds * NSEC_PER_SEC)
    cdef dispatch_time_t result
    with nogil:
        result = dispatch_time(_DISPATCH_TIME_NOW, delta_ns)
    return result


def walltime(double timestamp=0.0, double delta_seconds=0.0):
    """
    Create a dispatch time based on wall clock time.

    Unlike time_from_now() which uses monotonic time, walltime uses
    the system clock and will adjust for clock changes (e.g., NTP, DST).

    Args:
        timestamp: Unix timestamp (seconds since epoch). If 0, uses current time.
        delta_seconds: Additional seconds to add to the timestamp.

    Returns:
        A dispatch time value based on wall clock time.
    """
    cdef timespec ts
    cdef timespec* ts_ptr
    cdef int64_t delta_ns = <int64_t>(delta_seconds * NSEC_PER_SEC)
    cdef dispatch_time_t result

    if timestamp == 0.0:
        ts_ptr = NULL  # Use current time
    else:
        ts.tv_sec = <time_t>timestamp
        ts.tv_nsec = <long>((timestamp - <double>ts.tv_sec) * NSEC_PER_SEC)
        ts_ptr = &ts

    with nogil:
        result = dispatch_walltime(ts_ptr, delta_ns)
    return result


cdef class Timer:
    """
    Dispatch timer source.

    Timers fire repeatedly at specified intervals, executing a handler
    on a target queue. Timers are created suspended and must be started
    with start().
    """
    cdef dispatch_source_t _source
    cdef object _handler
    cdef bint _started
    cdef bint _cancelled

    def __cinit__(self):
        self._source = NULL
        self._handler = None
        self._started = False
        self._cancelled = False

    def __init__(self, double interval, handler, Queue queue=None,
                 double start_delay=0.0, double leeway=0.0, bint repeating=True):
        """
        Create a new timer.

        Args:
            interval: Time between firings in seconds. For one-shot timers,
                      this is ignored (set repeating=False).
            handler: Callable to invoke when the timer fires. Takes no arguments.
            queue: Queue to execute handler on. If None, uses default global queue.
            start_delay: Initial delay before first firing (seconds). Default is 0.
            leeway: Allowed leeway for system power optimization (seconds).
                    Default is 0 (minimal leeway).
            repeating: If True (default), timer fires repeatedly. If False,
                       fires once then stops.
        """
        if not callable(handler):
            raise TypeError("handler must be callable")

        cdef dispatch_queue_t q
        if queue is not None:
            q = queue._queue
        else:
            q = NULL  # Default global queue

        # Create timer source
        with nogil:
            self._source = dispatch_source_create(
                _dispatch_source_type_timer, 0, 0, q)

        if self._source == NULL:
            raise RuntimeError("Failed to create timer source")

        # Configure timer
        cdef uint64_t interval_ns
        cdef uint64_t leeway_ns = <uint64_t>(leeway * NSEC_PER_SEC)
        cdef dispatch_time_t start_time
        cdef int64_t start_delta_ns = <int64_t>(start_delay * NSEC_PER_SEC)

        if repeating:
            interval_ns = <uint64_t>(interval * NSEC_PER_SEC)
        else:
            interval_ns = _DISPATCH_TIME_FOREVER  # One-shot

        with nogil:
            start_time = dispatch_time(_DISPATCH_TIME_NOW, start_delta_ns)
            dispatch_source_set_timer(self._source, start_time, interval_ns, leeway_ns)

        # Store handler and set up callbacks
        self._handler = handler
        Py_INCREF(handler)

        cdef PyObject* ctx = <PyObject*>handler
        dispatch_set_context(<dispatch_source_t>self._source, <void*>ctx)
        dispatch_source_set_event_handler_f(self._source, _python_timer_callback)
        dispatch_source_set_cancel_handler_f(self._source, _python_timer_cancel_callback)

    def __dealloc__(self):
        if self._source != NULL:
            if not self._cancelled:
                # Must cancel before release
                dispatch_source_cancel(self._source)
            if not self._started:
                # Sources are created suspended, must resume before release
                dispatch_resume(<dispatch_queue_t>self._source)
            dispatch_release(<dispatch_queue_t>self._source)
            self._source = NULL

    def start(self):
        """
        Start the timer.

        The timer is created suspended and must be started to begin firing.
        """
        if self._started:
            return
        if self._cancelled:
            raise RuntimeError("Cannot start a cancelled timer")
        self._started = True
        with nogil:
            dispatch_resume(<dispatch_queue_t>self._source)

    def cancel(self):
        """
        Cancel the timer.

        After cancellation, the timer will not fire again.
        This is safe to call from any thread.
        """
        if self._cancelled:
            return
        self._cancelled = True
        with nogil:
            dispatch_source_cancel(self._source)

    @property
    def is_cancelled(self):
        """Check if the timer has been cancelled."""
        cdef intptr_t result
        with nogil:
            result = dispatch_source_testcancel(self._source)
        return result != 0

    def set_timer(self, double interval, double start_delay=0.0,
                  double leeway=0.0, bint repeating=True):
        """
        Reconfigure the timer's interval and start time.

        Can be called while the timer is running.

        Args:
            interval: Time between firings in seconds.
            start_delay: Delay before next firing (seconds).
            leeway: Allowed leeway for system power optimization (seconds).
            repeating: If True, timer fires repeatedly.
        """
        cdef uint64_t interval_ns
        cdef uint64_t leeway_ns = <uint64_t>(leeway * NSEC_PER_SEC)
        cdef dispatch_time_t start_time
        cdef int64_t start_delta_ns = <int64_t>(start_delay * NSEC_PER_SEC)

        if repeating:
            interval_ns = <uint64_t>(interval * NSEC_PER_SEC)
        else:
            interval_ns = _DISPATCH_TIME_FOREVER

        with nogil:
            start_time = dispatch_time(_DISPATCH_TIME_NOW, start_delta_ns)
            dispatch_source_set_timer(self._source, start_time, interval_ns, leeway_ns)


cdef class SignalSource:
    """
    Dispatch source for monitoring Unix signals.

    Allows handling signals asynchronously on a dispatch queue instead of
    using traditional signal handlers.

    Important: You must disable the default signal behavior for the signal
    you're monitoring (e.g., with signal.signal(sig, signal.SIG_IGN)).
    """
    cdef dispatch_source_t _source
    cdef object _handler
    cdef bint _started
    cdef bint _cancelled
    cdef int _signal

    def __cinit__(self):
        self._source = NULL
        self._handler = None
        self._started = False
        self._cancelled = False
        self._signal = 0

    def __init__(self, int signum, handler, Queue queue=None):
        """
        Create a new signal source.

        Args:
            signum: The Unix signal number to monitor (e.g., signal.SIGINT).
            handler: Callable to invoke when the signal is received.
                     Receives no arguments.
            queue: Queue to execute handler on. If None, uses default global queue.
        """
        if not callable(handler):
            raise TypeError("handler must be callable")

        self._signal = signum
        cdef dispatch_queue_t q
        if queue is not None:
            q = queue._queue
        else:
            q = NULL

        # Create signal source
        with nogil:
            self._source = dispatch_source_create(
                _dispatch_source_type_signal, <uintptr_t>signum, 0, q)

        if self._source == NULL:
            raise RuntimeError("Failed to create signal source")

        # Store handler and set up callbacks
        self._handler = handler
        Py_INCREF(handler)

        cdef PyObject* ctx = <PyObject*>handler
        dispatch_set_context(<dispatch_source_t>self._source, <void*>ctx)
        dispatch_source_set_event_handler_f(self._source, _python_timer_callback)
        dispatch_source_set_cancel_handler_f(self._source, _python_timer_cancel_callback)

    def __dealloc__(self):
        if self._source != NULL:
            if not self._cancelled:
                dispatch_source_cancel(self._source)
            if not self._started:
                dispatch_resume(<dispatch_queue_t>self._source)
            dispatch_release(<dispatch_queue_t>self._source)
            self._source = NULL

    def start(self):
        """Start monitoring the signal."""
        if self._started:
            return
        if self._cancelled:
            raise RuntimeError("Cannot start a cancelled signal source")
        self._started = True
        with nogil:
            dispatch_resume(<dispatch_queue_t>self._source)

    def cancel(self):
        """Stop monitoring the signal."""
        if self._cancelled:
            return
        self._cancelled = True
        with nogil:
            dispatch_source_cancel(self._source)

    @property
    def is_cancelled(self):
        """Check if the source has been cancelled."""
        cdef intptr_t result
        with nogil:
            result = dispatch_source_testcancel(self._source)
        return result != 0

    @property
    def signal(self):
        """Get the signal number being monitored."""
        return self._signal

    @property
    def count(self):
        """
        Get the number of signals received since last handler invocation.

        This is useful for coalesced signals where multiple signals may have
        arrived before the handler ran.
        """
        cdef uintptr_t data
        with nogil:
            data = dispatch_source_get_data(self._source)
        return data


cdef class ReadSource:
    """
    Dispatch source for monitoring file descriptor readability.

    Fires when the file descriptor has data available to read.
    """
    cdef dispatch_source_t _source
    cdef object _handler
    cdef bint _started
    cdef bint _cancelled
    cdef int _fd

    def __cinit__(self):
        self._source = NULL
        self._handler = None
        self._started = False
        self._cancelled = False
        self._fd = -1

    def __init__(self, int fd, handler, Queue queue=None):
        """
        Create a new read source.

        Args:
            fd: The file descriptor to monitor.
            handler: Callable to invoke when data is available to read.
                     Receives no arguments.
            queue: Queue to execute handler on. If None, uses default global queue.
        """
        if not callable(handler):
            raise TypeError("handler must be callable")

        self._fd = fd
        cdef dispatch_queue_t q
        if queue is not None:
            q = queue._queue
        else:
            q = NULL

        # Create read source
        with nogil:
            self._source = dispatch_source_create(
                _dispatch_source_type_read, <uintptr_t>fd, 0, q)

        if self._source == NULL:
            raise RuntimeError("Failed to create read source")

        # Store handler and set up callbacks
        self._handler = handler
        Py_INCREF(handler)

        cdef PyObject* ctx = <PyObject*>handler
        dispatch_set_context(<dispatch_source_t>self._source, <void*>ctx)
        dispatch_source_set_event_handler_f(self._source, _python_timer_callback)
        dispatch_source_set_cancel_handler_f(self._source, _python_timer_cancel_callback)

    def __dealloc__(self):
        if self._source != NULL:
            if not self._cancelled:
                dispatch_source_cancel(self._source)
            if not self._started:
                dispatch_resume(<dispatch_queue_t>self._source)
            dispatch_release(<dispatch_queue_t>self._source)
            self._source = NULL

    def start(self):
        """Start monitoring the file descriptor."""
        if self._started:
            return
        if self._cancelled:
            raise RuntimeError("Cannot start a cancelled read source")
        self._started = True
        with nogil:
            dispatch_resume(<dispatch_queue_t>self._source)

    def cancel(self):
        """Stop monitoring the file descriptor."""
        if self._cancelled:
            return
        self._cancelled = True
        with nogil:
            dispatch_source_cancel(self._source)

    @property
    def is_cancelled(self):
        """Check if the source has been cancelled."""
        cdef intptr_t result
        with nogil:
            result = dispatch_source_testcancel(self._source)
        return result != 0

    @property
    def fd(self):
        """Get the file descriptor being monitored."""
        return self._fd

    @property
    def bytes_available(self):
        """
        Get an estimate of the number of bytes available to read.

        This is an estimate and may not be exact.
        """
        cdef uintptr_t data
        with nogil:
            data = dispatch_source_get_data(self._source)
        return data


cdef class WriteSource:
    """
    Dispatch source for monitoring file descriptor writability.

    Fires when the file descriptor can accept data for writing.
    """
    cdef dispatch_source_t _source
    cdef object _handler
    cdef bint _started
    cdef bint _cancelled
    cdef int _fd

    def __cinit__(self):
        self._source = NULL
        self._handler = None
        self._started = False
        self._cancelled = False
        self._fd = -1

    def __init__(self, int fd, handler, Queue queue=None):
        """
        Create a new write source.

        Args:
            fd: The file descriptor to monitor.
            handler: Callable to invoke when writing is possible.
                     Receives no arguments.
            queue: Queue to execute handler on. If None, uses default global queue.
        """
        if not callable(handler):
            raise TypeError("handler must be callable")

        self._fd = fd
        cdef dispatch_queue_t q
        if queue is not None:
            q = queue._queue
        else:
            q = NULL

        # Create write source
        with nogil:
            self._source = dispatch_source_create(
                _dispatch_source_type_write, <uintptr_t>fd, 0, q)

        if self._source == NULL:
            raise RuntimeError("Failed to create write source")

        # Store handler and set up callbacks
        self._handler = handler
        Py_INCREF(handler)

        cdef PyObject* ctx = <PyObject*>handler
        dispatch_set_context(<dispatch_source_t>self._source, <void*>ctx)
        dispatch_source_set_event_handler_f(self._source, _python_timer_callback)
        dispatch_source_set_cancel_handler_f(self._source, _python_timer_cancel_callback)

    def __dealloc__(self):
        if self._source != NULL:
            if not self._cancelled:
                dispatch_source_cancel(self._source)
            if not self._started:
                dispatch_resume(<dispatch_queue_t>self._source)
            dispatch_release(<dispatch_queue_t>self._source)
            self._source = NULL

    def start(self):
        """Start monitoring the file descriptor."""
        if self._started:
            return
        if self._cancelled:
            raise RuntimeError("Cannot start a cancelled write source")
        self._started = True
        with nogil:
            dispatch_resume(<dispatch_queue_t>self._source)

    def cancel(self):
        """Stop monitoring the file descriptor."""
        if self._cancelled:
            return
        self._cancelled = True
        with nogil:
            dispatch_source_cancel(self._source)

    @property
    def is_cancelled(self):
        """Check if the source has been cancelled."""
        cdef intptr_t result
        with nogil:
            result = dispatch_source_testcancel(self._source)
        return result != 0

    @property
    def fd(self):
        """Get the file descriptor being monitored."""
        return self._fd

    @property
    def buffer_space(self):
        """
        Get an estimate of the space available in the write buffer.

        This is an estimate and may not be exact.
        """
        cdef uintptr_t data
        with nogil:
            data = dispatch_source_get_data(self._source)
        return data


cdef class ProcessSource:
    """
    Dispatch source for monitoring process events.

    Monitors a process for specific events like exit, fork, exec, or signal.
    """
    cdef dispatch_source_t _source
    cdef object _handler
    cdef bint _started
    cdef bint _cancelled
    cdef int _pid
    cdef uintptr_t _events

    def __cinit__(self):
        self._source = NULL
        self._handler = None
        self._started = False
        self._cancelled = False
        self._pid = 0
        self._events = 0

    def __init__(self, int pid, handler, uintptr_t events=_DISPATCH_PROC_EXIT, Queue queue=None):
        """
        Create a new process source.

        Args:
            pid: The process ID to monitor.
            handler: Callable to invoke when an event occurs.
                     Receives no arguments.
            events: Events to monitor. Combine with bitwise OR:
                    - PROC_EXIT: Process exited
                    - PROC_FORK: Process forked
                    - PROC_EXEC: Process executed exec()
                    - PROC_SIGNAL: Process received a signal
            queue: Queue to execute handler on. If None, uses default global queue.
        """
        if not callable(handler):
            raise TypeError("handler must be callable")

        self._pid = pid
        self._events = events
        cdef dispatch_queue_t q
        if queue is not None:
            q = queue._queue
        else:
            q = NULL

        # Create process source
        with nogil:
            self._source = dispatch_source_create(
                _dispatch_source_type_proc, <uintptr_t>pid, events, q)

        if self._source == NULL:
            raise RuntimeError("Failed to create process source")

        # Store handler and set up callbacks
        self._handler = handler
        Py_INCREF(handler)

        cdef PyObject* ctx = <PyObject*>handler
        dispatch_set_context(<dispatch_source_t>self._source, <void*>ctx)
        dispatch_source_set_event_handler_f(self._source, _python_timer_callback)
        dispatch_source_set_cancel_handler_f(self._source, _python_timer_cancel_callback)

    def __dealloc__(self):
        if self._source != NULL:
            if not self._cancelled:
                dispatch_source_cancel(self._source)
            if not self._started:
                dispatch_resume(<dispatch_queue_t>self._source)
            dispatch_release(<dispatch_queue_t>self._source)
            self._source = NULL

    def start(self):
        """Start monitoring the process."""
        if self._started:
            return
        if self._cancelled:
            raise RuntimeError("Cannot start a cancelled process source")
        self._started = True
        with nogil:
            dispatch_resume(<dispatch_queue_t>self._source)

    def cancel(self):
        """Stop monitoring the process."""
        if self._cancelled:
            return
        self._cancelled = True
        with nogil:
            dispatch_source_cancel(self._source)

    @property
    def is_cancelled(self):
        """Check if the source has been cancelled."""
        cdef intptr_t result
        with nogil:
            result = dispatch_source_testcancel(self._source)
        return result != 0

    @property
    def pid(self):
        """Get the process ID being monitored."""
        return self._pid

    @property
    def events_pending(self):
        """
        Get the events that have occurred since the last handler invocation.

        Returns a bitmask of PROC_* constants.
        """
        cdef uintptr_t data
        with nogil:
            data = dispatch_source_get_data(self._source)
        return data


cdef class Data:
    """
    Dispatch data object for efficient buffer management.

    Data objects are immutable containers for bytes that can be efficiently
    concatenated and sliced without copying the underlying data.
    """
    cdef dispatch_data_t _data
    cdef bint _owned

    def __cinit__(self):
        self._data = NULL
        self._owned = False

    def __init__(self, bytes data=None):
        """
        Create a new dispatch data object.

        Args:
            data: Optional bytes to wrap. If None, creates empty data.
        """
        cdef const char* buffer
        cdef size_t size

        if data is None or len(data) == 0:
            self._data = NULL
            self._owned = False
        else:
            buffer = data
            size = len(data)
            # Create a copy of the data (using default destructor)
            with nogil:
                self._data = dispatch_data_create(buffer, size, NULL, NULL)
            self._owned = True

    def __dealloc__(self):
        if self._data != NULL and self._owned:
            dispatch_release(<dispatch_queue_t>self._data)
            self._data = NULL

    def __len__(self):
        """Return the size of the data in bytes."""
        if self._data == NULL:
            return 0
        cdef size_t size
        with nogil:
            size = dispatch_data_get_size(self._data)
        return size

    @property
    def size(self):
        """Get the size of the data in bytes."""
        return len(self)

    def __bytes__(self):
        """Convert to bytes object."""
        if self._data == NULL:
            return b""
        cdef const void* buffer = NULL
        cdef size_t size = 0
        cdef dispatch_data_t mapped

        # Map the data to get contiguous access
        with nogil:
            mapped = dispatch_data_create_map(self._data, &buffer, &size)

        if mapped == NULL or buffer == NULL:
            return b""

        result = (<const char*>buffer)[:size]

        with nogil:
            dispatch_release(<dispatch_queue_t>mapped)

        return result

    def concat(self, Data other):
        """
        Concatenate this data with another.

        Args:
            other: Another Data object to append.

        Returns:
            A new Data object containing the concatenated data.
        """
        cdef Data result = Data.__new__(Data)

        if self._data == NULL and other._data == NULL:
            result._data = NULL
            result._owned = False
        elif self._data == NULL:
            dispatch_retain(<dispatch_queue_t>other._data)
            result._data = other._data
            result._owned = True
        elif other._data == NULL:
            dispatch_retain(<dispatch_queue_t>self._data)
            result._data = self._data
            result._owned = True
        else:
            with nogil:
                result._data = dispatch_data_create_concat(self._data, other._data)
            result._owned = True

        return result

    def subrange(self, size_t offset, size_t length):
        """
        Create a new Data object from a subrange of this data.

        Args:
            offset: Starting offset in bytes.
            length: Number of bytes to include.

        Returns:
            A new Data object containing the subrange.
        """
        cdef Data result = Data.__new__(Data)

        if self._data == NULL:
            result._data = NULL
            result._owned = False
        else:
            with nogil:
                result._data = dispatch_data_create_subrange(self._data, offset, length)
            result._owned = True

        return result

    @staticmethod
    cdef Data _from_dispatch_data(dispatch_data_t data, bint owned):
        """Create a Data object from a dispatch_data_t (internal use)."""
        cdef Data result = Data.__new__(Data)
        result._data = data
        result._owned = owned
        return result


# I/O type constants
IO_STREAM = 0  # DISPATCH_IO_STREAM
IO_RANDOM = 1  # DISPATCH_IO_RANDOM


# Trampoline for dispatch_read/dispatch_write handlers
cdef void _python_io_handler(dispatch_data_t data, int error) noexcept with gil:
    """Trampoline for async I/O completion handlers."""
    cdef object handler_tuple
    cdef object handler
    cdef object ctx_ptr

    # Get context (stored as tuple: (handler, context_id))
    # For now we use a simpler approach - the context is the handler itself
    pass  # This is handled differently below


# Storage for I/O callbacks (prevent garbage collection)
cdef dict _io_callbacks = {}
cdef int _io_callback_id = 0


cdef void _dispatch_read_handler(dispatch_data_t data, int error) noexcept with gil:
    """Handler for dispatch_read."""
    global _io_callback_id
    # This approach won't work well - we need to store context
    pass


# Simpler async I/O using completion handlers
def read_async(int fd, size_t length, handler, Queue queue=None):
    """
    Read data from a file descriptor asynchronously.

    Args:
        fd: File descriptor to read from.
        length: Maximum number of bytes to read.
        handler: Callable invoked with (data: bytes, error: int) when complete.
                 data is the bytes read, error is 0 on success.
        queue: Queue to execute handler on. If None, uses default global queue.
    """
    if not callable(handler):
        raise TypeError("handler must be callable")

    cdef dispatch_queue_t q
    if queue is not None:
        q = queue._queue
    else:
        with nogil:
            q = dispatch_get_global_queue(_DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)

    # We need to use a workaround since dispatch_read uses blocks
    # For now, implement using ReadSource and os.read
    import os as _os

    def _do_read():
        try:
            data = _os.read(fd, length)
            handler(data, 0)
        except OSError as e:
            handler(b"", e.errno)

    cdef Queue wrap_queue
    if queue is not None:
        wrap_queue = queue
    else:
        wrap_queue = Queue.global_queue()

    wrap_queue.run_async(_do_read)


def write_async(int fd, bytes data, handler, Queue queue=None):
    """
    Write data to a file descriptor asynchronously.

    Args:
        fd: File descriptor to write to.
        data: Bytes to write.
        handler: Callable invoked with (remaining: bytes, error: int) when complete.
                 remaining is any unwritten data, error is 0 on success.
        queue: Queue to execute handler on. If None, uses default global queue.
    """
    if not callable(handler):
        raise TypeError("handler must be callable")

    import os as _os

    def _do_write():
        try:
            written = _os.write(fd, data)
            remaining = data[written:] if written < len(data) else b""
            handler(remaining, 0)
        except OSError as e:
            handler(data, e.errno)

    cdef Queue wrap_queue
    if queue is not None:
        wrap_queue = queue
    else:
        wrap_queue = Queue.global_queue()

    wrap_queue.run_async(_do_write)


cdef class Workloop:
    """
    Dispatch workloop for priority-inversion-avoiding execution.

    Workloops are specialized queues that avoid priority inversion by
    dynamically adjusting the priority of work items.
    """
    cdef dispatch_workloop_t _workloop
    cdef bint _owned
    cdef bint _inactive
    cdef bytes _label_bytes

    def __cinit__(self):
        self._workloop = NULL
        self._owned = False
        self._inactive = False

    def __init__(self, str label, bint inactive=False):
        """
        Create a new workloop.

        Args:
            label: String label for debugging.
            inactive: If True, create in inactive state. Must call activate()
                      before the workloop will process tasks.
        """
        cdef const char* c_label = NULL

        if label is not None:
            self._label_bytes = label.encode('utf-8')
            c_label = self._label_bytes

        if inactive:
            with nogil:
                self._workloop = dispatch_workloop_create_inactive(c_label)
            self._inactive = True
        else:
            # dispatch_workloop_create creates an inactive workloop that must be activated
            with nogil:
                self._workloop = dispatch_workloop_create(c_label)

        if self._workloop == NULL:
            raise RuntimeError("Failed to create workloop")

        self._owned = True

        # Activate non-inactive workloops immediately
        if not inactive:
            with nogil:
                dispatch_activate(<dispatch_queue_t>self._workloop)

    def __dealloc__(self):
        if self._workloop != NULL and self._owned:
            # Must activate inactive workloops before releasing
            # otherwise dispatch_release will block forever
            if self._inactive:
                dispatch_activate(<dispatch_queue_t>self._workloop)
            dispatch_release(<dispatch_queue_t>self._workloop)
            self._workloop = NULL

    def activate(self):
        """
        Activate an inactive workloop.

        Raises:
            RuntimeError: If the workloop was not created as inactive.
        """
        if not self._inactive:
            raise RuntimeError("Workloop was not created as inactive")
        with nogil:
            dispatch_activate(<dispatch_queue_t>self._workloop)
        self._inactive = False

    @property
    def is_inactive(self):
        """Check if the workloop is currently inactive."""
        return self._inactive

    def run_async(self, func):
        """
        Submit a callable for asynchronous execution on the workloop.

        Args:
            func: A callable taking no arguments.

        Raises:
            RuntimeError: If the workloop is inactive.
        """
        if self._inactive:
            raise RuntimeError("Cannot submit work to an inactive workloop")
        if not callable(func):
            raise TypeError("func must be callable")
        Py_INCREF(func)
        cdef PyObject* ctx = <PyObject*>func
        with nogil:
            dispatch_async_f(<dispatch_queue_t>self._workloop, <void*>ctx, _python_callback)

    def run_sync(self, func):
        """
        Submit a callable for synchronous execution on the workloop.

        Note: Uses async + semaphore pattern since dispatch_sync_f can deadlock
        on workloops due to their specialized execution model.

        Args:
            func: A callable taking no arguments.

        Raises:
            RuntimeError: If the workloop is inactive.
        """
        if self._inactive:
            raise RuntimeError("Cannot submit work to an inactive workloop")
        if not callable(func):
            raise TypeError("func must be callable")

        # Use Python Semaphore to wait for completion
        sem = Semaphore(0)
        exception_info = [None]

        def wrapper():
            try:
                func()
            except Exception as e:
                exception_info[0] = e
            finally:
                sem.signal()

        self.run_async(wrapper)
        sem.wait()

        if exception_info[0] is not None:
            raise exception_info[0]