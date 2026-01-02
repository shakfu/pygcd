

.PHONY: all sync build rebuild test clean distclean wheel sdist help \
		format lint typecheck

# Default target
all: build

# Sync environment (initial setup, installs dependencies + package)
sync:
	@uv sync

# Build/rebuild the extension after code changes
build:
	@uv sync --reinstall-package pygcd

# Alias for build
rebuild: build

# Run tests
test:
	@uv run pytest tests/ -v

format:
	@uv run ruff format src/ tests/

lint:
	@uv run ruff check --fix src/ tests/

typecheck:
	@uv run mypy src/

# Build wheel
wheel:
	@uv build --wheel

# Build source distribution
sdist:
	@uv build --sdist

# Clean build artifacts
clean:
	@rm -rf build/
	@rm -rf dist/
	@rm -rf *.egg-info/
	@rm -rf src/*.egg-info/
	@rm -rf .pytest_cache/
	@find . -name "*.so" -delete
	@find . -name "*.pyd" -delete
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# Clean everything including CMake cache
distclean: clean
	@rm -rf CMakeCache.txt CMakeFiles/

# Show help
help:
	@echo "Available targets:"
	@echo "  all       - Build/rebuild the extension (default)"
	@echo "  sync      - Sync environment (initial setup)"
	@echo "  build     - Rebuild extension after code changes"
	@echo "  rebuild   - Alias for build"
	@echo "  test      - Run tests"
	@echo "  format    - Run ruff format"
	@echo "  lint      - Run ruff check --fix"
	@echo "  typecheck - Run mypy check"
	@echo "  wheel     - Build wheel distribution"
	@echo "  sdist     - Build source distribution"
	@echo "  clean     - Remove build artifacts"
	@echo "  distclean - Remove all generated files"
	@echo "  help      - Show this help message"
