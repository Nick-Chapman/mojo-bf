
module bf #(parameter logsize = 7)
  (
   input              clk,
   input              rst,
  
   input [1:8]        rx_data,
   input              rx_new,
  
   output [1:8]       tx_data,
   output             tx_send,
   input              tx_busy,

   output             mem_init,
   output [1:logsize] mem_addr,
   output [1:8]       mem_wdata,
   output             mem_wselect,
   output             mem_doit,
   input              mem_busy,
   input              mem_rvalid,
   input [1:8]        mem_rdata,

   output reg         running,
   output             rx_stall,

   output reg [1:log_msize]  mp,
   
   //output [7:0]       led
   output [1:6]       view_pc,
   output [1:4]       view_errors
   );

   wire             diff = 0; // for dev/debug
   
   //assign led = {running, rx_stall, 2'b00, eMpUnder, eMpOver, eNestOver, eDiff};
   //assign led = {running, rx_stall, pc};
   //assign led = {running, pc[2+:7]};

   assign view_pc = pc[log_psize -: 6]; //last 6 bits
   assign view_errors = {eMpUnder, eMpOver, eNestOver, eDiff};
   
   localparam log_psize = 8;
   localparam psize = 2 ** log_psize;
   localparam iwidth = 8; //wasteful, could use 3, but 8 nice for harcoded progs as strings

   localparam log_msize = logsize;
   localparam msize = 2 ** log_msize;
   localparam cwidth = 8; // this has to be 8

   localparam prog =
//",.>,.<.>.+.";
//",[,,+]";
//",,,,,,";
//".+.+.>.-.-.";                    
//".+..+..+..";
//",.+.. ,.+x. ,.+xxxxxxxxxxxxxxxxxxxxxxxxx.";
//"++++++++++.++++++++++++++++++++++++++.>,.>,.>,.<<<----.>.>.>.----.";
//"++++++++++.++++++++++++++++++++++++++.[,.+.]";


// This test program shows that 8 cycles (but not 7) is enough between a
// write ("+") and read (".") at the same address....
                    
//",.+. ,.+1234. ,.+12345. ,.+123456. ,.+1234567. ,.+12345678. ,.+1234567. ,.+123456. ,.+12345. ,.+1234.";

