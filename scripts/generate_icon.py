#!/usr/bin/env python3
"""Generate the Music Memo app icon matching the design.pen playful game icon.

Creates a 1024x1024 PNG with:
- Purple-to-blue gradient background
- Two overlapping card shapes with glass effect
- White music note on the front card
"""

import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SIZE = 1024
OUTPUT = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"


def lerp_color(c1, c2, t):
    """Linear interpolation between two RGB colors."""
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def draw_gradient(img, c1, c2):
    """Draw a diagonal gradient from top-left to bottom-right."""
    draw = ImageDraw.Draw(img)
    for y in range(SIZE):
        for x in range(SIZE):
            t = (x + y) / (2 * SIZE)
            color = lerp_color(c1, c2, t)
            draw.point((x, y), fill=color)


def draw_rounded_rect(draw, bbox, radius, fill=None, outline=None, width=0):
    """Draw a rounded rectangle."""
    x0, y0, x1, y1 = bbox
    # Use pieslice for corners + rectangles for sides
    draw.rounded_rectangle(bbox, radius=radius, fill=fill, outline=outline, width=width)


def draw_rotated_card(img, cx, cy, w, h, angle, fill, border_color=None, border_width=0, radius=40, shadow=False):
    """Draw a rotated rounded rectangle card with optional shadow."""
    # Create a larger canvas for the card
    card_size = int(max(w, h) * 1.5)
    card_img = Image.new("RGBA", (card_size, card_size), (0, 0, 0, 0))
    card_draw = ImageDraw.Draw(card_img)

    # Center the card in its own canvas
    card_x = (card_size - w) // 2
    card_y = (card_size - h) // 2

    # Draw shadow first (offset down-right)
    if shadow:
        shadow_img = Image.new("RGBA", (card_size, card_size), (0, 0, 0, 0))
        shadow_draw = ImageDraw.Draw(shadow_img)
        shadow_draw.rounded_rectangle(
            [card_x + 8, card_y + 8, card_x + w + 8, card_y + h + 8],
            radius=radius,
            fill=(0, 0, 0, 60),
        )
        shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(radius=20))
        shadow_rot = shadow_img.rotate(angle, expand=False, resample=Image.BICUBIC)
        paste_x = cx - card_size // 2
        paste_y = cy - card_size // 2
        img.paste(Image.alpha_composite(
            img.crop((paste_x, paste_y, paste_x + card_size, paste_y + card_size)).convert("RGBA"),
            shadow_rot
        ), (paste_x, paste_y))

    # Draw the card fill
    card_draw.rounded_rectangle(
        [card_x, card_y, card_x + w, card_y + h],
        radius=radius,
        fill=fill,
    )

    # Draw border if specified
    if border_color and border_width > 0:
        card_draw.rounded_rectangle(
            [card_x, card_y, card_x + w, card_y + h],
            radius=radius,
            outline=border_color,
            width=border_width,
        )

    # Rotate
    rotated = card_img.rotate(angle, expand=False, resample=Image.BICUBIC)

    # Paste onto main image
    paste_x = cx - card_size // 2
    paste_y = cy - card_size // 2
    img.paste(Image.alpha_composite(
        img.crop((paste_x, paste_y, paste_x + card_size, paste_y + card_size)).convert("RGBA"),
        rotated
    ), (paste_x, paste_y))


