<?xml version="1.0" encoding="UTF-8"?>
<project name="bf" board="Mojo V3" language="Verilog">
  <files>
    <src>mem_sim_delay.v</src>
    <src top="true">mojo_top.v</src>
    <src>bf.v</src>
    <src>ram_test.v</src>
    <src>mem_real_adaptor.v</src>
    <src>mem_sim_instant.v</src>
    <src>quote_tx.v</src>
    <ucf lib="true">sdram_shield.ucf</ucf>
    <ucf lib="true">mojo.ucf</ucf>
    <component>memory_bus.luc</component>
    <component>cclk_detector.luc</component>
    <component>pn_gen.luc</component>
    <component>uart_rx.luc</component>
    <component>spi_slave.luc</component>
    <component>avr_interface.luc</component>
    <component>uart_tx.luc</component>
    <component>sdram.luc</component>
    <component>reset_conditioner.luc</component>
    <core name="my_clk_wiz">
      <src>my_clk_wiz.v</src>
    </core>
    <core name="clk_wiz">
      <src>clk_wiz.v</src>
    </core>
  </files>
</project>
