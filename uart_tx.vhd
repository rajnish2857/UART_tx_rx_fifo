-- UART transmitter, 8N1 (1 start bit, 8 data bits LSB first, 1 stop bit)
library ieee;
use ieee.std_logic_1164.all;

entity uart_tx is
  generic (
    CLKS_PER_BIT : positive := 434      -- clk frequency / baud rate (50 MHz / 115200)
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;           -- synchronous, active high
    tx_start : in  std_logic;           -- pulse for one clock while tx_busy = '0'
    tx_data  : in  std_logic_vector(7 downto 0);
    tx       : out std_logic;           -- serial line, idles high
    tx_busy  : out std_logic
  );
end entity;

architecture rtl of uart_tx is
  type state_t is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
  signal state   : state_t := IDLE;
  signal clk_cnt : integer range 0 to CLKS_PER_BIT-1 := 0;
  signal bit_idx : integer range 0 to 7 := 0;
  signal shreg   : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_r    : std_logic := '1';
begin
  tx      <= tx_r;
  tx_busy <= '0' when state = IDLE else '1';

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state   <= IDLE;
        clk_cnt <= 0;
        bit_idx <= 0;
        tx_r    <= '1';
      else
        case state is
          when IDLE =>
            tx_r    <= '1';
            clk_cnt <= 0;
            bit_idx <= 0;
            if tx_start = '1' then
              shreg <= tx_data;
              state <= START_BIT;
            end if;

          when START_BIT =>
            tx_r <= '0';
            if clk_cnt = CLKS_PER_BIT-1 then
              clk_cnt <= 0;
              state   <= DATA_BITS;
            else
              clk_cnt <= clk_cnt + 1;
            end if;

          when DATA_BITS =>
            tx_r <= shreg(bit_idx);
            if clk_cnt = CLKS_PER_BIT-1 then
              clk_cnt <= 0;
              if bit_idx = 7 then
                bit_idx <= 0;
                state   <= STOP_BIT;
              else
                bit_idx <= bit_idx + 1;
              end if;
            else
              clk_cnt <= clk_cnt + 1;
            end if;

          when STOP_BIT =>
            tx_r <= '1';
            if clk_cnt = CLKS_PER_BIT-1 then
              clk_cnt <= 0;
              state   <= IDLE;
            else
              clk_cnt <= clk_cnt + 1;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
