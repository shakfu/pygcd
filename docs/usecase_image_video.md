# Image and Video Processing Use Case

Guide to using cygcd for parallel image and video processing pipelines.

## Why GCD for Image/Video Processing?

Image and video processing are inherently parallelizable:
- Individual frames are independent
- Image tiles can be processed concurrently
- I/O (reading/writing files) can overlap with computation
- Multiple processing stages form natural pipelines

GCD excels here because:
- `apply()` parallelizes loops with minimal overhead
- Concurrent queues maximize CPU utilization
- IOChannel provides efficient async file I/O
- Producer-consumer patterns handle variable processing times

## Relevant Features

| Feature | Image/Video Use Case |
|---------|---------------------|
| **apply()** | Parallel for-loops over pixels, frames, or files |
| **Concurrent Queue** | Process multiple images simultaneously |
| **Serial Queue** | Ordered output, resource serialization |
| **Group** | Wait for batch completion |
| **Semaphore** | Limit memory usage, control concurrency |
| **IOChannel** | Fast async file reading/writing |
| **Barrier** | Synchronization between pipeline stages |

## Examples

### Parallel Batch Image Processing

Process multiple images concurrently:

```python
import cygcd
import os
from PIL import Image

def process_image(path):
    """Apply filters to a single image."""
    img = Image.open(path)
    # Apply processing...
    img = img.convert("L")  # Grayscale
    img = img.resize((img.width // 2, img.height // 2))

    out_path = path.replace("/input/", "/output/")
    img.save(out_path)
    return out_path

# Get all images
input_dir = "/path/to/input"
images = [os.path.join(input_dir, f) for f in os.listdir(input_dir)
          if f.endswith(('.jpg', '.png'))]

# Process all images in parallel using apply()
results = [None] * len(images)

def process_at_index(i):
    results[i] = process_image(images[i])

cygcd.apply(len(images), process_at_index)

print(f"Processed {len(results)} images")
```

### Memory-Limited Concurrent Processing

Use Semaphore to limit concurrent operations when memory is constrained:

```python
import cygcd
from PIL import Image

# Limit to 4 concurrent large image operations
memory_limit = cygcd.Semaphore(4)
process_queue = cygcd.Queue("image.process", concurrent=True)

def process_large_image(path):
    """Process a large image with memory limiting."""
    memory_limit.wait()  # Acquire slot
    try:
        img = Image.open(path)
        # Heavy processing on large image...
        result = heavy_filter(img)
        result.save(path.replace(".raw", "_processed.tiff"))
    finally:
        memory_limit.signal()  # Release slot

# Queue all images - only 4 will process at once
g = cygcd.Group()
for path in large_images:
    g.run_async(process_queue, lambda p=path: process_large_image(p))

g.wait()  # Wait for all to complete
```

### Parallel Pixel Processing with apply()

Process image pixels in parallel strips:

```python
import cygcd
import numpy as np
from PIL import Image

def parallel_filter(img_array, kernel_func):
    """Apply a filter to an image using parallel strips."""
    height, width = img_array.shape[:2]
    result = np.zeros_like(img_array)

    # Number of strips = number of CPU cores
    num_strips = os.cpu_count() or 4
    strip_height = height // num_strips

    def process_strip(strip_idx):
        y_start = strip_idx * strip_height
        y_end = height if strip_idx == num_strips - 1 else (strip_idx + 1) * strip_height

        for y in range(y_start, y_end):
            for x in range(width):
                result[y, x] = kernel_func(img_array, x, y)

    # Process all strips in parallel
    cygcd.apply(num_strips, process_strip)

    return result

# Example: parallel blur
def blur_kernel(img, x, y):
    h, w = img.shape[:2]
    total = 0
    count = 0
    for dy in range(-1, 2):
        for dx in range(-1, 2):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w:
                total += img[ny, nx]
                count += 1
    return total // count

img = np.array(Image.open("input.png").convert("L"))
blurred = parallel_filter(img, blur_kernel)
Image.fromarray(blurred).save("output.png")
```

