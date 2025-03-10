module clock_divider #(parameter DELAY = 500) (input logic reset, input logic ref_clk, output logic clk_o);
  reg [9:0] count = 0;
 
  always@(posedge ref_clk) begin
  	if (!reset) begin
	  clk_o = 0;
	  count = 0;
	end
	else begin
	   if(count == {DELAY/2}) begin
		clk_o = ~clk_o;
		count = 0;
	   end else begin
	    count = count + 1;	
	  end
	end
  end

endmodule
