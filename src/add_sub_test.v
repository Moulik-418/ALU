module add_sub_test();

reg [7:0]a,b;
wire [7:0]out1;
wire [15:0]out2;

assign out1 = a + b;
assign out2 = a +b;

initial begin 

$monitor("a = %0b, b = %0b, out1 = %b, out2 = %b", a,b,out1, out2);
a = 255;
b = 10;
#2 a = 5;
b = -9;

end

endmodule