### Video Frame Processing Pipeline

Process video frames with a producer-consumer pipeline:

```python
import cygcd
import cv2
from collections import deque

class VideoProcessor:
    """Multi-stage video processing pipeline."""

    def __init__(self, max_buffered=10):
        # Queues for each stage
        self.read_queue = cygcd.Queue("video.read")
        self.process_queue = cygcd.Queue("video.process", concurrent=True)
        self.write_queue = cygcd.Queue("video.write")

        # Flow control
        self.buffer_slots = cygcd.Semaphore(max_buffered)
        self.frames_ready = cygcd.Semaphore(0)

        # Frame buffer (thread-safe access via queues)
        self.pending_frames = deque()
        self.processed_frames = {}
        self.frame_lock = cygcd.Queue("video.lock")  # Serial queue as lock

        self.running = False
        self.frame_count = 0
        self.processed_count = 0

    def _read_frames(self, video_path):
        """Read frames from video file."""
        cap = cv2.VideoCapture(video_path)
        frame_idx = 0

        while self.running:
            self.buffer_slots.wait()  # Wait for buffer space

            ret, frame = cap.read()
            if not ret:
                break

            # Add to pending queue
            def add_frame(idx=frame_idx, f=frame):
                self.pending_frames.append((idx, f))
                self.frame_count = idx + 1

            self.frame_lock.run_sync(add_frame)
            self.frames_ready.signal()
            frame_idx += 1

        cap.release()
        self.running = False

    def _process_frames(self):
        """Process frames (runs on concurrent queue)."""
        while self.running or self.pending_frames:
            if not self.frames_ready.wait(0.1):  # 100ms timeout
                continue

            # Get next frame
            frame_data = None
            def get_frame():
                nonlocal frame_data
                if self.pending_frames:
                    frame_data = self.pending_frames.popleft()

            self.frame_lock.run_sync(get_frame)

            if frame_data is None:
                continue

            idx, frame = frame_data

            # Process frame (this is the expensive part)
            processed = self._apply_effects(frame)

            # Store result
            def store_result(i=idx, p=processed):
                self.processed_frames[i] = p
                self.processed_count += 1

            self.frame_lock.run_sync(store_result)
            self.buffer_slots.signal()  # Free buffer slot

    def _apply_effects(self, frame):
        """Apply video effects to a frame."""
        # Example: edge detection + color adjustment
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        edges = cv2.Canny(gray, 100, 200)
        return cv2.cvtColor(edges, cv2.COLOR_GRAY2BGR)

    def _write_frames(self, output_path, fps, size):
        """Write processed frames in order."""
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out = cv2.VideoWriter(output_path, fourcc, fps, size)

        next_frame = 0
        while self.running or next_frame < self.frame_count:
            # Check if next frame is ready
            frame = None
            def check_frame():
                nonlocal frame
                if next_frame in self.processed_frames:
                    frame = self.processed_frames.pop(next_frame)

            self.frame_lock.run_sync(check_frame)

            if frame is not None:
                out.write(frame)
                next_frame += 1
            else:
                cygcd.Semaphore(0).wait(0.01)  # Small sleep

        out.release()

    def process(self, input_path, output_path):
        """Process entire video."""
        # Get video properties
        cap = cv2.VideoCapture(input_path)
        fps = cap.get(cv2.CAP_PROP_FPS)
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        cap.release()

        self.running = True

        # Start pipeline stages
        g = cygcd.Group()

        # Reader (single thread)
        g.run_async(self.read_queue, lambda: self._read_frames(input_path))

        # Processors (multiple concurrent)
        num_processors = os.cpu_count() or 4
        for _ in range(num_processors):
            g.run_async(self.process_queue, self._process_frames)

        # Writer (single thread, maintains order)
        g.run_async(self.write_queue,
                   lambda: self._write_frames(output_path, fps, (width, height)))

        g.wait()
        print(f"Processed {self.processed_count} frames")

# Usage
processor = VideoProcessor(max_buffered=20)
processor.process("input.mp4", "output.mp4")
```

