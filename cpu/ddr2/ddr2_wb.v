//2021.5.17修复了inner_address
//2021.5.17修复了ack设为0的时机在stb变为0之后
module ddr2_func_controller(
    input CLK100MHZ,
    input rst,
    input CLK200MHZ,
    input locked,
    
    output ddr2_ck_p,
    output ddr2_ck_n,
    output ddr2_cke,
    output ddr2_cs_n,
    output ddr2_ras_n,
    output ddr2_cas_n,
    output ddr2_we_n,
    output [1:0] ddr2_dm,
    output [2:0] ddr2_ba,
    output [12:0] ddr2_addr,
    inout [15:0] ddr2_dq,
    inout [1:0] ddr2_dqs_p,
    inout [1:0] ddr2_dqs_n,
    output ddr2_odt,
    
    output reg [31:0] s_odata,
	input [31:0] s_idata,
	input [31:0] s_addr,
	input [3:0] s_sel, 
	input s_we,
	input s_cyc,
	input s_stb, 
	output reg s_ack,
	output reg s_err,
	output reg s_rty,
    output sdram_init_done,
	
	output [7:0] st//for debug
);
    wire [31:0] inner_address;
    wire [3:0] span_address;
    
    wire [31:0] ddr_address;
    reg [127:0] ddr_din;
    reg ddr_we;
    wire ddr_wack;
    wire [127:0] ddr_dout;
    wire ddr_rack;
    wire ddr_rdy;
    wire ddr2_rst;
    // ddr2_signal_controller singal_controller(
	// 	.clk(CLK100MHZ),
	// 	.rst(ddr2_rst),
	// 	.ddr2_ck_p(ddr2_ck_p),
	// 	.ddr2_ck_n(ddr2_ck_n),
	// 	.ddr2_cke(ddr2_cke),
	// 	.ddr2_cs_n(ddr2_cs_n),
	// 	.ddr2_ras_n(ddr2_ras_n),
	// 	.ddr2_cas_n(ddr2_cas_n),
	// 	.ddr2_we_n(ddr2_we_n),
	// 	.ddr2_dm(ddr2_dm),
	// 	.ddr2_ba(ddr2_ba),
	// 	.ddr2_addr(ddr2_addr),
	// 	.ddr2_dq(ddr2_dq),
	// 	.ddr2_dqs_p(ddr2_dqs_p),
	// 	.ddr2_dqs_n(ddr2_dqs_n),
	// 	.ddr2_odt(ddr2_odt),
	// 	.clk_ref_i(CLK200MHZ),
	// 	.addr_in(ddr_address),
	// 	.data_in(ddr_din),
	// 	.stb_in(ddr_we),
	// 	.ack_out(ddr_wack),
	// 	.app_rd_data(ddr_dout),
	// 	.app_rd_data_valid(ddr_rack),
	// 	.app_rdy(ddr_rdy)
	// );
	reg [127:0] buffer;


    reg[31:0]  data_mem[0:1023];
    wire s_acc=s_cyc&s_stb;
    wire s_wr=s_acc&s_we;
    wire s_rd=s_acc&!s_we;
    assign sdram_init_done=1'b1;
    assign ddr2_rst=1'b1;
	
	parameter ddr_startLoop=16'd256;
	parameter readInsistLoop=16'd256;
	parameter writeInsistLoop=16'd256;
	reg [15:0] start_insist_count;
	reg [15:0] read_insist_count;
	reg [15:0] write_insist_count;	
	
	parameter INIT=8'd0;
	parameter IDLE=8'd1;
	parameter READ=8'd2;
	parameter WRITE=8'd3;
	parameter LOAD=8'd4;
	parameter SAVE=8'd5;
	reg [7:0] state;
	reg [7:0] return_state;
	
	always@(posedge CLK100MHZ or posedge rst)
	begin
        if(rst)
        begin
            s_ack<=1'b0;
            s_err<=1'b0;
            s_rty<=1'b0;
            ddr_we<=1'b0;  
            
            start_insist_count<=16'b0;
            read_insist_count<=16'b0;
            write_insist_count<=16'b0;
            
            state<=INIT;
            return_state<=INIT;
        end
        else
        begin
            case(state)
            INIT:begin
                s_ack<=1'b0;
                ddr_we<=1'b0;
                state<=IDLE;
            end
            IDLE:begin
                s_ack<=1'b0;
                ddr_we<=1'b0;
                start_insist_count<=16'b0;
                read_insist_count<=16'b0;
                write_insist_count<=16'b0;
                if(s_acc) begin
                        if(s_rd) begin
                            state<=READ;
                        end else if (s_wr) begin
                            state<=WRITE;
                        end
                        else begin
                            state<=IDLE;
                        end
                end else begin
                    state<=IDLE;
                end
            end
            READ:begin
                if(s_stb==1'b0) begin
                    s_ack<=1'b0;
                    state<=INIT;
                end else begin
                    s_ack<=1'b1;
                    state<=READ;
                    s_odata<=data_mem[{12'b0000000000,s_addr[21:2]}];
                end
            end
            WRITE:begin
                if(s_stb==1'b0) begin
                    s_ack<=1'b0;
                    state<=INIT;
                end else begin
                    ddr_we<=1'b0;
                    s_ack<=1'b1;
                    state<=WRITE;
                    if(s_sel[0]) begin
                        data_mem[{12'b0000000000,s_addr[21:2]}][7:0]<=s_idata[7:0];
                    end
                    if(s_sel[1]) begin
                        data_mem[{12'b0000000000,s_addr[21:2]}][15:8]<=s_idata[15:8];
                    end
                    if(s_sel[2]) begin
                        data_mem[{12'b0000000000,s_addr[21:2]}][23:16]<=s_idata[23:16];
                    end
                    if(s_sel[3]) begin
                        data_mem[{12'b0000000000,s_addr[21:2]}][31:24]<=s_idata[31:24];
                    end
                end
            end
            LOAD:begin
                if(ddr_rack)
                begin
                    if(read_insist_count<readInsistLoop)
                    begin
                        read_insist_count<=read_insist_count+16'b1;
                        buffer<=ddr_dout;
                        state<=LOAD;
                    end
                    else
                    begin
                        state<=return_state;
                    end
                end
            end
            SAVE:begin
                if(ddr_wack)
                begin
                    if(write_insist_count<writeInsistLoop)
                    begin
                        write_insist_count<=write_insist_count+16'b1;
                        state<=SAVE;
                    end
                    else
                    begin
                        state<=return_state;
                    end
                end
            end
            default:begin
            state<=8'hff;
            end       
            endcase
        end
	end
    
	assign inner_address={4'b0,s_addr[27:0]};
	assign ddr_address={4'b0,inner_address[31:4]};
	assign span_address=inner_address[3:0];
	
	assign st=state[7:0];
endmodule