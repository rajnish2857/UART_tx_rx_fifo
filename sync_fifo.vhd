-- Synchronous FIFO, first-word-fall-through (rd_data always shows the oldest entry)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sync_fifo is
  generic (
    DATA_WIDTH : positive := 8;
    DEPTH_LOG2 : positive := 4          -- depth = 2**DEPTH_LOG2
  );
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;            -- synchronous, active high
    wr_en   : in  std_logic;
    wr_data : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    rd_en   : in  std_logic;
    rd_data : out std_logic_vector(DATA_WIDTH-1 downto 0);
    full    : out std_logic;
    empty   : out std_logic;
    count   : out unsigned(DEPTH_LOG2 downto 0)
  );
end entity;

architecture rtl of sync_fifo is
  constant DEPTH : natural := 2**DEPTH_LOG2;
  type mem_t is array (0 to DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal mem    : mem_t := (others => (others => '0'));
  signal wr_ptr : unsigned(DEPTH_LOG2-1 downto 0) := (others => '0');
  signal rd_ptr : unsigned(DEPTH_LOG2-1 downto 0) := (others => '0');
  signal cnt    : unsigned(DEPTH_LOG2 downto 0)   := (others => '0');
  signal full_i, empty_i : std_logic;
  signal do_wr, do_rd    : std_logic;
begin
  full_i  <= '1' when cnt = DEPTH else '0';
  empty_i <= '1' when cnt = 0     else '0';

  -- writes are ignored when full, reads when empty
  do_wr <= wr_en and not full_i;
  do_rd <= rd_en and not empty_i;

  rd_data <= mem(to_integer(rd_ptr));
  full    <= full_i;
  empty   <= empty_i;
  count   <= cnt;

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        wr_ptr <= (others => '0');
        rd_ptr <= (others => '0');
        cnt    <= (others => '0');
      else
        if do_wr = '1' then
          mem(to_integer(wr_ptr)) <= wr_data;
          wr_ptr <= wr_ptr + 1;
        end if;
        if do_rd = '1' then
          rd_ptr <= rd_ptr + 1;
        end if;

        if do_wr = '1' and do_rd = '0' then
          cnt <= cnt + 1;
        elsif do_wr = '0' and do_rd = '1' then
          cnt <= cnt - 1;
        end if;
      end if;
    end if;
  end process;
end architecture;