### Thumbnail Generation with IOChannel

Generate thumbnails efficiently using async I/O:

```python
import cygcd
import os
from PIL import Image
from io import BytesIO

def generate_thumbnails_async(image_paths, thumb_size=(128, 128)):
    """Generate thumbnails using async file I/O."""

    process_queue = cygcd.Queue("thumb.process", concurrent=True,
                                qos=cygcd.QOS_CLASS_UTILITY)
    results = {}
    g = cygcd.Group()

    for path in image_paths:
        def process_image(p=path):
            # Read file with IOChannel for efficiency
            fd = os.open(p, os.O_RDONLY)
            channel = cygcd.IOChannel(fd, cygcd.IO_STREAM)

            data_chunks = []
            read_done = cygcd.Semaphore(0)

            def on_read(done, data, error):
                if data:
                    data_chunks.append(data)
                if done:
                    read_done.signal()

            file_size = os.path.getsize(p)
            channel.read(file_size, on_read)
            read_done.wait()
            channel.close()
            os.close(fd)

            # Process image
            image_data = b"".join(data_chunks)
            img = Image.open(BytesIO(image_data))
            img.thumbnail(thumb_size)

            # Save thumbnail
            thumb_path = p.replace("/images/", "/thumbs/")
            thumb_path = os.path.splitext(thumb_path)[0] + "_thumb.jpg"
            os.makedirs(os.path.dirname(thumb_path), exist_ok=True)
            img.save(thumb_path, "JPEG", quality=85)

            results[p] = thumb_path

        g.run_async(process_queue, process_image)

    g.wait()
    return results

# Generate thumbnails for all images
images = glob.glob("/data/images/**/*.jpg", recursive=True)
thumbs = generate_thumbnails_async(images)
print(f"Generated {len(thumbs)} thumbnails")
```

### Image Tiling for Large Images

Process very large images by splitting into tiles:

```python
import cygcd
import numpy as np
from PIL import Image

class TiledImageProcessor:
    """Process large images in parallel tiles."""

    def __init__(self, tile_size=512, overlap=32):
        self.tile_size = tile_size
        self.overlap = overlap
        self.queue = cygcd.Queue("tile.process", concurrent=True)

    def process(self, input_path, output_path, filter_func):
        """Process a large image using tiles."""
        img = Image.open(input_path)
        img_array = np.array(img)

        height, width = img_array.shape[:2]
        result = np.zeros_like(img_array)

        # Calculate tile positions
        tiles = []
        y = 0
        while y < height:
            x = 0
            while x < width:
                tiles.append((x, y))
                x += self.tile_size - self.overlap
            y += self.tile_size - self.overlap

        # Process tiles in parallel
        tile_results = {}
        g = cygcd.Group()

        for tx, ty in tiles:
            def process_tile(x=tx, y=ty):
                # Extract tile with overlap
                x_end = min(x + self.tile_size, width)
                y_end = min(y + self.tile_size, height)
                tile = img_array[y:y_end, x:x_end].copy()

                # Process tile
                processed = filter_func(tile)
                tile_results[(x, y)] = processed

            g.run_async(self.queue, process_tile)

        g.wait()

        # Stitch tiles back together (handle overlap with blending)
        for (tx, ty), tile in tile_results.items():
            th, tw = tile.shape[:2]

            # Calculate blend region
            x_start = tx + (self.overlap // 2 if tx > 0 else 0)
            y_start = ty + (self.overlap // 2 if ty > 0 else 0)

            tile_x_start = self.overlap // 2 if tx > 0 else 0
            tile_y_start = self.overlap // 2 if ty > 0 else 0

            # Copy tile to result
            result[y_start:ty+th, x_start:tx+tw] = tile[tile_y_start:, tile_x_start:]

        # Save result
        Image.fromarray(result).save(output_path)

# Example: process a large panorama
processor = TiledImageProcessor(tile_size=1024, overlap=64)

def sharpen_filter(tile):
    from scipy.ndimage import convolve
    kernel = np.array([[-1, -1, -1],
                       [-1,  9, -1],
                       [-1, -1, -1]])
    if len(tile.shape) == 3:
        return np.stack([convolve(tile[:,:,c], kernel) for c in range(3)], axis=2)
    return convolve(tile, kernel)

processor.process("panorama_huge.tiff", "panorama_sharp.tiff", sharpen_filter)
```

