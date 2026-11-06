`timescale 1ns / 1ps

module tb_cic_decimator;

    parameter INPUT_WIDTH  = 16;
    parameter OUTPUT_WIDTH = 16;

    reg clk;
    reg rst_n;
    reg ce_in;
    reg [1:0] decim_mode;
    reg signed [INPUT_WIDTH-1:0] din;
    
    wire ce_out;
    wire signed [OUTPUT_WIDTH-1:0] dout;

    // Instantiate Unit Under Test (UUT)
    cic_decimator #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .INTERNAL_WIDTH(28),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .ce_in(ce_in),
        .decim_mode(decim_mode),
        .din(din),
        .ce_out(ce_out),
        .dout(dout)
    );

    // Clock generation: 100 MHz (10ns period)
    always #5 clk = ~clk;

    // Input sample clock enable generation (e.g., every clock cycle for high-rate input)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ce_in <= 1'b0;
        else        ce_in <= 1'b1;
    end

    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        ce_in = 0;
        decim_mode = 2'b00; // R = 2
        din = 0;

        // Reset pulse
        #50;
        rst_n = 1;
        #50;

        // Apply a step input / constant DC test
        din = 16'sd1000;
        
        // Test Mode 00 (R = 2) for 1000ns
        decim_mode = 2'b00;
        #1000;

        // Test Mode 01 (R = 4) for 1000ns
        decim_mode = 2'b01;
        #1000;

        // Test Mode 10 (R = 8) for 1000ns
        decim_mode = 2'b10;
        #2000;

        // Test Mode 11 (R = 16) for 3000ns
        decim_mode = 2'b11;
        #3000;

        $finish;
    end

endmodule