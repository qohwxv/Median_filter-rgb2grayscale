`timescale 1ns/1ps

// Unit-level, self-checking verification for rgb2gray.
//
// The three DUT instances share one stimulus stream so the test exercises:
//   * the nominal RGB-to-gray equation,
//   * lower saturation with a negative brightness offset, and
//   * upper saturation with a positive brightness offset.
// Inputs are driven on the falling edge and observed after the rising-edge
// nonblocking assignments, avoiding a testbench/DUT race.
module tb_rgb2gray_selfcheck;

    localparam integer POSITIVE_OFFSET = 100;
    localparam integer NEGATIVE_OFFSET = -100;

    reg        clk;
    reg        rst_n;
    reg        valid_in;
    reg [23:0] rgb_in;

    wire [7:0] gray_nominal;
    wire       valid_nominal;
    wire [7:0] gray_positive;
    wire       valid_positive;
    wire [7:0] gray_negative;
    wire       valid_negative;

    reg [7:0] expected_nominal;
    reg [7:0] expected_positive;
    reg [7:0] expected_negative;

    integer checks;
    integer errors;
    integer i;
    integer j;
    integer k;
    reg [23:0] lfsr;

    // Variables sampled by the functional-coverage model.
    integer cov_valid;
    integer cov_r;
    integer cov_g;
    integer cov_b;
    integer cov_positive_class;
    integer cov_negative_class;

    // Class encoding: 0 = lower clamp, 1 = normal range, 2 = upper clamp.
    covergroup rgb_functional_coverage;
        option.per_instance = 1;

        cp_valid : coverpoint cov_valid {
            bins idle   = {0};
            bins active = {1};
        }

        cp_red : coverpoint cov_r iff (cov_valid) {
            bins zero   = {0};
            bins middle = {[1:254]};
            bins full   = {255};
        }

        cp_green : coverpoint cov_g iff (cov_valid) {
            bins zero   = {0};
            bins middle = {[1:254]};
            bins full   = {255};
        }

        cp_blue : coverpoint cov_b iff (cov_valid) {
            bins zero   = {0};
            bins middle = {[1:254]};
            bins full   = {255};
        }

        // All 27 RGB low/middle/high combinations are sent below.
        x_rgb_channels : cross cp_red, cp_green, cp_blue;

        cp_positive_offset : coverpoint cov_positive_class iff (cov_valid) {
            bins normal     = {1};
            bins upper_clip = {2};
        }

        cp_negative_offset : coverpoint cov_negative_class iff (cov_valid) {
            bins lower_clip = {0};
            bins normal     = {1};
        }
    endgroup

    rgb_functional_coverage rgb_cov = new();

    rgb2gray #(
        .BRIGHTNESS_OFFSET(0)
    ) dut_nominal (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .rgb_in    (rgb_in),
        .gray_out  (gray_nominal),
        .valid_out (valid_nominal)
    );

    rgb2gray #(
        .BRIGHTNESS_OFFSET(POSITIVE_OFFSET)
    ) dut_positive (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .rgb_in    (rgb_in),
        .gray_out  (gray_positive),
        .valid_out (valid_positive)
    );

    rgb2gray #(
        .BRIGHTNESS_OFFSET(NEGATIVE_OFFSET)
    ) dut_negative (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .rgb_in    (rgb_in),
        .gray_out  (gray_negative),
        .valid_out (valid_negative)
    );

    function automatic [7:0] model_gray(
        input [23:0] rgb,
        input integer brightness_offset
    );
        integer weighted_sum;
        integer base_gray;
        integer adjusted_gray;
        begin
            weighted_sum = 77 * rgb[23:16]
                         + 150 * rgb[15:8]
                         + 29 * rgb[7:0];
            base_gray = weighted_sum >> 8;
            adjusted_gray = base_gray + brightness_offset;

            if (adjusted_gray < 0)
                model_gray = 8'd0;
            else if (adjusted_gray > 255)
                model_gray = 8'd255;
            else
                model_gray = adjusted_gray[7:0];
        end
    endfunction

    function automatic integer model_class(
        input [23:0] rgb,
        input integer brightness_offset
    );
        integer weighted_sum;
        integer adjusted_gray;
        begin
            weighted_sum = 77 * rgb[23:16]
                         + 150 * rgb[15:8]
                         + 29 * rgb[7:0];
            adjusted_gray = (weighted_sum >> 8) + brightness_offset;

            if (adjusted_gray < 0)
                model_class = 0;
            else if (adjusted_gray > 255)
                model_class = 2;
            else
                model_class = 1;
        end
    endfunction

    function automatic [7:0] coverage_level(input integer index);
        begin
            case (index)
                0: coverage_level = 8'h00;
                1: coverage_level = 8'h80;
                default: coverage_level = 8'hff;
            endcase
        end
    endfunction

    task automatic report_error(input [8*160-1:0] message);
        begin
            errors = errors + 1;
            $display("ERROR [rgb2gray] %0t: %0s", $time, message);
        end
    endtask

    task automatic drive_valid(input [23:0] rgb);
        begin
            @(negedge clk);
            rgb_in = rgb;
            valid_in = 1'b1;

            expected_nominal = model_gray(rgb, 0);
            expected_positive = model_gray(rgb, POSITIVE_OFFSET);
            expected_negative = model_gray(rgb, NEGATIVE_OFFSET);

            cov_valid = 1;
            cov_r = rgb[23:16];
            cov_g = rgb[15:8];
            cov_b = rgb[7:0];
            cov_positive_class = model_class(rgb, POSITIVE_OFFSET);
            cov_negative_class = model_class(rgb, NEGATIVE_OFFSET);
            rgb_cov.sample();
        end
    endtask

    task automatic drive_idle;
        begin
            @(negedge clk);
            rgb_in = 24'd0;
            valid_in = 1'b0;

            cov_valid = 0;
            rgb_cov.sample();
        end
    endtask

    always #5 clk = ~clk;

    // Scoreboard: outputs are sampled after DUT nonblocking assignments settle.
    always @(posedge clk) begin
        #1;
        if (!rst_n) begin
            if ((valid_nominal !== 1'b0) ||
                (valid_positive !== 1'b0) ||
                (valid_negative !== 1'b0))
                report_error("valid_out must be deasserted during reset");
        end else begin
            if ((valid_nominal !== valid_in) ||
                (valid_positive !== valid_in) ||
                (valid_negative !== valid_in))
                report_error("valid_out does not match the registered valid_in transaction");

            if (valid_nominal) begin
                checks = checks + 3;

                if (gray_nominal !== expected_nominal)
                    report_error("nominal grayscale mismatch");
                if (gray_positive !== expected_positive)
                    report_error("positive-offset grayscale mismatch");
                if (gray_negative !== expected_negative)
                    report_error("negative-offset grayscale mismatch");
            end
        end
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        valid_in = 1'b0;
        rgb_in = 24'd0;
        expected_nominal = 8'd0;
        expected_positive = 8'd0;
        expected_negative = 8'd0;
        checks = 0;
        errors = 0;
        lfsr = 24'h1ace1;

        // Reset is asynchronous in the DUT; hold it across two clock edges.
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        // Directed boundary vectors and a valid gap.
        drive_valid(24'h000000); // black; negative offset must clamp low
        drive_valid(24'hffffff); // white; positive offset must clamp high
        drive_idle();
        drive_valid(24'hff0000); // primary colors validate the 77/150/29 weights
        drive_valid(24'h00ff00);
        drive_valid(24'h0000ff);
        drive_valid(24'h808080);

        // Complete every low/middle/high cross bin for R, G and B.
        for (i = 0; i < 3; i = i + 1) begin
            for (j = 0; j < 3; j = j + 1) begin
                for (k = 0; k < 3; k = k + 1) begin
                    drive_valid({coverage_level(i), coverage_level(j), coverage_level(k)});
                end
            end
        end

        // Deterministic pseudo-random regression vectors add arithmetic variety.
        for (i = 0; i < 32; i = i + 1) begin
            lfsr = {lfsr[22:0], lfsr[23] ^ lfsr[22] ^ lfsr[21] ^ lfsr[16]};
            drive_valid(lfsr);
        end

        drive_idle();
        repeat (2) @(posedge clk);
        #2;

        $display("rgb2gray checks: %0d, functional coverage: %0.2f%%",
                 checks, rgb_cov.get_inst_coverage());
        if (errors != 0)
            $fatal(1, "tb_rgb2gray_selfcheck FAILED with %0d error(s)", errors);

        $display("TEST PASSED: tb_rgb2gray_selfcheck");
        $finish;
    end

endmodule
