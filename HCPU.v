`timescale 1ns / 1ps



module CPU(//nop: sll $zero $zero 0
    input wire clock,
    input wire start
    );

    reg [7:0]instruction[255:0];
    reg [31:0]IF = 32'h00000000;//PC:32
    reg [31:0]IFID = 32'h00000000;//Code:32
    reg [111:0]IDEXE = 0;//reg_A/B: 2*32=64; imm:32; regDest:5; ALUop:3; FlagExamine:3; flags: 5
    reg [40:0]EXEMEM = 0;//flags: s:1; l:1; b:2; result:32; regDest:5; 
    reg [38:0]MEMWB = 0;// result:32; regDest:5;
    reg [19:0]registers = 20'b1111_1111_1111_1111_1111;
    reg [15:0]immcode;

    reg [31:0]gr[31:0];//[31:0]for 32bit MIPS processor
    reg [15:0]pc;// = 32'h00000000;

    reg [31:0]instr;
    reg [31:0]reg_A;
    reg [31:0]reg_B;
    reg [31:0]result;
    reg unsigned [4:0]reg_Dest;
    reg [31:0]imm;
    reg [3:0]FlagExamine;
    reg aAbsent = 0, bAbsent = 0;
    reg save = 0, load = 0, neg = 0, stall = 0, flush = 0, SignExt, bj, zf, nf, vf, cont = 0;
    reg [1:0]branchjump;

    reg [5:0]opcode;
    reg [5:0]functcode;
    integer datafile;
    integer scanfile;
    integer i;
    integer j = 0;
    logic [31:0] instructionLine;

    reg [31:0] instrIF;
    reg [111:0] EXELine = 0;
    reg [40:0] MEMLine = 0;
    reg [38:0] WBLine = 0;
    reg [2:0] ALUop;
    reg [31:0]Address[255:0];
always @(start)
    begin
        for (i = 0; i < 32; i = i + 1 )begin
        gr[i] = 32'h0000_0000;
        end
        datafile = $fopen ("C:\\Users\\king\\Desktop\\file2.txt", "r");
        while (!$feof(datafile)) begin
            scanfile = $fscanf(datafile, "%b\n", instructionLine);
            instruction[j] = instructionLine[31:24];
            instruction[j+1] = instructionLine[23:16];
            instruction[j+2] = instructionLine[15:8];
            instruction[j+3] = instructionLine[7:0];
            j = j + 4;
        end
        
    end

//sequential logic
always @(posedge clock)
	begin
        //pc
        
        EXELine = IDEXE;
        MEMLine = EXEMEM;
        WBLine = MEMWB;
        if(stall == 1'b0)begin
            pc = IF;
            IF = pc + 4;
            instr = IFID;
        end
        if(stall && cont) cont = 0;
        else if(stall) stall = 0;
        //IF
        if(stall == 0)begin
        instrIF[31:24] = instruction[pc];
        instrIF[23:16] = instruction[pc+1];
        instrIF[15:8] = instruction[pc+2];
        instrIF[7:0] = instruction[pc+3];
        //+-&|^~<>
        //ID
        opcode = instr[31:26];
        functcode = instr[5:0];
        immcode = instr[15:0];
        SignExt = (opcode[5]==1'b1||opcode[5:2]==4'b0001)?1'b1:1'b0;
        imm[31:16] = (SignExt&immcode[15])? 16'b1111_1111_1111_1111:16'b0000_0000_0000_0000;
        imm[15:0] = immcode;
        if (opcode == 6'b000000)//r
        begin
            if(functcode[5:2] == 4'b0000)begin
                reg_A = instr[10:6];
            end
            else if(instr[25:21] == 5'b00000)reg_A = 0;
            else if(instr[25:21] == registers[14:10])begin
                stall = 1;
                cont = 1;
                reg_A = 32'h00000000;
            end
            else if(instr[25:21] == registers[9:5])begin
                if(EXEMEM[1])begin
                    aAbsent = 1;
                    reg_A = 32'h00000000;
                end
                else if (EXELine[110]^EXELine[109])reg_A = 32'h00000000;
                else reg_A = EXEMEM[38:7];
            end
            else if(instr[25:21] == registers[4:0]&&WBLine[0]==0&&WBLine[1]==0)begin
                reg_A = MEMWB[38:7];
            end
            else reg_A = gr[instr[25:21]];

            
            if(instr[20:16] == 5'b00000)reg_B = 0;
            else if(instr[20:16] == registers[14:10])begin
                stall = 1;
                cont = 1;
                reg_B = 32'h00000000;
            end
            else if(instr[20:16] == registers[9:5])begin
                
                if(EXEMEM[1])begin
                    bAbsent = 1;
                    reg_B = 32'h00000000;
                end
                else if (EXELine[110]^EXELine[109])reg_B = 32'h00000000;
                else reg_B = EXEMEM[38:7];
            end
            else if(instr[20:16] == registers[4:0]&&MEMWB[0]==0&&MEMWB[1]==0)begin
                reg_B = MEMWB[38:7];
            end
            else reg_B = gr[instr[20:16]];
            
            
            reg_Dest = instr[15:11];
            ALUop[0] = (functcode == 6'b100101||functcode[1] == 1'b1)?1'b1:1'b0;
            ALUop[1] = (functcode[5:1] == 5'b10010||functcode[5] == 1'b0)?1'b1:1'b0;
            ALUop[2] = (functcode[5:1] == 5'b10011||functcode[5] == 1'b0)?1'b1:1'b0;//r
            if(functcode == 6'b001000)ALUop = 3'b000;
            FlagExamine[2] = (functcode == 6'b100001||functcode == 6'b100011||functcode == 6'b000011||functcode == 6'b000111)?1'b1:1'b0;
            FlagExamine[1] = 1'b0;
            FlagExamine[0] = (functcode[5:1] == 5'b00001||functcode == 6'b000100)?1'b1:1'b0;
            save = 1'b0;
            load = 1'b0;
            branchjump = (functcode == 6'b001000)? 2'b10:2'b00;//jr
            
            neg = (functcode == 6'b101010)? 1'b1:1'b0;//slt
        end
        else//i,j
        begin
            if(opcode[5:2] == 4'b0000)begin//i
                reg_B = instr[25:0];
                reg_A = 32'h00000002;
            end
            else
                begin
                    if(instr[25:21] == 5'b00000)reg_A = 0;
                    else if(instr[25:21] == registers[14:10])begin
                        stall = 1;
                        cont = 1;
                        reg_A = 32'h00000000;
                    end
                    else if(instr[25:21] == registers[9:5])begin
                        if(EXEMEM[1])begin
                            aAbsent = 1;
                            reg_A = 32'h00000000;
                        end
                        else reg_A = EXEMEM[38:7];
                    end
                    else if(instr[25:21] == registers[4:0]&&WBLine[0]==0&&WBLine[1]==0)begin
                        reg_A = MEMWB[38:7];
                    end
                    else reg_A = gr[instr[25:21]];

                    if(opcode[5:3] == 3'b000) begin
                        if(instr[20:16] == 5'b00000)reg_B = 0;
                        else if(instr[20:16] == registers[14:10])begin
                            stall = 1;
                            cont = 1;
                            reg_B = 32'h00000000;
                        end
                        else if(instr[20:16] == registers[9:5])begin
                            if(EXEMEM[1])begin
                                bAbsent = 1;
                                reg_B = 32'h00000000;
                            end
                            else reg_B = EXEMEM[38:7];
                        end
                        else if(instr[20:16] == registers[4:0]&&MEMWB[0]==0&&MEMWB[1]==0)begin
                            reg_B = MEMWB[38:7];
                        end
                        else reg_B = gr[instr[20:16]];
                    end
                    else reg_B = imm;
                end

            reg_Dest = (opcode[5:3] == 3'b000)? 30:instr[20:16];
            ALUop[0] = (opcode[5:2] == 4'b0001||opcode == 6'b001101)?1'b1:1'b0;
            ALUop[1] = (opcode[5:1] == 5'b00110||opcode[5:2] == 4'b0000)?1'b1:1'b0;
            ALUop[2] = (opcode[5:2] == 4'b0000)?1'b1:1'b0;//i
            FlagExamine[2] = (opcode[3:0] == 4'b1001)?1'b1:1'b0;
            FlagExamine[1] = (opcode[5:1] == 5'b00010)?1'b1:1'b0;
            FlagExamine[0] = (opcode[5:1] == 5'b00001||opcode == 6'b000100)?1'b1:1'b0;
            save = (opcode == 6'b101011)?1'b1:1'b0;
            load = (opcode == 6'b100011)?1'b1:1'b0;//lw sw

            branchjump[1] = (opcode[5:2] == 5'b0000)?1'b1:1'b0;//j b
            branchjump[0] = (opcode[5:1] == 5'b00010||opcode == 6'b000011)?1'b1:1'b0;
            neg = 1'b0;
        end
        registers[19:15] = reg_Dest;
        end
        
        //EXE
        vf = 0;
    

        //0-2: ALUop; 3-5: FE; 6-10: rD; 11-42: rA; 43-74: rB; 75-106: imm; 107-110: slbj; 111: negative Examine;
        case(EXELine[2:0])
            3'b000:
            begin
                result = EXELine[42:11] + EXELine[74:43];
                if(result[31]^EXELine[74]==1'b1&&EXELine[74]^EXELine[42]==1'b0)vf=1'b1;
            end
            3'b001:
            begin
                result = EXELine[42:11] - EXELine[74:43];
                if(result[31]^EXELine[74]==1'b0&&EXELine[74]^EXELine[42]==1'b1)vf=1'b1;
            end
            3'b010:
            begin
                result = EXELine[42:11] & EXELine[74:43];
            end
            3'b011:
            begin
                result = EXELine[42:11] | EXELine[74:43];
            end
            3'b100:
            begin
                result = EXELine[42:11] ^ EXELine[74:43];
            end
            3'b101:
            begin
                result = ~(EXELine[42:11] | EXELine[74:43]);
            end
            3'b110:
            begin
                result = EXELine[74:43] << EXELine[42:11];
            end
            3'b111:
            begin
                result = (EXELine[5])?EXELine[74:43] >>> EXELine[42:11]:EXELine[74:43] >> EXELine[42:11];
            end
        endcase
        if(vf == 1'b1)
        begin
            vf = 1'b0;
            if(EXELine[5] == 1'b0)
            begin
                $display("terminated after the following exception: overflow detected in +/- operation");
                $finish;
            end
        end
        nf=(result[31]==1'b1)?1'b1:1'b0;
        zf=(result==32'h00000000)?1'b1:1'b0;
        if(EXELine[4] == 1'b1&&EXELine[110:109] == 2'b01) begin            
            if(EXELine[3] == zf)begin
                IF += (EXELine[106:75]<<2)-8;
                flush = 1'b1;
            end
            else result = 0;
        end
        else if(EXELine[110] == 1'b1) begin
            IF[29:0] = result[29:0];
            flush = 1'b1;
            if(EXELine[109] == 1'b1) result = pc;
        end
        if(EXELine[111] == 1'b1)result = 32'h00000000 + nf;
        if(MEMLine[0] == 1'b1)Address[MEMLine[38:7]]=gr[MEMLine[6:2]];//?
        if(MEMLine[1] == 1'b1)begin
            MEMLine[38:7]=Address[MEMLine[38:7]];
        end
        bj = MEMLine[40]^MEMLine[39];
        if(WBLine[0]==0&&WBLine[1]==0)begin
            gr[WBLine[6:2]]=WBLine[38:7];  
        end
        //reload
        if(stall == 1'b0)begin
            IFID = instrIF;
            IDEXE[2:0] = ALUop;
            IDEXE[5:3] = FlagExamine;
            IDEXE[10:6] = reg_Dest;
            IDEXE[42:11] = reg_A;
            IDEXE[74:43] = reg_B;
            IDEXE[106:75] = imm;
            IDEXE[107] = save;
            IDEXE[108] = load;
            IDEXE[110:109] = branchjump;
            IDEXE[111] = neg;
        end
        
        EXEMEM[1:0] = EXELine[108:107];
        EXEMEM[6:2] = EXELine[10:6];
        EXEMEM[38:7] = result;
        EXEMEM[40:39] = EXELine[110:109];
        MEMWB[0] = MEMLine[0];
        MEMWB[1] = bj;
        MEMWB[6:2] = MEMLine[6:2];
        MEMWB[38:7] = MEMLine[38:7];
        if(registers[19:15] === 5'bxxxxx)registers[19:15] = 5'b11111;
        registers = registers>>5;
        if(stall)begin
            registers[19:15] = registers[14:10];
            registers[14:10] = 5'b11111;
        end
        if(aAbsent)begin
        IDEXE[42:11] = MEMLine[38:7];
        aAbsent = 0;
        end
        if(bAbsent)begin
        IDEXE[74:43] = MEMLine[38:7];
        bAbsent = 0;
        end
        if(flush == 1'b1)begin
            stall = 0;
            cont = 0;
            IDEXE = 0;
            IFID = 0;
            registers[19:10] = 10'b1111111111;
            flush = 1'b0;
        end
        if(gr[0]!=0)gr[0]=0;
    end
endmodule
                