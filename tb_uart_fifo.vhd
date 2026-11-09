-- Loopback testbench: TX pin wired to RX pin. Sends 8 bytes through the TX FIFO,
-- reads them back from the RX FIFO and checks every byte.
library ieee;
use ieee.std_logic_1164.all;

entity tb_uart_fifo is
end entity;

architecture sim of tb_uart_fifo is
  constant CLK_PERIOD   : time := 10 ns;
  constant CLKS_PER_BIT : positive := 16;   -- small value so simulation is fast

  type byte_array is array (0 to 7) of std_logic_vector(7 downto 0);
  constant TEST_DATA : byte_array :=
    (x"55", x"A3", x"00", x"FF", x"3C", x"81", x"7E", x"C4");

  signal clk, rst      : std_logic := '0';
  signal tx_wr_en      : std_logic := '0';
  signal tx_wr_data    : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_full       : std_logic;
  signal rx_rd_en      : std_logic := '0';
  signal rx_rd_data    : std_logic_vector(7 downto 0);
  signal rx_empty      : std_logic;
  signal rx_full       : std_logic;
  signal rx_frame_err  : std_logic;
  signal serial_line   : std_logic;
  signal done          : boolean := false;
  signal frame_errors  : natural := 0;
begin
  -- clock
  clk_gen : process
  begin
    while not done loop
      clk <= '0'; wait for CLK_PERIOD/2;
      clk <= '1'; wait for CLK_PERIOD/2;
    end loop;
    wait;
  end process;

  dut : entity work.uart_fifo_top
    generic map (CLKS_PER_BIT => CLKS_PER_BIT, FIFO_DEPTH_LOG2 => 4)
    port map (
      clk => clk, rst => rst,
      tx_wr_en => tx_wr_en, tx_wr_data => tx_wr_data, tx_full => tx_full,
      rx_rd_en => rx_rd_en, rx_rd_data => rx_rd_data,
      rx_empty => rx_empty, rx_full => rx_full, rx_frame_err => rx_frame_err,
      uart_txd => serial_line, uart_rxd => serial_line     -- loopback
    );

  -- count framing errors
  err_mon : process (clk)
  begin
    if rising_edge(clk) and rx_frame_err = '1' then
      frame_errors <= frame_errors + 1;
    end if;
  end process;

  stim : process
  begin
    rst <= '1';
    wait for 10 * CLK_PERIOD;
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);

    -- push all bytes into the TX FIFO, one per clock
    for i in TEST_DATA'range loop
      tx_wr_data <= TEST_DATA(i);
      tx_wr_en   <= '1';
      wait until rising_edge(clk);
    end loop;
    tx_wr_en <= '0';

    -- read them back and compare
    for i in TEST_DATA'range loop
      if rx_empty = '1' then
        wait until rx_empty = '0' for 20 us;
      end if;
      assert rx_empty = '0'
        report "Timeout waiting for byte " & integer'image(i)
        severity failure;
      assert rx_rd_data = TEST_DATA(i)
        report "Byte " & integer'image(i) & " mismatch"
        severity failure;
      rx_rd_en <= '1';
      wait until rising_edge(clk);
      rx_rd_en <= '0';
      wait until rising_edge(clk);
    end loop;

    assert rx_empty = '1' report "RX FIFO should be empty" severity failure;
    assert frame_errors = 0 report "Framing errors seen" severity failure;

    report "PASS: all 8 bytes received correctly" severity note;
    done <= true;
    wait;
  end process;
end architecture;
