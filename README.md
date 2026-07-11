# Median_filter-rgb2grayscale

# Lab 2 - Image Processing using Verilog

This project implements two image processing functions:

1. Noise removal using a 3x3 median filter.
2. Converting RGB images to grayscale.

The preprocessing and image reconstruction are written in Python. The core processing algorithms are described in Verilog and simulated using ModelSim/QuestaSim.

## Requirements

* Python 3
* ModelSim or QuestaSim
* Python libraries: `Pillow`, `NumPy`, `scikit-image`

Install Python libraries:

```bash
python3 -m pip install pillow numpy scikit-image
```

The Python scripts use relative paths, so they should be executed inside the `lab2_preprocessing` directory:

```bash
cd lab2_preprocessing
```

## 1. Median Filter

### 1.1. Processing Flow

```text
baitap1_nhieu.jpg
        |
        v
convert_jpg2txt.py
        |
        v
anh1_hex_1d.txt
        |
        v
tb_median_filter.v + median_filter.v
        |
        v
anh1_filtered.txt
        |
        v
convert_txt2jpg.py
        |
        v
image_filtered.jpg
        |
        v
compare_psnr_ssim.py
        |
        v
PSNR and SSIM
```

The input image has a resolution of `430 x 554`, corresponding to `238220` pixels.

### 1.2. Steps

#### Step 1: Convert noisy image to HEX data

```bash
cd lab2_preprocessing
python3 convert_jpg2txt.py
```

The output file is `anh1_hex_1d.txt`. Each line contains one 8-bit grayscale pixel in HEX format.

Verify the number of pixels:

```bash
wc -l anh1_hex_1d.txt
```

Expected result: `238220` lines.

#### Step 2: Run median filter using ModelSim

Open ModelSim and run in the Transcript window:

```tcl
cd /home/qh/Downloads/lab2/lab2_process
vlib work
vlog median_filter.v
vlog tb_median_filter.v
vsim work.tb_median_filter
run -all
```

The testbench reads `anh1_hex_1d.txt`, invokes the `median_filter` module, and generates `lab2_preprocessing/anh1_filtered.txt`.

When completed, ModelSim displays:

```text
Processing Complete. Total pixels filtered: 238220
```

> Note: `tb_median_filter.v` currently uses absolute paths `/home/qh/Downloads/lab2`. When cloning to another machine, update the two paths in `$readmemh` and `$fopen`.

#### Step 3: Convert HEX result back to JPG

```bash
cd /home/qh/Downloads/lab2/lab2_preprocessing
python3 convert_txt2jpg.py
```

The output image is `image_filtered.jpg`.

#### Step 4: Evaluate using PSNR and SSIM

`compare_psnr_ssim.py` compares the filtered image `image_filtered.jpg` with the clean image `baitap1_anhgoc.jpg`:

```bash
python3 compare_psnr_ssim.py
```

### 1.3. Results

```text
PSNR: 34.05 dB
SSIM: 0.9573
```

Higher PSNR and SSIM values closer to `1` indicate better similarity to the reference image.

## 2. RGB to Grayscale Conversion

### 2.1. Processing Flow

```text
baitap2_anhgoc.jpg
        |
        v
convert_rgb2bmp.py
        |
        v
baitap2_resized.bmp
        |
        v
convert_bmp2rgbtxt.py
        |
        v
image_rgb_hex.txt
        |
        v
tb_rgb2gray.v + rgb2gray.v
        |
        v
gray_output_hex.txt
        |
        v
convert_2_txt2grey.py
        |
        v
image2_filtered.jpg
```

The image is resized to `2048 x 1365`, corresponding to `2795520` pixels.

### 2.2. Steps

#### Step 1: Convert and normalize RGB image to BMP

```bash
cd lab2_preprocessing
python3 convert_rgb2bmp.py
```

The output file is `baitap2_resized.bmp`.

#### Step 2: Convert BMP image to RGB HEX data

```bash
python3 convert_bmp2rgbtxt.py
```

The output file is `image_rgb_hex.txt`. Each line contains one 24-bit pixel in `RRGGBB` format.

#### Step 3: Run RGB to grayscale conversion using ModelSim

Since `tb_rgb2gray.v` uses relative paths, run the simulation from the `lab2_preprocessing` directory:

```tcl
cd /home/qh/Downloads/lab2/lab2_preprocessing
vlib work
vlog ../lab2_process/rgb2gray.v
vlog ../lab2_process/tb_rgb2gray.v
vsim work.tb_rgb2gray
run -all
```

The simulation output file is `gray_output_hex.txt`.

The module uses an integer approximation formula:

```text
Gray = (77*R + 150*G + 29*B) / 256
```

`tb_rgb2gray.v` is currently configured with `BRIGHTNESS_OFFSET(-100)`, which darkens the output image. Change it to `BRIGHTNESS_OFFSET(0)` if you only want grayscale conversion without brightness adjustment.

#### Step 4: Convert grayscale HEX data to image

```bash
python3 convert_2_txt2grey.py
```

The final output image is `image2_filtered.jpg`.

## 3. Directory Structure

```text
lab2/
|-- README.md
|-- lab2_preprocessing/
|   |-- baitap1_anhgoc.jpg          # Clean reference image
|   |-- baitap1_nhieu.jpg           # Noisy input image
|   |-- convert_jpg2txt.py          # Noisy JPG -> grayscale HEX
|   |-- anh1_hex_1d.txt             # Input data for median filter
|   |-- convert_txt2jpg.py          # Filtered HEX -> JPG
|   |-- anh1_filtered.txt           # Median filter output (HEX)
|   |-- image_filtered.jpg          # Median filter output image
|   |-- compare_psnr_ssim.py        # Compute PSNR and SSIM
|   |-- median_filter_python.py     # Python reference implementation
|   |-- baitap2_anhgoc.jpg          # RGB input image
|   |-- convert_rgb2bmp.py          # Normalize and save BMP
|   |-- baitap2_resized.bmp         # Resized RGB image
|   |-- convert_bmp2rgbtxt.py       # BMP -> RGB HEX
|   |-- image_rgb_hex.txt           # 24-bit RGB data
|   |-- gray_output_hex.txt         # Grayscale output (HEX)
|   |-- convert_2_txt2grey.py       # Grayscale HEX -> JPG
|   `-- image2_filtered.jpg         # Final grayscale image
`-- lab2_process/
    |-- lab2.mpf                    # ModelSim project
    |-- median_filter.v             # 3x3 median filter module
    |-- tb_median_filter.v          # Median filter testbench
    |-- rgb2gray.v                  # RGB to grayscale module
    `-- tb_rgb2gray.v               # RGB to grayscale testbench
```

Virtual environment folders such as `venv/` and auto-generated simulation folders like `work/` should not be uploaded to GitHub.
