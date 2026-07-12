module tb_rx;

    // Parameters
    parameter DATA_WIDTH = 8;
    localparam SER_CNT_WIDTH = $clog2(DATA_WIDTH);

    // Signals
    logic                     CLK = 1'b0;
    logic                     RSTn;          // Asynchronous Reset - Active low
    logic                     PAR_TYP;
    logic                     PAR_EN;
    logic [5:0]               PRESCALE;
    logic                     RX_IN;

    logic [DATA_WIDTH-1:0]    P_DATA;
    logic                     DATA_VALID;
    logic                     PARITY_ERR;
    logic                     STOP_ERR;

    int error = 0;
    logic [SER_CNT_WIDTH-1:0] bit_idx = 0;

    // Clock Gen
    always #1 CLK = ~CLK;

    event e;

    // Instantiation
    // NOTE: adjust port names here if your top-level UART_RX differs
    UART_RX dut (.*);

    // Clocking
    clocking cb @(posedge CLK);
        default input #1step output #0;
        input  P_DATA, DATA_VALID, PARITY_ERR, STOP_ERR;
        output RX_IN, PAR_EN, PAR_TYP, PRESCALE;
    endclocking

    // Stim Gen

    task do_reset;
        RSTn     <= 1'b0;
        RX_IN    <= 1'b1;      // idle line is high
        PAR_EN   <= 1'b0;
        PAR_TYP  <= 1'b0;
        PRESCALE <= 6'd8;
        repeat (3) @(cb);
        RSTn <= 1'b1;
        @(cb);
    endtask

    // Drives one full UART frame onto RX_IN, bit-accurate to PRESCALE timing.
    // corrupt_parity / corrupt_stop let us intentionally break a frame to
    // exercise PARITY_ERR / STOP_ERR detection.
    task automatic send_frame(input int data, input logic parity_en, input logic parity_typ,
                              input bit corrupt_parity = 0, input bit corrupt_stop = 0, input bit back_to_idle = 1'b1);
        bit par_bit;
        int p;

        par_bit = (parity_typ) ? (~(^data[7:0])) : (^data[7:0]);
        if (corrupt_parity) par_bit = ~par_bit;

        // Start bit
        RX_IN <= 1'b0;
        repeat (PRESCALE) @(cb);

        // Data bits, LSB first
        for (p = 0; p < DATA_WIDTH; p++) begin
            RX_IN <= data[p];
            repeat (PRESCALE) @(cb);
        end

        // Parity bit (if enabled)
        if (parity_en) begin
            RX_IN <= par_bit;
            repeat (PRESCALE) @(cb);
        end

        // Stop bit
        RX_IN <= corrupt_stop ? 1'b0 : 1'b1;
        repeat (PRESCALE) @(cb);


        RX_IN <= 1'b1;
    endtask

    // Waits for DATA_VALID pulse and checks P_DATA / error flags against expectation.
    // If we expect an error frame, we don't require DATA_VALID (spec: no valid pulse
    // on a corrupted frame) -- instead we check the error flag directly after the frame.
    task automatic check_frame(input int exp_data, input logic parity_en, input logic parity_typ,
                                input bit expect_PARITY_ERR = 0, input bit expect_STOP_ERR = 0);
        
        if (!expect_PARITY_ERR && !expect_STOP_ERR) begin
            if (!cb.DATA_VALID) begin
                $display("[%t] [TB] TIMEOUT waiting for DATA_VALID, DATA: %h", $time, exp_data);
                error++;
                return;
            end

            if (cb.P_DATA != (exp_data & 8'hFF)) begin
                $display("[%t] [TB] P_DATA mismatch, ACTUAL: %h, EXPECTED: %h", $time, cb.P_DATA, exp_data & 8'hFF);
                error++;
            end

            if (cb.PARITY_ERR != 1'b0) begin
                $display("[%t] [TB] Unexpected PARITY_ERR high on good frame, DATA: %h", $time, exp_data);
                error++;
            end

            if (cb.STOP_ERR != 1'b0) begin
                $display("[%t] [TB] Unexpected STOP_ERR high on good frame, DATA: %h", $time, exp_data);
                error++;
            end
        end
        else begin
            // Corrupted frame: DATA_VALID must NOT pulse; error flag(s) must be set
            if (expect_PARITY_ERR && !cb.PARITY_ERR) begin
                $display("[%t] [TB] Expected PARITY_ERR not seen, DATA: %h", $time, exp_data);
                error++;
            end
            if (expect_STOP_ERR && !cb.STOP_ERR) begin
                $display("[%t] [TB] Expected STOP_ERR not seen", $time);
                error++;
            end
        end
    endtask

    task automatic test_byte(input int data, input logic parity_en, input logic parity_typ,
                              input bit corrupt_parity = 0, input bit corrupt_stop = 0);
        cb.PAR_EN  <= parity_en;
        cb.PAR_TYP <= parity_typ;
        send_frame(data, parity_en, parity_typ, corrupt_parity, corrupt_stop);
        check_frame(data, parity_en, parity_typ, corrupt_parity, corrupt_stop);
    endtask

    int i;
    initial begin
        do_reset;

        $display("[%t] [TB] === Test 1: No parity ===", $time);
        test_byte(8'hAA, 0, 0);
        $display("[%t] [TB]=== Test 1.1:DONE ===", $time);
        test_byte(8'hA5, 0, 0);
        $display("[%t] [TB]=== Test 1.2:DONE ===", $time);
        test_byte(8'h55, 0, 0);
        $display("[%t] [TB]=== Test 1.3:DONE ===", $time);

        $display("[%t] [TB] === Test 2: Even parity ===", $time);
        test_byte(8'h00, 1, 0);
        $display("[%t] [TB]=== Test 2.1:DONE ===", $time);
        test_byte(8'h01, 1, 0);
        $display("[%t] [TB]=== Test 2.2:DONE ===", $time);
        test_byte(8'hFF, 1, 0);
        $display("[%t] [TB]=== Test 2.3:DONE ===", $time);
        test_byte(8'hA5, 1, 0);
        $display("[%t] [TB]=== Test 2.4:DONE ===", $time);

        $display("[%t] [TB] === Test 3: Odd parity ===", $time);
        test_byte(8'h00, 1, 1);
        test_byte(8'h01, 1, 1);
        test_byte(8'hFF, 1, 1);
        test_byte(8'hA5, 1, 1);

        $display("[%t] [TB] === Test 4: Back-to-back frames (no idle gap) ===", $time);
        PAR_EN  <= 1'b0;
        PAR_TYP <= 1'b0;

        send_frame(8'h3C, 0, 0, 0, 0, 0);
        check_frame(8'h3C, 0, 0);
        send_frame(8'hC3, 0, 0, 0, 0, 0);
        check_frame(8'hC3, 0, 0);
        send_frame(8'h81, 0, 0, 0, 0, 0);
        check_frame(8'h81, 0, 0);



        $display("[%t] [TB]=== Test 5: Corrupted parity bit (expect PARITY_ERR, no DATA_VALID) ===", $time);
        test_byte(8'hA5, 1, 0, 1, 0);  // even parity, force wrong parity bit

        $display("[%t] [TB] === Test 6: Corrupted stop bit (expect STOP_ERR, no DATA_VALID) ===", $time);
        test_byte(8'h5A, 0, 0, 0, 1);  // no parity, force stop bit low


        $display("[%t] [TB] === Test 7: Different Prescale values ===", $time);
        do_reset;
        PRESCALE = 6'd16;
        test_byte(8'h42, 1, 1);
        PRESCALE = 6'd32;
        test_byte(8'h99, 1, 0);

        $display("[%t] [TB] === Test 8: Randomized ===", $time);
        do_reset;
        PRESCALE <= 6'd8;
        for (i = 0; i < 15; i = i + 1) begin
            test_byte($random, $random & 1'b1, $random & 1'b1);
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