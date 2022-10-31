module flash(
    input       clk,
    input       rst,
	input [31:0] rd_addr_i,
	output reg  [31:0] rd_data_o,
	output 	 	finish,
	output reg  led, // used to debug
    
    // Ports for SPI Flash
    output reg  cs_n,
    input       sdi,
    output reg  sdo,
    output      wp_n,
    output      hld_n
);

assign wp_n  = 1'b1;
assign hld_n = 1'b1;

parameter IDLE       = 4'b0000;
parameter START      = 4'b0001;
parameter INST_OUT   = 4'b0010;
parameter ADDR1_OUT  = 4'b0011;
parameter ADDR2_OUT  = 4'b0100;
parameter ADDR3_OUT  = 4'b0101;
parameter WRITE_DATA = 4'b0110;
parameter READ_DATA  = 4'b0111;
parameter ENDING     = 4'b1000;

reg         sck;
reg  [3:0]  state;
reg  [3:0]  next_state;
(* dont_touch = "true" *)reg  [7:0]   instruction;
(* dont_touch = "true" *)reg  [7:0]   datain_shift;
(* dont_touch = "true" *)reg  [7:0]   datain;
reg  [7:0]  dataout;
reg         sck_en;
reg  [2:0]  sck_en_d;
reg  [2:0]  cs_n_d;

(* dont_touch = "true" *)reg  [7:0]  inst_count;
reg         temp;
reg  [3:0]  sdo_count;
reg  [15:0] page_count;
reg  [7:0]  wait_count;
reg  [23:0] addr;
reg         wrh_rdl;  // High indicates write, low indicates read
reg         addr_req;  // Address writing requested
reg  [15:0] wr_cnt;  // Number of bytes to be written
reg  [15:0] rd_cnt;  // Number of bytes to be read
assign finish=(state==ENDING);

// State machine
always @(posedge clk or posedge rst) begin
	if(rst) begin
		state <= IDLE;
	end
	else begin
		state <= next_state;
	end
end

