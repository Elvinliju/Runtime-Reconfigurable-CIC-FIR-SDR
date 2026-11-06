`timescale 1ns / 1ps

module cic_fir_uart_top (
    input  wire        clk,          // 100 MHz board clock (W5)
    input  wire        rst_n,        // Reset switch (W16)
    input  wire        rx,           // UART RX pin from PC (B18)
    output wire        tx,           // UART TX pin to PC (B18)
    input  wire        bypass_sw,    // MATCHED TO XDC: SW3 mapped to Pin W17 for Bypass
    input  wire [1:0]  decim_mode,   // Decim mode switches (V17, V16)
    output wire [15:0] led           // 16 LEDs mapped to XDC
);

    // Internal wires for UART RX
    wire       rx_vld;
    wire [7:0] rx_data;

    uart_rx #(
        .CLKS_PER_BIT(868) // 100M / 115200
    ) u_uart_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .rx_vld(rx_vld),
        .rx_data(rx_data)
    );

    // Byte-to-16bit Assembler
    reg        byte_toggle;
    reg [15:0] din_sample;
    reg        ce_in_sample;
    reg [7:0]  rx_low_byte;

    always @(posedge clk) begin
        if (!rst_n) begin
            byte_toggle  <= 1'b0;
            din_sample   <= 16'd0;
            ce_in_sample <= 1'b0;
            rx_low_byte  <= 8'd0;
        end else if (rx_vld) begin
            if (!byte_toggle) begin
                rx_low_byte  <= rx_data;
                byte_toggle  <= 1'b1;
                ce_in_sample <= 1'b0;
            end else begin
                // Assemble 16-bit word {High Byte, Low Byte}
                din_sample   <= {rx_data, rx_low_byte};
                byte_toggle  <= 1'b0;
                ce_in_sample <= 1'b1; // Trigger filter input sample
            end
        end else begin
            ce_in_sample <= 1'b0;
        end
    end

    // Filter Top Chain Instance
    wire        ce_out_fir;
    wire [15:0] dout_fir;

    cic_fir_top #(
        .INPUT_WIDTH(16),
        .INTERNAL_WIDTH(28),
        .OUTPUT_WIDTH(16)
    ) u_filter_top (
        .clk(clk),
        .rst_n(rst_n),
        .ce_in(ce_in_sample),
        .decim_mode(decim_mode),
        .bypass(bypass_sw),       // <--- CORRECTED: Matches port name bypass_sw
        .din(din_sample),
        .ce_out_fir(ce_out_fir),
        .dout_fir(dout_fir)
    );

    // Display live filtered output on the 16 LEDs
    assign led = dout_fir;

    // Robust 2-Byte UART TX Serializer FSM
    reg [2:0]  tx_state;
    reg [15:0] saved_dout;
    reg        tx_start;
    reg [7:0]  tx_data;
    wire       tx_busy;
    reg        ce_out_d;
    reg        busy_d;

    always @(posedge clk) begin
        if (!rst_n) begin
            tx_state   <= 3'd0;
            tx_start   <= 1'b0;
            tx_data    <= 8'd0;
            saved_dout <= 16'd0;
            ce_out_d   <= 1'b0;
            busy_d     <= 1'b0;
        end else begin
            ce_out_d <= ce_out_fir;
            tx_start <= 1'b0;
            busy_d   <= tx_busy;

            case (tx_state)
                3'd0: begin // IDLE: Wait for filter output valid strobe
                    if (ce_out_fir && !ce_out_d) begin
                        saved_dout <= dout_fir;
                        if (!tx_busy) begin
                            tx_data  <= dout_fir[7:0]; // Send Low Byte first
                            tx_start <= 1'b1;
                            tx_state <= 3'd1;
                        end
                    end
                end

                3'd1: begin // Wait for tx_busy to go HIGH
                    if (tx_busy || busy_d) begin
                        tx_state <= 3'd2;
                    end
                end

                3'd2: begin // Wait for tx_busy to go LOW (Low byte transmission complete)
                    if (!tx_busy && !busy_d) begin
                        tx_data  <= saved_dout[15:8]; // Send High Byte second
                        tx_start <= 1'b1;
                        tx_state <= 3'd3;
                    end
                end

                3'd3: begin // Wait for tx_busy to go HIGH
                    if (tx_busy || busy_d) begin
                        tx_state <= 3'd4;
                    end
                end

                3'd4: begin // Wait for tx_busy to go LOW (High byte transmission complete)
                    if (!tx_busy && !busy_d) begin
                        tx_state <= 3'd0; // Return to IDLE
                    end
                end
            endcase
        end
    end

    uart_tx #(
        .CLKS_PER_BIT(868)
    ) u_uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(tx),
        .tx_busy(tx_busy)
    );

endmodule
