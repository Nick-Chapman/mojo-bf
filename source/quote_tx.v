
module quote_tx // a --> b
  (
   input        clk,
   input [1:8]  a_data,
   input        a_send,
   output       a_busy,

   output [1:8] b_data,
   output       b_send,
   input        b_busy);

   localparam Idle = 0;
   localparam Send1 = 1;
   localparam Send2 = 2;
   
   reg [1:8]    data;
   reg [1:2]    mode;

   always @(posedge clk) data = xdata;
   always @(posedge clk) mode = xmode;

   wire [1:8]   xdata = a_send ? a_data : data;

   wire [1:2]   xmode = 
                (mode==Idle) ? (a_send ? Send1 : mode) :
                (mode==Send1) ? (!b_busy ? Send2 : mode) :
                (mode==Send2) ? (!b_busy ? Idle : mode) :
                Idle;

   wire [1:4]   nib1 = data[1:4];
   wire [1:4]   nib2 = data[5:8];

   wire [1:8]   oh = "0";
   wire [1:8]   ay = "a";

   wire [1:8]   char1 = nib1 + ((nib1 > 9) ? ay-10 : oh);
   wire [1:8]   char2 = nib2 + ((nib2 > 9) ? ay-10 : oh);

   assign b_data = (mode==Send1) ? char1 : char2;
   assign b_send = (mode==Send1) | (mode==Send2);
   
   assign a_busy = !(mode==Idle);
   
endmodule