### Real-Time Frame Processing

Process frames from a camera feed in real-time:

```python
import cygcd
import cv2
import time

class RealtimeProcessor:
    """Process camera frames with bounded latency."""

    def __init__(self, max_queue_depth=2):
        # Drop frames rather than queue them to maintain low latency
        self.max_queue_depth = max_queue_depth
        self.queue_depth = cygcd.Semaphore(max_queue_depth)

        self.capture_queue = cygcd.Queue("camera.capture")
        self.process_queue = cygcd.Queue("camera.process", concurrent=True,
                                         qos=cygcd.QOS_CLASS_USER_INITIATED)
        self.display_queue = cygcd.Queue("camera.display",
                                         qos=cygcd.QOS_CLASS_USER_INTERACTIVE)

        self.running = False
        self.latest_frame = None
        self.frame_lock = cygcd.Queue("frame.lock")
        self.stats = {"captured": 0, "processed": 0, "dropped": 0}

    def _capture_loop(self, camera_id):
        """Capture frames, dropping if processing is behind."""
        cap = cv2.VideoCapture(camera_id)

        while self.running:
            ret, frame = cap.read()
            if not ret:
                continue

            self.stats["captured"] += 1

            # Try to acquire processing slot (non-blocking)
            if self.queue_depth.wait(0):  # timeout=0 means non-blocking
                self.process_queue.run_async(
                    lambda f=frame: self._process_frame(f)
                )
            else:
                self.stats["dropped"] += 1

        cap.release()

    def _process_frame(self, frame):
        """Process a single frame."""
        try:
            # Apply real-time effects
            processed = cv2.GaussianBlur(frame, (15, 15), 0)
            processed = cv2.Canny(processed, 50, 150)
            processed = cv2.cvtColor(processed, cv2.COLOR_GRAY2BGR)

            # Update latest frame for display
            def update_latest(f=processed):
                self.latest_frame = f

            self.frame_lock.run_sync(update_latest)
            self.stats["processed"] += 1
        finally:
            self.queue_depth.signal()  # Release processing slot

    def _display_loop(self):
        """Display processed frames."""
        while self.running:
            frame = None
            def get_frame():
                nonlocal frame
                frame = self.latest_frame

            self.frame_lock.run_sync(get_frame)

            if frame is not None:
                cv2.imshow("Processed", frame)

            if cv2.waitKey(1) & 0xFF == ord('q'):
                self.running = False

    def run(self, camera_id=0):
        """Start real-time processing."""
        self.running = True

        g = cygcd.Group()
        g.run_async(self.capture_queue, lambda: self._capture_loop(camera_id))
        g.run_async(self.display_queue, self._display_loop)

        g.wait()

        cv2.destroyAllWindows()
        print(f"Stats: {self.stats}")
        drop_rate = self.stats['dropped'] / max(1, self.stats['captured']) * 100
        print(f"Drop rate: {drop_rate:.1f}%")

# Run real-time processor
processor = RealtimeProcessor(max_queue_depth=3)
processor.run(camera_id=0)
```

### Batch Format Conversion

Convert images between formats in parallel:

