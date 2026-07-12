`define sample_check(chk_sig) \
    begin \
        if (sample) \
            DAT_SAMP_EN = 1'b1; \
        else \
            DAT_SAMP_EN = 1'b0; \
        \
        if (en) \
            chk_sig = 1'b1; \
        else \
            chk_sig = 1'b0; \
    end

module FSM_RX 
(
    input wire          CLK,
    input wire          RSTn,

    // IN
    input wire          RX_IN,
    input wire [5:0]    EDGE_CNT, // 0 -> PRESCALE
    input wire [3:0]    BIT_CNT, // 0 -> 10 (START BIT + DATA BITS + PARITY BIT "if enabled" + STOP BIT)
    input wire          PAR_EN,

    input wire          STRT_GLITCH,
    input wire          PAR_ERR,
    input wire          STP_ERR,
    input wire [5:0]    PRESCALE,

    // OUT
    output reg          CNT_EN,
    output reg          DAT_SAMP_EN,

    output reg          STRT_CHK_EN,
    output reg          PAR_CHK_EN,
    output reg          STP_CHK_EN,

    output reg          DES_EN,
    output reg          DATA_VALID,
    output reg          CNT_RST
);

// STATES
localparam IDLE         = 3'b000;
localparam START_CHK    = 3'b001;
localparam DATA_SAMP    = 3'b010;
localparam PARITY_CHK   = 3'b011;
localparam STP_CHK      = 3'b100;

reg [2:0] cs, ns;


// State Transition
always @(posedge CLK or negedge RSTn) begin
    if (~RSTn)
       cs <= IDLE;
    else 
        cs <= ns; 
end

// Next State Logic 
always @(*) begin
    case (cs)
        IDLE: begin
            if (~RX_IN) ns = START_CHK;
            else ns = IDLE;
        end

        START_CHK: begin
            if (BIT_CNT == 0 && EDGE_CNT == PRESCALE-1) begin
                if (STRT_GLITCH) ns = IDLE;
                else ns = DATA_SAMP;
            end
            else ns = START_CHK;
        end 

        DATA_SAMP: begin
            if (BIT_CNT == 8 && EDGE_CNT == PRESCALE-1) 
                if (PAR_EN) ns = PARITY_CHK;
                else ns = STP_CHK;
            else ns = DATA_SAMP;
        end

        PARITY_CHK: begin
            if (BIT_CNT == 9 && EDGE_CNT == PRESCALE-1) ns = STP_CHK;
            else ns = PARITY_CHK;
        end

        STP_CHK: begin
            if (((BIT_CNT == 9 && ~PAR_EN) || (BIT_CNT == 10 && PAR_EN)) 
            && EDGE_CNT == PRESCALE-1 ) 
                ns = IDLE;
            else ns = STP_CHK;
        end

        default: ns = IDLE;
    endcase
end



// OUPUT LOGIC
wire [5:0] half_prescale; assign half_prescale = PRESCALE >> 1;
wire sample; assign sample = (EDGE_CNT == (half_prescale-1) || 
                              EDGE_CNT == half_prescale || 
                              EDGE_CNT == (half_prescale+1));
wire en = (EDGE_CNT == (half_prescale + 2));
reg frame_done;

always @(*) begin
    if (~RSTn) begin
        CNT_EN = 1'b0;
        DAT_SAMP_EN = 1'b0;
        STRT_CHK_EN = 1'b0;
        PAR_CHK_EN = 1'b0;
        STP_CHK_EN = 1'b0;
        DES_EN = 1'b0;
        CNT_RST = 1'b0;   
        frame_done = 1'b0;       
    end
    else begin
        frame_done = 1'b0;
        CNT_RST = 1'b0;          
        DES_EN = 0;
        CNT_EN = 0;
        DAT_SAMP_EN = 0;
        STRT_CHK_EN = 0;
        PAR_CHK_EN = 0;
        STP_CHK_EN = 0;   
        case (cs)
            IDLE: begin 
                CNT_RST = 1'b1;          
                if (~RX_IN) begin
                    CNT_EN = 1'b1;      
                    CNT_RST = 1'b0;          
                end 
            end
            START_CHK: begin                        
                CNT_EN = 1;
                `sample_check(STRT_CHK_EN)
            end
            DATA_SAMP: begin          
                CNT_EN = 1;
                `sample_check(DES_EN)                          
            end
            PARITY_CHK: begin         
                CNT_EN = 1;
                `sample_check(PAR_CHK_EN)
            end
            STP_CHK: begin   
                CNT_EN = 1;
                `sample_check(STP_CHK_EN)

                if (EDGE_CNT == PRESCALE-2) 
                    frame_done = 1'b1;

                if (EDGE_CNT == PRESCALE-1)
                    CNT_RST = 1'b1;

            end
            default:;
        endcase
    end
end

always @(posedge CLK or negedge RSTn) begin
    if (~RSTn)
        DATA_VALID        <= 1'b0;
    else if (frame_done)
        DATA_VALID        <= (~STP_ERR && ~PAR_ERR);
    else 
        DATA_VALID        <= 1'b0;
end

endmodule