module bt656_decoder_tb();

   logic TD_CLK_27, lsb;  
   logic [7:0] data;  
   logic [15:0]  YCbCr;  
   logic reset;  
   logic field;  
   logic active_video;  
   logic Data_Valid; 
logic [12:0] count;
logic [7:0] q;

   
   bt656_decoder DUT( TD_CLK_27,    data,  YCbCr,  reset,   field,  active_video,   Data_Valid);


 initial begin
        TD_CLK_27 = 1;

        forever begin
            TD_CLK_27 = ~TD_CLK_27;
            #10;
        end
end


always @(posedge TD_CLK_27) begin
	if(!reset)
	   count <= 0;
	else
	 count <= count + 1;

end

always_comb begin

if (count == 1)
 data = 8'hFF;
else if (count == 2)
 data = 8'h00;
else if (count == 3)
 data = 8'h00;
else if (count == 4)
 data  = 8'hE7;
else if (count == 5)
 data = 8'hFF;
else if (count == 6)
 data = 8'h00;
else if (count == 7)
 data = 8'h00;
else if (count == 8)
 data = 8'h87;
else
 data [7:0]  = count;
end

initial begin
reset = 0;
#5;
reset = 1;


end

endmodule 

