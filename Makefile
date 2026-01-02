

.PHONY: all sync build test clean distclean wheel sdist help \
		format lint typecheck check publish publish-test release

# Default target
all: sync

# Sync environment (initial setup, installs dependencies + package)
sync:
	@uv sync --reinstall-package cygcd

# Build/rebuild the extension after code changes
build: distclean
	@uv build

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

release:
	@uv build --sdist
	@uv build --wheel --python 3.9
	@uv build --wheel --python 3.10
	@uv build --wheel --python 3.11
	@uv build --wheel --python 3.12
	@uv build --wheel --python 3.13
	@uv build --wheel --python 3.14

# Build source distribution
sdist:
	@uv build --sdist

# Check distributions with twine
check:
	@uv run twine check dist/*

# Publish to PyPI
publish:
	@uv run twine upload dist/*

# Publish to PyPI Test
publish-test:
	@uv run twine upload --repository testpypi dist/*

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
	@echo "  all          - Build/rebuild the extension (default)"
	@echo "  sync         - Sync environment (initial setup)"
	@echo "  build        - Rebuild extension after code changes"
	@echo "  rebuild      - Alias for build"
	@echo "  test         - Run tests"
	@echo "  format       - Run ruff format"
	@echo "  lint         - Run ruff check --fix"
	@echo "  typecheck    - Run mypy check"
	@echo "  wheel        - Build wheel distribution"
	@echo "  sdist        - Build source distribution"
	@echo "  check        - Check distributions with twine"
	@echo "  publish      - Upload to PyPI"
	@echo "  publish-test - Upload to PyPI Test"
	@echo "  clean        - Remove build artifacts"
	@echo "  distclean    - Remove all generated files"
	@echo "  help         - Show this help message"
