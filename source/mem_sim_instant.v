
module mem_sim_instant #(parameter logsize = 1)
   (
    input             clk,
    input             init,
   
    input [1:logsize] addr,
    input [1:8]       wdata,
    input             wselect,
    input             doit,
    output            busy,
    output            rvalid,
    output [1:8]      rdata
    );
   
   localparam size = 2 ** logsize;
   
   reg [0:8*size-1]   mem;

   assign rvalid = doit & !wselect;
   assign busy = 0;

   assign rdata = mem[addr*8 +: 8];
   
   always @(posedge clk) 
     begin
        if (init) mem = {size*8{1'b0}};
        else if (wselect & doit) mem[addr*8 +: 8] = wdata;
     end
   
endmodule 
