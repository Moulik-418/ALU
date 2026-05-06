module alu_main#(parameter N = 8, C = 4)(OPA,OPB,CIN,CLK,RST,CE,MODE,INP_VALID,CMD, RES, OFLOW, COUT, G,L,E, ERR);

//port declarations
input [N-1: 0]OPA, OPB;
input CLK,RST, CE,MODE, CIN;
input [1:0]INP_VALID; // [BA]
input [C-1:0]CMD;
output reg  [2*(N) -1:0]RES;
output reg ERR;
output  OFLOW, COUT, G,L,E;

// internal signals
reg [C-1 : 0] prev_CMD;
reg [1:0]count;
reg [N-1 : 0]tmp_a, tmp_b;  // multiplication sampling 
reg [(2*N)-1 : 0]tmp_res;

assign COUT = ((CMD == 'd0 || CMD == 'd2) && MODE == 1'b1 )? RES[N] : 1'b0;                                                                                                    // unsigned ADD/ADD_CIN
assign {G,L,E} = ((CMD == 'd8 || CMD == 'd11 || CMD == 'd12) && MODE == 1'b1 )? ({$signed(OPA)> $signed(OPB), $signed(OPA) < $signed(OPB), $signed(OPA) == $signed(OPB)}): 3'b0; // COMP, signed ADD/SUB
assign OFLOW = ((CMD == 'd1 || CMD == 'd3 || CMD == 'd11 || CMD == 'd12) && MODE == 1'b1) ? (~RES[N]) : 1'b0;                                                                  // unsigned SUB/SUB_CIN, signed SUB/ADD

always@(posedge CLK)begin
        if(RST)begin
                RES <= {(2*N){1'b0}};
                ERR <= 1'b0;
        end

        else if(CE)begin
                prev_CMD <= CMD;

                //counter logic for multiplication 
          if((prev_CMD !=  CMD ) || count >= 2'b01 )
                        count <= 2'd0;
                else if((CMD == 'd9) || (CMD == 'd10))
                        count <= count +1;
                else count <= 2'd0;


                if(MODE)begin                                           // ARITHEMATIC operations

                        case(CMD)
                                'd0 : begin                             // unsigned ADD
                                        RES <= OPA + OPB;
                                       ERR <= (INP_VALID  == 2'b11)? 1'b0: 1'b1;

                        end

                                'd1 : begin                              // unsigned SUB
                                        RES <= OPA - OPB ;
                                       ERR <= (INP_VALID  == 2'b11)? 1'b0: 1'b1;

                        end
                                'd2 : begin                             // unsigned ADD CIN
  					RES <= OPA + OPB + CIN;
                                       ERR <= (INP_VALID  == 2'b11)? 1'b0: 1'b1;
                        end

                                'd3 : begin                             // overflow SUB CIN
                                        RES <= OPA - OPB - CIN ;
                                       ERR <= (INP_VALID  == 2'b11)? 1'b0: 1'b1;
                        end

                                'd4 : begin                             // INC_A
                                        RES <= OPA +1'b1 ;
                                       ERR <= (INP_VALID[0])? 1'b0: 1'b1;
                        end
                                'd5 : begin                             // DEC_A
                                        RES <= OPA - 1'b1;
                                       ERR <= (INP_VALID[0])? 1'b0: 1'b1;
                        end

                                'd6 : begin                             // INC_B
                                  RES <= OPB + 1'b1;
                                       ERR <= (INP_VALID[1])? 1'b0: 1'b1;
                        end

                                'd7 : begin                             // DEC_B
                                        RES <= OPB - 1'b1;
                                       ERR <= (INP_VALID[1])? 1'b0: 1'b1;
                        end

                        'd8 : begin                                     // Comparator (handled using assign statement)

                                        ERR <= (INP_VALID == 2'b11)? 1'b0: 1'b1;
                        end

                       'd9: begin                              // Inc & Multiply
                                        ERR <= (INP_VALID  == 2'b11)? 1'b0: 1'b1;
                                                        {tmp_a, tmp_b} <=(count == 2'd0 || count == 2'd2)? {OPA, OPB}: {tmp_a, tmp_b};
                                        RES <=(count >= 2'd1)?((tmp_a + 1'b1)* (tmp_b + 1'b1)):RES;
                        end
                        'd10 : begin                            // Shift & Multiply 
                                        ERR <= (INP_VALID  == 2'b11)? 1'b0: 1'b1;
                                        {tmp_a, tmp_b} <= (count == 2'd0 || count == 2'd2)? {OPA, OPB}: {tmp_a, tmp_b};
                                        RES <= (count >= 2'd1)?((tmp_a << 1'b1)* tmp_b): RES;

                        end
                                                                                                          
   			 'd11 : begin                            //Signed Addition
                                       ERR <= (INP_VALID  == 2'b11)? 1'b0: 1'b1;
                                  RES <=  ($signed(OPA) + $signed(OPB));
                                                                                                              end

                                'd12 : begin                            //Signed Subtraction
                                       ERR <= (INP_VALID  == 2'b11)? 1'b0: 1'b1;
                                        RES <=  ($signed(OPA) - $signed(OPB));
                        end

                                default : RES <= RES;
                        endcase
                end

                else begin                                              // LOGICAL operations 

                        case(CMD)
                                'd0 : begin
                                RES <= OPA & OPB;
                                ERR <= (INP_VALID == 2'd3)? 1'b0: 1'b1;
                        end
                        'd1 :begin
                          RES <= {8'd0,~(OPA & OPB)};
                                ERR <= (INP_VALID == 2'd3)? 1'b0: 1'b1;
                        end
                        'd2 :begin
                                RES <= OPA | OPB;
                                ERR <= (INP_VALID == 2'd3)? 1'b0: 1'b1;
                        end
                        'd3 : begin
                          RES <= {8'd0, ~(OPA | OPB)};
                                ERR <= (INP_VALID == 2'd3)? 1'b0: 1'b1;
                        end
                        'd4 :begin
                                RES <= OPA ^ OPB;
                                ERR <= (INP_VALID == 2'd3)? 1'b0: 1'b1;
                        end
                        'd5 :begin
                          RES <= {8'd0,~(OPA ^ OPB)};
                                ERR <= (INP_VALID == 2'd3)? 1'b0: 1'b1;
                        end
                        'd6 : begin
                          RES <= {8'd0,~OPA};
                                ERR <= (INP_VALID[0])? 1'b0: 1'b1;
                        end
                        'd7 : begin
                          RES <= {8'd0,~OPB};
                                ERR <= (INP_VALID[1])? 1'b0: 1'b1;
                        end
                        'd8 : begin
				 RES <= {{N{1'b0}}, (OPA >> 1)};
                                ERR <= (INP_VALID[0])? 1'b0: 1'b1;
                        end
                        'd9 :begin
                                RES <= {{N{1'b0}}, (OPA << 1)};
                                ERR <= (INP_VALID[0])? 1'b0: 1'b1;
                        end
                        'd10 :  begin
                                RES <= {{N{1'b0}}, (OPB >> 1)};
                                ERR <= (INP_VALID[1])? 1'b0: 1'b1;
                        end

                        'd11 : begin
                                RES <= {{N{1'b0}}, (OPB << 1)};
                                ERR <= (INP_VALID[1])? 1'b0: 1'b1;
                        end


                        'd12 : begin
                                                RES <= {{N{1'b0}}, (OPA <<OPB[($clog2(N) -1):0])};
                          ERR <= (OPB[N-1:($clog2(N)) +1] > 4'd0 || (INP_VALID != 2'd3))?1'b1 : 1'b0;

                                        end

                        'd13 : begin
                                                RES <= {{N{1'b0}}, (OPA >> OPB[($clog2(N) -1):0])};
                          ERR <= (OPB[N-1:($clog2(N)) + 1] > 4'd0 || (INP_VALID != 2'd3))?1'b1 :1'b0;

                        end
                                default : RES <= RES;

                        endcase

                end
        end

end

endmodule


