-- UART receiver, 8N1. Two-flop input synchroniser, samples each bit at its midpoint.
library ieee;
use ieee.std_logic_1164.all;

entity uart_rx is
  generic (
    CLKS_PER_BIT : positive := 434
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;          -- synchronous, active high
    rx        : in  std_logic;
    rx_data   : out std_logic_vector(7 downto 0);
    rx_valid  : out std_logic;          -- one-clock pulse when rx_data is a good byte
    frame_err : out std_logic           -- one-clock pulse when the stop bit was not '1'
  );
end entity;

architecture rtl of uart_rx is
  type state_t is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
  signal state    : state_t := IDLE;
  signal clk_cnt  : integer range 0 to CLKS_PER_BIT-1 := 0;
  signal bit_idx  : integer range 0 to 7 := 0;
  signal shreg    : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_s1    : std_logic := '1';
  signal rx_s2    : std_logic := '1';
  signal data_r   : std_logic_vector(7 downto 0) := (others => '0');
  signal valid_r  : std_logic := '0';
  signal ferr_r   : std_logic := '0';
begin
  rx_data   <= data_r;
  rx_valid  <= valid_r;
  frame_err <= ferr_r;

  process (clk)
  begin
    if rising_edge(clk) then
      -- synchroniser (rx is asynchronous to clk)
      rx_s1 <= rx;
      rx_s2 <= rx_s1;

      -- default: pulses last one clock
      valid_r <= '0';
      ferr_r  <= '0';

      if rst = '1' then
        state   <= IDLE;
        clk_cnt <= 0;
        bit_idx <= 0;
      else
        case state is
          when IDLE =>
            clk_cnt <= 0;
            bit_idx <= 0;
            if rx_s2 = '0' then          -- falling edge: possible start bit
              state <= START_BIT;
            end if;

          when START_BIT =>              -- wait to the middle of the start bit
            if clk_cnt = (CLKS_PER_BIT-1)/2 then
              if rx_s2 = '0' then        -- still low: real start bit
                clk_cnt <= 0;
                state   <= DATA_BITS;
              else                       -- glitch, go back
                state   <= IDLE;
              end if;
            else
              clk_cnt <= clk_cnt + 1;
            end if;

          when DATA_BITS =>              -- one full bit later = middle of each data bit
            if clk_cnt = CLKS_PER_BIT-1 then
              clk_cnt        <= 0;
              shreg(bit_idx) <= rx_s2;
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
            if clk_cnt = CLKS_PER_BIT-1 then
              clk_cnt <= 0;
              state   <= IDLE;
              if rx_s2 = '1' then
                data_r  <= shreg;
                valid_r <= '1';
              else
                ferr_r  <= '1';
              end if;
            else
              clk_cnt <= clk_cnt + 1;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
