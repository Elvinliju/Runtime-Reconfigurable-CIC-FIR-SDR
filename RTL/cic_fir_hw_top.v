`timescale 1ns / 1ps

module cic_fir_hw_top (
    input  wire        clk,          // 100 MHz board clock (W5)
    input  wire        rst_n,        // Reset switch (W16)
    input  wire [1:0]  decim_mode,   // Mode switches V17, V16 (SW0, SW1)
    output wire [15:0] led           // 16 Onboard LEDs for output display
);

    // Free-running counter to generate a large input signal for visible LED output
    reg [23:0] free_counter;
    reg        ce_in;
    reg [15:0] test_din;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            free_counter <= 24'd0;
            ce_in        <= 1'b0;
            test_din     <= 16'd0;
        end else begin
            free_counter <= free_counter + 24'd1;
            
            // Pulse ce_in every 16 clock cycles and use a larger step (1000) 
            // so fixed-point scaling does not truncate the output to zero.
            if (free_counter[3:0] == 4'hF) begin
                ce_in    <= 1'b1;
                test_din <= test_din + 16'sd1000; 
            end else begin
                ce_in    <= 1'b0;
            end
        end
    end

    // Wires for top-level filter chain connection
    wire        ce_out_fir;
    wire [15:0] dout_fir;

    // Instantiate filter top module
    cic_fir_top #(
        .INPUT_WIDTH(16),
        .INTERNAL_WIDTH(28),
        .OUTPUT_WIDTH(16)
    ) u_filter_top (
        .clk(clk),
        .rst_n(rst_n),
        .ce_in(ce_in),
        .decim_mode(decim_mode),
        .din(test_din),
        .ce_out_fir(ce_out_fir),
        .dout_fir(dout_fir)
    );

    // Display the filtered output directly on the 16 Basys 3 LEDs
    assign led = dout_fir;

endmodule
