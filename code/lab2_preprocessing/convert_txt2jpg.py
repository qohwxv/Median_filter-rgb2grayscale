import numpy as np
from PIL import Image

width, height = 430, 554
expected_pixels = width * height

pixels = []

# Using 'with open' is best practice to ensure the file safely closes
with open("anh1_filtered.txt", "r") as file:
    for line in file:
        clean_line = line.strip()
        
        # Skip blank lines
        if not clean_line:
            continue
            
        # Handle Verilog 'x' (undefined) states by forcing them to 0 (black)
        if 'x' in clean_line.lower():
            pixels.append(0)
        else:
            try:
                # Convert from hex to base-10 integer
                pixels.append(int(clean_line, 16))
            except ValueError:
                # Silently ignore any other malformed lines (like stray text)
                continue

# Pad with black pixels (0) if the hardware pipeline cut off early
if len(pixels) < expected_pixels:
    print(f"Warning: Image underrun. Padding {expected_pixels - len(pixels)} pixels.")
    pixels.extend([0] * (expected_pixels - len(pixels)))
    
# Trim if there are too many
elif len(pixels) > expected_pixels:
    print(f"Warning: Image overrun. Trimming {len(pixels) - expected_pixels} excess pixels.")
    pixels = pixels[:expected_pixels]

# Convert to image
img_array = np.array(pixels, dtype=np.uint8).reshape((height, width))
img = Image.fromarray(img_array, 'L')
img.save("image_filtered.jpg")
print("Hardware filtering complete! Saved as image_filtered.jpg")