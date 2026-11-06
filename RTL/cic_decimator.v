`timescale 1ns / 1ps

module cic_decimator #(
    parameter INPUT_WIDTH  = 16,
    parameter INTERNAL_WIDTH = 28,
    parameter OUTPUT_WIDTH = 16
)(
    input  wire                              clk,
    input  wire                              rst_n,          // Active-low synchronous reset
    input  wire                              ce_in,          // Input clock enable (sample rate clock)
    input  wire [1:0]                        decim_mode,     // 00: R=2, 01: R=4, 10: R=8, 11: R=16
    input  wire signed [INPUT_WIDTH-1:0]     din,            // Input data sample
    output reg                               ce_out,         // Output clock enable (decimated rate)
    output reg signed [OUTPUT_WIDTH-1:0]     dout            // Filtered & normalized output
);

    // -------------------------------------------------------------------------
    // 1. Decimation Rate Decoding & Counter Setup
    // -------------------------------------------------------------------------
    reg [4:0] max_count;
    always @(*) begin
        case (decim_mode)
            2'b00: max_count = 5'd2;   // R = 2
            2'b01: max_count = 5'd4;   // R = 4
            2'b10: max_count = 5'd8;   // R = 8
            2'b11: max_count = 5'd16;  // R = 16
            default: max_count = 5'd2;
        endcase
    end

    reg [4:0] dec_counter;

    always @(posedge clk) begin
        if (!rst_n) begin
            dec_counter <= 5'd0;
        end else if (ce_in) begin
            if (dec_counter >= max_count - 1'b1) begin
                dec_counter <= 5'd0;
            end else begin
                dec_counter <= dec_counter + 1'b1;
            end
        end
    end

    // Combinational decimation strobe (eliminates register race condition)
    wire sample_ce = ce_in && (dec_counter == max_count - 1'b1);

    // -------------------------------------------------------------------------
    // 2. Integrator Stages (3 Stages, Operating at High Sample Rate `ce_in`)
    // -------------------------------------------------------------------------
    reg signed [INTERNAL_WIDTH-1:0] int1, int2, int3;

    always @(posedge clk) begin
        if (!rst_n) begin
            int1 <= 'sd0;
            int2 <= 'sd0;
            int3 <= 'sd0;
        end else if (ce_in) begin
            int1 <= int1 + {{(INTERNAL_WIDTH-INPUT_WIDTH){din[INPUT_WIDTH-1]}}, din};
            int2 <= int2 + int1;
            int3 <= int3 + int2;
        end
    end

    // -------------------------------------------------------------------------
    // 3. Decimator Sampling Register
    // -------------------------------------------------------------------------
    reg signed [INTERNAL_WIDTH-1:0] dec_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            dec_reg <= 'sd0;
        end else if (sample_ce) begin
            dec_reg <= int3;
        end
    end

    // -------------------------------------------------------------------------
    // 4. Comb Stages (3 Stages, Operating at Decimated Rate `sample_ce`)
    // -------------------------------------------------------------------------
    reg signed [INTERNAL_WIDTH-1:0] c1_d1, c2_d1, c3_d1;
    reg signed [INTERNAL_WIDTH-1:0] comb1, comb2, comb3;

    always @(posedge clk) begin
        if (!rst_n) begin
            c1_d1 <= 'sd0;
            c2_d1 <= 'sd0;
            c3_d1 <= 'sd0;
            comb1 <= 'sd0;
            comb2 <= 'sd0;
            comb3 <= 'sd0;
            ce_out <= 1'b0;
            dout   <= 'sd0;
        end else if (sample_ce) begin
            // Stage 1 Comb ($M=1$)
            comb1 <= dec_reg - c1_d1;
            c1_d1 <= dec_reg;

            // Stage 2 Comb
            comb2 <= comb1 - c2_d1;
            c2_d1 <= comb1;

            // Stage 3 Comb
            comb3 <= comb2 - c3_d1;
            c3_d1 <= comb2;

            // Set output valid strobe
            ce_out <= 1'b1;

            // -----------------------------------------------------------------
            // 5. Gain Normalization (Right shift by 3 * log2(R))
            // -----------------------------------------------------------------
            case (decim_mode)
                2'b00: dout <= (comb3 >>> 3);
                2'b01: dout <= (comb3 >>> 6);
                2'b10: dout <= (comb3 >>> 9);
                2'b11: dout <= (comb3 >>> 12);
                default: dout <= (comb3 >>> 3);
            endcase
        end else begin
            ce_out <= 1'b0;
        end
    end

endmodule
