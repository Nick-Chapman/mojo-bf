
module bf_fsm_style //Lets see..
  (
   input        clk,
   input        rst,
  
   input [1:8]  rx_data,
   input        new_rx,
  
   output [1:8] tx_data,
   output       tx_send,
   input        tx_busy,

   output [7:0] led
   );

   assign led = {running, rx_stall, 3'b000, eMpUnder, eMpOver, eNestOver};
   //assign led = {running, rx_stall, 2'b00, pc};

   localparam psizelog = 8;
   localparam psize = 2 ** psizelog;
   localparam iwidth = 8; //wasteful, could use 3, but 8 nice for harcoded progs as strings

   localparam msizelog = 5;
   localparam msize = 2 ** msizelog;
   localparam cwidth = 8; // this has to be 8

   localparam prog = 
//",>,<.>.+."; 
//"++++++++++.++++++++++++++++++++++++++.>,.>,.>,.<<<----.>.>.>.";
//"++++++++++.++++++++++++++++++++++++++.[,.+.]"; 
">++++++++++>+>+[[+++++[>++++++++<-]>.<++++++[>--------<-]+<<<]>.>>[[-]<[>+<-]>>[<<+>+>-]<[>+<-[>+<-[>+<-[>+<-[>+<-[>+<- [>+<-[>+<-[>+<-[>[-]>+>+<<<-[>+<-]]]]]]]]]]]+>>>]<<<]"; //fibs

   wire [0 : psize * iwidth - 1] code = prog;
   
   reg [0 : msize * cwidth - 1]  mem;

   reg                           running;
   reg                           eMpUnder;
   reg                           eMpOver;
   reg                           eNestOver;

   localparam Exec = 0;
   localparam SkipR = 1;
   localparam SkipL = 2;
   reg [1:2]                     mode;

   reg [1:psizelog]              pc;
   reg [1:msizelog]              mp;
   reg [1:5]                     nest;

   wire                          error = eMpUnder | eMpOver | eNestOver;
   wire                          finished = (pc==0) | error;
   wire                          start = rx_data == "\n" & new_rx;

   wire                          executing = running & (mode==Exec);
   wire                          rx_stall = executing & (instr == ",") & !new_rx;

   wire [1:cwidth]               mcell = mem[mp * cwidth +: cwidth];
   wire [1:iwidth]               instr = code[pc * iwidth +: iwidth];
   
   always @(posedge clk) begin
      running = rst ? 0 : running ? !finished : start;
      if (!running) begin
         mode = Exec;
         mp = 0;
         pc = 1;
         mem = {msize*cwidth{1'b0}};
      end
      if ((!running & start) | rst) begin
         eMpUnder = 0;
         eMpOver = 0;
         eNestOver = 0;
      end
      if (running)
        case (mode)
          Exec: begin
             pc = pc + 1;
             case (instr)
               "<": if (mp==0) eMpUnder = 1; else mp = mp - 1;
               ">": if (&mp) eMpOver = 1; else mp = mp + 1;
               "+": mem[mp * cwidth +: cwidth] = mcell + 1;
               "-": mem[mp * cwidth +: cwidth] = mcell - 1;
               ",": if (new_rx) mem[mp * cwidth +: cwidth] = rx_data; else pc = pc - 1;
               ".": if (tx_busy) pc = pc - 1;
               "[": if (mcell == 0) mode = SkipR;
               "]": if (mcell != 0) mode = SkipL;
             endcase
             if (mode == SkipL) pc = pc - 2;
          end
          SkipR: begin
             pc = pc + 1;
             case (instr)
               "[": if (&nest) eNestOver = 1; else nest = nest + 1;
               "]": if (nest==0) mode = Exec; else nest = nest - 1;
             endcase
          end
          SkipL: begin
             pc = pc - 1;
             case (instr)
               "]": if (&nest) eNestOver = 1; else nest = nest + 1;
               "[": if (nest==0) mode = Exec; else nest = nest - 1;
             endcase
             if (mode == Exec) pc = pc + 2;
          end
        endcase

   end

   assign tx_data = mcell;
   assign tx_send = executing & (instr == ".") & !tx_busy;

endmodule
