module mojo_top
  (
   input         clk,
   input         rst_n,
   input         cclk,
  
   output        spi_miso,
   input         spi_mosi,
   input         spi_ss,
   input         spi_sck,

   output [3:0]  spi_channel,
   output        avr_rx,
   input         avr_tx, 
   input         avr_rx_busy,

   output [21:0] sdramOut,
   inout [7:0]   sdramInOut,

   output [7:0]  led
   );

   localparam logsize = 6;  //address width 
   // = log memory size - with sim memory, keep it at 5
   // with real memory we can be as ig as we like!
   
   // Address width of 6 using real memory: fibs gives odd behaviour!
   // The final number reached before mp overflows varies between 2
   // different values on successive runs allowing one-extra/one-less
   // digit in the result.  But for width of 7, everythig is cool.
   
   assign led = {running, rx_stall, 2'b00, view_errors};
   //assign led = {running, 1'b0, mp};
   
   wire          clk50;
   wire          clk100;
   my_clk_wiz wiz 
     (
      .clk(clk),
      .clk50(clk50),
      .clk100(clk100)
      );

   reset_conditioner reset_cond 
     (
      .clk(clk100),
      .in(~rst_n),
      .out(rst)
      );
   
   wire [56:0]   memOut;
   wire [33:0]   memIn;

   // if sdram is clocked at 100MHz (as it must be), and ram_test is
   // clocked at 50MHz.. we get errors.
   // we must clock it at 100MHz also.
   
   sdram sdram 
     (
      .clk(clk100),
      .rst(rst),
      .sdramOut(sdramOut),
      .sdramInOut(sdramInOut),
      //switch in/out! Bad idea to have In/Out in the name.      
      .memIn(memOut),
      .memOut(memIn)
      );

   // This is the ram_test demo from the mojo tutorial
   /*wire [7:0]    ram_test_led;
    ram_test ram_test 
    (
    .clk(clk100),
    .rst(rst),
    .memOut(memOut),
    .memIn(memIn),
    .leds(ram_test_led)
    );*/
   
   wire          new_sample;
   wire [9:0]    sample;
   wire [3:0]    sample_channel;
   
   wire [1:8]    rx_data;
   wire          rx_new;
   
   wire [1:8]    tx_data;
   wire          tx_send;
   wire          tx_busy;
   
   wire [1:8]    qtx_data;
   wire          qtx_send;
   wire          qtx_busy;

   wire          mem_init;
   wire [1:logsize] mem_addr;
   wire [1:8]       mem_wdata;
   wire             mem_wselect;
   wire             mem_doit;
   wire             mem_busy;
   wire             mem_rvalid;
   wire [1:8]       mem_rdata;

   wire             running;
   wire             rx_stall;
   wire [1:logsize] mp;
   wire [1:6]       view_pc;
   wire [1:4]       view_errors;



   // Choose simulated or real memory... 
   
   //mem_sim_instant mem

   //1000 delay steps slows the fibs computation nicely
   //mem_sim_delay #(.logsize(logsize), .steps(1000)) mem
   
   mem_real_adaptor #(.logsize(logsize)) mem
     (
      .clk(clk100),

      // comment out these two lines when using simulated memory
      .memOut(memOut),
      .memIn(memIn),
      
      .init(mem_init),
      .addr(mem_addr),
      .wdata(mem_wdata),
      .wselect(mem_wselect),
      .doit(mem_doit),
      .busy(mem_busy),
      .rvalid(mem_rvalid),
      .rdata(mem_rdata)
      );

   bf #(.logsize(logsize)) bf
     (.clk(clk100),
      .rst(rst),
      .rx_data(rx_data),
      .rx_new(rx_new),
      .tx_data(tx_data),
      .tx_send(tx_send),
      .tx_busy(tx_busy),
      .mem_init(mem_init),
      .mem_addr(mem_addr),
      .mem_wdata(mem_wdata),
      .mem_wselect(mem_wselect),
      .mem_doit(mem_doit),
      .mem_busy(mem_busy),
      .mem_rvalid(mem_rvalid),
      .mem_rdata(mem_rdata),
      .running(running),
      .rx_stall(rx_stall),
      .mp(mp),
      .view_pc(view_pc),
      .view_errors(view_errors)
      );

   // The quotae_tx module translates each byte written into the two
   // bytes for the hex code of that byte. i.e "ab" -> "6162".  This
   // can be helxpful when debugging!
   
   /*quote_tx qt
    (.clk(clk100),
    .a_data(tx_data),
    .a_send(tx_send),
    .a_busy(tx_busy),
    .b_data(qtx_data),
    .b_send(qtx_send),
    .b_busy(qtx_busy));*/
   assign qtx_data = tx_data;
   assign qtx_send = tx_send;
   assign tx_busy = qtx_busy;

   // When client is at 100MHz, but avr is at 50MHz: some output is dropped.

   // When client is at 100MHz, and avr is at 100MHz,
   // (but the parameter is not adjusted) : ... rx does not work.

   // When client is at 100MHz, and avr is at 100MHz,
   // (and param is adjusted): ... rx/tx appears to work fine...
   // at least for my bf/fibs/sim-mem-delay1000 example
   
   avr_interface #(.CLK_FREQ(100000000)) avr
     (
      .clk(clk100),
      .rst(rst),
      .cclk(cclk),
      .spi_miso(spi_miso),
      .spi_mosi(spi_mosi),
      .spi_sck(spi_sck),
      .spi_ss(spi_ss),
      .channel(4'hf),
      .new_sample(new_sample),
      .sample(sample),
      .sample_channel(sample_channel),
      .spi_channel(spi_channel),
      .tx(avr_rx),
      .rx(avr_tx),
      .tx_data(qtx_data),
      .new_tx_data(qtx_send),
      .tx_busy(qtx_busy),
      .rx_data(rx_data),
      .new_rx_data(rx_new),
      .tx_block(avr_rx_busy)
      );

endmodule
