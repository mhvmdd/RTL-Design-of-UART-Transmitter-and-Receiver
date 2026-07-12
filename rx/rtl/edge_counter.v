module EDGE_COUNTER
(
    input wire          CLK,
    input wire          RSTn,

    // IN
    input wire          CNT_EN,
    input wire [5:0]    PRESCALE,
    input wire          CNT_RST,
    // OUT
    output reg [3:0]    BIT_CNT,
    output reg [5:0]    EDGE_CNT
);

always @(posedge CLK or negedge RSTn) begin
    if (~RSTn) begin
        BIT_CNT <= 4'b0;
        EDGE_CNT <= 6'b0;
    end
    else if (CNT_RST) begin
        EDGE_CNT <= 6'b0;
        BIT_CNT <= 4'b0;    
    end
    else if (CNT_EN) begin
        EDGE_CNT <= EDGE_CNT + 1;
        if (EDGE_CNT == PRESCALE-1) begin
            EDGE_CNT <= 6'b0;
            BIT_CNT <= BIT_CNT + 1;
        end
    end
end

endmodule
