module i2c_master(
      wclk         ,
      rst_wclk_n   ,
      i2c_en       ,
      txfifo_empty ,
      hs_mode      ,
      data_wr_rd   ,
      master_code  ,
      slave_addr   ,
      tx_data      ,
      i2c_comb_wr  ,
      rx_byte_num  ,
      div_num      ,
      hs_div       ,
//i2c input
      sda_in       ,
      scl_in       ,
//i2c output
      sda_out      ,
      scl_out      ,
      txfifo_rd_en ,
      rx_data      ,
      rx_wr_en_out
);

input       wclk         ;
input       rst_wclk_n   ;
input       i2c_en       ;
input       txfifo_empty ;
input       hs_mode      ;
input       data_wr_rd   ;
input [7:0] master_code  ;
input [7:0] slave_addr   ;
input [7:0] tx_data      ;
input       i2c_comb_wr  ;
input [7:0] rx_byte_num  ;
input [7:0] div_num      ;
input [7:0] hs_div       ;
input       sda_in       ;
input       scl_in       ;

output      sda_out      ;
output      scl_out      ;
output      txfifo_rd_en ;
output [7:0]rx_data      ;
output      rx_wr_en_out ;

wire [7:0]  master_code  ;
wire [7:0]  slave_addr   ;
reg         sda_out      ;
reg         scl_out      ;
reg [7:0]   rx_data      ;
//reg         txfifo_rd_en ;

//status define
localparam  s_idle          = 8'b0000_0000;
localparam  s_start         = 8'b0000_0001;
localparam  s_send_mst_code = 8'b0000_0011;
localparam  s_send_addr     = 8'b0000_0010;
localparam  s_addr_ack      = 8'b0000_0110;
localparam  s_tx_data       = 8'b0000_0111;
localparam  s_tx_ack        = 8'b0000_1111;
localparam  s_stop          = 8'b0000_1110;
localparam  s_rx_data       = 8'b0000_1100;
localparam  s_send_ack      = 8'b0000_1000;
localparam  s_restart       = 8'b0001_1000;

reg [7:0]   current_state ;
reg [7:0]   next_state    ;
reg         next_sda_out  ;
reg         next_scl_out  ;
reg [2:0]   clk_cnt       ;
reg [2:0]   next_clk_cnt  ;
//reg [2:0]   byte_cnt      ;
//reg [2:0]   next_byte_cnt ;
reg [7:0]   shift_dat     ;
reg [7:0]   next_shift_dat;
reg         txfifo_rd     ;
reg         txfifo_rd_d1  ;
reg         txfifo_rd_d2  ;

reg [7:0]   next_rx_data  ;
reg [7:0]   rx_byte       ;
reg [7:0]   next_rx_byte  ;
reg         i2c_wr_rd     ;
reg [3:0]   next_bit_cnt  ;
reg [3:0]   bit_cnt       ;
//reg [2:0]   rx_byte       ;
//reg [2:0]   next_rx_byte  ;
reg [7:0]   rx_wr_data    ;
reg         rx_wr_en      ;
reg [2:0]   rx_byte_cnt   ;
reg [2:0]   next_rx_byte_cnt;
reg [7:0]   frequence_div ;
reg [7:0]   time_out_cnt  ;
reg         rx_wr_en_d1   ;

wire        no_ack        ;
wire        div_end       ;
assign txfifo_rd_en = (current_state == s_idle || current_state == s_idle)? 1'b0:txfifo_rd_d1 ^ txfifo_rd_d2;
assign rx_wr_en_out = (current_state == s_idle || current_state == s_idle)? 1'b0:rx_wr_en ^ rx_wr_en_d1;
always @(posedge wclk or negedge rst_wclk_n)
begin
    if(!rst_wclk_n)
    begin
        sda_out      <= 1'b1;
        scl_out      <= 1'b1;
