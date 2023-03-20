module i2c_slave(
    input        sscl_in   ,
    input        ssda_in   ,
    input        wclk      ,
    input        rst_wclk_n,
    input        slave_en  ,
    input        stxfifo_empty,
    //input        srxfifo_full ,
    input [7:0]  stx_fifo_dat ,
    input        rxfifo_almost_full,
    input [7:0]  master_code,
    input [7:0]  slave_addr ,

    output reg   sscl_out  ,
    output reg   ssda_out  ,
    output [7:0] rx_sdat    ,
    output       srxfifo_en,
    output       stx_fifo_rd_en

);
localparam s_idle           = 8'b0000_0000;
localparam s_start          = 8'b0000_0001;
localparam s_receive_code   = 8'b0000_0011;
localparam s_send_code_ack  = 8'b0000_0010;
localparam s_hs_rx_add      = 8'b0000_0110;
localparam s_send_dat       = 8'b0000_0111;
localparam s_receive_dat    = 8'b0000_1111;
localparam s_rx_dat_ack     = 8'b0000_1110;
localparam s_wait           = 8'b0000_1100;
localparam s_send_dat_ack   = 8'b0000_1000;
reg        rise_edge   ;     
reg        fall_edge   ;
reg        detect_start;
reg        detect_stop ;
reg        ssda_in_d1  ;
reg        ssda_in_d2  ;
reg        sscl_in_d1  ;
reg        sscl_in_d2  ;
reg [7:0]  current_state;
reg [7:0]  next_state  ;
reg [7:0]  next_rx_sdat;
reg [7:0]  rx_sdat     ;
reg [3:0]  bit_cnt     ;
reg [3:0]  next_bit_cnt;
reg        master_code_match;
reg        next_ssda_out;
reg        next_sscl_out;
reg        srx_fifo_wr  ;
reg        stx_fifo_rd  ;
reg        slave_addr_match;
reg        slave_wr        ;
reg        slave_rd        ;
reg [7:0]  next_sshift_dat ;
reg [7:0]  sshift_dat      ;
wire       bit_end         ;
reg        stxfifo_ept_continue;
reg        srxfifo_en_d;
reg        stx_fifo_rd1;
//data flip
always @(posedge wclk or negedge rst_wclk_n)
begin
    if(!rst_wclk_n)
    begin
        sscl_in_d1 <= 1'b0;
        sscl_in_d2 <= 1'b0;
        ssda_in_d1 <= 1'b0;
        ssda_in_d2 <= 1'b0;
        srxfifo_en_d  <= 1'b0;
        sscl_out      <= 1'b1;
    //    ssda_out      <= 1'b1;
        rx_sdat       <= 8'd0;
        stx_fifo_rd1  <= 1'b0;  
    //    sshift_dat    <= 8'hFF; 
    end
    else
    begin
        sscl_in_d1 <= sscl_in   ;
        sscl_in_d2 <= sscl_in_d1;
        ssda_in_d1 <= ssda_in   ;
        ssda_in_d2 <= ssda_in_d1;
        srxfifo_en_d <= srx_fifo_wr;
        sscl_out     <= next_sscl_out;
     //   ssda_out     <= next_ssda_out;
        rx_sdat      <= next_rx_sdat;
        stx_fifo_rd1 <= stx_fifo_rd;
     //   sshift_dat   <= next_sshift_dat;
    end
