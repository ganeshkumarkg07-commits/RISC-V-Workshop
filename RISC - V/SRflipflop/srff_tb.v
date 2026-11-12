`timescale 1ns/1ps

module tb_dff_4bit;

reg clk;
reg reset;
reg [3:0] d;
wire [3:0] q;

// DUT Instantiation
dff_4bit uut (
    .clk(clk),
    .reset(reset),
    .d(d),
    .q(q)
);

// Clock Generation
always #5 clk = ~clk;

// Test Stimulus
initial
begin
    clk = 0;
    reset = 1;
    d = 4'b0000;

    #10 reset = 0;

    #10 d = 4'b1010;
    #10 d = 4'b1100;
    #10 d = 4'b1111;
    #10 d = 4'b0101;
    #10 d = 4'b1001;

    #10 reset = 1;
    #10 reset = 0;

    #20 $finish;
end

// Monitor
initial
begin
    $monitor("Time=%0t | CLK=%b | RESET=%b | D=%b | Q=%b",
              $time, clk, reset, d, q);
end

endmodule