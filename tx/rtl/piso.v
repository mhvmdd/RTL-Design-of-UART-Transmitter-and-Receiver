module PISO 
#(
    parameter DATA_WIDTH = 8
)
(
    input   wire CLK,
    input   wire RSTn,

    input   wire SER_EN,
    input   wire [DATA_WIDTH-1:0] DATA_IN,
    input   wire SAMPLE,

    output  reg SER_DONE,
    output  reg DATA_OUT
);

localparam CNT_WIDTH = $clog2 (DATA_WIDTH);

reg [DATA_WIDTH-1:0] reg_data;
reg [CNT_WIDTH-1:0] cnt;

always @(posedge CLK or negedge RSTn) begin
    if (!RSTn) begin
        SER_DONE <= 1'b0;
        DATA_OUT <= 1'b0;
        cnt <= {CNT_WIDTH{1'b0}};
        reg_data <= {DATA_WIDTH{1'b0}};
    end
    else begin
        if (SAMPLE) begin
            reg_data <= DATA_IN;
            cnt <= {CNT_WIDTH{1'b0}};
            SER_DONE <= 1'b0;
        end
        else if (SER_EN) begin
            DATA_OUT <= reg_data[0];
            reg_data <= reg_data >> 1;
            cnt <= cnt + 1;
            if (cnt == DATA_WIDTH-1)
                SER_DONE <=  1'b1;
            else 
                SER_DONE <= 1'b0;
        end
    end
end


endmodule