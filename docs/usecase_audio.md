# Audio Use Case

Guide to using cygcd for precisely timed concurrent audio applications.

## Relevant Features

| Feature | Audio Use Case |
|---------|----------------|
| **Timer** | Periodic buffer fills, metronome ticks, scheduled events |
| **Workloop** | Prevents audio glitches from priority inversion when audio thread waits on locks |
| **Queue (QOS_CLASS_USER_INTERACTIVE)** | Highest priority for latency-critical audio processing |
| **Semaphore** | Producer-consumer between render and playback threads |
| **Group** | Synchronize multiple tracks to start together |

## Examples

### Low-Latency Audio Callback

Use a high-priority queue with a precise timer for regular buffer fills:

```python
import cygcd

# High-priority queue for audio work
audio_queue = cygcd.Queue("audio", qos=cygcd.QOS_CLASS_USER_INTERACTIVE)

# Precise timer for buffer fills (e.g., every 10ms)
timer = cygcd.Timer(
    interval=0.010,      # 10ms
    handler=fill_audio_buffer,
    queue=audio_queue,
    leeway=0.0           # Minimize timing jitter
)
timer.start()
```

### Synchronized Multi-Track Start

Use Group to prepare tracks concurrently, then start them together:

```python
import cygcd

g = cygcd.Group()
audio_q = cygcd.Queue("audio", qos=cygcd.QOS_CLASS_USER_INTERACTIVE)

# Prepare all tracks concurrently
for track in tracks:
    g.run_async(audio_q, track.prepare)

# Wait for all ready, then start together
g.wait()
start_time = cygcd.time_from_now(0.050)  # 50ms from now
for track in tracks:
    audio_q.after(0.050, track.play)
```

### Producer-Consumer Audio Pipeline

Use Semaphore to coordinate between render and playback threads:

```python
import cygcd

buffer_ready = cygcd.Semaphore(0)
buffer_free = cygcd.Semaphore(2)  # Double buffering

render_queue = cygcd.Queue("render", qos=cygcd.QOS_CLASS_USER_INITIATED)
playback_queue = cygcd.Queue("playback", qos=cygcd.QOS_CLASS_USER_INTERACTIVE)

def render_loop():
    while running:
        buffer_free.wait()      # Wait for free buffer
        render_to_buffer()
        buffer_ready.signal()   # Signal buffer ready

def playback_loop():
    while running:
        buffer_ready.wait()     # Wait for rendered data
        play_from_buffer()
        buffer_free.signal()    # Signal buffer consumed

render_queue.run_async(render_loop)
playback_queue.run_async(playback_loop)
```

### Avoiding Priority Inversion with Workloop

When audio threads share state with lower-priority threads:

```python
import cygcd
import threading

# Shared state between UI and audio
audio_params = {"volume": 1.0, "pan": 0.0}
params_lock = threading.Lock()

# Workloop prevents priority inversion
audio_workloop = cygcd.Workloop("audio.workloop")

def audio_callback():
    with params_lock:
        vol = audio_params["volume"]
        pan = audio_params["pan"]
    process_audio(vol, pan)

def ui_update_volume(new_vol):
    # Lower priority, but won't block audio indefinitely
    with params_lock:
        audio_params["volume"] = new_vol

# Audio runs on workloop - if it waits on params_lock while
# UI holds it, the UI thread's priority is temporarily boosted
timer = cygcd.Timer(0.010, audio_callback, queue=None)
```

## MIDI Playback

MIDI is well-suited to GCD because it's event-based rather than sample-based. While individual MIDI messages have microsecond-level timestamps, the scheduling granularity of ~1ms is often acceptable for musical timing.

### MIDI Timing Considerations

| Tempo (BPM) | Beat Duration | 1ms as % of Beat |
|-------------|---------------|------------------|
| 60          | 1000 ms       | 0.1%             |
| 120         | 500 ms        | 0.2%             |
| 180         | 333 ms        | 0.3%             |
| 240         | 250 ms        | 0.4%             |

At typical tempos, 1ms jitter is imperceptible. GCD is suitable for MIDI scheduling.

### Basic MIDI Sequencer

Schedule MIDI events using `after()` for precise timing:

```python
import cygcd

midi_queue = cygcd.Queue("midi", qos=cygcd.QOS_CLASS_USER_INTERACTIVE)

def schedule_note(note, velocity, time_seconds, duration_seconds):
    """Schedule a note-on and note-off event."""
    def note_on():
        send_midi(0x90, note, velocity)  # Note on

    def note_off():
        send_midi(0x80, note, 0)  # Note off

    midi_queue.after(time_seconds, note_on)
    midi_queue.after(time_seconds + duration_seconds, note_off)

# Schedule a C major chord at t=0
schedule_note(60, 100, 0.0, 1.0)   # C
schedule_note(64, 100, 0.0, 1.0)   # E
schedule_note(67, 100, 0.0, 1.0)   # G
```

### Concurrent MIDI Streams (Multi-Track)

Use a concurrent queue to play multiple MIDI tracks simultaneously:

