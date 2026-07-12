module CHECKER 
(
    input wire                  CLK,
    input wire                  RSTn,

    // IN
    input wire                  STRT_CHK_EN,
    input wire                  PAR_CHK_EN,
    input wire                  STP_CHK_EN,
    
    input wire                  PAR_TYP,

    input wire                  SAMPLED_BIT,
    input wire [7:0]            P_DATA,   


    // OUT
    output reg                  STRT_GLITCH,
    output reg                  PAR_ERR,
    output reg                  STP_ERR
);


// START
always @(posedge CLK or negedge RSTn) begin
    if (~RSTn) begin
        STRT_GLITCH <= 1'b0;
    end
    else begin
        if (STRT_CHK_EN)
            STRT_GLITCH <= (SAMPLED_BIT); // if high then error
    end
end


//PARITY
// 1 Odd, 0 Even
wire exp_par; assign exp_par = (PAR_TYP) ? ~(^P_DATA) : ^P_DATA;
always @(posedge CLK or negedge RSTn) begin
    if (~RSTn) begin
        PAR_ERR <= 1'b0;
    end
    else begin
        if (PAR_CHK_EN)
            PAR_ERR <= (SAMPLED_BIT != exp_par);
    end
end


// STP
always @(posedge CLK or negedge RSTn) begin
    if (~RSTn) begin
        STP_ERR <= 1'b0;
    end
    else begin
        if (STP_CHK_EN)
            STP_ERR <= (~SAMPLED_BIT);
    end
end


endmodule 