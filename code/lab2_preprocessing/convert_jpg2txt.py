from PIL import Image
import numpy as np

# Load image
img = Image.open("baitap1_nhieu.jpg").convert("L")
img_array = np.array(img)

# Save 1D hex (each pixel per line)
with open("anh1_hex_1d.txt", "w") as f:
    for row in img_array:
        for pixel in row:
            f.write(f"{pixel:02X}\n")   # 2-digit HEX (uppercase)

# Save 2D hex (tab separated)
#with open("anh1_hex_2d.txt", "w") as f:
#    for row in img_array:
#        f.write("\t".join(f"{pixel:02X}" for pixel in row) + "\n")