```python
import cygcd

# Concurrent queue allows parallel track playback
midi_queue = cygcd.Queue("midi.concurrent",
                         concurrent=True,
                         qos=cygcd.QOS_CLASS_USER_INTERACTIVE)

class MIDITrack:
    def __init__(self, name, channel):
        self.name = name
        self.channel = channel
        self.events = []  # List of (time, note, velocity, duration)

    def play(self, start_time=0.0):
        """Schedule all events on this track."""
        note_on = 0x90 | self.channel
        note_off = 0x80 | self.channel

        for time, note, velocity, duration in self.events:
            event_time = start_time + time

            def make_handlers(n, v, no, noff):
                return (
                    lambda: send_midi(no, n, v),
                    lambda: send_midi(noff, n, 0)
                )

            on_handler, off_handler = make_handlers(note, velocity, note_on, note_off)
            midi_queue.after(event_time, on_handler)
            midi_queue.after(event_time + duration, off_handler)

# Create tracks
melody = MIDITrack("melody", channel=0)
bass = MIDITrack("bass", channel=1)
drums = MIDITrack("drums", channel=9)

# Load events...
melody.events = [(0.0, 72, 100, 0.5), (0.5, 74, 100, 0.5), ...]
bass.events = [(0.0, 36, 80, 1.0), (1.0, 38, 80, 1.0), ...]
drums.events = [(0.0, 36, 127, 0.1), (0.5, 42, 100, 0.1), ...]

# Play all tracks - they run concurrently
melody.play()
bass.play()
drums.play()
```

### Synchronized Multi-Track Start

Use Group to prepare tracks and start them at exactly the same time:

```python
import cygcd
import time

midi_queue = cygcd.Queue("midi", concurrent=True,
                         qos=cygcd.QOS_CLASS_USER_INTERACTIVE)
tracks = [melody, bass, drums, chords]

# Prepare all tracks (load events, set up state)
g = cygcd.Group()
for track in tracks:
    g.run_async(midi_queue, track.prepare)
g.wait()

# Calculate start time (small delay to ensure all scheduling completes)
start_delay = 0.050  # 50ms
start_time = time.time() + start_delay

# Schedule all tracks with same reference time
for track in tracks:
    track.play(start_time=start_delay)

print(f"Playback starting at {start_time}")
```

### MIDI Clock Generation

Generate MIDI clock (24 PPQ) with a Timer:

```python
import cygcd

class MIDIClock:
    def __init__(self, bpm=120.0):
        self.bpm = bpm
        self.running = False
        self.timer = None
        self.queue = cygcd.Queue("midi.clock",
                                  qos=cygcd.QOS_CLASS_USER_INTERACTIVE)

    @property
    def tick_interval(self):
        """Interval between MIDI clock ticks (24 PPQ)."""
        beat_duration = 60.0 / self.bpm
        return beat_duration / 24.0

    def _send_clock(self):
        send_midi(0xF8)  # MIDI Clock message

    def start(self):
        send_midi(0xFA)  # MIDI Start
        self.running = True
        self.timer = cygcd.Timer(
            interval=self.tick_interval,
            handler=self._send_clock,
            queue=self.queue,
            leeway=0.0  # Minimize jitter
        )
        self.timer.start()

    def stop(self):
        if self.timer:
            self.timer.cancel()
        send_midi(0xFC)  # MIDI Stop
        self.running = False

    def set_tempo(self, bpm):
        """Change tempo - reconfigure timer."""
        self.bpm = bpm
        if self.timer and self.running:
            self.timer.set_timer(
                start=cygcd.DISPATCH_TIME_NOW,
                interval=self.tick_interval,
                leeway=0.0
            )

clock = MIDIClock(bpm=120)
clock.start()
# ... later
clock.set_tempo(140)  # Speed up
# ... later
clock.stop()
```

### Lookahead Scheduling for Tighter Timing

For better timing precision, schedule events ahead of time in batches:

```python
import cygcd
import time

class LookaheadSequencer:
    """Schedule MIDI events in batches for tighter timing."""

    def __init__(self, lookahead_ms=50):
        self.lookahead = lookahead_ms / 1000.0
        self.queue = cygcd.Queue("midi.seq",
                                  qos=cygcd.QOS_CLASS_USER_INTERACTIVE)
        self.events = []  # (absolute_time, midi_bytes)
        self.position = 0
        self.start_time = 0
        self.timer = None
        self.running = False

    def _schedule_batch(self):
        """Schedule events within the lookahead window."""
        if not self.running:
            return

        now = time.time() - self.start_time
        window_end = now + self.lookahead

        while self.position < len(self.events):
            event_time, midi_data = self.events[self.position]

            if event_time > window_end:
                break  # Event is beyond lookahead window

            delay = max(0, event_time - now)
            self.queue.after(delay, lambda d=midi_data: send_midi_bytes(d))
            self.position += 1

        # Check if we're done
        if self.position >= len(self.events):
            self.stop()

    def play(self):
        self.running = True
        self.position = 0
        self.start_time = time.time()

        # Timer fires every lookahead/2 to schedule next batch
        self.timer = cygcd.Timer(
            interval=self.lookahead / 2,
            handler=self._schedule_batch,
            queue=self.queue
        )
        self._schedule_batch()  # Schedule first batch immediately
        self.timer.start()

    def stop(self):
        self.running = False
        if self.timer:
            self.timer.cancel()
```

