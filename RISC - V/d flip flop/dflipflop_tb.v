module tb_d_flip_flop;

reg clk;
reg reset;
reg d;
wire q;

// Instantiate D Flip-Flop
d_flip_flop uut (
    .clk(clk),
    .reset(reset),
    .d(d),
    .q(q)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// Test inputs
initial begin
    reset = 1;
    d = 0;

    #10 reset = 0;

    #10 d = 1;
    #10 d = 0;
    #10 d = 1;
    #10 d = 1;
    #10 d = 0;

    #20 
//$finish;
end

// Monitor output
initial begin
    $monitor("Time=%0t | clk=%b | reset=%b | d=%b | q=%b",
              $time, clk, reset, d, q);
end

endmodule