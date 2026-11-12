
module riscv_pipeline_tb;

reg clk;
reg reset;
 
wire misaligned_access;

// Processor instantiation
riscv_pipeline uut (
    .clk(clk),
    .reset(reset),
    .misaligned_access(misaligned_access)
);

// Clock generation: 10 ns period
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// Test sequence
initial begin

    reset = 1;

    // Initialize instruction memory

    uut.imem[0] = 32'h00500093; // ADDI x1,x0,5
    uut.imem[1] = 32'h00700113; // ADDI x2,x0,7
    uut.imem[2] = 32'h002081B3; // ADD x3,x1,x2
    uut.imem[3] = 32'h40118233; // SUB x4,x3,x1
    uut.imem[4] = 32'h00302023; // SW x3,0(x0)
    uut.imem[5] = 32'h00002283; // LW x5,0(x0)
    uut.imem[6] = 32'h00128313; // ADDI x6,x5,1

    // Initialize data memory
    uut.dmem[0] = 0;

    // Reset duration
    #20;
    reset = 0;

    // Wait for pipeline execution
    #300;

    // Display results
    $display("");
    $display("================================");
    $display("  32-BIT RISC-V PIPELINE RESULT");
    $display("================================");

    $display("Register x1 = %0d", uut.regs[1]);
    $display("Register x2 = %0d", uut.regs[2]);
    $display("Register x3 = %0d", uut.regs[3]);
    $display("Register x4 = %0d", uut.regs[4]);
    $display("Register x5 = %0d", uut.regs[5]);
    $display("Register x6 = %0d", uut.regs[6]);

    $display("Data Memory[0] = %0d", uut.dmem[0]);

    $display("--------------------------------");

    // Automatic verification
    if (
        uut.regs[1] == 5 &&
        uut.regs[2] == 7 &&
        uut.regs[3] == 12 &&
        uut.regs[4] == 7 &&
        uut.regs[5] == 12 &&
        uut.regs[6] == 13 &&
        uut.dmem[0] == 12 &&
        misaligned_access == 0
    )
        $display("TEST PASSED");

    else
        $display("TEST FAILED");

    $display("================================");

    $finish;

end

// Monitor processor operation
initial begin

    $monitor(
        "Time=%0t | PC=%h | x1=%d | x2=%d | x3=%d | Stall=%b",
        $time,
        uut.pc,
        uut.regs[1],
        uut.regs[2],
        uut.regs[3],
        uut.stall
    );

end

endmodule
