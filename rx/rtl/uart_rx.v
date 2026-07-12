module UART_RX #(
    parameter DATA_WIDTH = 8
) (
    input wire CLK,
    input wire RSTn,

    // IN
    input wire PAR_TYP,
    input wire PAR_EN,
    input wire [5:0] PRESCALE,
    input wire RX_IN,

    // OUT
    output wire [DATA_WIDTH-1:0] P_DATA,
    output wire DATA_VALID,
    output wire PARITY_ERR,
    output wire STOP_ERR
);

    // IN
    wire [5:0]    EDGE_CNT; // 0 -> PRESCALE
    wire [3:0]    BIT_CNT; // 0 -> 10 (START BIT + DATA BITS + PARITY BIT "if enabled" + STOP BIT)
    wire          STRT_GLITCH;

    // OUT
    wire          CNT_EN;
    wire          DAT_SAMP_EN;

    wire          STRT_CHK_EN;
    wire          PAR_CHK_EN;
    wire          STP_CHK_EN;

    wire          DES_EN;
    wire          CNT_RST;

    wire SAMPLED_BIT;

// FSM
FSM_RX fsm(
    .CLK(CLK),
    .RSTn(RSTn),

    .RX_IN(RX_IN),
    .EDGE_CNT(EDGE_CNT),
    .BIT_CNT(BIT_CNT),
    .PAR_EN(PAR_EN),

    .STRT_GLITCH(STRT_GLITCH),
    .PAR_ERR(PARITY_ERR),
    .STP_ERR(STOP_ERR),
    .PRESCALE(PRESCALE),

    .CNT_EN(CNT_EN),
    .DAT_SAMP_EN(DAT_SAMP_EN),
    .STRT_CHK_EN(STRT_CHK_EN),
    .PAR_CHK_EN(PAR_CHK_EN),
    .STP_CHK_EN(STP_CHK_EN),

    .DES_EN(DES_EN),
    .DATA_VALID(DATA_VALID),
    .CNT_RST(CNT_RST)
);

// EDGE COUNTER

EDGE_COUNTER edge_counter (
    .CLK(CLK),
    .RSTn(RSTn),

    .CNT_RST(CNT_RST),
    .CNT_EN(CNT_EN),
    .PRESCALE(PRESCALE),

    .BIT_CNT(BIT_CNT),
    .EDGE_CNT(EDGE_CNT)
);

// DATA SAMPLING
DATA_SAMPLING data_sampling (
    .CLK(CLK),
    .RSTn(RSTn),

    .RX_IN(RX_IN),
    .DAT_SAMP_EN(DAT_SAMP_EN),
    .PRESCALE(PRESCALE),
    .EDGE_CNT(EDGE_CNT),

    .SAMPLED_BIT(SAMPLED_BIT)
);
// DESERIALIZER

DESERIALIZER des (
    .CLK(CLK),
    .RSTn(RSTn),

    .DES_EN(DES_EN),
    .SAMPLED_BIT(SAMPLED_BIT),

    .P_DATA(P_DATA)
);

// CHECKER
CHECKER check (
    .CLK(CLK),
    .RSTn(RSTn),

    .STRT_CHK_EN(STRT_CHK_EN),
    .STP_CHK_EN(STP_CHK_EN),
    .PAR_CHK_EN(PAR_CHK_EN),

    .PAR_TYP(PAR_TYP),
    .SAMPLED_BIT(SAMPLED_BIT),

    .P_DATA(P_DATA),

    .STRT_GLITCH(STRT_GLITCH),
    .STP_ERR(STOP_ERR),
    .PAR_ERR(PARITY_ERR)
);
    
endmodule