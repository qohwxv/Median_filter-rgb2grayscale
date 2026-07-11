module rgb2gray #(
    parameter signed [8:0] BRIGHTNESS_OFFSET = 0
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire [23:0] rgb_in,     // Format: {R[7:0], G[7:0], B[7:0]}
    output reg  [7:0]  gray_out,
    output reg         valid_out
);

    // 1. Extract color channels
    wire [7:0] r = rgb_in[23:16];
    wire [7:0] g = rgb_in[15:8];
    wire [7:0] b = rgb_in[7:0];

    wire [15:0] gray_calc = (r * 8'd77) + (g * 8'd150) + (b * 8'd29);
    wire [7:0]  base_gray = gray_calc[15:8];


    wire signed [9:0] gray_adjusted = $signed({2'b00, base_gray}) + BRIGHTNESS_OFFSET;

    // 4. Sequential logic with saturation (clamping)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gray_out  <= 8'd0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_in;
            
            if (valid_in) begin
                if (gray_adjusted > 11'sd255) begin
                    gray_out <= 8'd255; // Clamp to pure white
                end else if (gray_adjusted < 11'sd0) begin
                    gray_out <= 8'd0;   // Clamp to pure black
                end else begin
                    gray_out <= gray_adjusted[7:0]; // Normal range
                end
            end
        end
    end
endmodule
