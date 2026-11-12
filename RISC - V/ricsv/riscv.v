
module riscv_pipeline (
    input clk,
    input reset,
    output wire misaligned_access
);

// =================================
// MEMORY AND REGISTER DECLARATIONS
// =================================

reg [31:0] imem [0:63];
reg [31:0] dmem [0:63];
reg [31:0] regs [0:31];

reg [31:0] pc;

// =================================
// IF/ID PIPELINE REGISTERS
// =================================

reg [31:0] if_id_instr;
reg [31:0] if_id_pc;

// =================================
// ID/EX PIPELINE REGISTERS
// =================================

reg [31:0] id_ex_pc;
reg [31:0] id_ex_a;
reg [31:0] id_ex_b;
reg [31:0] id_ex_imm;

reg [4:0] id_ex_rs1;
reg [4:0] id_ex_rs2;
reg [4:0] id_ex_rd;

reg id_ex_regwrite;
reg id_ex_memread;
reg id_ex_memwrite;
reg id_ex_memtoreg;
reg id_ex_alusrc;

reg [2:0] id_ex_aluop;

// =================================
// EX/MEM PIPELINE REGISTERS
// =================================

reg [31:0] ex_mem_result;
reg [31:0] ex_mem_store_data;

reg [4:0] ex_mem_rd;

reg ex_mem_regwrite;
reg ex_mem_memread;
reg ex_mem_memwrite;
reg ex_mem_memtoreg;

// =================================
// MEM/WB PIPELINE REGISTERS
// =================================

reg [31:0] mem_wb_data;

reg [4:0] mem_wb_rd;
reg mem_wb_regwrite;

// =================================
// INSTRUCTION FIELDS
// =================================

wire [6:0] opcode;
wire [4:0] rd;
wire [2:0] funct3;
wire [4:0] rs1;
wire [4:0] rs2;
wire [6:0] funct7;

assign opcode = if_id_instr[6:0];
assign rd     = if_id_instr[11:7];
assign funct3 = if_id_instr[14:12];
assign rs1    = if_id_instr[19:15];
assign rs2    = if_id_instr[24:20];
assign funct7 = if_id_instr[31:25];

// =================================
// STAGE 2: INTELLIGENT DECODE
// =================================

reg dec_regwrite;
reg dec_memread;
reg dec_memwrite;
reg dec_memtoreg;
reg dec_alusrc;

reg [2:0] dec_aluop;
reg [31:0] dec_imm;

reg uses_rs1;
reg uses_rs2;

wire stall;

