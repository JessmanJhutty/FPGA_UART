module  i2c_master (input logic clk,
                    input logic reset,
                    input logic read,
                    input logic [7:0] data_to_send,
                    output logic [7:0] data_to_read,
						  input logic [7:0] reg_dest,
                    inout logic sda,
                    output logic scl,
						  input logic start);

typedef enum logic[4:0] {
    IDLE,
    START,
    READ,
    WRITE,
    WAIT,
    SEND_ADDR,
    RECEIVE_WACK_WR,
    RECEIVE_WACK_RD,
    RECEIVE_WACK2,
    RECEIVE_WACK_SEND_REG_ADDR,
    SEND_REG_ADDRESS,
    SEND_ADDR_READ,
    SEND_DATA,
    READ_DATA, 
    RECEIVE_NACK,
    READ_DATA_START,
    REPEATED_START,
    STOP
} State; 

State current_state, nextState;

logic [7:0] addr; 
logic [7:0] count, data_to_read_o;
logic count_en, scl_en, sda_out, sda_reg, data_reg, scl_STOP;


/////////// Counter Registers ///////////////////////////////
always_ff @(posedge clk) begin
    if(!count_en)
        count <= 8'd7;
    else 
        count <= count - 1;
end


////// State machine Register //////////////////

always_ff @(posedge clk) begin
    if(!reset)
        current_state <= IDLE;
    else
        current_state <= nextState; 
    if(data_reg) data_to_read[count] = data_to_read_o[count];
end




//Potential Issue:   



/////////  Clocking  for I2C    ///////////
always_ff @(negedge clk) begin
   if(reset == 0) begin
	scl_en <= 0;
   end else begin
	
	if ((current_state == IDLE) || (current_state == STOP) || (current_state == READ_DATA_START)) begin
	    scl_en <= 0;
	end else scl_en = 1;
	
	case(current_state)
		IDLE: begin scl_en <= 0; end
		STOP: begin scl_en <= 0; end
		READ_DATA_START: begin scl_en <= 0; end
	default: scl_en <= 1;
	endcase
    
   end

end

/*
always_ff @(negedge clk) begin
	if(current_state == WAIT)
		  scl_STOP = 1;
	else
		scl_STOP = 0;
end
*/
assign scl = /*(current_state == WAIT ) ? 1'b0 : */ scl_en ? ~clk : 1'b1;
assign sda = sda_out ? 1'bz : 1'b0;

/////////////  Output Combinational Logic Block ///////////////////
always_comb begin
    sda_reg = 1'b1;
    sda_out = 1'b1;
    //scl_en = 1;
    addr = 7'h40;
    count_en = 1;
    data_reg = 0;
    data_to_read_o[7:0] = 8'h00;
    nextState = current_state;
    case(current_state) 
        IDLE: begin
            //sda_reg = 1'b1;
            //scl_en = 0;
            if(!start) nextState = START;
        end
        START: begin
            sda_out = 0;
	    //scl_en = 0;
            count_en = 0;
            nextState = SEND_ADDR;
        end
        SEND_ADDR: begin
             sda_out =  addr[count];
            if(count == 1 & !read)  begin
                nextState = WRITE;
            end else if (count == 1 & read) nextState = WRITE;
        end
        SEND_ADDR_READ: begin
            sda_out = addr[count];
            if(count == 1) nextState = READ;
        end
        WRITE: begin
            sda_out = 0;
            nextState = RECEIVE_WACK_WR;
        end
        READ: begin
            sda_out = 1;
            nextState = RECEIVE_WACK_RD;
        end
        RECEIVE_WACK_WR:begin
            sda_out = 1;
            count_en = 0;
            if(sda == 0) nextState = SEND_REG_ADDRESS; else nextState = STOP; // this need to be changed to stop
        end 
    /*
        WAIT: begin
        sda_reg = 0;
        if(scl_STOP) scl_en = 0; else  scl_en = 1;
        nextState = STOP;
        end
    */
        RECEIVE_WACK_RD: begin
            sda_out = 1;
            count_en = 0;
            if(sda == 0) nextState = READ_DATA; else nextState = STOP; //this also need to be changed
        end
        SEND_DATA: begin
            sda_out = data_to_send[count];
            if (count == 0) nextState = RECEIVE_WACK2;
        end
	    SEND_REG_ADDRESS: begin
	        sda_out = reg_dest[count];
	        if (count == 0) nextState = RECEIVE_WACK_SEND_REG_ADDR;
	    end
	    RECEIVE_WACK_SEND_REG_ADDR: begin
	        sda_out = 1;
		count_en = 0;
            if(sda == 0 & read) 
		        nextState = READ_DATA_START; 
	        else if(sda == 0 & !read) nextState = SEND_DATA;
		else nextState = STOP; // change this to STOP
	    end
        READ_DATA_START: begin
            sda_out = 1;
            //scl_en = 0;
            nextState = REPEATED_START;
        end
	    REPEATED_START: begin
	        count_en = 0;
	        //scl_en = 0;
	        sda_out = 0;
	    nextState = SEND_ADDR_READ;
	    end
        READ_DATA: begin
	        sda_out = 1;
            data_reg = 1;
            data_to_read_o[count] = sda;
            if(count == 0) nextState = RECEIVE_NACK;
        end
        RECEIVE_WACK2: begin 
            sda_out = 1;
            nextState = STOP;
        end 
        RECEIVE_NACK: begin
            sda_out = 1;
            nextState = STOP; 
        end
        STOP: begin
            sda_out = 0;
            //scl_en = 0;
            nextState = IDLE;
        end
    default: nextState = IDLE;
    endcase

end


endmodule
