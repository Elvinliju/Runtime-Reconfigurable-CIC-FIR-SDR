`timescale 1ns / 1ps

module cic_fir_top #(
    parameter INPUT_WIDTH  = 16,
    parameter INTERNAL_WIDTH = 28,
    parameter OUTPUT_WIDTH = 16
)(
    input  wire                       clk,
    input  wire                       rst_n,          // Active-low synchronous reset
    input  wire                       ce_in,          // Input clock enable (sample rate clock)
    input  wire [1:0]                 decim_mode,     // 00: R=2, 01: R=4, 10: R=8, 11: R=16
    input  wire                       bypass,         // NEW: 0 = CIC + FIR, 1 = CIC Only
    input  wire signed [INPUT_WIDTH-1:0]   din,       // Input data sample
    output wire                       ce_out_fir,     // Final output valid strobe
    output wire signed [OUTPUT_WIDTH-1:0] dout_fir    // Final output data
);

    // Internal wires connecting CIC output to FIR input
    wire                       cic_ce_out;
    wire signed [OUTPUT_WIDTH-1:0] cic_dout;

    // Instantiate CIC Decimator
    cic_decimator #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .INTERNAL_WIDTH(INTERNAL_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) u_cic (
        .clk(clk),
        .rst_n(rst_n),
        .ce_in(ce_in),
        .decim_mode(decim_mode),
        .din(din),
        .ce_out(cic_ce_out),
        .dout(cic_dout)
    );

    // Internal wires for FIR output
    wire                       fir_ce_out;
    wire signed [OUTPUT_WIDTH-1:0] fir_dout;

    // Instantiate FIR Compensation Filter
    fir_compensator #(
        .DATA_WIDTH(OUTPUT_WIDTH),
        .COEFF_WIDTH(16),
        .ACCU_WIDTH(36)
    ) u_fir (
        .clk(clk),
        .rst_n(rst_n),
        .ce_in(cic_ce_out),
        .din(cic_dout),
        .ce_out(fir_ce_out),
        .dout(fir_dout)
    );

    // Multiplexer to select between CIC-only and CIC+FIR output
    assign ce_out_fir = bypass ? cic_ce_out : fir_ce_out;
    assign dout_fir   = bypass ? cic_dout   : fir_dout;

endmodule