always @(*) begin

    dec_regwrite = 0;
    dec_memread  = 0;
    dec_memwrite = 0;
    dec_memtoreg = 0;
    dec_alusrc   = 0;

    dec_aluop = 3'b000;
    dec_imm = 0;

    uses_rs1 = 0;
    uses_rs2 = 0;

    case (opcode)

        // ADD and SUB
        7'b0110011: begin

            uses_rs1 = 1;
            uses_rs2 = 1;
            dec_regwrite = 1;

            if (funct3 == 3'b000 &&
                funct7 == 7'b0100000)
                dec_aluop = 3'b001;
            else
                dec_aluop = 3'b000;

        end

        // ADDI
        7'b0010011: begin

            dec_regwrite = 1;
            dec_alusrc = 1;
            uses_rs1 = 1;

            dec_imm = {{20{if_id_instr[31]}},
                       if_id_instr[31:20]};

        end

        // LW
        7'b0000011: begin

            dec_regwrite = 1;
            dec_memread = 1;
            dec_memtoreg = 1;
            dec_alusrc = 1;
            uses_rs1 = 1;

            dec_imm = {{20{if_id_instr[31]}},
                       if_id_instr[31:20]};

        end

        // SW
        7'b0100011: begin

            dec_memwrite = 1;
            dec_alusrc = 1;

            uses_rs1 = 1;
            uses_rs2 = 1;

            dec_imm = {{20{if_id_instr[31]}},
                       if_id_instr[31:25],
                       if_id_instr[11:7]};

        end

        default: begin
        end

    endcase

end

// =================================
// INNOVATION 1: HAZARD DETECTION
// =================================

assign stall =
    id_ex_memread &&
    (id_ex_rd != 0) &&
    ((uses_rs1 && (id_ex_rd == rs1)) ||
     (uses_rs2 && (id_ex_rd == rs2)));

// =================================
// STAGE 3: EXECUTE
// DATA FORWARDING
// =================================

reg [31:0] alu_a;
reg [31:0] alu_b;
reg [31:0] operand_b;
reg [31:0] alu_result;

always @(*) begin

    alu_a = id_ex_a;
    operand_b = id_ex_b;

    // Forwarding from EX/MEM
    if (ex_mem_regwrite &&
        !ex_mem_memread &&
        (ex_mem_rd != 0) &&
        (ex_mem_rd == id_ex_rs1))
        alu_a = ex_mem_result;

    else if (mem_wb_regwrite &&
             (mem_wb_rd != 0) &&
             (mem_wb_rd == id_ex_rs1))
        alu_a = mem_wb_data;

    // Forwarding for second operand
    if (ex_mem_regwrite &&
        !ex_mem_memread &&
        (ex_mem_rd != 0) &&
        (ex_mem_rd == id_ex_rs2))
        operand_b = ex_mem_result;

    else if (mem_wb_regwrite &&
             (mem_wb_rd != 0) &&
             (mem_wb_rd == id_ex_rs2))
        operand_b = mem_wb_data;

    // ALU input selection
    if (id_ex_alusrc)
        alu_b = id_ex_imm;
    else
        alu_b = operand_b;

end

// ALU operations
always @(*) begin

    case (id_ex_aluop)

        3'b000:
            alu_result = alu_a + alu_b;

        3'b001:
            alu_result = alu_a - alu_b;

        default:
            alu_result = 0;

    endcase

end

// =================================
// INNOVATION 2: SMART MEMORY ACCESS
// ALIGNMENT CHECK
// =================================

assign misaligned_access =
    (ex_mem_memread || ex_mem_memwrite) &&
    (ex_mem_result[1:0] != 2'b00);

// =================================
// PIPELINE SEQUENTIAL LOGIC
// =================================

integer i;

always @(posedge clk or posedge reset) begin

    if (reset) begin

        pc <= 0;

        if_id_instr <= 0;
        if_id_pc <= 0;

        id_ex_pc <= 0;
        id_ex_a <= 0;
        id_ex_b <= 0;
        id_ex_imm <= 0;

        id_ex_rs1 <= 0;
        id_ex_rs2 <= 0;
        id_ex_rd <= 0;

        id_ex_regwrite <= 0;
        id_ex_memread <= 0;
        id_ex_memwrite <= 0;
        id_ex_memtoreg <= 0;
        id_ex_alusrc <= 0;
        id_ex_aluop <= 0;

        ex_mem_result <= 0;
        ex_mem_store_data <= 0;
        ex_mem_rd <= 0;

        ex_mem_regwrite <= 0;
        ex_mem_memread <= 0;
        ex_mem_memwrite <= 0;
        ex_mem_memtoreg <= 0;

        mem_wb_data <= 0;
        mem_wb_rd <= 0;
        mem_wb_regwrite <= 0;

        for (i = 0; i < 32; i = i + 1)
            regs[i] <= 0;

    end

    else begin

        // =================================
        // STAGE 5: WRITE BACK
        // =================================

        if (mem_wb_regwrite &&
            mem_wb_rd != 0)
            regs[mem_wb_rd] <= mem_wb_data;

        regs[0] <= 0;

        // =================================
        // STAGE 4: MEMORY ACCESS
        // =================================

        mem_wb_rd <= ex_mem_rd;
        mem_wb_regwrite <=
            ex_mem_regwrite &&
            !misaligned_access;

        if (ex_mem_memread &&
            !misaligned_access)
            mem_wb_data <=
                dmem[ex_mem_result[7:2]];

        else
            mem_wb_data <= ex_mem_result;

        if (ex_mem_memwrite &&
            !misaligned_access)
            dmem[ex_mem_result[7:2]]
                <= ex_mem_store_data;

        // =================================
        // STAGE 3: EXECUTE
        // =================================

        ex_mem_result <= alu_result;
        ex_mem_store_data <= operand_b;
        ex_mem_rd <= id_ex_rd;

        ex_mem_regwrite <= id_ex_regwrite;
        ex_mem_memread <= id_ex_memread;
        ex_mem_memwrite <= id_ex_memwrite;
        ex_mem_memtoreg <= id_ex_memtoreg;

        // =================================
        // STAGE 2: DECODE
        // =================================

        if (stall) begin

            // Insert pipeline bubble
            id_ex_regwrite <= 0;
            id_ex_memread <= 0;
            id_ex_memwrite <= 0;
            id_ex_memtoreg <= 0;
            id_ex_alusrc <= 0;
            id_ex_aluop <= 0;

            // Hold PC and instruction
            pc <= pc;
            if_id_instr <= if_id_instr;
            if_id_pc <= if_id_pc;

        end

        else begin

            id_ex_pc <= if_id_pc;

            // WB to ID bypass
            if (mem_wb_regwrite &&
                mem_wb_rd != 0 &&
                mem_wb_rd == rs1)
                id_ex_a <= mem_wb_data;
            else
                id_ex_a <= regs[rs1];

            if (mem_wb_regwrite &&
                mem_wb_rd != 0 &&
                mem_wb_rd == rs2)
                id_ex_b <= mem_wb_data;
            else
                id_ex_b <= regs[rs2];

            id_ex_imm <= dec_imm;

            id_ex_rs1 <= rs1;
            id_ex_rs2 <= rs2;
            id_ex_rd <= rd;

            id_ex_regwrite <= dec_regwrite;
            id_ex_memread <= dec_memread;
            id_ex_memwrite <= dec_memwrite;
            id_ex_memtoreg <= dec_memtoreg;
            id_ex_alusrc <= dec_alusrc;
            id_ex_aluop <= dec_aluop;

            // =================================
            // STAGE 1: INSTRUCTION FETCH
            // =================================

            if_id_instr <= imem[pc[7:2]];
            if_id_pc <= pc;

            pc <= pc + 4;

        end

    end

end

endmodule
