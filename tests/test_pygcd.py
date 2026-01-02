"""Tests for pygcd Cython extension module."""

import pygcd


def test_add():
    """Test add function."""
    assert pygcd.add(1, 2) == 3
    assert pygcd.add(-1, 1) == 0
    assert pygcd.add(0, 0) == 0


def test_greet():
    """Test greet function."""
    assert pygcd.greet("World") == "Hello, World!"
    assert pygcd.greet("Python") == "Hello, Python!"
