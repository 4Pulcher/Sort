"""functions.image - native media dimension parsing.

Python equivalent of the shell `functions/imagemagick` module: it replaces
ImageMagick `identify`. Dimensions for PNG, GIF, BMP, JPEG and WEBP are
parsed from the file bytes with `struct` (stdlib).
"""

from . import ENGINE

image_dimensions = ENGINE.image_dimensions
resolution_format_label = ENGINE.resolution_format_label
RESOLUTION_TIERS = ENGINE.RESOLUTION_TIERS

__all__ = ["image_dimensions", "resolution_format_label", "RESOLUTION_TIERS"]
