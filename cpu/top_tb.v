`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/06/01 19:43:51
// Design Name: 
// Module Name: top_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top_tb();
    reg clk;
    reg rst;
    reg flash_sdi;

    openmips_min_sopc top_0(
        .clk(clk),
        .rst(rst),
        .flash_sdi(flash_sdi)
        );
    initial begin
        clk<=0;
        rst<=1;
        flash_sdi<=0;
        #10;
        rst<=0;
    end
    always #5 clk<=~clk;
    always #50 flash_sdi<=~flash_sdi;
endmodule
