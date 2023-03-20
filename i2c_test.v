`timescale 1ns/1ps
module i2c_test();
//assign sda = (msda_out)? 1'bz:msda_out;
//assign msda_in  = (msda_out)?sda:1'b1;
reg       wclk         ;
reg       rst_wclk_n   ;
reg       i2c_en       ;
wire      txfifo_empty ;
wire [7:0]tx_data      ;
wire      sda_out      ;
wire      scl_out      ;
wire      txfifo_rd_en ;
wire [7:0]rx_data      ;  
reg       wr_en ;
reg [7:0]     din;
reg       swr_en;
reg [7:0]   sdin;
wire [7:0] stx_fifo_dat;
wire [7:0] s_rx_dat;
//clock
initial
begin
    wclk = 1'b0;
    forever #50 wclk = ~wclk;
end
//reset
initial
begin
    rst_wclk_n = 1'b0;
    #5000;
    rst_wclk_n = 1'b1;
end
//master control
initial
begin
    i2c_en = 1'b0 ;
     #6000;
            repeat(6) 
            begin
              @(posedge wclk)begin
                    din    <= $random%255;
                    wr_en  <= 1'b1;
                end      
            end       
             repeat(6) 
            begin
              @(posedge wclk)begin
                    sdin    <= $random%255;
                    swr_en  <= 1'b1;
                end      
            end           
            @(posedge wclk)
            begin
                i2c_en <= 1'b1;
                wr_en   <= 1'b0;
            end
            #20000;
            force i2c_master.scl_in = 1'b0;
            #500;
            release i2c_master.scl_in;
end

i2c_master i2c_master(
      .wclk        (wclk         ),
      .rst_wclk_n  (rst_wclk_n   ),
      .i2c_en      (i2c_en       ),
      .txfifo_empty(txfifo_empty ),
      .hs_mode     (1'b1         ),
      .data_wr_rd  (1'b1         ),
      .master_code (8'b1001_0001 ),
      .slave_addr  (8'b1010_1010 ),
      .tx_data     (tx_data      ),
      .i2c_comb_wr (1'b1         ),
      .rx_byte_num (8'd4         ),
      .div_num     (8'd100        ),
      .hs_div      (8'd10        ),
      .sda_in      (ssda_out     ),
      .scl_in      (sscl_out     ),
      .sda_out     (sda_out      ),
      .scl_out     (scl_out      ),
      .txfifo_rd_en(txfifo_rd_en ),
      .rx_data     (rx_data      ),
      .rx_wr_en_out(rx_wr_en_out )
);
i2c_slave i2c_slave(
    .sscl_in           (scl_out           ),  
    .ssda_in           (sda_out           ),  
    .wclk              (wclk              ),  
    .rst_wclk_n        (rst_wclk_n        ),  
    .slave_en          (1'b1              ),  
    .stxfifo_empty     (stxfifo_empty     ),     
   // .srxfifo_full      (srxfifo_full      ),     
    .stx_fifo_dat      (stx_fifo_dat      ),     
    .rxfifo_almost_full(rxfifo_almost_full),          
    .master_code       (8'b1001_0001      ),   
    .slave_addr        (8'b1010_1011      ),   
    .sscl_out          (sscl_out          ),   
    .ssda_out          (ssda_out          ),   
    .rx_sdat            (s_rx_dat          ),   
    .srxfifo_en        (srxfifo_en        ),
    .stx_fifo_rd_en    (stx_fifo_rd_en   )
);

i2c_txfifo i2c_txfifo (
  .clk(wclk),            // input wire clk
  .srst(~rst_wclk_n),    // input wire srst
  .din(din),             // input wire [7 : 0] din
  .wr_en(wr_en),         // input wire wr_en
  .rd_en(txfifo_rd_en),  // input wire rd_en
  .dout(tx_data),        // output wire [7 : 0] dout
  .full(),               // output wire full
  .empty(txfifo_empty)   // output wire empty
);

slave_rxfifo  slave_rxfifo(
  .clk(wclk),                  // input wire clk
  .srst(~rst_wclk_n),                // input wire srst
  .din(s_rx_dat ),                  // input wire [7 : 0] din
  .wr_en(srxfifo_en),              // input wire wr_en
  .rd_en(rd_en),              // input wire rd_en
  .dout(dout),                // output wire [7 : 0] dout
  .full(srxfifo_full),                // output wire full
  .almost_full(rxfifo_almost_full),  // output wire almost_full
  .empty(empty)              // output wire empty
);

slave_txfifo your_instance_name (
  .clk(wclk),      // input wire clk
  .srst(~rst_wclk_n),    // input wire srst
  .din(sdin),      // input wire [7 : 0] din
  .wr_en(swr_en),  // input wire wr_en
  .rd_en(stx_fifo_rd_en),  // input wire rd_en
  .dout(stx_fifo_dat),    // output wire [7 : 0] dout
  .full(full),    // output wire full
  .empty(stxfifo_empty)  // output wire empty
);
endmodule
