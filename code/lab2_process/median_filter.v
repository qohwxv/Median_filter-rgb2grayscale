module median_filter #(
    parameter WIDTH  = 430,  
    parameter LENGTH = 554,   
    parameter SIZE   = 8
)(
    input  wire clk,
    input  wire reset,
    input  wire valid_in,
    input  wire [SIZE-1:0] pixel_in,
    
    output reg  valid_out,
    output reg  [SIZE-1:0] pixel_out
);

    // Coordinate counters for the OUTPUT (tracks the center pixel p22)
    reg [15:0] out_col;
    reg [15:0] out_row;
    
    // Pointer for line buffer writes
    reg [15:0] in_col;

    // Pipeline control counters
    reg [31:0] in_cnt;
    reg [31:0] out_cnt;
    reg [15:0] shift_cnt;

    // Line Buffers
    reg [SIZE-1:0] line_buf1 [0:WIDTH-1];
    reg [SIZE-1:0] line_buf2 [0:WIDTH-1];
    
    // Shift registers for the 3x3 window (Raw values)
    reg [SIZE-1:0] p11, p12, p13;
    reg [SIZE-1:0] p21, p22, p23;
    reg [SIZE-1:0] p31, p32, p33;

    // Padded 3x3 window values
    wire [SIZE-1:0] w11, w12, w13;
    wire [SIZE-1:0] w21, w22, w23;
    wire [SIZE-1:0] w31, w32, w33;

	//
    wire [SIZE-1:0] lb1_out = line_buf1[in_col];
    wire [SIZE-1:0] lb2_out = line_buf2[in_col];

    integer i;

    wire [SIZE-1:0] max_of_mins, med_of_meds, min_of_maxs;
    wire [SIZE-1:0] final_median;

    
    wire do_shift = valid_in || (in_cnt == (WIDTH * LENGTH) && out_cnt < (WIDTH * LENGTH));

    always @(posedge clk) begin
        if (reset) begin
            out_col   <= 0;
            out_row   <= 0;
            in_col    <= 0;
            in_cnt    <= 0;
            out_cnt   <= 0;
            shift_cnt <= 0;
            valid_out <= 0;
            pixel_out <= 0;
            
            p11 <= 0; p12 <= 0; p13 <= 0;
            p21 <= 0; p22 <= 0; p23 <= 0;
            p31 <= 0; p32 <= 0; p33 <= 0;

            for (i = 0; i < WIDTH; i = i + 1) begin
                line_buf1[i] <= 0;
                line_buf2[i] <= 0;
            end
        end 
	else begin
            valid_out <= 0; 
            
            if (do_shift) begin
                // Update Line Buffers
                line_buf1[in_col] <= pixel_in;
                line_buf2[in_col] <= lb1_out;

                // Move write pointer for line buffers
                if (in_col == WIDTH - 1)
                    in_col <= 0;
                else
                    in_col <= in_col + 1;

                // Shift 3x3 window
                p31 <= p32; p32 <= p33; p33 <= pixel_in;
                p21 <= p22; p22 <= p23; p23 <= lb1_out;
                p11 <= p12; p12 <= p13; p13 <= lb2_out;

                // Track total incoming pixels safely
                if (valid_in && in_cnt < (WIDTH * LENGTH)) begin
                    in_cnt <= in_cnt + 1;
                end

                // Delay the output valid signal until p22 actually contains the first pixel
                if (shift_cnt < WIDTH + 2) begin
                    shift_cnt <= shift_cnt + 1;
                end

                if (shift_cnt >= WIDTH + 2) begin
                    valid_out <= 1;
                    pixel_out <= final_median;
                    
                    out_cnt <= out_cnt + 1;

                    // Track coordinates of the output pixel for zero padding
                    if (out_col == WIDTH - 1) begin
                        out_col <= 0;
                        out_row <= out_row + 1;
                    end else begin
                        out_col <= out_col + 1;
                    end
                end
            end
        end
    end

    
    assign w11 = (out_row == 0 || out_col == 0)         ? {SIZE{1'b0}} : p11;
    assign w12 = (out_row == 0)                         ? {SIZE{1'b0}} : p12;
    assign w13 = (out_row == 0 || out_col == WIDTH - 1) ? {SIZE{1'b0}} : p13;

    assign w21 = (out_col == 0)                         ? {SIZE{1'b0}} : p21;
    assign w22 = p22; // Center
    assign w23 = (out_col == WIDTH - 1)                 ? {SIZE{1'b0}} : p23;

    assign w31 = (out_row == LENGTH - 1 || out_col == 0)         ? {SIZE{1'b0}} : p31;
    assign w32 = (out_row == LENGTH - 1)                         ? {SIZE{1'b0}} : p32;
    assign w33 = (out_row == LENGTH - 1 || out_col == WIDTH - 1) ? {SIZE{1'b0}} : p33;

    
    function [SIZE-1:0] max2(input [SIZE-1:0] a, input [SIZE-1:0] b);
        max2 = (a > b) ? a : b;
    endfunction

    function [SIZE-1:0] min2(input [SIZE-1:0] a, input [SIZE-1:0] b);
        min2 = (a < b) ? a : b;
    endfunction

    function [SIZE-1:0] max3(input [SIZE-1:0] a, input [SIZE-1:0] b, input [SIZE-1:0] c);
        max3 = max2(max2(a, b), c);
    endfunction

    function [SIZE-1:0] min3(input [SIZE-1:0] a, input [SIZE-1:0] b, input [SIZE-1:0] c);
        min3 = min2(min2(a, b), c);
    endfunction

    function [SIZE-1:0] med3(input [SIZE-1:0] a, input [SIZE-1:0] b, input [SIZE-1:0] c);
        med3 = max2(min2(a, b), min2(max2(a, b), c));
    endfunction


    assign max_of_mins = max3(
        min3(w11, w12, w13),
        min3(w21, w22, w23),
        min3(w31, w32, w33)
    );

    assign med_of_meds = med3(
        med3(w11, w12, w13),
        med3(w21, w22, w23),
        med3(w31, w32, w33)
    );

    assign min_of_maxs = min3(
        max3(w11, w12, w13),
        max3(w21, w22, w23),
        max3(w31, w32, w33)
    );

    assign final_median = med3(max_of_mins, med_of_meds, min_of_maxs);

endmodule