">++++++++++>+>+[[+++++[>++++++++<-]>.<++++++[>--------<-]+<<<]>.>>[[-]<[>+<-]>>[<<+>+>-]<[>+<-[>+<-[>+<-[>+<-[>+<-[>+<- [>+<-[>+<-[>+<-[>[-]>+>+<<<-[>+<-]]]]]]]]]]]+>>>]<<<]"; //fibs
   
   reg                           eMpUnder;
   reg                           eMpOver;
   reg                           eNestOver;
   reg                           eDiff;
   always @(posedge clk) begin
      eMpUnder  = rst|start ? 1'b0 : eMpUnder | mpUnder;
      eMpOver   = rst|start ? 1'b0 : eMpOver | mpOver;
      eNestOver = rst|start ? 1'b0 : eNestOver | nestOver;
      eDiff     = rst|start ? 1'b0 : eDiff | diff;
   end

   always @(posedge clk) running = xrunning;
   //reg          running;
   wire         xrunning = rst ? 1'b0 : running ? !stop : start;
   
   wire         start = rx_data == "\n" & rx_new;
   wire         stop = (&pc & xpc == 0) | error;
   
   localparam Exec = 0;
   localparam SkipR = 1;
   localparam SkipL = 2;
   
   always @(posedge clk) mode = xmode;
   reg [1:2]    mode;
   wire [1:2]   xmode =
                !running ? Exec :
                (mode==Exec) ? (beginSkipR ? SkipR : beginSkipL ? SkipL : mode) :
                (mode==SkipR) ? (endSkipR ? Exec : mode) :
                (mode==SkipL) ? (endSkipL ? Exec : mode) :
                Exec;
   
   wire         beginSkipR = isOpen & mem_rvalid & (mem_rdata == 0);
   wire         beginSkipL = isClose & mem_rvalid & (mem_rdata != 0);

   wire         endSkipR = isClose & (nest==0);
   wire         endSkipL = isOpen & (nest==0);

   always @(posedge clk) pc = xpc;
   reg [1:log_psize] pc;
   wire [1:log_psize] xpc  = 
                      !running ? 0 :
                      (xmode==SkipL) ? pc - 1 : //note: "next"-mode
                      (mode==Exec & stall) ? pc :
                      pc + 1;
   
   always @(posedge clk) mp = xmp;
   //reg [1:log_msize]  mp;
   wire [1:log_msize] xmp = 
                      !running ? 0 :
                      !executing ? mp : 
                      isRight ? mp + 1 : isLeft ? mp - 1 : mp;
   
   always @(posedge clk) nest = xnest;
   reg [1:5]          nest;
   wire [1:5]         xnest =
                      (mode==Exec) ? 0 : 
                      incNest ? nest + 1 :
                      decNest ? nest - 1 : 
                      nest;

   localparam Phase1 = 0;
   localparam Phase2 = 1;

   wire             phase1 = phase==Phase1;
   wire             phase2 = phase==Phase2;
   
   wire             incNest = (mode==SkipR) & isOpen | (mode==SkipL) & isClose;
   wire             decNest = (mode==SkipR) & isClose | (mode==SkipL) & isOpen;
   
   wire             error = mpUnder | mpOver | nestOver;

   wire             mpUnder = (mp==0) & isLeft & executing;
   wire             mpOver =  &mp & isRight & executing;
   wire             nestOver = &nest & incNest;

   wire             executing = running & (mode==Exec);

   assign           rx_stall = isComma & phase1;

   wire             stall =
                    isComma ? (phase1 ? 1 : mem_busy) :         //rx,w
                    isDot   ? (phase1 ? 1 : tx_busy) :          //r,tx
                    isPlus  ? (phase1 ? 1 : mem_busy) :         //r,w
                    isMinus ? (phase1 ? 1 : mem_busy) :         //r,w
                    isOpen  ? (phase1 ? !mem_rvalid : 0) :      //r
                    isClose ? (phase1 ? !mem_rvalid : 0) :      //r
                    isLeft  ? 0 :
                    isRight ? 0 :
                    0 ;
   
   always @(posedge clk) phase = xphase;
   reg              phase;
   wire             xphase =
                    isComma ? (phase1 ? (rx_new     ? Phase2 : Phase1) : (mem_busy ? Phase2 : Phase1)) :
                    isDot   ? (phase1 ? (mem_rvalid ? Phase2 : Phase1) : (tx_busy  ? Phase2 : Phase1)) :
                    isPlus  ? (phase1 ? (mem_rvalid ? Phase2 : Phase1) : (mem_busy ? Phase2 : Phase1)) :
                    isMinus ? (phase1 ? (mem_rvalid ? Phase2 : Phase1) : (mem_busy ? Phase2 : Phase1)) :
                    isOpen  ? Phase1 :
                    isClose ? Phase1 :
                    isLeft  ? Phase1 :
                    isRight ? Phase1 :
                    Phase1;
   
   always @(posedge clk) mcell = xmcell ;
   reg [1:8]        mcell; // The(!) datum register
   wire [1:8]       xmcell =
                    (isDot & phase1 & mem_rvalid) ? mem_rdata :
                    (isPlus & phase1 & mem_rvalid) ? mem_rdata + 1 :
                    (isMinus & phase1 & mem_rvalid) ? mem_rdata - 1 :
                    (isComma & phase1 & rx_new) ? rx_data :
                    mcell;
   
   wire             isComma = instr ==",";
   wire             isDot = instr ==".";
   wire             isLeft = instr =="<";
   wire             isRight = instr ==">";
   wire             isPlus = instr =="+";
   wire             isMinus = instr =="-";
   wire             isOpen = instr =="[";
   wire             isClose = instr =="]";
   
   wire [1:iwidth]  instr = code[pc * iwidth +: iwidth];

   // The program literal is left filled with 0s, so it sits in the
   // right-hand end of the available space, preceeded by junk which
   // just gets skipped (like junk always does).  We start the pc
   // pointing at index 1 (probably still junk).  Index 0 is reserved
   // to indicate we are finished; we ran off the end of the program,
   // and wrapped.  So, the program had better be strictly smaller
   // than psize.
   
   wire [0 : psize * iwidth - 1] code = prog;

   wire                          needsRead = isPlus | isMinus | isDot | isOpen | isClose;
   wire                          needsWrite = isPlus | isMinus | isComma;
   
   //drive signals to memory
   assign mem_init = !running & start;
   assign mem_addr = mp;
   assign mem_wdata = mcell;
   assign mem_wselect = phase2;
   assign mem_doit = executing & !mem_busy & (phase2 ? needsWrite : needsRead);
   
   //drive signals to tx
   assign tx_data = mcell;
   assign tx_send = executing & !tx_busy & phase2 & isDot;
    
endmodule
