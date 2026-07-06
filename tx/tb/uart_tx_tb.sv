module tb_tx;


    // Parameters 
    parameter DATA_WIDTH = 8;
    localparam SER_CNT_WIDTH = $clog2(DATA_WIDTH);

    // Signals
    logic                      CLK = 1'b0;
    logic                      RSTn; // Asynchronus Reset - Active low
    logic                      PAR_TYP;
    logic                      PAR_EN;
    logic [DATA_WIDTH-1 : 0]   P_DATA;
    logic                      DATA_VALID;

    logic                      TX_OUT;
    logic                      BUSY;

    int error = 0;
    logic [SER_CNT_WIDTH-1:0] bit_idx = 0;

    // Clock Gen
    always #5 CLK = ~CLK;


    // Instantiation
    UART_TX #(.DATA_WIDTH(DATA_WIDTH)) dut (.*);


    // Clocking
    clocking cb @(posedge CLK);
        default input #1step output #0;
        input TX_OUT, BUSY;
        output PAR_EN, PAR_TYP, P_DATA, DATA_VALID;
    endclocking

    //Stim Gen

    task do_reset;
        RSTn <= 1'b0;
        PAR_EN <= 1'b0;
        P_DATA <= {DATA_WIDTH{1'b0}};
        PAR_TYP <= 1'b0;
        DATA_VALID <= 1'b0;
        repeat (3) @(posedge CLK);
        RSTn <= 1'b1;
        @(posedge CLK);
    endtask

    task send_byte (input int data, input logic parity_en, input logic parity_typ);
        @(posedge CLK);
        DATA_VALID <= 1'b1;
        P_DATA <= data;
        PAR_EN <= parity_en;
        PAR_TYP <= parity_typ;

        @(posedge CLK);

        DATA_VALID <= 0;

    endtask

    task automatic check_txn (input int exp_data, input logic parity_en, input logic parity_typ);

        bit par_bit = (parity_en) ? ( (parity_typ) ? (~(^exp_data[7:0])) : (^exp_data[7:0]) ) : (1'b0);
        int act_data = 0;
        bit_idx = 0;

        @(posedge CLK);

        while (!BUSY) @(posedge CLK);

        if (TX_OUT != 1'b0) begin
            $display("[%t] [TB] Start bit is not correct", $time);
            error ++;
        end

        repeat (DATA_WIDTH) begin
            @(posedge CLK);
            act_data[bit_idx] = TX_OUT;
            if (TX_OUT != exp_data[bit_idx]) begin
                $display("[%t] [TB] Bit %d is not correct, ACTUAL: %b, EXPECTED: %b ....... DATA: %b", $time, bit_idx ,TX_OUT, exp_data[bit_idx], exp_data);
                error ++;
            end
            // $display ("[%t] BIT_INDEX: %d, ACT_DATA: %b", $time, bit_idx, act_data);
            bit_idx ++;
        end
        // act_data[bit_idx] = TX_OUT;
        if (act_data != (exp_data & 32'h0000_00ff)) begin
                $display("[%t] [TB] TX_DATA is not correct, ACTUAL: %h, EXPECTED: %h", $time, act_data, (exp_data & 32'h0000_00ff));
                error ++;
        end

        @(posedge CLK);


        if (parity_en) begin
            if (TX_OUT != par_bit) begin
                $display("[%t] [TB] Parity bit is not correct, par_en: %b, par_typ: %s, par_bit: %b, TX_OUT: %b, Actual_Data: %b ,Expected_Data: %b", $time, parity_en, (parity_typ) ? "ODD": "EVEN", par_bit, TX_OUT, act_data[7:0], exp_data[7:0]);
                error ++;
            end
            @(posedge CLK);
        end


        if (TX_OUT != 1'b1) begin
            $display("[%t] [TB] Stop bit is not correct", $time);
            error ++;
        end

    endtask

    task test_byte(input int data, input logic parity_en, input logic parity_typ);
        begin
            send_byte(data, parity_en, parity_typ);
            check_txn(data, parity_en, parity_typ);
        end
    endtask


    int i;
    initial begin
        do_reset;

        $display("=== Test 1: No parity ===");
        test_byte(8'hFF, 0, 0);
        test_byte(8'hA5, 0, 0);
        test_byte(8'h55, 0, 0);

        $display("=== Test 2: Even parity ===");
        test_byte(8'h00, 1, 0);
        test_byte(8'h01, 1, 0);
        test_byte(8'hFF, 1, 0);
        test_byte(8'hA5, 1, 0);

        $display("=== Test 3: Odd parity ===");
        test_byte(8'h00, 1, 1);
        test_byte(8'h01, 1, 1);
        test_byte(8'hFF, 1, 1);
        test_byte(8'hA5, 1, 1);

        $display("=== Test 4: Back-to-back frames (ser_done reload / re-latch check) ===");
        test_byte(8'h3C, 0, 0);
        test_byte(8'hC3, 1, 0);
        test_byte(8'h81, 1, 1);
        test_byte(8'h00, 0, 0);

        $display("=== Test 5: Randomized ===");
        for (i = 0; i < 15; i = i + 1) begin
            test_byte($random, $random & 1, $random & 1);
        end

        $display("========================================");
        $display("ERRORS: %0d", error);
        if (error == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** TESTS FAILED ***");
        $finish;
    end

endmodule 