```python
import cygcd
import os
from PIL import Image
from pathlib import Path

class BatchConverter:
    """Convert images between formats in parallel."""

    def __init__(self, num_workers=None):
        self.num_workers = num_workers or os.cpu_count() or 4
        self.queue = cygcd.Queue("convert", concurrent=True,
                                 qos=cygcd.QOS_CLASS_UTILITY)
        self.progress_queue = cygcd.Queue("progress")  # Serial for safe updates
        self.completed = 0
        self.errors = []

    def convert(self, input_dir, output_dir, output_format="webp", **save_options):
        """Convert all images in directory."""
        input_path = Path(input_dir)
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)

        # Find all images
        extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.gif'}
        images = [f for f in input_path.rglob("*") if f.suffix.lower() in extensions]
        total = len(images)

        print(f"Converting {total} images to {output_format}...")

        # Limit concurrent conversions to manage memory
        memory_limit = cygcd.Semaphore(self.num_workers * 2)
        g = cygcd.Group()

        for img_path in images:
            def convert_one(p=img_path):
                memory_limit.wait()
                try:
                    # Calculate output path
                    rel_path = p.relative_to(input_path)
                    out_file = output_path / rel_path.with_suffix(f".{output_format}")
                    out_file.parent.mkdir(parents=True, exist_ok=True)

                    # Convert
                    img = Image.open(p)
                    if img.mode in ('RGBA', 'LA') and output_format.lower() == 'jpeg':
                        img = img.convert('RGB')
                    img.save(out_file, **save_options)

                    # Update progress
                    def update():
                        self.completed += 1
                        if self.completed % 100 == 0:
                            print(f"Progress: {self.completed}/{total}")

                    self.progress_queue.run_async(update)

                except Exception as e:
                    def log_error(path=p, error=e):
                        self.errors.append((path, error))
                    self.progress_queue.run_async(log_error)
                finally:
                    memory_limit.signal()

            g.run_async(self.queue, convert_one)

        g.wait()

        print(f"Completed: {self.completed}/{total}")
        if self.errors:
            print(f"Errors: {len(self.errors)}")
            for path, error in self.errors[:5]:
                print(f"  {path}: {error}")

# Convert PNG to WebP
converter = BatchConverter(num_workers=8)
converter.convert(
    "/data/screenshots",
    "/data/screenshots_webp",
    output_format="webp",
    quality=85,
    method=4  # WebP compression method
)
```

## Performance Tips

### Choosing Concurrency Level

```python
import os

# CPU-bound work: use CPU count
cpu_workers = os.cpu_count() or 4

# I/O-bound work: can exceed CPU count
io_workers = (os.cpu_count() or 4) * 2

# Memory-bound: limit based on image size and available RAM
available_ram_gb = 16
avg_image_mb = 50
memory_workers = int(available_ram_gb * 1024 / avg_image_mb / 2)
```

### QOS Classes for Image Processing

| Task Type | QOS Class | Reason |
|-----------|-----------|--------|
| User-initiated conversion | USER_INITIATED | User is waiting |
| Background batch | UTILITY | Long-running, battery-friendly |
| Real-time preview | USER_INTERACTIVE | Immediate feedback needed |
| Thumbnail generation | UTILITY | Background optimization |

### Avoiding Common Pitfalls

1. **Memory pressure**: Use Semaphore to limit concurrent large image loads
2. **GIL contention**: Use `apply()` for NumPy operations (releases GIL)
3. **File handle exhaustion**: Close files promptly, limit concurrent I/O
4. **Unordered output**: Use serial queue or explicit ordering for video frames

```python
# Bad: Unlimited concurrent loads
for img in images:
    queue.run_async(lambda: process_large(img))  # Memory explosion

# Good: Limited concurrent loads
limit = cygcd.Semaphore(4)
for img in images:
    def process(path=img):
        limit.wait()
        try:
            process_large(path)
        finally:
            limit.signal()
    queue.run_async(process)
```
