`timescale 1ns/1ps


module CPU_test;

    // Inputs
	reg clock;
    reg start;

    CPU uut(
        .clock(clock),
        .start(start)
    );

    initial begin
        clock = 0;
        start = 1;

    $display("pc  :        instruction             :  gr1   :  gr2   :  gr3   :  gr4   :  gr5   :  gr6   :  gr7   :  gr30  :   ADD  ");
    $monitor("%h:%b:%h:%h:%h:%h:%h:%h:%h:%h:%h",
        uut.pc, uut.instr, uut.gr[1], uut.gr[2], uut.gr[3], uut.gr[4], uut.gr[5],uut.gr[6],uut.gr[7],uut.gr[30],uut.Address[2]
        );

    #period $finish;
    end

parameter period = 600;
always #5 clock = ~clock;
endmodule