### Real-Time MIDI Input Handling

Use a serial queue to process incoming MIDI without blocking:

```python
import cygcd

# Serial queue ensures MIDI events are processed in order
midi_in_queue = cygcd.Queue("midi.input",
                            qos=cygcd.QOS_CLASS_USER_INTERACTIVE)

def on_midi_received(midi_bytes):
    """Called from MIDI input callback (e.g., Core MIDI)."""
    # Don't process in the callback - dispatch to queue
    midi_in_queue.run_async(lambda: process_midi(midi_bytes))

def process_midi(midi_bytes):
    """Process MIDI on dedicated queue."""
    status = midi_bytes[0]

    if status & 0xF0 == 0x90:  # Note On
        note, velocity = midi_bytes[1], midi_bytes[2]
        trigger_sound(note, velocity)
    elif status & 0xF0 == 0x80:  # Note Off
        note = midi_bytes[1]
        release_sound(note)
    elif status == 0xF8:  # Clock
        advance_sequencer()
```

### Multi-Port MIDI Output

Handle multiple MIDI outputs with separate queues to avoid blocking:

```python
import cygcd

class MIDIOutputManager:
    def __init__(self):
        # Each port gets its own serial queue
        self.port_queues = {}

    def add_port(self, port_id, port_name):
        queue = cygcd.Queue(f"midi.out.{port_name}",
                           qos=cygcd.QOS_CLASS_USER_INTERACTIVE)
        self.port_queues[port_id] = queue

    def send(self, port_id, midi_bytes, delay=0.0):
        """Send MIDI to specific port."""
        queue = self.port_queues.get(port_id)
        if queue:
            if delay > 0:
                queue.after(delay, lambda: port_send(port_id, midi_bytes))
            else:
                queue.run_async(lambda: port_send(port_id, midi_bytes))

    def send_all(self, midi_bytes, delay=0.0):
        """Broadcast to all ports simultaneously."""
        for port_id, queue in self.port_queues.items():
            if delay > 0:
                queue.after(delay, lambda p=port_id: port_send(p, midi_bytes))
            else:
                queue.run_async(lambda p=port_id: port_send(p, midi_bytes))

manager = MIDIOutputManager()
manager.add_port(1, "synth")
manager.add_port(2, "drums")

# Send to specific port
manager.send(1, [0x90, 60, 100])

# Broadcast clock to all ports
manager.send_all([0xF8])
```

## Caveats

### GCD is Not Hard Real-Time

GCD provides priority scheduling but not hard timing guarantees. For sample-accurate audio:

- **Use Core Audio** for actual audio I/O callbacks - it provides real-time threads managed by the system
- **Use GCD** for supporting tasks:
  - UI updates from audio state
  - Loading/decoding files in background
  - MIDI event scheduling
  - Non-sample-accurate timing (visual metronomes, beat indicators)

### Timer Precision

GCD timers provide approximately 1ms precision, which is insufficient for sample-accurate timing:

| Sample Rate | Sample Period |
|-------------|---------------|
| 44.1 kHz    | 22.7 microseconds |
| 48 kHz      | 20.8 microseconds |
| 96 kHz      | 10.4 microseconds |

For sample-accurate work, use Core Audio's timestamps and audio unit callbacks.

### When to Use Workloop

Workloop is specifically useful when your audio system has:

1. A high-priority render/playback thread
2. Shared state with lower-priority threads (UI, file I/O, network)
3. Any locking between priority levels

Without Workloop, this scenario can cause audio glitches:

```
1. Low-priority UI thread acquires params_lock
2. High-priority audio callback needs params_lock, blocks
3. Medium-priority background task runs (file loading)
4. Audio callback is blocked by medium-priority task (priority inversion)
5. Audio buffer underrun -> glitch
```

Workloop's priority inheritance temporarily boosts the UI thread's priority when audio is waiting, preventing the medium-priority task from causing delays.

## Recommended Architecture

```
+------------------+     +-------------------+
|   Core Audio     |     |   cygcd Queues    |
|   (Real-time)    |     |   (Best-effort)   |
+------------------+     +-------------------+
| Audio Unit       |     | File loading      |
| Callbacks        |<--->| MIDI scheduling   |
| Sample-accurate  |     | UI updates        |
| HAL threads      |     | State management  |
+------------------+     +-------------------+
         ^                        ^
         |                        |
         v                        v
    +--------+              +-----------+
    | Audio  |<------------>| Workloop  |
    | Buffer |   (locked)   | (priority |
    +--------+              |  safe)    |
                            +-----------+
```

Use Core Audio for the timing-critical path, and cygcd for everything else with appropriate QOS classes and Workloop where shared state exists.
