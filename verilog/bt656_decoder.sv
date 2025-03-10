module bt656_decoder(input logic TD_CLK_27, input logic [7:0] data, output logic [15:0]  YCbCr, input logic reset, output logic field, output logic active_video, output logic Data_Valid );

  logic [31:0] count;
  logic [23:0] Window;
  logic [15:0] Data_Cont, TV_Y;
  logic [7:0] Cb, Cr;
  logic [15:0 ]H_line;
  logic SAV, V_blank, skip, Field, Pre_Field, Active_Video, Start, swap;

  assign SAV = (Window == 24'hFF0000) & ~data[4];
  assign skip = (((count >> 1) % 9) == 0);
  assign H_line = count >> 1;


  divide_by_9 div9(H_line, swap); // lsb of quotient

  always @(posedge TD_CLK_27 or negedge reset) begin
  	if(!reset) begin
	  Window <= 24'h0;
	  V_blank <= 0;
	  Field <= 0;
	  Pre_Field <= 0;
	  Start <= 0;
	  YCbCr <= 0;
	  Data_Valid <= 0;
	  active_video <= 0;
	  Cr <= 0;
	  Cb <= 0;
	end else begin
	Window <= {Window [15:0], data};
	if(SAV) // Check if we are begining of active video frame. Still need to check if we are in blanking period or not. 
		count <= 0;
	else if (count < 1440)
		count <= count + 1;
	if(SAV)
		Active_Video<=	1'b1;
	else if(count ==1440)
		Active_Video <=	1'b0;
	//	Is frame start?
	Pre_Field	<=	Field;
	if({Pre_Field,Field}==2'b10) // Need to make sure that we start at the frame and not in the middle of one
		Start		<=	1'b1;
	if(Window==24'hFF0000) // Here we are checking for the blanking period. 
		begin
			V_blank	<=	~data[5];
			Field	<=	data[6];
		end
	if(swap)
		begin
			case(count[1:0])		//	Swap
			0:	Cb		<=	 data;
			1:	YCbCr	<=	{data,Cr};
			2:	Cr		<=	 data;
			3:	YCbCr	<=	{data,Cb};
			endcase
		end
	else
		begin
		case(count[1:0])		//	Normal
		   0:	Cb		<=	 data;
			1:	YCbCr	<=	{data,Cb};
			2:	Cr		<=	 data;
			3:	YCbCr	<=	{data,Cr};
		endcase
		end
		//	Check data valid
	if(		Start				//	Frame Start?
			&& 	V_blank				//	Frame valid?
			&& 	Active_Video		//	Active video?
			&& 	count[0]				//	Complete ITU-R 601?
			&& 	!skip	)			//	Is non-skip pixel?
		Data_Valid	<=	1'b1;
	else
		Data_Valid	<=	1'b0;
		//	TV decoder line counter for one field
	if(Field && SAV)
		TV_Y<=	TV_Y+1;
	if(!Field)
		TV_Y<=	0;
		//	Data counter for one field
	if(!Field)
		Data_Cont	<=	0;
	if(Data_Valid)
		Data_Cont	<=	Data_Cont+1'b1;
  	end
  end


endmodule

module	ITU_656_Decoder(	//	TV Decoder Input
							iTD_DATA,
							//	Position Output
							oTV_X,
							oTV_Y,
							oTV_Cont,
							//	YUV 4:2:2 Output
							oYCbCr,
							oDVAL,
							//	Control Signals
							iSwap_CbCr,
							iSkip,
							iRST_N,
							iCLK_27	);
input	[7:0]	iTD_DATA;
input			iSwap_CbCr;
input			iSkip;
input			iRST_N;
input			iCLK_27;
output	[15:0]	oYCbCr;
output	[9:0]	oTV_X;
output	[9:0]	oTV_Y;
output	[31:0]	oTV_Cont;
output			oDVAL;

//	For detection
reg		[23:0]	Window;		//	Sliding window register
reg		[17:0]	Cont;		//	Counter
reg				Active_Video;
reg				Start;
reg				Data_Valid;
reg				Pre_Field;
reg				Field;
wire			SAV;
reg				FVAL;
reg		[9:0]	TV_Y;
reg		[31:0]	Data_Cont;

//	For ITU-R 656 to ITU-R 601
reg		[7:0]	Cb;
reg		[7:0]	Cr;
reg		[15:0]	YCbCr;

assign	oTV_X	=	Cont>>1;
assign	oTV_Y	=	TV_Y;
assign	oYCbCr	=	YCbCr;
assign	oDVAL	=	Data_Valid;
assign	SAV		=	(Window==24'hFF0000)&(iTD_DATA[4]==1'b0);
assign	oTV_Cont=	Data_Cont;

always@(posedge iCLK_27 or negedge iRST_N)
begin
	if(!iRST_N)
	begin
		//	Register initial
		Active_Video<=	1'b0;
		Start		<=	1'b0;
		Data_Valid	<=	1'b0;
		Pre_Field	<=	1'b0;
		Field		<=	1'b0;
		Window		<=	24'h0;
		Cont		<=	18'h0;
		Cb			<=	8'h0;
		Cr			<=	8'h0;
		YCbCr		<=	16'h0;
		FVAL		<=	1'b0;
		TV_Y		<=	10'h0;
		Data_Cont	<=	32'h0;
	end
	else
	begin
		//	Sliding window
		Window	<=	{Window[15:0],iTD_DATA};
		//	Active data counter
		if(SAV)
		Cont	<=	18'h0;
		else if(Cont<1440)
		Cont	<=	Cont+1'b1;
		//	Check the video data is active?
		if(SAV)
		Active_Video<=	1'b1;
		else if(Cont==1440)
		Active_Video<=	1'b0;
		//	Is frame start?
		Pre_Field	<=	Field;
		if({Pre_Field,Field}==2'b10)
		Start		<=	1'b1;
		//	Field and frame valid check
		if(Window==24'hFF0000)
		begin
			FVAL	<=	!iTD_DATA[5];
			Field	<=	iTD_DATA[6];
		end
		//	ITU-R 656 to ITU-R 601
		if(iSwap_CbCr)
		begin
			case(Cont[1:0])		//	Swap
			0:	Cb		<=	 iTD_DATA;
			1:	YCbCr	<=	{iTD_DATA,Cr};
			2:	Cr		<=	 iTD_DATA;
			3:	YCbCr	<=	{iTD_DATA,Cb};
			endcase
		end
		else
		begin
			case(Cont[1:0])		//	Normal
			0:	Cb		<=	 iTD_DATA;
			1:	YCbCr	<=	{iTD_DATA,Cb};
			2:	Cr		<=	 iTD_DATA;
			3:	YCbCr	<=	{iTD_DATA,Cr};
			endcase
		end
		//	Check data valid
		if(		Start				//	Frame Start?
			&& 	FVAL				//	Frame valid?
			&& 	Active_Video		//	Active video?
			&& 	Cont[0]				//	Complete ITU-R 601?
			&& 	!iSkip	)			//	Is non-skip pixel?
		Data_Valid	<=	1'b1;
		else
		Data_Valid	<=	1'b0;
		//	TV decoder line counter for one field
		if(FVAL && SAV)
		TV_Y<=	TV_Y+1;
		if(!FVAL)
		TV_Y<=	0;
		//	Data counter for one field
		if(!FVAL)
		Data_Cont	<=	0;
		if(Data_Valid)
		Data_Cont	<=	Data_Cont+1'b1;
	end
end

endmodule
