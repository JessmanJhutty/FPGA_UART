module divide_by_9 (
    input logic [12:0] num,   // Input number (higher precision)
    output logic       lsb    // LSB of (num / 9)
);
    logic [15:0] reciprocal;
    logic [31:0] quotient;
    
    always_comb begin
        reciprocal = 16'h1C72; // Approximate 1/9 in fixed-point (1/9 ? 0.111... = 0x1C72 in Q16)
        quotient = (num * reciprocal) >> 16; // Multiply and shift (fixed-point division)
    end

    assign lsb = quotient[0];  // Extract LSB
endmodule
