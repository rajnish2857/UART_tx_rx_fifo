-- UART with TX and RX FIFOs.
--   Write bytes into the TX FIFO (tx_wr_en / tx_wr_data) and they are sent out automatically.
--   Received bytes are stored in the RX FIFO; read them with rx_rd_en (rx_rd_data shows the oldest byte).
library ieee;
use ieee.std_logic_1164.all;

entity uart_fifo_top is
  generic (
    CLKS_PER_BIT    : positive := 434;  -- clk frequency / baud rate
    FIFO_DEPTH_LOG2 : positive := 4     -- 16 entries
  );
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;

    -- TX side
    tx_wr_en    : in  std_logic;
    tx_wr_data  : in  std_logic_vector(7 downto 0);
    tx_full     : out std_logic;

    -- RX side
    rx_rd_en    : in  std_logic;
    rx_rd_data  : out std_logic_vector(7 downto 0);
    rx_empty    : out std_logic;
    rx_full     : out std_logic;        -- bytes arriving while full are dropped
    rx_frame_err: out std_logic;

    -- serial pins
    uart_txd    : out std_logic;
    uart_rxd    : in  std_logic
  );
end entity;

architecture rtl of uart_fifo_top is
  signal txf_rd_data : std_logic_vector(7 downto 0);
  signal txf_empty   : std_logic;
  signal tx_busy     : std_logic;
  signal tx_start    : std_logic;

  signal rx_data     : std_logic_vector(7 downto 0);
  signal rx_valid    : std_logic;
begin
  -- Start a transmission whenever the TX FIFO has data and the transmitter is idle.
  -- The FIFO is first-word-fall-through, so tx_start also pops the byte being sent.
  tx_start <= (not txf_empty) and (not tx_busy);

  u_tx_fifo : entity work.sync_fifo
    generic map (DATA_WIDTH => 8, DEPTH_LOG2 => FIFO_DEPTH_LOG2)
    port map (
      clk => clk, rst => rst,
      wr_en => tx_wr_en, wr_data => tx_wr_data,
      rd_en => tx_start, rd_data => txf_rd_data,
      full => tx_full, empty => txf_empty, count => open
    );

  u_tx : entity work.uart_tx
    generic map (CLKS_PER_BIT => CLKS_PER_BIT)
    port map (
      clk => clk, rst => rst,
      tx_start => tx_start, tx_data => txf_rd_data,
      tx => uart_txd, tx_busy => tx_busy
    );

  u_rx : entity work.uart_rx
    generic map (CLKS_PER_BIT => CLKS_PER_BIT)
    port map (
      clk => clk, rst => rst,
      rx => uart_rxd,
      rx_data => rx_data, rx_valid => rx_valid, frame_err => rx_frame_err
    );

  u_rx_fifo : entity work.sync_fifo
    generic map (DATA_WIDTH => 8, DEPTH_LOG2 => FIFO_DEPTH_LOG2)
    port map (
      clk => clk, rst => rst,
      wr_en => rx_valid, wr_data => rx_data,
      rd_en => rx_rd_en, rd_data => rx_rd_data,
      full => rx_full, empty => rx_empty, count => open
    );
end architecture;
