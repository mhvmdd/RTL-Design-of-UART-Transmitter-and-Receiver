module DESERIALIZER
#(
    parameter DATA_WIDTH = 8
)
(
    input wire                      CLK,
    input wire                      RSTn,
    
    // IN
    input wire                      DES_EN,
    input wire                      SAMPLED_BIT,

    // OUT
    output reg [DATA_WIDTH-1:0]     P_DATA
);

localparam CNT_WIDTH = $clog2(DATA_WIDTH);

reg [DATA_WIDTH-1:0] reg_data;
reg [CNT_WIDTH-1:0] cnt;


always @(posedge CLK or negedge RSTn) begin
    if (~RSTn) begin
        P_DATA <= {DATA_WIDTH{1'b0}};
        reg_data <= {DATA_WIDTH{1'b0}};
        cnt <= {CNT_WIDTH{1'b0}};
    end
    else begin
        if (DES_EN) begin
            reg_data[cnt] <= SAMPLED_BIT;
            cnt <= cnt + 1;
            if (cnt == DATA_WIDTH-1)
                P_DATA <= {SAMPLED_BIT, reg_data[DATA_WIDTH-2:0]};
        end
    end
end


endmodule 