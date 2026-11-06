`timescale 1ns / 1ps

module uart_tx #(
    parameter CLKS_PER_BIT = 868 // 100 MHz clock / 115200 baud ? 868
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,    // Pulsed high to trigger transmission of tx_data
    input  wire [7:0] tx_data,     // 8-bit data byte to send
    output reg        tx,          // Serial data output to USB-UART (Pin B18)
    output reg        tx_busy      // High when transmitting, low when ready
);

    localparam S_IDLE      = 3'b000;
    localparam S_START_BIT = 3'b001;
    localparam S_DATA_BITS = 3'b010;
    localparam S_STOP_BIT  = 3'b011;
    localparam S_CLEANUP   = 3'b100;

    reg [2:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  tx_byte_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            clk_count   <= 16'd0;
            bit_index   <= 3'd0;
            tx_byte_reg <= 8'd0;
            tx          <= 1'b1; // Idle high for UART
            tx_busy     <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;

                    if (tx_start) begin
                        tx_byte_reg <= tx_data;
                        tx_busy     <= 1'b1;
                        state       <= S_START_BIT;
                    end
                end

                S_START_BIT: begin
                    tx <= 1'b0; // Start bit (logic low)
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 16'd0;
                        state     <= S_DATA_BITS;
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                S_DATA_BITS: begin
                    tx <= tx_byte_reg[bit_index]; // Send LSB first
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 16'd0;
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
                    tx <= 1'b1; // Stop bit (logic high)
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 16'd0;
                        state     <= S_CLEANUP;
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                S_CLEANUP: begin
                    tx_busy <= 1'b0;
                    state   <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule