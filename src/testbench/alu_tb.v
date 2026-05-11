`timescale 1ns/1ps
`include "alu_main.v"

module alu_tb;

    parameter N = 8;
    parameter C = 4;

    reg  [N-1:0]   OPA, OPB;
    reg            CIN, CLK, RST, CE, MODE;
    reg  [1:0]     INP_VALID;
    reg  [C-1:0]   CMD;

    wire [2*N-1:0] RES;
    wire           ERR, OFLOW, COUT;
    wire           G, L, E;

    reg  [2*N-1:0] ref_RES;
    reg            ref_ERR, ref_OFLOW, ref_COUT;
    reg            ref_G, ref_L, ref_E;

    integer pass_count;
    integer fail_count;
    integer test_num;         // current test ID

    // DUT instantiation
    alu_main #(.N(N), .C(C)) DUT (
        .OPA(OPA), .OPB(OPB), .CIN(CIN),
        .CLK(CLK), .RST(RST), .CE(CE),
        .MODE(MODE), .INP_VALID(INP_VALID), .CMD(CMD),
        .RES(RES), .OFLOW(OFLOW), .COUT(COUT),
        .G(G), .L(L), .E(E), .ERR(ERR)
    );

    // Clock generation : 10 ns period
    initial CLK = 0;
    always #5 CLK = ~CLK;

    task ref_model;
        input [N-1:0]  a, b;
        input          cin;
        input          mode;
        input [1:0]    iv;    // INP_VALID
        input [C-1:0]  cmd;
        begin
            ref_RES   = {(2*N){1'b0}};
            ref_ERR   = 1'b0;
            ref_OFLOW = 1'b0;
            ref_COUT  = 1'b0;
            ref_G = 1'b0; ref_L = 1'b0; ref_E = 1'b0;

            if (mode) begin  // ---- ARITHMETIC ----
                case (cmd)
                    4'd0: begin   // unsigned ADD
                        ref_RES = a + b;
                        ref_ERR = (iv == 2'b11) ? 0 : 1;
                        ref_COUT = ref_RES[N];
                    end
                    4'd1: begin   // unsigned SUB
                        ref_RES   = a - b;
                        ref_ERR   = (iv == 2'b11) ? 0 : 1;
                        ref_OFLOW = ~ref_RES[N];
                    end
                    4'd2: begin   // ADD with CIN
                        ref_RES  = a + b + cin;
                        ref_ERR  = (iv == 2'b11) ? 0 : 1;
                        ref_COUT = ref_RES[N];
                    end
                    4'd3: begin   // SUB with CIN
                        ref_RES   = a - b - cin;
                        ref_ERR   = (iv == 2'b11) ? 0 : 1;
                        ref_OFLOW = ~ref_RES[N];
                    end
                    4'd4: begin   // INC_A
                        ref_RES = a + 1;
                        ref_ERR = iv[0] ? 0 : 1;
                    end
                    4'd5: begin   // DEC_A
                        ref_RES = a - 1;
                        ref_ERR = iv[0] ? 0 : 1;
                    end
                    4'd6: begin   // INC_B
                        ref_RES = b + 1;
                        ref_ERR = iv[1] ? 0 : 1;
                    end
                    4'd7: begin   // DEC_B
                        ref_RES = b - 1;
                        ref_ERR = iv[1] ? 0 : 1;
                    end
                    4'd8: begin   // Comparator (combinatorial assign)
                        ref_ERR = (iv == 2'b11) ? 0 : 1;
                        ref_G = ($signed(a) > $signed(b));
                        ref_L = ($signed(a) < $signed(b));
                        ref_E = ($signed(a) == $signed(b));
                    end
                    // CMD9 & CMD10: multi-cycle; handled by dedicated tasks
                    4'd11: begin  // Signed ADD
                        ref_RES = $signed({{8{a[N-1]}},a}) + $signed({{8{b[N-1]}},b});
                        ref_ERR = (iv == 2'b11) ? 0 : 1;
                        ref_OFLOW = ~ref_RES[N];
                    end
                    4'd12: begin  // Signed SUB
                        ref_RES = $signed({{8{a[N-1]}},a}) - $signed({{8{b[N-1]}},b});
                        ref_ERR = (iv == 2'b11) ? 0 : 1;
                        ref_OFLOW = ~ref_RES[N];
                    end
                    default: ; // hold previous (not checked in these tests)
                endcase
            end else begin  // ---- LOGICAL ----
                case (cmd)
                    4'd0: begin   // AND
                        ref_RES = {{N{1'b0}}, a & b};
                        ref_ERR = (iv == 2'b11) ? 0 : 1;
                    end
                    4'd1: begin   // NAND
                        ref_RES = {{N{1'b0}}, ~(a & b)};
                        ref_ERR = (iv == 2'b11) ? 0 : 1;
                    end
                    4'd2: begin   // OR
                        ref_RES = {{N{1'b0}}, a | b};
                        ref_ERR = (iv == 2'b11) ? 0 : 1;
                    end
                    4'd3: begin   // NOR
                        ref_RES = {{N{1'b0}}, ~(a | b)};
                        ref_ERR = (iv == 2'b11) ? 0 : 1;
                    end
                    4'd4: begin   // XOR
                        ref_RES = {{N{1'b0}}, a ^ b};
                        ref_ERR = (iv == 2'b11) ? 0 : 1;
                    end
                    4'd5: begin   // XNOR
                        ref_RES = {{N{1'b0}}, ~(a ^ b)};
                        ref_ERR = (iv == 2'b11) ? 0 : 1;
                    end
                    4'd6: begin   // NOT A
                        ref_RES = {{N{1'b0}}, ~a};
                        ref_ERR = iv[0] ? 0 : 1;
                    end
                    4'd7: begin   // NOT B
                        ref_RES = {{N{1'b0}}, ~b};
                        ref_ERR = iv[1] ? 0 : 1;
                    end
                    4'd8: begin   // Right Shift A by 1
                        ref_RES = {{N{1'b0}}, a >> 1};
                        ref_ERR = iv[0] ? 0 : 1;
                    end
                    4'd9: begin   // Left Shift A by 1
                        ref_RES = {{N{1'b0}}, a[N-2:0], 1'b0};
                        ref_ERR = iv[0] ? 0 : 1;
                    end
                    4'd10: begin  // Right Shift B by 1
                        ref_RES = {{N{1'b0}}, b >> 1};
                        ref_ERR = iv[1] ? 0 : 1;
                    end
                    4'd11: begin  // Left Shift B by 1
                        ref_RES = {{N{1'b0}}, b[N-2:0], 1'b0};
                        ref_ERR = iv[1] ? 0 : 1;
                    end
                    4'd12: begin  // Variable Left Shift A by OPB[2:0]
                        ref_RES = {{N{1'b0}}, a << b[2:0]};
                        ref_ERR = ((b[N-1:3] > 0) || (iv != 2'b11)) ? 1 : 0;
                    end
                    4'd13: begin  // Variable Right Shift A by OPB[2:0]
                        ref_RES = {{N{1'b0}}, a >> b[2:0]};
                        ref_ERR = ((b[N-1:3] > 0) || (iv != 2'b11)) ? 1 : 0;
                    end
                    default: ;
                endcase
            end
        end
    endtask

    // Helper: apply stimulus for single-cycle ops, clock once,
    task apply_and_check;
        input [63:0]  tid;       // test number (for display)
        input [N-1:0] a, b;
        input         cin;
        input         mode;
        input [1:0]   iv;
        input [C-1:0] cmd;
        // which outputs to check (bit flags)
        input         chk_res;
        input         chk_err;
        input         chk_cout;
        input         chk_oflow;
        input         chk_gle;
        begin
            // Drive inputs
            OPA       = a;
            OPB       = b;
            CIN       = cin;
            MODE      = mode;
            INP_VALID = iv;
            CMD       = cmd;

            // Compute expected
            ref_model(a, b, cin, mode, iv, cmd);

            // Clock rising edge
            @(posedge CLK); #1;

            // Compare
            check_outputs(tid, chk_res, chk_err, chk_cout, chk_oflow, chk_gle);
        end
    endtask

    // Check outputs and print PASS/FAIL
    task check_outputs;
        input [63:0] tid;
        input        chk_res, chk_err, chk_cout, chk_oflow, chk_gle;
        reg          ok;
        begin
            ok = 1;
            if (chk_res   && (RES   !== ref_RES))   begin ok=0; $display("  FAIL T-%0d: RES    got=%h exp=%h", tid, RES, ref_RES); end
            if (chk_err   && (ERR   !== ref_ERR))   begin ok=0; $display("  FAIL T-%0d: ERR    got=%b exp=%b", tid, ERR, ref_ERR); end
            if (chk_cout  && (COUT  !== ref_COUT))  begin ok=0; $display("  FAIL T-%0d: COUT   got=%b exp=%b", tid, COUT, ref_COUT); end
            if (chk_oflow && (OFLOW !== ref_OFLOW)) begin ok=0; $display("  FAIL T-%0d: OFLOW  got=%b exp=%b", tid, OFLOW, ref_OFLOW); end
            if (chk_gle   && ({G,L,E} !== {ref_G,ref_L,ref_E})) begin
                ok=0;
                $display("  FAIL T-%0d: GLE    got=%b%b%b exp=%b%b%b", tid, G,L,E, ref_G,ref_L,ref_E);
            end
            if (ok) begin
                pass_count = pass_count + 1;
                $display("  PASS T-%0d", tid);
            end else begin
                fail_count = fail_count + 1;
            end
        end
    endtask

    task apply_inc_mul;
        input [63:0]  tid;
        input [N-1:0] a, b;
        input [1:0]   iv;
        reg [2*N-1:0] exp_res;
        reg           exp_err;
        begin
            exp_res = (a + 1) * (b + 1);
            exp_err = (iv == 2'b11) ? 0 : 1;

            MODE      = 1;
            CMD       = 4'd9;
            OPA       = a;
            OPB       = b;
            INP_VALID = iv;
            CIN       = 0;

            // 3 clock cycles to produce result
            @(posedge CLK); #1;
            @(posedge CLK); #1;
            @(posedge CLK); #1;

            if (RES === exp_res && ERR === exp_err) begin
                pass_count = pass_count + 1;
                $display("  PASS T-%0d", tid);
            end else begin
                fail_count = fail_count + 1;
                if (RES !== exp_res)   $display("  FAIL T-%0d: INC_MUL RES got=%h exp=%h", tid, RES, exp_res);
                if (ERR !== exp_err)   $display("  FAIL T-%0d: INC_MUL ERR got=%b exp=%b", tid, ERR, exp_err);
            end
        end
    endtask

    task apply_shf_mul;
        input [63:0]  tid;
        input [N-1:0] a, b;
        input [1:0]   iv;
        reg [2*N-1:0] exp_res;
        begin
            exp_res = (a << 1) * b;

            MODE      = 1;
            CMD       = 4'd10;
            OPA       = a;
            OPB       = b;
            INP_VALID = iv;
            CIN       = 0;

            @(posedge CLK); #1;
            @(posedge CLK); #1;
            @(posedge CLK); #1;

            if (RES === exp_res) begin
                pass_count = pass_count + 1;
                $display("  PASS T-%0d", tid);
            end else begin
                fail_count = fail_count + 1;
                $display("  FAIL T-%0d: SHF_MUL RES got=%h exp=%h", tid, RES, exp_res);
            end
        end
    endtask

    initial begin
        // Initialise
        pass_count = 0;
        fail_count = 0;
        OPA=0; OPB=0; CIN=0; RST=0; CE=1; MODE=1; INP_VALID=2'b11; CMD=0;

        $display("=================================================");
        $display("         ALU Self-Checking Testbench");
        $display("=================================================");

        // ---- GROUP 1 : Reset & Control ----
        $display("\n--- Reset & Control ---");

        // T-01-01 : Normal RST
        RST=1; CE=1;
        @(posedge CLK); #1;
        if (RES===0 && ERR===0) begin
            pass_count=pass_count+1; $display("  PASS T-1");
        end else begin
            fail_count=fail_count+1; $display("  FAIL T-1 RST: RES=%h ERR=%b", RES, ERR);
        end
        RST=0;

        // T-01-02 : RST during active op
        OPA=100; OPB=55; MODE=1; CMD=0; INP_VALID=2'b11;
        @(posedge CLK); #1;  // one ADD clock
        RST=1;
        @(posedge CLK); #1;
        if (RES===0 && ERR===0) begin
            pass_count=pass_count+1; $display("  PASS T-2");
        end else begin
            fail_count=fail_count+1; $display("  FAIL T-2 RST-during-op: RES=%h ERR=%b", RES, ERR);
        end
        RST=0;

        // T-01-03 : CE=0 holds previous value
        OPA=50; OPB=50; MODE=1; CMD=0; INP_VALID=2'b11; CE=1;
        @(posedge CLK); #1;
        begin: t3_blk
            reg [2*N-1:0] held_res;
            held_res = RES;
            CE=0; OPA=10; OPB=10;
            @(posedge CLK); #1;
            if (RES === held_res) begin
                pass_count=pass_count+1; $display("  PASS T-3");
            end else begin
                fail_count=fail_count+1; $display("  FAIL T-3 CE=0: RES changed to %h (was %h)", RES, held_res);
            end
        end
        CE=1;

        // T-01-04 : CE=1 normal operation
        OPA=10; OPB=10; MODE=1; CMD=0; INP_VALID=2'b11;
        @(posedge CLK); #1;
        if (RES === 16'h0014 && ERR===0) begin
            pass_count=pass_count+1; $display("  PASS T-4");
        end else begin
            fail_count=fail_count+1; $display("  FAIL T-4 CE=1: RES=%h ERR=%b", RES, ERR);
        end

        // ---- GROUP 2 : Unsigned Addition ----
        $display("\n--- Unsigned Addition ---");
        //        tid  a    b    cin  mode iv       cmd   res  err  cout oflow gle
        apply_and_check(201, 100, 55,  0, 1, 2'b11, 0,    1,   1,   1,   0,   0);
        apply_and_check(202,   0,  0,  0, 1, 2'b11, 0,    1,   1,   1,   0,   0);
        apply_and_check(203,   0,255,  0, 1, 2'b11, 0,    1,   1,   1,   0,   0);
        apply_and_check(204, 255,  1,  0, 1, 2'b11, 0,    1,   1,   1,   0,   0);
        apply_and_check(205, 255,255,  0, 1, 2'b11, 0,    1,   1,   1,   0,   0);
        apply_and_check(206,  10,  5,  0, 1, 2'b01, 0,    1,   1,   0,   0,   0);
        apply_and_check(207,  10,  5,  0, 1, 2'b10, 0,    1,   1,   0,   0,   0);
        apply_and_check(208,  10,  5,  0, 1, 2'b00, 0,    1,   1,   0,   0,   0);

        // ---- GROUP 3 : Unsigned Subtraction ----
        $display("\n--- Unsigned Subtraction ---");
        apply_and_check(301, 100, 40,  0, 1, 2'b11, 1,    1,   1,   0,   1,   0);
        apply_and_check(302,   0,  0,  0, 1, 2'b11, 1,    1,   1,   0,   1,   0);
        apply_and_check(303, 255,255,  0, 1, 2'b11, 1,    1,   1,   0,   1,   0);
        apply_and_check(304,   0,255,  0, 1, 2'b11, 1,    0,   1,   0,   1,   0); // only OFLOW check
        apply_and_check(305,  50, 20,  0, 1, 2'b00, 1,    1,   1,   0,   0,   0);

        // ---- GROUP 4 : Addition with CIN ----
        $display("\n--- Addition with CIN ---");
        apply_and_check(401,  50, 50,  1, 1, 2'b11, 2,    1,   1,   1,   0,   0);
        apply_and_check(402,  50, 50,  0, 1, 2'b11, 2,    1,   1,   1,   0,   0);
        apply_and_check(403,   0,  0,  1, 1, 2'b11, 2,    1,   1,   1,   0,   0);
        apply_and_check(404, 255,255,  1, 1, 2'b11, 2,    1,   1,   1,   0,   0);
        apply_and_check(405,  10,  5,  1, 1, 2'b01, 2,    1,   1,   0,   0,   0);

        // ---- GROUP 5 : Subtraction with CIN ----
        $display("\n--- Subtraction with CIN ---");
        apply_and_check(501, 100, 30,  1, 1, 2'b11, 3,    1,   1,   0,   1,   0);
        apply_and_check(502, 100, 30,  0, 1, 2'b11, 3,    1,   1,   0,   1,   0);
        apply_and_check(503,   0,  0,  0, 1, 2'b11, 3,    1,   1,   0,   1,   0);
        apply_and_check(504,   0,  0,  1, 1, 2'b11, 3,    0,   1,   0,   1,   0); // only OFLOW
        apply_and_check(505,  50, 20,  0, 1, 2'b10, 3,    0,   1,   0,   0,   0); // only ERR

        // ---- GROUP 6 : Increment A ----
        $display("\n--- Increment A ---");
        apply_and_check(601,   0,  0,  0, 1, 2'b01, 4,    1,   1,   0,   0,   0);
        apply_and_check(602, 127,  0,  0, 1, 2'b01, 4,    1,   1,   0,   0,   0);
        apply_and_check(603, 255,  0,  0, 1, 2'b01, 4,    1,   1,   0,   0,   0);
        apply_and_check(604,  10,8'hFF,0,1, 2'b01, 4,    1,   1,   0,   0,   0);
        apply_and_check(605,  10,  0,  0, 1, 2'b10, 4,    1,   1,   0,   0,   0);

        // ---- GROUP 7 : Decrement A ----
        $display("\n--- Decrement A ---");
        apply_and_check(701,  10,  0,  0, 1, 2'b01, 5,    1,   1,   0,   0,   0);
        apply_and_check(702,   1,  0,  0, 1, 2'b01, 5,    1,   1,   0,   0,   0);
        apply_and_check(703,   0,  0,  0, 1, 2'b01, 5,    1,   1,   0,   0,   0);
        apply_and_check(704,   5,  0,  0, 1, 2'b10, 5,    1,   1,   0,   0,   0);

        // ---- GROUP 8 : Increment B ----
        $display("\n--- Increment B ---");
        apply_and_check(801,   0,  0,  0, 1, 2'b10, 6,    1,   1,   0,   0,   0);
        apply_and_check(802,   0,255,  0, 1, 2'b10, 6,    1,   1,   0,   0,   0);
        apply_and_check(803,8'hFF,10,  0, 1, 2'b10, 6,    1,   1,   0,   0,   0);
        apply_and_check(804,   0, 10,  0, 1, 2'b01, 6,    1,   1,   0,   0,   0);

        // ---- GROUP 9 : Decrement B ----
        $display("\n--- Decrement B ---");
        apply_and_check(901,   0, 10,  0, 1, 2'b10, 7,    1,   1,   0,   0,   0);
        apply_and_check(902,   0,  1,  0, 1, 2'b10, 7,    1,   1,   0,   0,   0);
        apply_and_check(903,   0,  0,  0, 1, 2'b10, 7,    1,   1,   0,   0,   0);
        apply_and_check(904,   0,  5,  0, 1, 2'b01, 7,    1,   1,   0,   0,   0);

        // ---- GROUP 10 : Signed Comparator ----
        $display("\n--- Signed Comparator ---");
        apply_and_check(1001, 8'h32, 8'h14, 0, 1, 2'b11, 8,   0, 1, 0, 0, 1);
        apply_and_check(1002, 8'h0A, 8'h64, 0, 1, 2'b11, 8,   0, 1, 0, 0, 1);
        apply_and_check(1003, 8'h4D, 8'h4D, 0, 1, 2'b11, 8,   0, 1, 0, 0, 1);
        apply_and_check(1004,     0,     0,  0, 1, 2'b11, 8,   0, 1, 0, 0, 1);
        apply_and_check(1005, 8'h0A, 8'h8A, 0, 1, 2'b11, 8,   0, 1, 0, 0, 1);
        apply_and_check(1006, 8'h8A, 8'h0A, 0, 1, 2'b11, 8,   0, 1, 0, 0, 1);
        apply_and_check(1007, 8'h32, 8'h14, 0, 1, 2'b00, 8,   0, 1, 0, 0, 1);

        // ---- GROUP 11 : INC & Multiply ----
        $display("\n--- INC & Multiply ---");
        apply_inc_mul(1101,  4,  3, 2'b11);
        apply_inc_mul(1102,  0,  0, 2'b11);
        apply_inc_mul(1103,  1,  1, 2'b11);
        apply_inc_mul(1104,  7,  7, 2'b11);
        apply_inc_mul(1105,127,127, 2'b11);
        apply_inc_mul(1106,  4,  3, 2'b00); // ERR=1

        // ---- GROUP 12 : Shift & Multiply ----
        $display("\n--- Shift & Multiply ---");
        apply_shf_mul(1201,  4,  3, 2'b11);
        apply_shf_mul(1202,  0,  0, 2'b11);
        apply_shf_mul(1203,  0, 10, 2'b11);
        apply_shf_mul(1204, 10,  0, 2'b11);
        apply_shf_mul(1205,  1,  7, 2'b11);

        // T-12-06: CMD switch mid-pipeline resets
        $display("  (T-12-06: CMD switch -> ADD)");
        MODE=1; CMD=4'd9; OPA=8'h0A; OPB=8'h0A; INP_VALID=2'b11;
        @(posedge CLK); #1;       // tick 1 with CMD=9
        CMD=4'd0;                  // switch to ADD
        OPA=10; OPB=10;
        @(posedge CLK); #1;
        if (RES === 16'h0014 && ERR===0) begin
            pass_count=pass_count+1; $display("  PASS T-1206");
        end else begin
            fail_count=fail_count+1; $display("  FAIL T-1206: RES=%h ERR=%b", RES, ERR);
        end

        // ---- GROUP 13 : Signed Addition ----
        $display("\n--- Signed Addition ---");
        apply_and_check(1301, 8'h0A, 8'h05, 0, 1, 2'b11, 11,  1, 1, 0, 0, 0);
        apply_and_check(1302, 8'h00, 8'h00, 0, 1, 2'b11, 11,  1, 1, 0, 0, 0);
        apply_and_check(1303, 8'h7F, 8'h7F, 0, 1, 2'b11, 11,  1, 1, 0, 0, 0);
        apply_and_check(1304, 8'h8A, 8'h85, 0, 1, 2'b11, 11,  1, 1, 0, 0, 0);  // -118 + -123

        // ---- GROUP 14 : Signed Subtraction ----
        $display("\n--- Signed Subtraction ---");
        apply_and_check(1401, 8'h3C, 8'h28, 0, 1, 2'b11, 12,  1, 1, 0, 0, 0);
        apply_and_check(1402, 8'h00, 8'h00, 0, 1, 2'b11, 12,  1, 1, 0, 0, 0);
        apply_and_check(1403, 8'h0A, 8'h14, 0, 1, 2'b11, 12,  1, 1, 0, 0, 0);
        apply_and_check(1404, 8'h8A, 8'h85, 0, 1, 2'b11, 12,  1, 1, 0, 0, 0);
        apply_and_check(1405, 8'h0A, 8'h05, 0, 1, 2'b01, 12,  0, 1, 0, 0, 0); // ERR only

        // ---- GROUP 15 : AND ----
        $display("\n--- AND ---");
        apply_and_check(1501, 8'hAA, 8'hF0, 0, 0, 2'b11, 0,  1, 1, 0, 0, 0);
        apply_and_check(1502, 8'hFF, 8'hFF, 0, 0, 2'b11, 0,  1, 1, 0, 0, 0);
        apply_and_check(1503, 8'h00, 8'hFF, 0, 0, 2'b11, 0,  1, 1, 0, 0, 0);
        apply_and_check(1504, 8'hAA, 8'h55, 0, 0, 2'b11, 0,  1, 1, 0, 0, 0);
        apply_and_check(1505, 8'hAA, 8'h55, 0, 0, 2'b00, 0,  1, 1, 0, 0, 0);

        // ---- GROUP 16 : NAND ----
        $display("\n--- NAND ---");
        apply_and_check(1601, 8'hFF, 8'hFF, 0, 0, 2'b11, 1,  1, 1, 0, 0, 0);
        apply_and_check(1602, 8'h00, 8'h00, 0, 0, 2'b11, 1,  1, 1, 0, 0, 0);
        apply_and_check(1603, 8'hAA, 8'h55, 0, 0, 2'b11, 1,  1, 1, 0, 0, 0);

        // ---- GROUP 17 : OR ----
        $display("\n--- OR ---");
        apply_and_check(1701, 8'hAA, 8'h55, 0, 0, 2'b11, 2,  1, 1, 0, 0, 0);
        apply_and_check(1702, 8'h00, 8'h00, 0, 0, 2'b11, 2,  1, 1, 0, 0, 0);
        apply_and_check(1703, 8'hFF, 8'h00, 0, 0, 2'b11, 2,  1, 1, 0, 0, 0);

        // ---- GROUP 18 : NOR ----
        $display("\n--- NOR ---");
        apply_and_check(1801, 8'h00, 8'h00, 0, 0, 2'b11, 3,  1, 1, 0, 0, 0);
        apply_and_check(1802, 8'hFF, 8'hFF, 0, 0, 2'b11, 3,  1, 1, 0, 0, 0);
        apply_and_check(1803, 8'hAA, 8'h55, 0, 0, 2'b11, 3,  1, 1, 0, 0, 0);

        // ---- GROUP 19 : XOR ----
        $display("\n--- XOR ---");
        apply_and_check(1901, 8'hAA, 8'hAA, 0, 0, 2'b11, 4,  1, 1, 0, 0, 0);
        apply_and_check(1902, 8'hAA, 8'h55, 0, 0, 2'b11, 4,  1, 1, 0, 0, 0);
        apply_and_check(1903, 8'h00, 8'hFF, 0, 0, 2'b11, 4,  1, 1, 0, 0, 0);
        apply_and_check(1904, 8'hFF, 8'hFF, 0, 0, 2'b11, 4,  1, 1, 0, 0, 0);

        // ---- GROUP 20 : XNOR ----
        $display("\n--- XNOR ---");
        apply_and_check(2001, 8'hAA, 8'hAA, 0, 0, 2'b11, 5,  1, 1, 0, 0, 0);
        apply_and_check(2002, 8'hAA, 8'h55, 0, 0, 2'b11, 5,  1, 1, 0, 0, 0);
        apply_and_check(2003, 8'h00, 8'hFF, 0, 0, 2'b11, 5,  1, 1, 0, 0, 0);

        // ---- GROUP 21 : NOT A ----
        $display("\n--- NOT A ---");
        apply_and_check(2101, 8'h00, 8'h00, 0, 0, 2'b01, 6,  1, 1, 0, 0, 0);
        apply_and_check(2102, 8'hFF, 8'h00, 0, 0, 2'b01, 6,  1, 1, 0, 0, 0);
        apply_and_check(2103, 8'hAA, 8'hFF, 0, 0, 2'b01, 6,  1, 1, 0, 0, 0);
        apply_and_check(2104, 8'hAA, 8'h00, 0, 0, 2'b10, 6,  1, 1, 0, 0, 0);

        // ---- GROUP 22 : NOT B ----
        $display("\n--- NOT B ---");
        apply_and_check(2201, 8'h00, 8'h00, 0, 0, 2'b10, 7,  1, 1, 0, 0, 0);
        apply_and_check(2202, 8'h00, 8'hFF, 0, 0, 2'b10, 7,  1, 1, 0, 0, 0);
        apply_and_check(2203, 8'hFF, 8'hAA, 0, 0, 2'b10, 7,  1, 1, 0, 0, 0);
        apply_and_check(2204, 8'h00, 8'hAA, 0, 0, 2'b01, 7,  1, 1, 0, 0, 0);

        // ---- GROUP 23 : Right Shift A ----
        $display("\n--- Right Shift A ---");
        apply_and_check(2301, 8'hAA, 0, 0, 0, 2'b01, 8,  1, 1, 0, 0, 0);
        apply_and_check(2302, 8'hFF, 0, 0, 0, 2'b01, 8,  1, 1, 0, 0, 0);
        apply_and_check(2303, 8'h01, 0, 0, 0, 2'b01, 8,  1, 1, 0, 0, 0);
        apply_and_check(2304, 8'h00, 0, 0, 0, 2'b01, 8,  1, 1, 0, 0, 0);
        apply_and_check(2305, 8'hAA, 0, 0, 0, 2'b10, 8,  1, 1, 0, 0, 0);

        // ---- GROUP 24 : Left Shift A ----
        $display("\n--- Left Shift A ---");
        apply_and_check(2401, 8'h55, 0, 0, 0, 2'b01, 9,  1, 1, 0, 0, 0);
        apply_and_check(2402, 8'h80, 0, 0, 0, 2'b01, 9,  1, 1, 0, 0, 0);
        apply_and_check(2403, 8'h01, 0, 0, 0, 2'b01, 9,  1, 1, 0, 0, 0);
        apply_and_check(2404, 8'hFF, 0, 0, 0, 2'b01, 9,  1, 1, 0, 0, 0);

        // ---- GROUP 25 : Right Shift B ----
        $display("\n--- Right Shift B ---");
        apply_and_check(2501, 0, 8'hF0, 0, 0, 2'b10, 10,  1, 1, 0, 0, 0);
        apply_and_check(2502, 0, 8'hFF, 0, 0, 2'b10, 10,  1, 1, 0, 0, 0);
        apply_and_check(2503, 0, 8'h01, 0, 0, 2'b10, 10,  1, 1, 0, 0, 0);
        apply_and_check(2504, 0, 8'hF0, 0, 0, 2'b01, 10,  1, 1, 0, 0, 0);

        // ---- GROUP 26 : Left Shift B ----
        $display("\n--- Left Shift B ---");
        apply_and_check(2601, 0, 8'h0F, 0, 0, 2'b10, 11,  1, 1, 0, 0, 0);
        apply_and_check(2602, 0, 8'h80, 0, 0, 2'b10, 11,  1, 1, 0, 0, 0);
        apply_and_check(2603, 0, 8'hFF, 0, 0, 2'b10, 11,  1, 1, 0, 0, 0);
        apply_and_check(2604, 0, 8'h0F, 0, 0, 2'b01, 11,  1, 1, 0, 0, 0);

        // ---- GROUP 27 : Variable Left Shift A ----
        $display("\n--- Variable Left Shift A ---");
        apply_and_check(2701, 8'd1,  8'd0, 0, 0, 2'b11, 12,  1, 1, 0, 0, 0);
        apply_and_check(2702, 8'd1,  8'd3, 0, 0, 2'b11, 12,  1, 1, 0, 0, 0);
        apply_and_check(2703, 8'd1,  8'd7, 0, 0, 2'b11, 12,  1, 1, 0, 0, 0);
        apply_and_check(2704, 8'h00, 8'd4, 0, 0, 2'b11, 12,  1, 1, 0, 0, 0);
        apply_and_check(2705, 8'd1, 8'h10, 0, 0, 2'b11, 12,  0, 1, 0, 0, 0); // ERR=1
        apply_and_check(2706, 8'd1,  8'd2, 0, 0, 2'b01, 12,  0, 1, 0, 0, 0); // ERR=1

        // ---- GROUP 28 : Variable Right Shift A ----
        $display("\n--- Variable Right Shift A ---");
        apply_and_check(2801, 8'hFF, 8'd0, 0, 0, 2'b11, 13,  1, 1, 0, 0, 0);
        apply_and_check(2802, 8'd64, 8'd1, 0, 0, 2'b11, 13,  1, 1, 0, 0, 0);
        apply_and_check(2803, 8'd128,8'd7, 0, 0, 2'b11, 13,  1, 1, 0, 0, 0);
        apply_and_check(2804, 8'h00, 8'd4, 0, 0, 2'b11, 13,  1, 1, 0, 0, 0);
        apply_and_check(2805, 8'd1, 8'h20, 0, 0, 2'b11, 13,  0, 1, 0, 0, 0); // ERR=1
        apply_and_check(2806, 8'd64, 8'd2, 0, 0, 2'b10, 13,  0, 1, 0, 0, 0); // ERR=1

        // ---- GROUP 29 : MODE Switch ----
        $display("\n--- MODE Switch ---");
        // T-29-01: Arithmetic ADD then switch to Logic XOR
        OPA=50; OPB=30; MODE=1; CMD=0; INP_VALID=2'b11;
        @(posedge CLK); #1;
        MODE=0; CMD=4; OPA=8'hAA; OPB=8'h55;
        @(posedge CLK); #1;
        if (RES===16'h00FF && ERR===0) begin
            pass_count=pass_count+1; $display("  PASS T-2901");
        end else begin
            fail_count=fail_count+1; $display("  FAIL T-2901: RES=%h ERR=%b", RES, ERR);
        end

        // T-29-02: Logic XOR then switch to Arithmetic SUB
        OPA=8'hAA; OPB=8'h55; MODE=0; CMD=4; INP_VALID=2'b11;
        @(posedge CLK); #1;
        MODE=1; CMD=1; OPA=100; OPB=100;
        @(posedge CLK); #1;
        if (RES===16'h0000 && ERR===0) begin
            pass_count=pass_count+1; $display("  PASS T-2902");
        end else begin
            fail_count=fail_count+1; $display("  FAIL T-2902: RES=%h ERR=%b", RES, ERR);
        end

        // ---- GROUP 30 : Default / No-op CMDs ----
        $display("\n--- Default CMD (no-op) ---");
        // T-30-02 : CMD=14 (no-op for N=8, C=4 has max 15)
        begin: t3002_blk
            reg [2*N-1:0] prev_res;
            reg           prev_err;
            MODE=1; CMD=0; OPA=42; OPB=0; INP_VALID=2'b11;
            @(posedge CLK); #1;    // establish known state
            prev_res = RES;
            prev_err = ERR;
            CMD=4'd14;             // default branch
            @(posedge CLK); #1;
            if (RES===prev_res && ERR===prev_err) begin
                pass_count=pass_count+1; $display("  PASS T-3002");
            end else begin
                fail_count=fail_count+1; $display("  FAIL T-3002: RES=%h (was %h) ERR=%b (was %b)", RES, prev_res, ERR, prev_err);
            end
        end

        // ---- Summary ----
        $display("\n=================================================");
        $display("  RESULTS:  PASS=%0d   FAIL=%0d   TOTAL=%0d",
                 pass_count, fail_count, pass_count+fail_count);
        $display("=================================================");

        $finish;
    end

    // --------------------------------------------------------
    // Timeout watchdog (100 us)
    // --------------------------------------------------------
    initial begin
        #100000;
        $display("TIMEOUT \u2013 simulation did not finish.");
        $finish;
    end

endmodule
