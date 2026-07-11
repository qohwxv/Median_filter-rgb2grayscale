module tb_rgb2gray;

    // ... clock generation ...
    reg clk;
    reg rst_n;
    reg valid_in;
    reg [23:0] rgb_in;
    wire [7:0] gray_out;
    wire valid_out;

    // Memory array to hold the image (Depth = 2048 * 1365)
    reg [23:0] image_mem [0:2795519]; 
    integer out_file;

    // --- Replaced the 'i' integer used in the for-loop ---
    // Using a register for the address pointer
    reg [21:0] read_addr; 
    reg stream_enable;

    // DUT instantiation
	rgb2gray #(
        .BRIGHTNESS_OFFSET(-100) 
    )
	 uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .rgb_in(rgb_in),
        .gray_out(gray_out),
        .valid_out(valid_out)
    );

    initial begin
        
        $readmemh("/home/qh/Downloads/lab2/lab2_preprocessing/image_rgb_hex.txt", image_mem);
        
       
        out_file = $fopen("/home/qh/Downloads/lab2/lab2_preprocessing/gray_output_hex.txt", "w");
        
        // 3. Apply reset and initialize signals
        rst_n = 1'b0;
        stream_enable = 1'b0;
        
        #20; // Wait for a few clock cycles
        rst_n = 1'b1;
        
        // 4. Trigger the start of the stream
        stream_enable = 1'b1;
    end
	initial begin
		clk = 0;
		forever #5 clk = ~clk;
	end
    // ---------------------------------------------------------
    // The Clocked Driver (Replaces the for-loop)
    // ---------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_addr <= 22'd0;
            valid_in  <= 1'b0;
            rgb_in    <= 24'd0;
        end else if (stream_enable && read_addr < 2795520) begin
            // Drive the DUT inputs
            valid_in <= 1'b1;
            rgb_in   <= image_mem[read_addr];
            
            read_addr <= read_addr + 1;
        end else begin
            // Stop driving when memory is fully read or stream is disabled
            valid_in <= 1'b0;
            
            if (read_addr == 2795520) begin
                $display("Finished streaming image data.");
                stream_enable <= 1'b0; 
                // Add a small delay to let the last pixel flush through the pipeline before $finish
                #100 $finish; 
            end
        end
    end

    // Capture the output (remains exactly the same)
    always @(posedge clk) begin
        if (valid_out) begin
            $fdisplay(out_file, "%02h", gray_out);
        end
    end

endmodule
