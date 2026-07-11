from PIL import Image
import numpy as np
from skimage.metrics import peak_signal_noise_ratio, structural_similarity

# Load images
img1 = Image.open("baitap1_anhgoc.jpg").convert("L")   # original image
img2 = Image.open("image_filtered.jpg").convert("L")   # processed image

# Convert to numpy arrays
img1 = np.array(img1)
img2 = np.array(img2)

# Make sure same size
assert img1.shape == img2.shape, "Images must have same size!"

# Compute PSNR
psnr_value = peak_signal_noise_ratio(img1, img2, data_range=255)

# Compute SSIM
ssim_value = structural_similarity(img1, img2, data_range=255)

print(f"PSNR: {psnr_value:.2f} dB")
print(f"SSIM: {ssim_value:.4f}")


