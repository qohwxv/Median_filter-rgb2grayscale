`timescale 1ns/1ps

// Unit-level, self-checking verification for median_filter.
//
// A compact 5x5 frame makes every border and pipeline condition observable in
// a short simulation.  The reference model is intentionally independent from
// the DUT's max/min sorting network: it sorts nine samples and applies the
// RTL's documented zero-padding border policy.
module tb_median_filter_selfcheck;

    localparam integer FRAME_WIDTH  = 5;
    localparam integer FRAME_HEIGHT = 5;
    localparam integer PIXEL_BITS   = 8;
    localparam integer FRAME_PIXELS = FRAME_WIDTH * FRAME_HEIGHT;

    localparam integer CASE_CONSTANT    = 0;
    localparam integer CASE_RAMP        = 1;
    localparam integer CASE_CHECKERBOARD = 2;
    localparam integer CASE_SALT_PEPPER = 3;
    localparam integer CASE_RANDOM      = 4;

    reg                  clk;
    reg                  reset;
    reg                  valid_in;
    reg [PIXEL_BITS-1:0] pixel_in;
    wire                 valid_out;
    wire [PIXEL_BITS-1:0] pixel_out;

    reg [PIXEL_BITS-1:0] stimulus [0:FRAME_PIXELS-1];
    reg [PIXEL_BITS-1:0] expected [0:FRAME_PIXELS-1];

    integer active_case;
    integer out_seen;
    integer checks;
    integer errors;
    integer cov_case;
    integer cov_region;
    integer cov_output_phase;
    integer cov_input_mode;
    integer cov_value;
    reg     test_active;
    reg     all_input_sent;
    reg [23:0] lfsr;

    // Functional coverage is sampled for every output transaction.
    // Region encoding: 0 = corner, 1 = non-corner edge, 2 = interior.
    // Output phase: 0 = while input is still streaming, 1 = self-flush.
    covergroup median_functional_coverage;
        option.per_instance = 1;

        cp_case : coverpoint cov_case {
            bins constant    = {CASE_CONSTANT};
            bins ramp        = {CASE_RAMP};
            bins checkerboard = {CASE_CHECKERBOARD};
            bins salt_pepper = {CASE_SALT_PEPPER};
            bins random      = {CASE_RANDOM};
        }

        cp_region : coverpoint cov_region {
            bins corner   = {0};
            bins border     = {1};
            bins interior = {2};
        }

        cp_output_phase : coverpoint cov_output_phase {
            bins streaming = {0};
            bins flush     = {1};
        }

        cp_input_mode : coverpoint cov_input_mode {
            bins continuous = {0};
            bins gapped     = {1};
        }

        cp_result_value : coverpoint cov_value {
            bins zero   = {0};
            bins middle = {[1:254]};
            bins full   = {255};
        }

        x_case_region : cross cp_case, cp_region;
    endgroup

    median_functional_coverage median_cov = new();

    median_filter #(
        .WIDTH  (FRAME_WIDTH),
        .LENGTH (FRAME_HEIGHT),
        .SIZE   (PIXEL_BITS)
    ) dut (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (valid_in),
        .pixel_in  (pixel_in),
        .valid_out (valid_out),
        .pixel_out (pixel_out)
    );

    function automatic [PIXEL_BITS-1:0] source_or_zero(
        input integer row,
        input integer col
    );
        begin
            if ((row < 0) || (row >= FRAME_HEIGHT) ||
                (col < 0) || (col >= FRAME_WIDTH))
                source_or_zero = {PIXEL_BITS{1'b0}};
            else
                source_or_zero = stimulus[row * FRAME_WIDTH + col];
        end
    endfunction

    function automatic [PIXEL_BITS-1:0] median_of_nine(
        input [PIXEL_BITS-1:0] v0,
        input [PIXEL_BITS-1:0] v1,
        input [PIXEL_BITS-1:0] v2,
        input [PIXEL_BITS-1:0] v3,
        input [PIXEL_BITS-1:0] v4,
        input [PIXEL_BITS-1:0] v5,
        input [PIXEL_BITS-1:0] v6,
        input [PIXEL_BITS-1:0] v7,
        input [PIXEL_BITS-1:0] v8
    );
        reg [PIXEL_BITS-1:0] values [0:8];
        reg [PIXEL_BITS-1:0] temporary;
        integer a;
        integer b;
        begin
            values[0] = v0; values[1] = v1; values[2] = v2;
            values[3] = v3; values[4] = v4; values[5] = v5;
            values[6] = v6; values[7] = v7; values[8] = v8;

            for (a = 0; a < 8; a = a + 1) begin
                for (b = a + 1; b < 9; b = b + 1) begin
                    if (values[b] < values[a]) begin
                        temporary = values[a];
                        values[a] = values[b];
                        values[b] = temporary;
                    end
                end
            end
            median_of_nine = values[4];
        end
    endfunction

    function automatic [PIXEL_BITS-1:0] model_pixel(
        input integer row,
        input integer col
    );
        begin
            model_pixel = median_of_nine(
                source_or_zero(row - 1, col - 1),
                source_or_zero(row - 1, col),
                source_or_zero(row - 1, col + 1),
                source_or_zero(row,     col - 1),
                source_or_zero(row,     col),
                source_or_zero(row,     col + 1),
                source_or_zero(row + 1, col - 1),
                source_or_zero(row + 1, col),
                source_or_zero(row + 1, col + 1)
            );
        end
    endfunction

    function automatic integer region_for_index(input integer index);
        integer row;
        integer col;
        begin
            row = index / FRAME_WIDTH;
            col = index % FRAME_WIDTH;
            if (((row == 0) || (row == FRAME_HEIGHT - 1)) &&
                ((col == 0) || (col == FRAME_WIDTH - 1)))
                region_for_index = 0;
            else if ((row == 0) || (row == FRAME_HEIGHT - 1) ||
                     (col == 0) || (col == FRAME_WIDTH - 1))
                region_for_index = 1;
            else
                region_for_index = 2;
        end
    endfunction

    task automatic report_error(input [8*180-1:0] message);
        begin
            errors = errors + 1;
            $display("ERROR [median_filter] %0t: %0s", $time, message);
        end
    endtask

    task automatic build_expected;
        integer row;
        integer col;
        begin
            for (row = 0; row < FRAME_HEIGHT; row = row + 1)
                for (col = 0; col < FRAME_WIDTH; col = col + 1)
                    expected[row * FRAME_WIDTH + col] = model_pixel(row, col);
        end
    endtask

    task automatic load_frame(input integer case_id);
        integer index;
        integer row;
        integer col;
        begin
            case (case_id)
                CASE_CONSTANT: begin
                    for (index = 0; index < FRAME_PIXELS; index = index + 1)
                        stimulus[index] = 8'h80;
                end

                CASE_RAMP: begin
                    for (index = 0; index < FRAME_PIXELS; index = index + 1)
                        stimulus[index] = index + 1;
                end

                CASE_CHECKERBOARD: begin
                    for (row = 0; row < FRAME_HEIGHT; row = row + 1)
                        for (col = 0; col < FRAME_WIDTH; col = col + 1)
                            stimulus[row * FRAME_WIDTH + col] =
                                ((row + col) % 2) ? 8'hff : 8'h00;
                end

                CASE_SALT_PEPPER: begin
                    for (index = 0; index < FRAME_PIXELS; index = index + 1)
                        stimulus[index] = 8'h80;
                    stimulus[1]  = 8'h00;
                    stimulus[6]  = 8'hff;
                    stimulus[12] = 8'h00;
                    stimulus[18] = 8'hff;
                    stimulus[23] = 8'h00;
                end

                default: begin
                    lfsr = 24'h5a17c3;
                    for (index = 0; index < FRAME_PIXELS; index = index + 1) begin
                        lfsr = {lfsr[22:0],
                                lfsr[23] ^ lfsr[22] ^ lfsr[21] ^ lfsr[16]};
                        stimulus[index] = lfsr[7:0];
                    end
                end
            endcase
            build_expected();
        end
    endtask

    task automatic run_frame(
        input integer case_id,
        input integer insert_bubbles
    );
        integer index;
        begin
            load_frame(case_id);
            active_case = case_id;
            all_input_sent = 1'b0;
            test_active = 1'b0;

            // reset is synchronous in median_filter; hold it for two rising edges.
            @(negedge clk);
            reset = 1'b1;
            valid_in = 1'b0;
            pixel_in = {PIXEL_BITS{1'b0}};
            repeat (2) @(posedge clk);
            @(negedge clk);
            reset = 1'b0;
            test_active = 1'b1;

            for (index = 0; index < FRAME_PIXELS; index = index + 1) begin
                if (insert_bubbles && ((index % 5) == 2)) begin
                    @(negedge clk);
                    valid_in = 1'b0;
                    pixel_in = {PIXEL_BITS{1'b0}};
                end

                @(negedge clk);
                valid_in = 1'b1;
                pixel_in = stimulus[index];
            end

            // The DUT must now self-flush exactly FRAME_WIDTH+2 shifts.
            @(negedge clk);
            valid_in = 1'b0;
            pixel_in = {PIXEL_BITS{1'b0}};
            all_input_sent = 1'b1;

            wait (out_seen == FRAME_PIXELS);
            @(negedge clk);
            test_active = 1'b0;
            all_input_sent = 1'b0;
        end
    endtask

    always #5 clk = ~clk;

    // Scoreboard checks order, data and exact output count for every frame.
    always @(posedge clk) begin
        #1;
        if (reset) begin
            out_seen = 0;
            if (valid_out !== 1'b0)
                report_error("valid_out must be low while synchronous reset is asserted");
        end else if (valid_out) begin
            if (!test_active) begin
                report_error("unexpected output transaction outside an active frame");
            end else if (out_seen >= FRAME_PIXELS) begin
                report_error("DUT emitted more than FRAME_WIDTH*FRAME_HEIGHT outputs");
            end else begin
                checks = checks + 1;
                if (pixel_out !== expected[out_seen])
                    report_error("pixel mismatch against independent zero-padded median oracle");

                cov_case = active_case;
                cov_region = region_for_index(out_seen);
                cov_output_phase = all_input_sent ? 1 : 0;
                cov_input_mode = (active_case == CASE_RAMP ||
                                  active_case == CASE_SALT_PEPPER ||
                                  active_case == CASE_RANDOM) ? 1 : 0;
                cov_value = pixel_out;
                median_cov.sample();

                out_seen = out_seen + 1;
            end
        end
    end

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        valid_in = 1'b0;
        pixel_in = {PIXEL_BITS{1'b0}};
        active_case = CASE_CONSTANT;
        out_seen = 0;
        checks = 0;
        errors = 0;
        test_active = 1'b0;
        all_input_sent = 1'b0;
        lfsr = 24'h5a17c3;

        run_frame(CASE_CONSTANT, 0);
        run_frame(CASE_RAMP, 1);
        run_frame(CASE_CHECKERBOARD, 0);
        run_frame(CASE_SALT_PEPPER, 1);
        run_frame(CASE_RANDOM, 1);

        // Allow one more clock to expose a spurious transaction after the last frame.
        repeat (2) @(posedge clk);
        #2;

        $display("median_filter checks: %0d, functional coverage: %0.2f%%",
                 checks, median_cov.get_inst_coverage());
        if (errors != 0)
            $fatal(1, "tb_median_filter_selfcheck FAILED with %0d error(s)", errors);

        $display("TEST PASSED: tb_median_filter_selfcheck");
        $finish;
    end

    // A wrong valid count must fail rather than silently hanging forever.
    initial begin
        #100000;
        $fatal(1, "tb_median_filter_selfcheck timed out waiting for DUT output");
    end

endmodule
