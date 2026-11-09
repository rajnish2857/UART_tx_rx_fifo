# UART Transceiver with FIFOs (VHDL)

A UART (8N1) transmitter and receiver written in VHDL, each buffered by a synchronous FIFO. A self-checking loopback testbench verifies the design in simulation.

**Status:** verified in simulation with GHDL. Not yet synthesized or tested on an FPGA board.

## Features

- 8N1 framing: 1 start bit, 8 data bits (LSB first), 1 stop bit, no parity
- Baud rate set by the `CLKS_PER_BIT` generic (clock frequency / baud rate)
- Receiver with a two-flop input synchroniser, start-bit glitch rejection, mid-bit sampling and framing-error detection
- Parameterised synchronous FIFO (width and depth), first-word-fall-through read, with `full`, `empty` and `count` outputs
- TX FIFO feeds the transmitter automatically; the RX FIFO collects received bytes
- Self-checking loopback testbench using `assert` statements

## Architecture

```
                  +-----------------------------------------------+
                  |                uart_fifo_top                  |
 tx_wr_en/data -->|--> [ TX FIFO ] --> [ uart_tx ] ---------------|--> uart_txd
                  |                                               |
 rx_rd_en/data <--|<-- [ RX FIFO ] <-- [ uart_rx ] <--------------|<-- uart_rxd
                  +-----------------------------------------------+
```

The top level starts a transmission whenever the TX FIFO is not empty and the transmitter is idle. The receiver pushes each good byte into the RX FIFO.

## Files

| File | Description |
|------|-------------|
| `sync_fifo.vhd` | Generic synchronous FIFO (first-word-fall-through) |
| `uart_tx.vhd` | UART transmitter (4-state FSM) |
| `uart_rx.vhd` | UART receiver (4-state FSM, input synchroniser) |
| `uart_fifo_top.vhd` | Top level: UART TX and RX, each with a FIFO |
| `tb_uart_fifo.vhd` | Loopback testbench |

## Interfaces

### `uart_fifo_top`

| Port | Dir | Description |
|------|-----|-------------|
| `clk`, `rst` | in | Clock and synchronous active-high reset |
| `tx_wr_en`, `tx_wr_data[7:0]` | in | Write a byte into the TX FIFO |
| `tx_full` | out | TX FIFO full (writes are ignored while full) |
| `rx_rd_en` | in | Pop a byte from the RX FIFO |
| `rx_rd_data[7:0]` | out | Oldest received byte (valid when `rx_empty = '0'`) |
| `rx_empty`, `rx_full` | out | RX FIFO status |
| `rx_frame_err` | out | One-clock pulse when a stop bit was not high |
| `uart_txd`, `uart_rxd` | out / in | Serial pins |

### Generics

| Generic | Default | Meaning |
|---------|---------|---------|
| `CLKS_PER_BIT` | 434 | Clock cycles per bit (50 MHz / 115200 baud) |
| `FIFO_DEPTH_LOG2` | 4 | FIFO depth = 2^4 = 16 bytes |

## How it works

**Transmitter.** Idles high. On `tx_start` it latches the byte, then drives the start bit, 8 data bits (LSB first) and the stop bit, holding each for `CLKS_PER_BIT` clock cycles. `tx_busy` is high whenever it is not idle.

**Receiver.** Synchronises `rx` with two flip-flops, waits for a falling edge, then waits half a bit and checks the line is still low to reject glitches. After that it samples one bit every `CLKS_PER_BIT` cycles, so each sample lands near the middle of a bit. If the stop bit is high it outputs the byte with a one-clock `rx_valid` pulse; otherwise it pulses `frame_err`.

## Simulation (GHDL)

Compile and run from the folder with the `.vhd` files:

```bash
ghdl -a --std=08 sync_fifo.vhd uart_tx.vhd uart_rx.vhd uart_fifo_top.vhd tb_uart_fifo.vhd
ghdl -e --std=08 tb_uart_fifo
ghdl -r --std=08 tb_uart_fifo --stop-time=200us --wave=wave.ghw
```

Expected output:

```
PASS: all 8 bytes received correctly
```

View the waveform with `gtkwave wave.ghw`.

The testbench connects `uart_txd` to `uart_rxd`, writes 8 bytes into the TX FIFO, reads them back from the RX FIFO and asserts that every byte matches, the RX FIFO ends empty and no framing errors occurred. It uses `CLKS_PER_BIT = 16` so the simulation is fast.

## Limitations

- No parity bit and no configurable data width or stop bits
- Baud rate is fixed at compile time through the generic
- A byte received while the RX FIFO is full is dropped without an error flag
- Single clock domain; not yet tested on hardware

## Possible extensions

- Overflow flag for the RX FIFO
- Parity support
- Runtime-configurable baud rate
- FPGA top level with pin constraints and a test on a development board
