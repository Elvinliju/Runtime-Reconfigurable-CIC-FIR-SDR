`timescale 1ns / 1ps

module uart_rx #(
    parameter CLKS_PER_BIT = 868 // 100 MHz clock / 115200 baud ? 868
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,          // Serial data input from USB-UART (Pin A18)
    output reg        rx_vld,      // Pulsed high for 1 cycle when a byte is received
    output reg [7:0]  rx_data      // 8-bit received data byte
);

    // State machine states
    localparam S_IDLE       = 3'b000;
    localparam S_START_BIT  = 3'b001;
    localparam S_DATA_BITS  = 3'b010;
    localparam S_STOP_BIT   = 3'b011;
    localparam S_CLEANUP    = 3'b100;

    reg [2:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  rx_byte_reg;
    reg        rx_sync1, rx_sync2;

    // Synchronize asynchronous RX line to prevent metastability
    always @(posedge clk) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            clk_count   <= 16'd0;
            bit_index   <= 3'd0;
            rx_byte_reg <= 8'd0;
            rx_vld      <= 1'b0;
            rx_data     <= 8'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    rx_vld <= 1'b0;
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;
                    
                    // Detect Falling Edge of Start Bit (logic low)
                    if (rx_sync2 == 1'b0)
                        state <= S_START_BIT;
                end

                S_START_BIT: begin
                    // Sample at the middle of the start bit
                    if (clk_count == (CLKS_PER_BIT / 2)) begin
                        if (rx_sync2 == 1'b0) begin
                            clk_count <= 16'd0;
                            state     <= S_DATA_BITS;
                        end else begin
                            state     <= S_IDLE; // False start bit noise rejection
                        end
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                S_DATA_BITS: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 16'd0;
                        rx_byte_reg[bit_index] <= rx_sync2; // Sample bit
                        
                        if (bit_index < 3'd7) begin
                            bit_index <= bit_index + 3'd1;
                        end else begin
                            bit_index <= 3'd0;
                            state     <= S_STOP_BIT;
                        end
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                S_STOP_BIT: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        rx_vld  <= 1'b1; // Pulse valid strobe
                        rx_data <= rx_byte_reg;
                        clk_count <= 16'd0;
                        state     <= S_CLEANUP;
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                S_CLEANUP: begin
                    rx_vld <= 1'b0;
                    state  <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule