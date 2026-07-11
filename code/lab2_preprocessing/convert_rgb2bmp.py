from PIL import Image

def convert_and_resize_to_bmp(input_filename, output_filename, target_width, target_height):
    """
    Loads an RGB image, resizes it to target dimensions, and saves it as a BMP.
    """
    try:
        # 1. Load the original RGB image
        print(f"Loading image: {input_filename}...")
        img = Image.open(input_filename)

        # Ensure the image is in RGB mode (e.g., if it's grayscale or palette-based)
        if img.mode != 'RGB':
            print(f"Converting image mode from {img.mode} to RGB.")
            img = img.convert('RGB')

        # 2. Resize the image to 2048 x 1365
        print(f"Resizing from {img.size} to ({target_width}, {target_height})...")
        # Use Image.Resampling.LANCZOS for high-quality resizing
        resized_img = img.resize((target_width, target_height), Image.Resampling.LANCZOS)

        # 3. Save the image as a BMP file
        print(f"Saving new image as BMP: {output_filename}...")
        resized_img.save(output_filename, format="BMP")

        print("Conversion complete!")

    except FileNotFoundError:
        print(f"Error: The file '{input_filename}' was not found. Please check the file path.")
    except Exception as e:
        print(f"An error occurred: {e}")

# --- Configuration ---
# Match the input filename to the one shown in your VS Code workspace (or your actual file)
input_file_path = "baitap2_anhgoc.jpg"
output_file_path = "baitap2_resized.bmp"
new_width = 2048
new_height = 1365

# --- Run the conversion ---
convert_and_resize_to_bmp(input_file_path, output_file_path, new_width, new_height)