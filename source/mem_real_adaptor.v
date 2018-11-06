
module mem_real_adaptor #(parameter logsize = 1)
   (
    input             clk,
      
    // connect to sdram controller
    output [56:0]     memOut,
    input [33:0]      memIn,
   
    // connect to bf interpreter
    input             init,
    input [1:logsize] addr,
    input [1:8]       wdata,
    input             wselect,
    input             doit,
    output            busy,
    output            rvalid,
    output [1:8]      rdata
    );
   
   localparam Init = 0;
   localparam Run = 1;

   always @(posedge clk) mode = xmode;
   always @(posedge clk) icount = xicount;
   
   reg                mode;
   wire               isInit = (mode==Init);
   wire               xmode = isInit
                      ? (&icount ? Run : Init) 
                      : (init ? Init : Run);

   reg [1:logsize]    icount;
   wire [1:logsize]   xicount = 
                      isInit 
                      ? (mem_busy ? icount : icount + 1)
                      : 0;

   wire [1:logsize]   mem_sig_addr  = isInit ? icount    : addr;
   wire [1:8]         mem_sig_wdata = isInit ? 8'b0      : wdata;
   wire               mem_doit      = isInit ? !mem_busy : doit;
   wire               mem_wselect   = isInit ? 1'b1      : wselect;

   // Currently we use only 1 byte of the 4 available at each address
   // read/written via the sdram controller. We could use all 4 bytes
   // by muxing with 2 bits of our address.

   wire [1:23]        mem_addr = {{23-logsize{1'b0}}, mem_sig_addr};
   wire [1:32]        mem_wdata = {mem_sig_wdata, 24'b0}; //write 1 byte of 4

   assign memOut   = {mem_wselect, mem_addr, mem_doit, mem_wdata};

   wire               mem_busy = memIn[33];
   
   assign busy     = mem_busy | isInit | mywait!=0 ;
   assign rvalid   = memIn[32];
   assign rdata    = memIn[31-:8]; //read 1 byte of 4
   
   // There's some problem with the underlying sdram controller!
   // Specifically, when doing a write followed by a read at a given
   // address.  Work around by waiting a fixed number of cyles after
   // every operation. 50 seems enough. 20 not so.
   
   always @(posedge clk) mywait = xmywait; 
   reg [1:7]          mywait;
   wire [1:7]         xmywait = doit ? 50 : mywait==0 ? 0 : mywait-1;
   
endmodule 
