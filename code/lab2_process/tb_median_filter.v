`timescale 1ns/1ps

module tb_median_filter();

    // Matching image constraints
    parameter Width  = 430;
    parameter Length = 554;
    parameter size   = 8;
    parameter TOTAL_PIXELS = Width * Length;

    reg clk;
    reg reset;
    
    // Accelerator Interface
    reg  valid_in;
    reg  [size-1:0] pixel_in;
    wire valid_out;
    wire [size-1:0] pixel_out;

    integer index_read;
    integer index_write;
    integer open_write;

    // Memory array matching exact image dimensions
    reg [size-1:0] memory [0:TOTAL_PIXELS-1];
    
    // Instantiate the Filter
    median_filter #(
        .WIDTH(Width),
        .LENGTH(Length),
        .SIZE(size)
    ) dut (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .pixel_in(pixel_in),
        .valid_out(valid_out),
        .pixel_out(pixel_out)
    );

    
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // File I/O and Control Sequence
    initial begin
        // Reset everything
        reset = 1;
        valid_in = 0;
        pixel_in = 0;
        index_read = 0;
        index_write = 0;
        
        // Read the HEX input file
        $readmemh("/home/qh/Downloads/lab2/lab2_preprocessing/anh1_hex_1d.txt", memory); 
        
        // Open the filtered output file
        open_write = $fopen("/home/qh/Downloads/lab2/lab2_preprocessing/anh1_filtered.txt", "w");
        if (!open_write) begin
            $display("ERROR: Cannot open output file anh1_filtered.txt");
            $finish;
        end
	
        // Assert reset for 20ns, then release
        #20 reset = 0;
        
        // Wait until all pixels have been written to the output
        wait (index_write == TOTAL_PIXELS);
        
        // Wait a few extra cycles to ensure clean finish
        #50; 
        
        $fclose(open_write);
        $display("Processing Complete. Total pixels filtered: %0d", index_write);
        $finish;
    end

    // DMA READ (Feed accelerator)
    always @(posedge clk) begin
        if (reset) begin
            index_read <= 0;
            valid_in   <= 0;
        end else begin
            if (index_read < TOTAL_PIXELS) begin
                valid_in   <= 1;
                pixel_in   <= memory[index_read];
                index_read <= index_read + 1;
            end else begin
                valid_in   <= 0; // Stop pushing data
            end
        end
    end

    // DMA WRITE (Capture from accelerator)
    always @(posedge clk) begin
        if (!reset) begin
            if (valid_out) begin
                // Write out the processed pixel
                $fwrite(open_write, "%02x\n", pixel_out);
                index_write <= index_write + 1;
            end
        end
    end

endmodule
