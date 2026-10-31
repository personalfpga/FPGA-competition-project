`timescale 1ns/1ps
module xadc_reader_tb;
    reg clk=0, rst_n=0, eoc=0, drdy=0;
    reg [4:0] channel=3;
    reg [15:0] drp_data=0;
    wire den,pending,valid,seen;
    wire [6:0] address;
    wire [15:0] word;
    wire [11:0] code;
    wire [31:0] count;
    integer tests=0, expected_count=0;
    xadc_reader dut(clk,rst_n,eoc,channel,drdy,drp_data,den,address,pending,
                    word,code,valid,seen,count);
    always #10 clk=~clk;
    task tick; @(posedge clk); #1; endtask
    task check(input bit condition,input string message);
        if (!condition) $fatal(1,"XADC_READER_FAIL: %s",message);
    endtask
    task conversion(input reg [15:0] value,input integer delay_cycles);
        @(negedge clk); channel=3; eoc=1;
        tick(); check(den && pending,"request must follow VP/VN EOC");
        check(address==7'h03,"dedicated channel register address");
        @(negedge clk); eoc=0;
        tick(); check(!den && !valid,"DEN is exactly one cycle; wait for DRDY");
        repeat(delay_cycles) begin
            @(negedge clk); drp_data=~value;
            tick(); check(!valid && pending,"invalid data must not be consumed");
        end
        // Overlapping EOC must not issue a second DRP request.
        @(negedge clk); eoc=1;
        tick(); check(!den,"no overlapping request while pending");
        @(negedge clk); eoc=0; drp_data=value; drdy=1;
        tick(); expected_count=expected_count+1;
        check(valid && word==value && code==value[15:4],"capture all 16 bits and extract upper 12");
        check(count==expected_count && seen && !pending,"fresh sample counter and flags");
        tick(); check(!valid && count==expected_count,"held DRDY must not duplicate sample");
        @(negedge clk); drdy=0;
        tick(); tests=tests+1;
    endtask
    initial begin
        repeat(3) tick(); check(count==0 && !valid && !seen,"reset state");
        @(negedge clk); rst_n=1; drdy=1; drp_data=16'hFACE;
        tick(); check(!valid && count==0,"unsolicited DRDY ignored");
        @(negedge clk); drdy=0; channel=0; eoc=1;
        tick(); check(!den && !pending,"non VP/VN channel rejected");
        @(negedge clk); eoc=0;
        conversion(16'h0000,0); conversion(16'h000F,1);
        conversion(16'hFFFF,7); conversion(16'hBAE5,3);
        conversion(16'h8000,2); conversion(16'h0010,5);
        for(integer k=0;k<64;k=k+1) conversion($random,(k%9));
        // Reset aborts an outstanding read; late response cannot leak through.
        @(negedge clk); channel=3; eoc=1;
        tick(); check(pending,"pending before reset");
        @(negedge clk); rst_n=0; eoc=0;
        tick(); check(!pending && count==0 && !seen,"reset aborts read");
        @(negedge clk); rst_n=1; drdy=1;
        tick(); check(!valid && count==0,"late response after reset ignored");
        @(negedge clk); drdy=0;
        expected_count=0;
        conversion(16'hBADC,4);
        $display("XADC_READER_PASS: transactions=%0d channel_filter=PASS delayed_DRDY=PASS no_overlap=PASS reset_abort=PASS upper12=PASS",tests);
        $finish;
    end
    initial begin #1000000; $fatal(1,"XADC_READER_FAIL timeout"); end
endmodule