def draw_music_note(img, cx, cy, scale=1.0):
    """Draw a white music note (beamed eighth notes) at center position."""
    draw = ImageDraw.Draw(img)

    # Music note dimensions
    note_w = int(160 * scale)
    note_h = int(200 * scale)

    # Starting position (top-left of bounding box)
    x = cx - note_w // 2
    y = cy - note_h // 2

    beam_thickness = int(16 * scale)
    stem_width = int(10 * scale)
    head_rx = int(30 * scale)
    head_ry = int(22 * scale)

    # Left stem
    left_stem_x = x + head_rx
    left_stem_bottom = y + note_h - head_ry
    left_stem_top = y + int(20 * scale)

    # Right stem
    right_stem_x = x + note_w - head_rx
    right_stem_bottom = y + note_h - head_ry + int(15 * scale)
    right_stem_top = y + int(35 * scale)

    white = (255, 255, 255, 255)

    # Draw stems
    draw.rectangle(
        [left_stem_x - stem_width // 2, left_stem_top,
         left_stem_x + stem_width // 2, left_stem_bottom],
        fill=white
    )
    draw.rectangle(
        [right_stem_x - stem_width // 2, right_stem_top,
         right_stem_x + stem_width // 2, right_stem_bottom],
        fill=white
    )

    # Draw beam (connecting bar at top)
    # Angled beam from left top to right top
    beam_points = [
        (left_stem_x - stem_width // 2, left_stem_top),
        (right_stem_x + stem_width // 2, right_stem_top),
        (right_stem_x + stem_width // 2, right_stem_top + beam_thickness),
        (left_stem_x - stem_width // 2, left_stem_top + beam_thickness),
    ]
    draw.polygon(beam_points, fill=white)

    # Second beam (slightly lower)
    offset = int(24 * scale)
    beam2_points = [
        (left_stem_x - stem_width // 2, left_stem_top + offset),
        (right_stem_x + stem_width // 2, right_stem_top + offset),
        (right_stem_x + stem_width // 2, right_stem_top + offset + beam_thickness),
        (left_stem_x - stem_width // 2, left_stem_top + offset + beam_thickness),
    ]
    draw.polygon(beam2_points, fill=white)

    # Draw note heads (filled ellipses, slightly rotated look)
    # Left note head
    draw.ellipse(
        [left_stem_x - head_rx - int(12 * scale), left_stem_bottom - head_ry,
         left_stem_x + head_rx - int(12 * scale), left_stem_bottom + head_ry],
        fill=white
    )
    # Right note head
    draw.ellipse(
        [right_stem_x - head_rx - int(12 * scale), right_stem_bottom - head_ry,
         right_stem_x + head_rx - int(12 * scale), right_stem_bottom + head_ry],
        fill=white
    )


def add_glass_highlight(img, cx, cy, w, h, angle):
    """Add a subtle glass/shine effect on the card."""
    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(highlight)

    # Create a highlight shape (top portion of card)
    card_size = int(max(w, h) * 1.5)
    h_card = Image.new("RGBA", (card_size, card_size), (0, 0, 0, 0))
    h_card_draw = ImageDraw.Draw(h_card)

    card_x = (card_size - w) // 2
    card_y = (card_size - h) // 2

    # Top half highlight
    h_card_draw.rounded_rectangle(
        [card_x + 6, card_y + 6, card_x + w - 6, card_y + h // 2],
        radius=35,
        fill=(255, 255, 255, 25),
    )

    rotated = h_card.rotate(angle, expand=False, resample=Image.BICUBIC)
    paste_x = cx - card_size // 2
    paste_y = cy - card_size // 2
    img.paste(Image.alpha_composite(
        img.crop((paste_x, paste_y, paste_x + card_size, paste_y + card_size)).convert("RGBA"),
        rotated
    ), (paste_x, paste_y))


def main():
    # Create base image with gradient
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))

    # Purple to blue gradient
    purple = (139, 92, 246)  # #8B5CF6
    blue = (79, 128, 240)    # #4F80F0

    print("Drawing gradient...")
    draw_gradient(img, purple, blue)

    # Card dimensions
    card_w = 360
    card_h = 480
    card_radius = 44

    # Back card (slightly left and rotated)
    back_cx = SIZE // 2 - 50
    back_cy = SIZE // 2 + 10
    back_angle = 12  # degrees

    # Front card (slightly right and rotated other way)
    front_cx = SIZE // 2 + 60
    front_cy = SIZE // 2 - 10
    front_angle = -5

    # Card colors - semi-transparent purple/violet
    back_fill = (160, 120, 255, 140)   # lighter purple, more transparent
    front_fill = (130, 90, 230, 200)   # darker purple, more opaque

    border_color = (255, 255, 255, 80)

    print("Drawing back card...")
    draw_rotated_card(img, back_cx, back_cy, card_w, card_h, back_angle,
                      fill=back_fill, border_color=border_color, border_width=4,
                      radius=card_radius, shadow=True)
    add_glass_highlight(img, back_cx, back_cy, card_w, card_h, back_angle)

    print("Drawing front card...")
    draw_rotated_card(img, front_cx, front_cy, card_w, card_h, front_angle,
                      fill=front_fill, border_color=border_color, border_width=4,
                      radius=card_radius, shadow=True)
    add_glass_highlight(img, front_cx, front_cy, card_w, card_h, front_angle)

    # Draw music note on front card
    print("Drawing music note...")
    # Adjust note position to account for card rotation
    note_cx = front_cx + 10
    note_cy = front_cy + 10
    draw_music_note(img, note_cx, note_cy, scale=1.3)

    # Convert to RGB (iOS icons don't support alpha)
    final = Image.new("RGB", (SIZE, SIZE), (255, 255, 255))
    final.paste(img, mask=img.split()[3])

    # Actually, just flatten the RGBA to RGB
    final = img.convert("RGB")

    print(f"Saving to {OUTPUT}...")
    final.save(OUTPUT, "PNG")
    print("Done! 1024x1024 icon saved.")


if __name__ == "__main__":
    main()
