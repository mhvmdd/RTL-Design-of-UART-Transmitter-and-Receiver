module DATA_SAMPLING
(
    input wire          CLK,
    input wire          RSTn,

    // IN
    input wire RX_IN,
    input wire DAT_SAMP_EN,
    input wire [5:0] PRESCALE,
    input wire [4:0] EDGE_CNT,

    // OUT
    output wire SAMPLED_BIT
);

reg samp_1, samp_2, samp_3;
wire [5:0] half_prescale; assign half_prescale = PRESCALE >> 1;
always @(posedge CLK or negedge RSTn) begin
    if (~RSTn) begin
        samp_1 <= 1'b0;
        samp_2 <= 1'b0;
        samp_3 <= 1'b0;
    end
    else if (DAT_SAMP_EN) begin 
        if (EDGE_CNT == (half_prescale-1))
            samp_1 <= RX_IN;
        else if (EDGE_CNT == (half_prescale))
            samp_2 <= RX_IN;
        else if (EDGE_CNT == (half_prescale+1))
            samp_3 <= RX_IN;
    end
end

assign SAMPLED_BIT = ((samp_1 + samp_2 + samp_3) >= 2) ? 1'b1 : 1'b0;

endmodule