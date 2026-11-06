`timescale 1ns / 1ps

module fir_compensator #(
    parameter DATA_WIDTH = 16,
    parameter COEFF_WIDTH = 16,
    parameter ACCU_WIDTH = 36
)(
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       ce_in,         // Strobe from CIC output (ce_out)
    input  wire signed [DATA_WIDTH-1:0]   din,       // CIC normalized output
    output reg                        ce_out,        // Filtered output valid strobe (aligned)
    output reg signed [DATA_WIDTH-1:0]  dout         // Fully compensated FIR output
);

    // 15-Tap Symmetric FIR Filter Coefficients (Scaled for Fixed-Point Q15 format)
    // Corrected 15-Tap Inverse-Sinc Compensation Filter Coefficients (Q15 format)
    reg signed [COEFF_WIDTH-1:0] c [0:14];
initial begin
        c[0]  = 16'shFEDD; // -291
        c[1]  = 16'shFA84; // -1404
        c[2]  = 16'shF9B5; // -1611
        c[3]  = 16'shFEE8; // -280
        c[4]  = 16'sh0A3D; // 2621
        c[5]  = 16'sh181C; // 6172
        c[6]  = 16'sh2363; // 9059
        c[7]  = 16'sh27DA; // 10202 (Center tap - peak boost)
        c[8]  = 16'sh2363; // 9059
        c[9]  = 16'sh181C; // 6172
        c[10] = 16'sh0A3D; // 2621
        c[11] = 16'shFEE8; // -280
        c[12] = 16'shF9B5; // -1611
        c[13] = 16'shFA84; // -1404
        c[14] = 16'shFEDD; // -291
    end

    // Delay line (shift register) for input samples, clocked on ce_in
    reg signed [DATA_WIDTH-1:0] delay_line [0:14];
    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < 15; i = i + 1) begin
                delay_line[i] <= 'sd0;
            end
        end else if (ce_in) begin
            delay_line[0] <= din;
            for (i = 1; i < 15; i = i + 1) begin
                delay_line[i] <= delay_line[i-1];
            end
        end
    end

    // Symmetric Multiply-Accumulate (MAC) Logic with Pipelined Strobe Alignment
    reg signed [ACCU_WIDTH-1:0] mac_sum;
    reg ce_pipeline;

    always @(posedge clk) begin
        if (!rst_n) begin
            mac_sum     <= 'sd0;
            dout        <= 'sd0;
            ce_pipeline <= 1'b0;
            ce_out      <= 1'b0;
        end else if (ce_in) begin
            // Pipeline the valid strobe to match 1-cycle MAC latency
            ce_pipeline <= 1'b1;
            ce_out      <= ce_pipeline;

            // Exploiting symmetry: (x[n] + x[n-14]) * c[0], etc.
            mac_sum <= 
                (({{ (ACCU_WIDTH-DATA_WIDTH){delay_line[0][DATA_WIDTH-1]}}, delay_line[0]} + 
                  {{ (ACCU_WIDTH-DATA_WIDTH){delay_line[14][DATA_WIDTH-1]}}, delay_line[14]}) * c[0]) +
                (({{ (ACCU_WIDTH-DATA_WIDTH){delay_line[1][DATA_WIDTH-1]}}, delay_line[1]} + 
                  {{ (ACCU_WIDTH-DATA_WIDTH){delay_line[13][DATA_WIDTH-1]}}, delay_line[13]}) * c[1]) +
                (({{ (ACCU_WIDTH-DATA_WIDTH){delay_line[2][DATA_WIDTH-1]}}, delay_line[2]} + 
                  {{ (ACCU_WIDTH-DATA_WIDTH){delay_line[12][DATA_WIDTH-1]}}, delay_line[12]}) * c[2]) +
                (({{ (ACCU_WIDTH-DATA_WIDTH){delay_line[3][DATA_WIDTH-1]}}, delay_line[3]} + 
                  {{ (ACCU_WIDTH-DATA_WIDTH){delay_line[11][DATA_WIDTH-1]}}, delay_line[11]}) * c[3]) +
                (({{ (ACCU_WIDTH-DATA_WIDTH){delay_line[4][DATA_WIDTH-1]}}, delay_line[4]} + 
                  {{ (ACCU_WIDTH-DATA_WIDTH){delay_line[10][DATA_WIDTH-1]}}, delay_line[10]}) * c[4]) +
                (({{ (ACCU_WIDTH-DATA_WIDTH){delay_line[5][DATA_WIDTH-1]}}, delay_line[5]} + 
                  {{ (ACCU_WIDTH-DATA_WIDTH){delay_line[9][DATA_WIDTH-1]}}, delay_line[9]}) * c[5]) +
                (({{ (ACCU_WIDTH-DATA_WIDTH){delay_line[6][DATA_WIDTH-1]}}, delay_line[6]} + 
                  {{ (ACCU_WIDTH-DATA_WIDTH){delay_line[8][DATA_WIDTH-1]}}, delay_line[8]}) * c[6]) +
                (({{ (ACCU_WIDTH-DATA_WIDTH){delay_line[7][DATA_WIDTH-1]}}, delay_line[7]}) * c[7]);

            // Truncate/Scale down from Q31/Accumulator format back to 16-bit output
            // Truncate/Scale down from accumulator format back to 16-bit output
        // Using proper rounding and safe right-shift to prevent overflow
        // Truncate/Scale down with extra headroom shift (>>> 16) to prevent clipping
        dout <= (mac_sum + 32768) >>> 16;
        end else begin
            ce_pipeline <= 1'b0;
            ce_out      <= ce_pipeline;
        end
    end

endmodule