//        clk_cnt      <= 3'd0;
//        byte_cnt     <= 3'd0;
//        shift_dat    <= 8'd0;
        txfifo_rd_d1 <= 1'b0;
        txfifo_rd_d2 <= 1'b0;
        rx_data      <= 8'd0;
//        next_rx_data <= 8'd0;
        rx_byte      <= 8'd0;
        rx_byte_cnt  <= 3'd0;
//        bit_cnt      <= 8'd0;
        rx_wr_en_d1    <= 1'b0;
    end
    else 
    begin
        sda_out      <= next_sda_out    ;
        scl_out      <= next_scl_out    ;
 //       clk_cnt      <= next_clk_cnt    ;
 //       byte_cnt     <= next_byte_cnt   ;
 //       shift_dat    <= next_shift_dat  ;
        txfifo_rd_d1 <= txfifo_rd       ;
        txfifo_rd_d2 <= txfifo_rd_d1    ;
        rx_data      <= next_rx_data    ;
        rx_byte      <= next_rx_byte    ;
        rx_byte_cnt  <= next_rx_byte_cnt;
//        bit_cnt      <= next_bit_cnt    ;
        rx_wr_en_d1  <= rx_wr_en;
    end
end
always @(posedge wclk or negedge rst_wclk_n)
begin 
    if(!rst_wclk_n)
    begin
        shift_dat <= 8'd0;     
    end
    else
        shift_dat <= next_shift_dat;
end

