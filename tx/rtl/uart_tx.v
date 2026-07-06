module UART_TX 
#(
    parameter integer DATA_WIDTH = 8
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

localparam CNT_WIDTH = $clog2 (DATA_WIDTH);


// States
localparam IDLE     = 3'b000;
localparam START    = 3'b001;
localparam TRANS    = 3'b010;
localparam PARITY   = 3'b011;
localparam STOP     = 3'b100;

reg [2:0] cs, ns;


reg ser_en;
reg ser_done;
reg ser_bit;

reg [DATA_WIDTH-1:0] reg_data;
reg [CNT_WIDTH-1:0] cnt;

reg par_bit;
reg par_en;

// FSM

always @(posedge CLK or negedge RSTn) begin
    if (!RSTn) begin
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
            if (ser_done) 
                if (par_en) ns = PARITY;
                else ns = STOP;
            else ns = TRANS;
        end

        PARITY: ns = STOP;

        STOP: ns = IDLE;

    endcase
end


// Parity logic
always @(posedge CLK or negedge RSTn) begin
    if (!RSTn) begin
        par_bit <= 1'b0;
        par_en <= 1'b0;
    end
    else begin
        if (DATA_VALID && cs == IDLE) begin
                par_en <= PAR_EN;
                // Parity 
                if (PAR_EN) begin
                    if (PAR_TYP) begin // ODD PARITY
                        par_bit <= ~(^P_DATA);
                    end
                    else begin // EVEN PARITY
                        par_bit <= ^P_DATA;
                    end
                end
                else begin
                    par_bit <= 1'b0;
                    par_en <= 1'b0;
                end
        end
    end
end

always @(*) begin
    ser_en = 0;
    if (cs == START)
        ser_en = 1;
    else if (cs == TRANS) begin      
        ser_en = 1;
        if (ser_done)
            ser_en = 0;
    end
end

// always @(posedge CLK or negedge RSTn) begin
//     if (!RSTn) begin
//         ser_done <= 1'b0;
//         ser_bit <= 1'b0;
//         cnt <= {CNT_WIDTH{1'b0}};
//         reg_data <= {DATA_WIDTH{1'b0}};
//     end
//     else begin
//         if (DATA_VALID && cs == IDLE) begin
//             reg_data <= P_DATA;
//         end
//         else if (ser_en) begin
//                 ser_bit <= reg_data[0];
//                 reg_data <= reg_data >> 1;
//                 cnt <= cnt + 1;
//                 if (cnt == DATA_WIDTH-1)
//                     ser_done <=  1'b1;
//                 else 
//                     ser_done <= 1'b0;
//         end
//         else begin
//             cnt <= {CNT_WIDTH{1'b0}};
//             ser_done <= 1'b0;
//         end
//     end
// end

// Output
always @(*) begin
    if (~RSTn) begin 
        TX_OUT = 1'b1; // IDLE
        BUSY = 1'b0;
    end
    else begin
        case (cs)
            IDLE : begin
                TX_OUT = 1'b1;
                BUSY = 1'b0;
            end

            START: begin
                BUSY = 1'b1;
                TX_OUT = 1'b0; // START BIT
            end
            TRANS: begin
                BUSY = 1'b1;
                TX_OUT = ser_bit;
            end

            PARITY: begin
                BUSY = 1'b1;
                TX_OUT = par_bit;
            end

            STOP: begin
                BUSY = 1'b1;
                TX_OUT = 1'b1;   // STOP BIT         
            end
        endcase
    end
end

endmodule 


module PISO 
#(
    parameter DATA_WIDTH = 8
)
(
    input   wire CLK,
    input   wire RSTn,

    input   wire EN,
    input   wire [DATA_WIDTH-1:0] DATA_IN,
    input   wire DATA_VALID,

    output  reg DONE,
    output  reg DATA_OUT
);

localparam CNT_WIDTH = $clog2 (DATA_WIDTH);

reg [DATA_WIDTH-1:0] reg_data;
reg [CNT_WIDTH-1:0] cnt;

always @(posedge CLK or negedge RSTn) begin
    if (!RSTn) begin
        DONE <= 1'b0;
        DATA_OUT <= 1'b0;
        cnt <= {CNT_WIDTH{1'b0}};
        reg_data <= {DATA_WIDTH{1'b0}};
    end
    else begin
        if (EN) begin
            DATA_OUT <= reg_data[0];
            reg_data <= reg_data >> 1;
            cnt <= cnt + 1;
            if (cnt == DATA_WIDTH-1)
                DONE <=  1'b1;
            else 
                DONE <= 1'b0;
        end
        else if (DATA_VALID) begin
            reg_data <= DATA_IN;
            cnt <= {CNT_WIDTH{1'b0}};
            DONE <= 1'b0;
        end
    end
end


endmodule