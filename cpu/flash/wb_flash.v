//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2014 leishangwen@163.com                       ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
// Module:  flash_top
// File:    wb_flash.v
// Author:  Lei Silei
// E-mail:  leishangwen@163.com
// Description: Nor Flash Controller for DE2    
// Revision: 1.0
//////////////////////////////////////////////////////////////////////

module flash_top(
    // Parallel FLASH Interface
    wb_clk_i, wb_rst_i, wb_adr_i, wb_dat_o, wb_dat_i, wb_sel_i, wb_we_i,
    wb_stb_i, wb_cyc_i, wb_ack_o,
    // Ports for SPI Flash
    flash_cs_n,flash_sdi,flash_sdo,flash_wp_n,flash_hld_n
);
    output wire      flash_cs_n;
    input  wire      flash_sdi;
    output wire      flash_sdo;
    output wire      flash_wp_n;
    output wire      flash_hld_n;

    //
    // Default address and data bus width
    //
    parameter aw = 19;   // number of address-bits
    parameter dw = 32;   // number of data-bits
    parameter ws = 4'h3; // number of wait-states

    //
    // FLASH interface
    //
    input   wb_clk_i;
    input   wb_rst_i;
    (* dont_touch = "true" *)input   [31:0] wb_adr_i;
    (* dont_touch = "true" *)output reg [dw-1:0] wb_dat_o;
    input   [dw-1:0] wb_dat_i;
    input   [3:0] wb_sel_i;
    input   wb_we_i;
    (* dont_touch = "true" *)input   wb_stb_i;
    (* dont_touch = "true" *)input   wb_cyc_i;
    (* dont_touch = "true" *)output reg wb_ack_o;
    // output reg [31:0] flash_adr_o;
    // input   [7:0] flash_dat_i;
    // output  flash_rst;
    // output  flash_oe;
    // output  flash_ce;
    // output  flash_we;
    (* dont_touch = "true" *)reg [3:0] waitstate;
    (* dont_touch = "true" *)reg [3:0] is_end;
    wire    [1:0] adr_low;

    // Wishbone read/write accesses
    wire wb_acc = wb_cyc_i & wb_stb_i;    // WISHBONE access
    wire wb_wr  = wb_acc & wb_we_i;       // WISHBONE write access
    wire wb_rd  = wb_acc & !wb_we_i;      // WISHBONE read access

    (* dont_touch = "true" *)wire flash_finish;
    (* dont_touch = "true" *)reg flash_rst;
    (* dont_touch = "true" *)reg [31:0] flash_addr_i;
    (* dont_touch = "true" *)wire [31:0] flash_data_o;
    flash flash0(
        .clk(wb_clk_i),
        .rst(flash_rst),
        .rd_addr_i(flash_addr_i),
        .rd_data_o(flash_data_o),
        .finish(flash_finish),
        .led(),
        // Ports for SPI Flash
        .cs_n(flash_cs_n),
        .sdi(flash_sdi),
        .sdo(flash_sdo),
        .wp_n(flash_wp_n),
        .hld_n(flash_hld_n)
    );

    always @(posedge wb_clk_i) begin
        if( wb_rst_i == 1'b1 ) begin
            waitstate <= 4'h0;
            wb_ack_o <= 1'b0;
            flash_rst<=1'b1;
            is_end<=4'b0;
        end else if(wb_acc == 1'b0) begin
            waitstate <= 4'h0;
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'h00000000;
            flash_rst<=1'b1;
            is_end<=4'b0;
        end else if(waitstate == 4'h0) begin
            wb_ack_o <= 1'b0;
            if(wb_acc) begin
              waitstate <= waitstate + 4'h1;
            end
			flash_addr_i <= {10'b0000000000,wb_adr_i[21:2],2'b0};
            flash_rst<=1'b0;
            is_end<=4'b0;
        end else begin
            if(flash_finish) begin
                // wb_dat_o<=inst_mem[{12'b0,wb_adr_i[21:2]}];
                wb_dat_o<=flash_data_o;
                flash_rst<=1'b1;
                wb_ack_o <= 1'b1;
                is_end<=4'b1;
            end
            else begin
                waitstate <= waitstate + 4'h1;
            end

            if(is_end==4'b1&&wb_stb_i==1'b0) begin
                // is_end<=4'b0;
                // waitstate <= 4'h0;
                wb_ack_o <= 1'b0;
            end
            // else if(is_end!=4'b0) begin
            //     is_end<=is_end+1;
            // end
         end
      end

    // assign flash_ce = !wb_acc;
    // assign flash_we = 1'b1;
    // assign flash_oe = !wb_rd;


    // assign flash_rst = !wb_rst_i;

endmodule
