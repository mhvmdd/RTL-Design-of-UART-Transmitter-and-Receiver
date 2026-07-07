module UART_TX
#(
    parameter DATA_WIDTH = 8
)
(
    input   wire                      CLK,
    input   wire                      RSTn, // Asynchronus Reset - Active low
    input   wire                      PAR_TYP,
    input   wire                      PAR_EN,
    input   wire [DATA_WIDTH-1 : 0]   P_DATA,
    input   wire                      DATA_VALID,

    output  reg                      TX_OUT,
    output  reg                      BUSY
);


wire SAMPLE;
wire [2:0] SEL;

// PISO
wire SER_EN;
wire SER_DONE;
wire SER_BIT;

// PARITY
wire PAR_BIT;
wire REG_PAR_EN;

FSM #(.DATA_WIDTH(DATA_WIDTH)) fsm (
    
    // IN
    .CLK(CLK),
    .RSTn(RSTn),
    .DATA_VALID(DATA_VALID),
    .SER_DONE(SER_DONE),
    .REG_PAR_EN(REG_PAR_EN),

    // OUT
    .SER_EN(SER_EN),
    .SAMPLE(SAMPLE),
    .SEL(SEL)
);


PISO #(.DATA_WIDTH(DATA_WIDTH)) piso (

    // IN
    .CLK(CLK),
    .RSTn(RSTn),
    .SER_EN(SER_EN),
    .SAMPLE(SAMPLE),
    .DATA_IN(P_DATA),

    // OUT
    .SER_DONE(SER_DONE),
    .DATA_OUT(SER_BIT)
);


PARITY #(.DATA_WIDTH(DATA_WIDTH)) parity (
    // IN
    .CLK(CLK),
    .RSTn(RSTn),
    .SAMPLE(SAMPLE),
    .PAR_EN(PAR_EN),
    .PAR_TYP(PAR_TYP),
    .DATA_IN(P_DATA),

    // OUT
    .PAR_BIT(PAR_BIT),
    .REG_PAR_EN(REG_PAR_EN)
);


always @(*) begin
    if (~RSTn) begin    
        TX_OUT = 1'b1; // IDLE
        BUSY = 1'b0;
    end
    else begin
        case (SEL)
            3'b000: begin
                TX_OUT = 1'b1;
                BUSY = 1'b0;
            end

            3'b001: begin
                TX_OUT = 1'b0;
                BUSY = 1'b1;
            end

            3'b010: begin
                TX_OUT = SER_BIT;
                BUSY = 1'b1;
            end

            3'b011: begin
                TX_OUT = PAR_BIT;
                BUSY = 1'b1;
            end

            3'b100: begin
                TX_OUT = 1'b1;
                BUSY = 1'b1;
            end

            default: begin
                TX_OUT = 1'b1;
                BUSY = 1'b0;               
            end
        endcase
    end

end



endmodule