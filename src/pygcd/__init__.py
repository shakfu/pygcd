"""
pygcd - A Python extension module built with Cython.

Example usage:
    >>> import pygcd
    >>> pygcd.add(1, 2)
    3
    >>> pygcd.greet("World")
    'Hello, World!'
"""

from pygcd._core import add, greet

__all__ = ["add", "greet"]
__version__ = "0.1.0"
