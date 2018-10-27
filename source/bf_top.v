
module bf_top
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
   //assign led = pc;
   
   localparam psizelog = 8;
   localparam psize = 2 ** psizelog;
   localparam iwidth = 8; //wasteful, could use 3, but 8 nice for harcoded progs as strings

   localparam msizelog = 8;
   localparam msize = 2 ** msizelog;
   localparam cwidth = 8; // this has to be 8
   
   //localparam prog = ",>,<.>.+."; 
   //localparam prog = "++++++++++.++++++++++++++++++++++++++.>,.>,.>,.<<<----.>.>.>."; 
   //localparam prog = "++++++++++.++++++++++++++++++++++++++.[,.+.]"; 

   localparam prog = //fibs
">++++++++++>+>+[[+++++[>++++++++<-]>.<++++++[>--------<-]+<<<]>.>>[[-]<[>+<-]>>[<<+>+>-]<[>+<-[>+<-[>+<-[>+<-[>+<-[>+<- [>+<-[>+<-[>+<-[>[-]>+>+<<<-[>+<-]]]]]]]]]]]+>>>]<<<]";

   //localparam prog =  //collatz
//">>+>+++++++>+>++><<[<<]>><+><[->[>>]<<>>+[-<<>[>>]<]<<[>++++++++++++++++++++++++++++++++++++++++++++++++.------------------------------------------------<<<]++++++++++.[-]>><[-]>->[-<<+>><+>[-<<->><+>[-<<+>><+>[-<<->><+>[-<<+>><+>[-<<->><+>[-<<+>><+>[-<<->><+>[-<<+>><+>[-<<->><+>]]]]]]]]]]<[->+<]+<[->[->[-<+++>]<[->+<]+>>]<<[<<]>>>+<[->[-<+>[-<+>[-<+>[-<+>[-<+>[-<+>[-<+>[-<+>[-<+>[-<+>>>+<<<[-]>>[-]+<[-<+>[-<+>[-<+>[-<+>[-<+>[-<+>[-<+>[-<+>[-<+>[-<+>>>+<<<[-]>[-<+>]]]]]]]]]]]]]]]]]]]]]<[->+<]+>>]<<[<<]>>[>>]<<>>+[-<<>[>>]<]<<[>++++++++++++++++++++++++++++++++++++++++++++++++.------------------------------------------------<<<]++++++++++.[-]>><]>[->[-<<+++++>>[-<<----->><+>[-<<+++++>>[-<<----->><+>[-<<+++++>>[-<<----->><+>[-<<+++++>>[-<<----->><+>[-<<+++++>>[-<<----->><+>]]]]]]]]]]<[->+<]+>>]<<[<<]>><[-]+>->[-<+><<->>[-<+><<+>>[-<+>]]]<[->+<]+>>[-<<<[-]+>>>]+<<<]>++++++++++++++++++++++++++++++++++++++++++++++++.[-]++++++++++.";

   //localparam prog = //interpreter