end
assign srxfifo_en = srx_fifo_wr ^ srxfifo_en_d;
assign stx_fifo_rd_en = stx_fifo_rd ^ stx_fifo_rd1;
//detect start
always @(posedge wclk or negedge rst_wclk_n)
begin
    if(!rst_wclk_n)
        detect_start<= 1'b0;
    else if(sscl_in == 1'b1 && ssda_in_d1 == 1'b0 && ssda_in_d2 == 1'b1)
        detect_start<= 1'b1;
    else
        detect_start<= 1'b0;
end
// detect stop
always @(posedge wclk or negedge rst_wclk_n)
begin
    if(!rst_wclk_n)
        detect_stop <= 1'b0;
    else if(sscl_in == 1'b1 && ssda_in_d1 == 1'b1 && ssda_in_d2 == 1'b0)
        detect_stop<= 1'b1;
    else
        detect_stop<= 1'b0;
end
//detect scl rise edge
always @(posedge wclk or negedge rst_wclk_n)
begin
    if(!rst_wclk_n)
        rise_edge <= 1'b0;
    else if(sscl_in_d1 == 1'b1 && sscl_in_d2 == 1'b0)
        rise_edge <= 1'b1;
    else
        rise_edge <= 1'b0;
end
//detect scl fall edge
always @(posedge wclk or negedge rst_wclk_n)
begin
    if(!rst_wclk_n)
        fall_edge <= 1'b0;
    else if(sscl_in_d1 == 1'b0 && sscl_in_d2 == 1'b1)
        fall_edge <= 1'b1;
    else
        fall_edge <= 1'b0;
end
always @(posedge wclk or negedge rst_wclk_n)
begin
    if(!rst_wclk_n)
        current_state <= s_idle;
    else if(slave_en)
    begin
        if(detect_stop)
            current_state <= s_idle;
        else if(detect_start && slave_en == 1'b1)
            current_state <= s_start;
        else
            current_state <= next_state;
    end
    else
        current_state <= s_idle;
end
always @(posedge wclk or negedge rst_wclk_n)
begin
    if(!rst_wclk_n)
    begin
        bit_cnt <= 4'd0;
        ssda_out <= 1'b1;
        sshift_dat <= 8'hFF;
    end
    else //if(rise_edge)
    begin 
        bit_cnt    <= next_bit_cnt;
        ssda_out   <= next_ssda_out;
        sshift_dat <= next_sshift_dat;
    end
end
always @(*)
begin
    case(current_state)
        s_idle:begin
            next_rx_sdat  = 8'd0;
            next_sscl_out = 1'b1;
            next_ssda_out = 1'b1;
            srx_fifo_wr   = 1'b0;
            stx_fifo_rd   = 1'b0;
            next_bit_cnt  = 4'b0;
            stxfifo_ept_continue = 1'b0;
            if(slave_en == 1'b1 && detect_start == 1'b1)
                next_state = s_start;
            else
                next_state = s_idle;
        end
        s_start:begin
            next_bit_cnt = 3'd0;
            if(fall_edge)
            begin
                next_state = s_receive_code;
            end
            else
            begin
                next_state = s_start;
            end
        end
        s_receive_code:begin
            if(rise_edge)
            begin
                next_rx_sdat = {rx_sdat[6:0],ssda_in};
                next_bit_cnt = bit_cnt + 1'b1;  
            end
            else if(fall_edge && bit_end)
            begin
                next_bit_cnt = 3'd0;
                if(!master_code_match && !slave_addr_match)
                    next_state = s_idle;
                else
                begin
                    next_state = s_send_code_ack;
                    if(!stxfifo_empty && slave_rd)
                    begin
                        stx_fifo_rd          = ~stx_fifo_rd;
                        stxfifo_ept_continue = 1'b1;
                    end
                        
                end
            end
        end
        s_send_code_ack:begin
            if(fall_edge)
            begin
                next_ssda_out = 1'b1;
                if(master_code_match)
                    next_state = s_hs_rx_add;
                else if(slave_addr_match && slave_wr && !rxfifo_almost_full)
                    next_state = s_receive_dat;
                else if(slave_addr_match && stxfifo_ept_continue && slave_rd)
                begin
                    next_state      = s_send_dat;
                    next_sshift_dat = stx_fifo_dat;
                    stxfifo_ept_continue = 1'b0;
                end
                else
                    next_state = s_wait;
            end
            else
                next_ssda_out = 1'b0;
        end
        s_hs_rx_add:begin
            if(rise_edge)
            begin   
                next_rx_sdat = {rx_sdat[6:0],ssda_in};
                next_bit_cnt = bit_cnt + 1'b1;  
            end
            else if(fall_edge && bit_end)
            begin
                next_bit_cnt = 3'd0;
                if(slave_addr_match)
                begin
                    next_state = s_send_code_ack;
                    if(slave_rd && !stxfifo_empty)
                        stxfifo_ept_continue = 1'b1;
                end
                else
                    next_state = s_idle;
            end
        end
        s_receive_dat:begin
            if(rise_edge)
            begin   
                next_rx_sdat = {rx_sdat[6:0],ssda_in};
                next_bit_cnt = bit_cnt + 1'b1;  
            end
            else if(fall_edge && bit_end)
            begin
                next_bit_cnt = 3'd0;
                srx_fifo_wr  = ~srx_fifo_wr;
                next_state   = s_rx_dat_ack;
                next_ssda_out = 1'b0;
            end
        end
        s_rx_dat_ack:begin
            if(fall_edge)
            begin
                next_ssda_out = 1'b1;
                if(rxfifo_almost_full)
                    next_state = s_wait;
                else
                    next_state = s_receive_dat;
            end
            else
                next_ssda_out = 1'b0;
        end
        s_wait:begin
            next_bit_cnt <= 3'd0;
            if(slave_rd && !stxfifo_empty)
            begin
                next_state = s_send_dat;
                next_sscl_out = 1'b1;
            end
            else if(slave_wr && !rxfifo_almost_full)
            begin
                next_state = s_receive_dat;
                next_sscl_out = 1'b1;
            end
            else 
                next_sscl_out = 1'b0;
        end
        s_send_dat:begin
            next_ssda_out   = sshift_dat[7];
            if(bit_end && fall_edge)
            begin
                next_bit_cnt  = 3'd0;
                next_state    = s_send_dat_ack;
                next_ssda_out = 1'b1;
                if(!stxfifo_empty)
                    stx_fifo_rd   = ~stx_fifo_rd;
            end
            else if(rise_edge)
            begin
                next_bit_cnt    = bit_cnt + 1'b1;
                next_sshift_dat = {sshift_dat[6:0],1'b1};
                next_ssda_out   = sshift_dat[7];
            end
        end
        s_send_dat_ack:begin
            if(rise_edge && ssda_in)
            begin
                next_state = s_idle;
            end
            else if(fall_edge)
            begin
                if(stxfifo_empty)
                    next_state = s_wait;
                else
                begin
                    next_state     = s_send_dat;
                    next_sshift_dat = stx_fifo_dat;
                end
            end            
        end
        default:begin
                next_state = s_idle;
        end
    endcase
end
assign bit_end = bit_cnt == 4'd8;
always @(posedge wclk or negedge rst_wclk_n)
begin
    if(!rst_wclk_n)
    begin
        master_code_match <= 1'b0;
    end
    else if((current_state == s_receive_code ) && rx_sdat == master_code && bit_end)
        master_code_match <= 1'b1;
    else if(current_state == s_send_code_ack)
        master_code_match <= master_code_match;
    else
        master_code_match <= 1'b0;
end
always @(posedge wclk or negedge rst_wclk_n)
begin
    if(!rst_wclk_n)
    begin
        slave_addr_match <= 1'b0;
    end
    else if((current_state == s_receive_code || current_state == s_hs_rx_add )&& rx_sdat[6:1] == slave_addr[6:1] && bit_end)
        slave_addr_match <= 1'b1;
    else if(current_state == s_send_code_ack)
        slave_addr_match <= slave_addr_match;
    else
        slave_addr_match <= 1'b0;
end
always @(posedge wclk or negedge rst_wclk_n)
begin
    if(!rst_wclk_n)
    begin
        slave_wr <= 1'b0;
        slave_rd <= 1'b0;
    end
    else if(slave_addr_match)
    begin
        if(rx_sdat[0] == 1'b1)
        begin
            slave_wr <= 1'b0;
            slave_rd <= 1'b1;
        end
        else
        begin
            slave_rd <= 1'b0;
            slave_wr <= 1'b1;
        end
    end
end
endmodule
