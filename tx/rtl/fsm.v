module FSM 
#(
    parameter integer DATA_WIDTH = 8
)
(
    input   wire                      CLK,
    input   wire                      RSTn, // Asynchronus Reset - Active low
    input   wire                      DATA_VALID,
    input   wire                      SER_DONE,
    input   wire                      REG_PAR_EN,

    output  reg                      SER_EN,
    output  reg                      SAMPLE,
    output  reg [2:0]                SEL
);

// States
localparam IDLE     = 3'b000;
localparam START    = 3'b001;
localparam TRANS    = 3'b010;
localparam PARITY   = 3'b011;
localparam STOP     = 3'b100;

reg [2:0] cs, ns;

// FSM

always @(posedge CLK or negedge RSTn) begin
    if (~RSTn) begin
        cs <= IDLE;
    end
    else begin
        cs <= ns;
    end
end


always @(*) begin
    case (cs) 
        IDLE: begin
            if (DATA_VALID) ns = START;
            else ns = IDLE;
        end

        START: ns = TRANS;

        TRANS: begin
            if (SER_DONE) 
                if (REG_PAR_EN) ns = PARITY;
                else ns = STOP;
            else ns = TRANS;
        end

        PARITY: ns = STOP;

        STOP: ns = IDLE;

    endcase
end

// Output
always @(*) begin
    if (~RSTn) begin 
        SER_EN = 1'b0;
        SAMPLE = 1'b0;
        SEL = 3'b000;
    end
    else begin
        case (cs)
            IDLE : begin
                SEL = 3'b000;
                SER_EN = 1'b0;
                SAMPLE = 1'b0;
                if (DATA_VALID) begin
                    SAMPLE = 1'b1;
                end
            end
            START: begin
                SEL = 3'b001;
                SER_EN = 1'b1;
                SAMPLE = 1'b0;
            end
            TRANS: begin
                SEL = 3'b010;
                SER_EN = 1'b1;
                if (SER_DONE) begin
                    SER_EN = 1'b0;
                end
                SAMPLE = 1'b0;
            end

            PARITY: begin
                SEL = 3'b011;
                SER_EN = 1'b0;
                SAMPLE = 1'b0;
            end

            STOP: begin
                SEL = 3'b100;
                SER_EN = 1'b0;
                SAMPLE = 1'b0;      
            end

            default: begin
                SEL = 3'b000;
                SER_EN = 1'b0;
                SAMPLE = 1'b0;
            end
        endcase
    end
end

endmodule 