from PIL import Image

def generate_hex_file(image_path, output_txt_path):
    print(f"Opening {image_path} to extract RGB values...")
    img = Image.open(image_path)
    
    # Ensure it's in RGB mode
    if img.mode != 'RGB':
        img = img.convert('RGB')
        
    width, height = img.size
    pixels = img.load() # Load pixel data into memory for fast access

    print(f"Writing hex data to {output_txt_path}...")
    with open(output_txt_path, "w") as f:
        # Loop through every pixel (row by row is standard for hardware streaming)
        for y in range(height):
            for x in range(width):
                r, g, b = pixels[x, y]
                
                # Format as 24-bit hex: e.g., Red=255, Green=0, Blue=128 becomes FF0080
                hex_string = f"{r:02X}{g:02X}{b:02X}\n"
                f.write(hex_string)
                
    print("Done! The hex file is ready for your testbench.")

# Run the extraction
generate_hex_file("baitap2_resized.bmp", "image_rgb_hex.txt")