//clk divide
always @(posedge wclk or negedge rst_wclk_n)
begin
    if(!rst_wclk_n)
        frequence_div <= 8'd0;
    else if(div_end || i2c_en == 1'b0)
        frequence_div <= 8'd0;
    else if(scl_in == 1'b1)
        frequence_div <= frequence_div + 1'b1;    
    else
        frequence_div <= frequence_div;
end
assign div_end = hs_mode ?  ((current_state == s_start || current_state == s_send_mst_code )? frequence_div == div_num
                            : frequence_div == hs_div)
                            : frequence_div == div_num;
always @(posedge wclk or negedge rst_wclk_n)
begin
    if(!rst_wclk_n)
    begin
        clk_cnt <= 3'd1;
        bit_cnt <= 8'd0;
    end
    else if(scl_in == 1'b1 && div_end)
    begin
        clk_cnt <= next_clk_cnt;
        bit_cnt <= next_bit_cnt;
    end
    else
    begin
        clk_cnt <= clk_cnt;
        bit_cnt <= bit_cnt;
    end
end

always @(posedge wclk or negedge rst_wclk_n)
begin
    if(!rst_wclk_n)
        current_state <= s_idle;
    else if(time_out_cnt == 8'hFF)
        current_state <= s_stop;
    else
        current_state <= next_state;
end

always @(posedge wclk or negedge rst_wclk_n)
begin
    if(!rst_wclk_n)
        time_out_cnt = 8'd0;
    else if(time_out_cnt == 8'hFF)
        time_out_cnt = 8'd0;
    else if(scl_in == 1'b0)
        time_out_cnt = time_out_cnt + 1'b1;
end

always @(*)
begin
    case(current_state)
        s_idle:begin
            if(i2c_en && (!txfifo_empty && data_wr_rd) || !data_wr_rd)
            begin
                next_state   = s_start;
                next_clk_cnt = 3'd1 ;
                i2c_wr_rd    = data_wr_rd;
            end
            else 
            begin
                next_state       = s_idle;
                next_sda_out     = 1'b1  ;
                next_scl_out     = 1'b1  ;
                next_rx_byte     = 8'd0  ;
                next_bit_cnt     = 4'd0  ;
                next_shift_dat   = 8'd0  ;
                txfifo_rd        = 1'b0  ;
                rx_wr_en         = 1'b0  ;
                next_rx_data     = 8'd0  ;
                next_rx_byte_cnt = 3'd0  ;
                rx_wr_data       = 8'd0;
            end
        end
        s_start:begin
            if(div_end)
            begin
                case(clk_cnt)
                    3'd1:begin
                        next_sda_out = 1'b0;
                        next_scl_out = 1'b1;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd0:begin
                        next_sda_out = 1'b0;
                        next_scl_out = 1'b0;
                        next_clk_cnt = 3'd2;
                        if(hs_mode)
                        begin
                            next_state      = s_send_mst_code;
                            next_shift_dat  = master_code;
                        end
                        else
                        begin
                            next_state     = s_send_addr;
                            next_shift_dat = slave_addr;
                        end
                    end
                    default :next_state = s_stop;
                endcase
            end
        end
        s_send_mst_code:begin
            if(div_end)
            begin
                case(clk_cnt)
                    3'd2:begin
                        next_sda_out = shift_dat[7];
                        next_scl_out = 1'b0;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd1:begin
                        next_scl_out = 1'b1;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd0:begin
                        next_scl_out = 1'b0;
                        next_clk_cnt = 3'd2;
                       if(bit_cnt == 4'd8)
                        begin
                            next_state     = s_send_addr;
                            next_shift_dat = slave_addr;
                            next_bit_cnt   = 3'd0;
                        end
                        else
                        begin
                            next_state     = s_send_mst_code;
                            next_shift_dat = {shift_dat[6:0],1'b1};
                            next_bit_cnt   = bit_cnt + 1'b1;
                        end
                    end
                default :next_state = s_stop;
                endcase
            end
        end
        s_send_addr:begin
            if(div_end)
            begin
                case(clk_cnt)
                    3'd2:begin
                        next_sda_out = shift_dat[7];
                        next_scl_out = 1'b0;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd1:begin
                        next_scl_out = 1'b1;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd0:begin
                        next_scl_out = 1'b0;
                        next_clk_cnt = 3'd2;
                       if(bit_cnt == 4'd7)
                        begin
                            next_state     = s_addr_ack;
                            next_bit_cnt   = 4'd0;
                            if( i2c_wr_rd == 1'b1)
                                txfifo_rd = ~txfifo_rd;
                        end
                        else 
                        begin
                            next_state     = s_send_addr;
                            next_shift_dat = {shift_dat[6:0],1'b1};
                            next_bit_cnt   = bit_cnt + 1'b1;
                        end
                    end
                default :next_state = s_stop;
                endcase
            end
        end
        s_addr_ack:begin
            if(div_end)
            begin
                case(clk_cnt)
                    3'd2:begin
                        next_sda_out = 1'b1;
                        next_scl_out = 1'b0;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd1:begin
                        next_scl_out = 1'b1;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd0:begin
                        next_scl_out = 1'b0;
                        next_clk_cnt = 3'd2;
                        if(!no_ack && i2c_wr_rd == 1'b1)
                        begin
                            next_shift_dat = tx_data;
                            next_state = s_tx_data;
                        end
                        else if(!no_ack && i2c_wr_rd == 1'b0)
                            next_state = s_rx_data;
                        else
                            next_state = s_stop;
                    end
                endcase
            end
        end
        s_tx_data:begin
            if(div_end)
            begin
                case(clk_cnt)
                    3'd2:begin
                        next_sda_out = shift_dat[7];
                        next_scl_out = 1'b0;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd1:begin
                        next_scl_out = 1'b1;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd0:begin
                        next_scl_out = 1'b0;
                        next_clk_cnt = 3'd2;
                       if(bit_cnt == 4'd7)
                        begin
                            next_state     = s_tx_ack;
                            next_bit_cnt   = 4'd0;
                            if(txfifo_empty == 1'b0)
                                txfifo_rd = ~txfifo_rd;
                        end
                        else
                        begin
                            next_shift_dat = {shift_dat[6:0],1'b1};
                            next_bit_cnt   = bit_cnt + 1'b1;
                        end
                    end
                default :next_state = s_stop;
                endcase
            end
        end
        s_tx_ack:begin
            if(div_end)
            begin
                case(clk_cnt)
                    3'd2:begin
                        next_sda_out = 1'b1;
                        next_scl_out = 1'b0;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd1:begin
                        next_scl_out = 1'b1;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd0:begin
                        next_scl_out = 1'b0;
                        if(!no_ack && txfifo_empty == 1'b1 && i2c_comb_wr)
                        begin
                            next_state  = s_restart;
                            i2c_wr_rd   = 1'b0   ;
                            next_clk_cnt = 3'd4;
                        end
                        else if(!no_ack && txfifo_empty == 1'b0)
                        begin
                            next_state     = s_tx_data;
                            next_shift_dat = tx_data;
                            next_clk_cnt   = 3'd2;
                        end
                        else
                            next_state = s_stop;
                    end
                    default :next_state = s_stop;
                endcase
            end
        end
        s_restart:begin
            if(div_end)
            begin
                case(clk_cnt)
                    3'd4:begin
                        next_scl_out = 1'b0;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd3:begin
                        next_sda_out = 1'b1;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd2:begin
                        next_scl_out = 1'b1;
                        next_clk_cnt = 3'd1;
                    end
                    3'd1:begin
                        next_sda_out = 1'b0;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd0:begin
                        next_scl_out = 1'b0;
                        next_clk_cnt = 3'd2;
                        next_state     = s_send_addr;
                        next_shift_dat = {slave_addr[7:1],1'b1};
                    end
                    default :next_state = s_stop;
                endcase
            end
        end
        s_rx_data:begin
            if(div_end)
            begin
                case(clk_cnt)
                    3'd2:begin
                        next_scl_out = 1'b0;
                        next_sda_out = 1'b1;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd1:begin
                        next_scl_out = 1'b1;
                        next_clk_cnt = clk_cnt - 1'b1;
                        next_rx_data = {rx_data[6:0],sda_in};
                    end
                    3'd0:begin
                        next_scl_out = 1'b0;
                        next_clk_cnt = 3'd2;
                        if(rx_byte == 3'd7)
                        begin
                            next_rx_byte = 8'd0;
                            next_state   = s_send_ack;
                            rx_wr_data   = rx_data;
                            rx_wr_en     = ~rx_wr_en ;
                        end
                        else
                        begin
                            next_rx_byte = rx_byte + 1'b1;
                            next_state   = s_rx_data;
                        end
                    end
                    default :next_state = s_stop;
                endcase
            end
        end
        s_send_ack:begin
            if(div_end)
            begin
                case(clk_cnt)
                    3'd2:begin
                        next_scl_out = 1'b0;
                        next_clk_cnt = clk_cnt - 1'b1;
                        if(rx_byte_cnt == rx_byte_num)
                            next_sda_out = 1'b1;
                        else
                            next_sda_out = 1'b0;
                    end
                    3'd1:begin
                        next_scl_out = 1'b1;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd0:begin
                        next_scl_out = 1'b0;
                        next_clk_cnt = 3'd2;
                        if(rx_byte_cnt == rx_byte_num)
                        begin
                            next_state = s_stop;
                        end
                        else
                        begin
                            next_rx_byte_cnt = rx_byte_cnt + 1'b1;
                            next_state       = s_rx_data;
                        end
                    end
                    default :next_state = s_stop;
                endcase
            end
        end
        s_stop:begin
            if(div_end)
            begin
                case(clk_cnt)
                    3'd2:begin
                        next_scl_out = 1'b0;
                        next_sda_out = 1'b0;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd1:begin
                        next_scl_out = 1'b1;
                        next_clk_cnt = clk_cnt - 1'b1;
                    end
                    3'd0:begin
                        next_sda_out = 1'b1;
                        next_clk_cnt = 3'd2;
                        next_state   = s_idle;
                    end
                    default :next_state = s_stop;
                endcase
            end
        end
    default:begin
        next_state = s_idle;
    end
    endcase
end

assign no_ack = ((current_state == s_addr_ack || current_state == s_tx_ack) && (sda_in == 1'b1))? 1'b1 : 1'b0;
endmodule