//">>>+[[-]>>[-]++>+>+++++++[<++++>>++<-]++>>+>+>+++++[>++>++++++<<-]+>>>,<++[[>[->>]<[>>]<<-]<[<]<+>>[>]>[<+>-[[<+>-]>]<[[[-]<]++<-[<+++++++++>[<->-]>>]>>]]<<]<]<[[<]>[[>]>>[>>]+[<<]<[<]<+>>-]>[>]+[->>]<<<<[[<<]<[<]+<<[+>+<<-[>-->+<<-[> +<[>>+<<-]]]>[<+>-]<]++>>-->[>]>>[>>]]<<[>>+<[[<]<]>[[<<]<[<]+[-<+>>-[<<+>++>- [<->[<<+>>-]]]<[>+<-]>]>[>]>]>[>>]>>]<<[>>+>>+>>]<<[->>>>>>>>]<<[>.>>>>>>>]<<[>->>>>>]<<[>,>>>]<<[>+>]<<[+<<]<]";
   
   
   reg                           eMpUnder;
   reg                           eMpOver;
   reg                           eNestOver;
   always @(posedge clk) begin
      eMpUnder = rst ? 0 : eMpUnder | mpUnder;
      eMpOver  = rst ? 0 : eMpOver | mpOver;
      eNestOver  = rst ? 0 : eNestOver | nestOver;
   end
   
   reg                           running;
   always @(posedge clk) 
     running = rst ? 1'b0 : running ? !finished : start;

   localparam Exec = 0;
   localparam SkipR = 1;
   localparam SkipL = 2;

   reg [1:2]                     mode;
   always @(posedge clk) mode
     =
      !running ? Exec :
      (mode==Exec) ? (beginSkipR ? SkipR : beginSkipL ? SkipL : mode) :
      (mode==SkipR) ? (endSkipR ? Exec : mode) :
      (mode==SkipL) ? (endSkipL ? Exec : mode) :
      Exec;
   
   reg [0 : msize * cwidth - 1]  mem; //PLAN: use sdram for this
   always @(posedge clk) begin
      if (!running & start) mem = {msize*cwidth{1'b0}};
      else 
        mem[mp * cwidth +: cwidth] 
          = 
            !executing ? mcell :
            isPlus ? mcell+1 : 
            isMinus ? mcell-1 :
            (isComma & new_rx) ? rx_data :
            mcell;
   end

   reg [1:psizelog]                pc;
   always @(posedge clk) pc
     = 
       !running ? 1 :
       (mode==SkipR) ? pcInc :
       (mode==SkipL) ? (endSkipL ? pcInc : pcDec) :
       //so (mode==Exec)
       beginSkipL ? pcDec :
       (rx_stall | tx_stall) ? pc :
       pcInc;
   
   reg [1:msizelog]                mp;
   always @(posedge clk) mp
     = 
       !running ? 0 : 
       !executing ? mp : 
       isRight ? mp+1 : isLeft ? mp-1 : mp;

   reg [1:5]                       nest;
   always @(posedge clk) nest
     = 
       (mode==Exec) ? 0 : 
       incNest ? nest+1 :
       decNest ? nest-1 : 
       nest;

   // The program literal is left filled with 0s, so it sits in the right-hand end
   // of the available space, preceeded by junk which just gets skipped (like junk always does).
   // We start the pc pointing at index 1 (probably still junk).
   // Index 0 is reserved to indicate we are finished; we ran off the end of the program, and wrapped.
   // So, the program had better be strictly smaller than psize.
   
   wire [0 : psize * iwidth - 1] code = prog; //prog hardcoded. when read in, need a reg

   wire [1:iwidth]                 instr = code[pc * iwidth +: iwidth];
   
   wire                            start = rx_data == "\n" & new_rx;
   wire                            finished = (pc==0) | error;

   wire                            error = mpUnder | mpOver | nestOver;

   wire                            mpUnder = (mp==0) & isLeft & executing;
   wire                            mpOver =  &mp & isRight & executing;
   wire                            nestOver = &nest & incNest;
   
   wire                            executing = running & (mode==Exec);

   wire [1:psizelog]               pcInc = pc + 1;
   wire [1:psizelog]               pcDec = pc - 1;
   
   wire                            beginSkipR = isOpen & (mcell==0);
   wire                            beginSkipL = isClose & (mcell!=0);

   wire                            endSkipR = isClose & (nest==0);
   wire                            endSkipL = isOpen & (nest==0);
   
   wire                            incNest = (mode==SkipR) & isOpen | (mode==SkipL) & isClose;
   wire                            decNest = (mode==SkipR) & isClose | (mode==SkipL) & isOpen;
   
   wire                            isComma = instr ==",";
   wire                            isDot = instr ==".";
   wire                            isLeft = instr =="<";
   wire                            isRight = instr ==">";
   wire                            isPlus = instr =="+";
   wire                            isMinus = instr =="-";
   wire                            isOpen = instr =="[";
   wire                            isClose = instr =="]";

   wire [1:cwidth]                 mcell = mem[mp * cwidth +: cwidth];
   
   wire                            rx_stall = isComma & !new_rx;
   wire                            tx_stall = isDot & tx_busy;

   assign tx_data = mcell;
   assign tx_send = executing & isDot & !tx_busy;
   
endmodule
