module PARITY
#( 
    parameter DATA_WIDTH = 8
)
(
    input wire CLK,
    input wire RSTn,

    input wire PAR_EN,
    input wire PAR_TYP,
    input wire SAMPLE,
    input wire [DATA_WIDTH-1:0] DATA_IN,

    output reg PAR_BIT,
    output reg REG_PAR_EN
);

always @(posedge CLK or negedge RSTn) begin
    if (~RSTn) begin
        PAR_BIT <= 1'b0;
        REG_PAR_EN <= 1'b0;
    end
    else begin
        if (SAMPLE) begin
            REG_PAR_EN <= PAR_EN;
            if (PAR_EN) begin
                if (PAR_TYP) begin // ODD PARITY
                    PAR_BIT <= ~(^DATA_IN);
                end
                else begin // EVEN PARITY
                    PAR_BIT <= ^DATA_IN;
                end
            end
            else begin
                PAR_BIT <= 1'b0;
                REG_PAR_EN <= 1'b0;
            end
        end
    end
end

endmodule