always @(posedge clk or posedge rst) begin
	if(rst) begin
		next_state  <= IDLE;
		sck_en      <= 1'b0;
		cs_n_d[0]   <= 1'b1;
		dataout     <= 8'd0;
		sdo_count   <= 4'd0;
		sdo         <= 1'b0;
		datain      <= 8'd0;
        inst_count  <= 8'd0;
        temp        <= 1'b0;
        page_count  <= 16'd0;
        wait_count  <= 8'd0;
	end
	else begin
		case(state)
		IDLE: 
		begin	// IDLE state
			next_state <= START;
            wait_count <= 8'd0;
		end
		START:
		begin	// enable SCK and CS
			sck_en <= 1'b1;
			cs_n_d[0]  <= 1'b0;
			next_state <= INST_OUT;
		end
		INST_OUT:
		begin	// send out instruction
			if(sdo_count == 4'd1) begin
				{sdo, dataout[6:0]} <= instruction;
			end
			else if(sdo_count[0]) begin
				{sdo, dataout[6:0]} <= {dataout[6:0],1'b0};
			end
			
			if(sdo_count != 4'd15) begin
				sdo_count <= sdo_count + 4'd1;
			end
			else begin
				sdo_count  <= 4'd0;
				next_state <= (addr_req) ?  ADDR1_OUT : ((wrh_rdl) ? ((wr_cnt==16'd0) ? ENDING : WRITE_DATA) : ((rd_cnt==16'd0) ? ENDING : READ_DATA));
			end
		end
		ADDR1_OUT:
		begin	// send out address[23:16]
			if(sdo_count == 4'd1) begin
				{sdo, dataout[6:0]} <= addr[23:16];
			end
			else if(sdo_count[0]) begin
				{sdo, dataout[6:0]} <= {dataout[6:0],1'b0};
			end
			
			if(sdo_count != 4'd15) begin
				sdo_count <= sdo_count + 4'd1;
			end
			else begin
				sdo_count  <= 4'd0;
				next_state <= ADDR2_OUT;
			end
		end
		ADDR2_OUT:
		begin	// send out address[15:8]
			if(sdo_count == 4'd1) begin
				{sdo, dataout[6:0]} <= addr[15:8];
			end
			else if(sdo_count[0]) begin
				{sdo, dataout[6:0]} <= {dataout[6:0],1'b0};
			end
			
			if(sdo_count != 4'd15) begin
				sdo_count <= sdo_count + 4'd1;
			end
			else begin
				sdo_count  <= 4'd0;
				next_state <= ADDR3_OUT;
			end
		end
		ADDR3_OUT:
		begin	// send out address[7:0]
			if(sdo_count == 4'd1) begin
				{sdo, dataout[6:0]} <= addr[7:0];
			end
			else if(sdo_count[0]) begin
				{sdo, dataout[6:0]} <= {dataout[6:0],1'b0};
			end
			
			if(sdo_count != 4'd15) begin
				sdo_count <= sdo_count + 4'd1;
			end
			else begin
				sdo_count  <= 4'd0;
				next_state <= (wrh_rdl) ? ((wr_cnt==16'd0) ? ENDING : WRITE_DATA) : ((rd_cnt==16'd0) ? ENDING : READ_DATA);
                page_count <= 16'd0;
			end
		end
		WRITE_DATA:
		begin	// send testing data out to flash
			if(sdo_count == 4'd1) begin
				{sdo, dataout[6:0]} <= 8'h5A;
			end
			else if(sdo_count[0]) begin
				{sdo, dataout[6:0]} <= {dataout[6:0],1'b0};
			end
			
			if(sdo_count != 4'd15) begin
				sdo_count <= sdo_count + 4'd1;
			end
			else begin
                page_count <= page_count + 16'd1;
				sdo_count  <= 4'd0;
				next_state <= (page_count < (wr_cnt-16'd1)) ? WRITE_DATA : ENDING;
			end
		end
		READ_DATA:
		begin	// get the first data from flash
            if(~sdo_count[0]) begin
                datain_shift <= {datain_shift[6:0],sdi};
            end
            
            if(sdo_count == 4'd1) begin
                datain <= {datain_shift, sdi};
				case (page_count)
					16'h1:	rd_data_o[31:24] <= {datain_shift, sdi};
					16'h2:	rd_data_o[23:16] <= {datain_shift, sdi};
					16'h3:	rd_data_o[15:8] <= {datain_shift, sdi};
					16'h4:	rd_data_o[7:0] <= {datain_shift, sdi};

					default: begin end
				endcase
            end
            
			if(sdo_count != 4'd15) begin
				sdo_count <= sdo_count + 4'd1;
			end
			else begin
                page_count <= page_count + 16'd1;
				sdo_count  <= 4'd0;
				next_state <= (page_count < (rd_cnt)) ? READ_DATA : ENDING;
			end
		end
		ENDING:
		begin	//disable SCK and CS, wait for 32 clock cycles
            if(wait_count != 8'd64) begin
                wait_count <= wait_count + 8'd1;
                next_state <= ENDING;
            end
            else begin
                if(instruction == 8'h05 && datain[0]) begin // If in RDSR1, wait until the process ended
                    {inst_count,temp} <= {inst_count,temp};
                end
                else begin
                    {inst_count,temp} <= {inst_count,temp} + 9'd1;
                end
                next_state <= IDLE;
            end
			sck_en <= 1'b0;
			cs_n_d[0] <= 1'b1;
            sdo_count <= 4'd0;
            page_count <= 16'd0;
		end
		endcase
	end
end

// SCK generator, 50MHz output
always @(posedge clk) begin
    sck_en_d <= {sck_en_d[1:0],sck_en};
end

always @(posedge clk or posedge rst) begin
	if(rst) begin
		sck <= 1'b0;
	end
	else if(sck_en_d[2] & sck_en) begin
		sck <= ~sck;
	end
    else begin
        sck <= 1'b0;
    end
end

always @(posedge clk or posedge rst) begin
    if(rst) begin
        {cs_n,cs_n_d[2:1]} <= 3'h7;
    end
    else begin
        {cs_n,cs_n_d[2:1]} <= cs_n_d;
    end
end

STARTUPE2
#(
.PROG_USR("FALSE"),
.SIM_CCLK_FREQ(10.0)
)
STARTUPE2_inst
(
  .CFGCLK     (),
  .CFGMCLK    (),
  .EOS        (),
  .PREQ       (),
  .CLK        (1'b0),
  .GSR        (1'b0),
  .GTS        (1'b0),
  .KEYCLEARB  (1'b0),
  .PACK       (1'b0),
  .USRCCLKO   (sck),      // First three cycles after config ignored, see AR# 52626
  .USRCCLKTS  (1'b0),     // 0 to enable CCLK output
  .USRDONEO   (1'b1),     // Shouldn't matter if tristate is high, but generates a warning if tied low.
  .USRDONETS  (1'b1)      // 1 to tristate DONE output
);

// ROM for instructions
always @(posedge clk) begin
	instruction <= 8'h03; wrh_rdl <= 1'b0; addr_req <= 1'b1; 
    addr <= rd_addr_i[23:0]; wr_cnt <= 16'd0; rd_cnt <= 16'd4;   // READ
	// case(inst_count)
	// 8'd0 : begin 
    // instruction <= 8'h90; wrh_rdl <= 1'b0; addr_req <= 1'b1; 
    // addr <= 24'h000000; wr_cnt <= 16'd0; rd_cnt <= 16'd2; end  // READ_ID
    // 8'd1 : begin 
    // instruction <= 8'h9F; wrh_rdl <= 1'b0; addr_req <= 1'b0; 
    // addr <= 24'h000000; wr_cnt <= 16'd0; rd_cnt <= 16'd81; end  // RDID
	// 8'd2 : begin 
    // instruction <= 8'h05; wrh_rdl <= 1'b0; addr_req <= 1'b0; 
    // addr <= 24'h000000; wr_cnt <= 16'd0; rd_cnt <= 16'd2; end  // RDSR1
    // 8'd3 : begin 
    // instruction <= 8'h35; wrh_rdl <= 1'b0; addr_req <= 1'b0; 
    // addr <= 24'h000000; wr_cnt <= 16'd0; rd_cnt <= 16'd2; end  // RDCR
	// 8'd4 : begin 
    // instruction <= 8'h03; wrh_rdl <= 1'b0; addr_req <= 1'b1; 
    // addr <= 24'h800000; wr_cnt <= 16'd0; rd_cnt <= 16'd32; end  // READ
    // 8'd5 : begin 
    // instruction <= 8'h06; wrh_rdl <= 1'b0; addr_req <= 1'b0; 
    // addr <= 24'h000000; wr_cnt <= 16'd0; rd_cnt <= 16'd0; end  // WREN
    // 8'd6 : begin 
    // instruction <= 8'h05; wrh_rdl <= 1'b0; addr_req <= 1'b0; 
    // addr <= 24'h000000; wr_cnt <= 16'd0; rd_cnt <= 16'd2; end  // RDSR1
	// 8'd7 : begin 
    // instruction <= 8'hd8; wrh_rdl <= 1'b0; addr_req <= 1'b1; 
    // addr <= 24'h800000; wr_cnt <= 16'd0; rd_cnt <= 16'd64; end  // SE
    // 8'd8 : begin 
    // instruction <= 8'h05; wrh_rdl <= 1'b0; addr_req <= 1'b0; 
    // addr <= 24'h000000; wr_cnt <= 16'd0; rd_cnt <= 16'd2; end  // RDSR1
    // 8'd9 : begin 
    // instruction <= 8'h03; wrh_rdl <= 1'b0; addr_req <= 1'b1; 
    // addr <= 24'h800000; wr_cnt <= 16'd0; rd_cnt <= 16'd32; end  // READ
    // 8'd10: begin 
    // instruction <= 8'h06; wrh_rdl <= 1'b0; addr_req <= 1'b0; 
    // addr <= 24'h000000; wr_cnt <= 16'd0; rd_cnt <= 16'd0; end  // WREN
	// 8'd11: begin 
    // instruction <= 8'h02; wrh_rdl <= 1'b1; addr_req <= 1'b1; 
    // addr <= 24'h800000; wr_cnt <= 16'd32; rd_cnt <= 16'd0; end  // PP
    // 8'd12: begin 
    // instruction <= 8'h05; wrh_rdl <= 1'b0; addr_req <= 1'b0; 
    // addr <= 24'h000000; wr_cnt <= 16'd0; rd_cnt <= 16'd2; end  // RDSR1
	// 8'd13: begin 
    // instruction <= 8'h03; wrh_rdl <= 1'b0; addr_req <= 1'b1; 
    // addr <= 24'h800000; wr_cnt <= 16'd0; rd_cnt <= 16'd32; end  // READ
	// default : begin 
    // instruction <= 8'h05; wrh_rdl <= 1'b0; addr_req <= 1'b0; 
    // addr <= 24'h000000; wr_cnt <= 16'd0; rd_cnt <= 16'd2; end  // RDSR1
	// endcase
end

// Debug LED port
always @(posedge clk or posedge rst) begin
	if(rst) begin
		led <= 1'b0;
	end
	else if(instruction == 8'h03) begin
		led <= (datain == 8'h5a) ? 1'b1 : 1'b0;
	end
end

endmodule
