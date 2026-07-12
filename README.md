# RTL Design of UART Transmitter and Receiver

RTL implementation of a configurable UART (Universal Asynchronous Receiver/Transmitter) in **Verilog**, with self-checking testbenches written in **SystemVerilog**. The project covers both the **Transmitter (TX)** and **Receiver (RX)** blocks independently, plus an integrated **full-duplex** top level.

UART is a full-duplex, asynchronous serial protocol: the transmitting side converts parallel data into a serial bitstream, and the receiving side reconstructs it back into parallel data, with no shared clock between the two devices.

```
Device 1                          Device 2
 ┌───────────────┐                ┌───────────────┐
 │  TX ──────────┼───────────────▶│ RX            │
 │  RX ◀─────────┼────────────────┼─ TX            │
 │  GND ─────────┼────────────────┼─ GND           │
 └───────────────┘                └───────────────┘
```

## Repository Structure

```
.
├── tx/     # UART Transmitter RTL + testbench
├── rx/     # UART Receiver RTL + testbench
└── full/   # Integrated TX + RX (full-duplex) top level
```

---

## UART Transmitter (TX)

### Block Interface

| Port Name    | Width | Direction | Description                                |
|--------------|:-----:|:---------:|---------------------------------------------|
| `CLK`        | 1     | in        | UART TX clock signal                        |
| `RST`        | 1     | in        | Synchronized reset signal                    |
| `PAR_EN`     | 1     | in        | Parity enable (0: disabled, 1: enabled)      |
| `PAR_TYP`    | 1     | in        | Parity type (0: even, 1: odd)                |
| `P_DATA`     | 8     | in        | Input data byte                              |
| `DATA_VALID` | 1     | in        | Input data valid strobe                      |
| `TX_OUT`     | 1     | out       | Serial data output                           |
| `Busy`       | 1     | out       | High while a frame is being transmitted      |

### Specification Highlights

- New data on `P_DATA` is accepted only when `DATA_VALID` is high, and `DATA_VALID` is asserted for exactly **one clock cycle**.
- While `Busy` is high (frame in progress), any new `DATA_VALID` pulse is ignored — the TX will not interrupt an in-flight frame.
- `TX_OUT` idles high; a frame is `START (0) → 8 data bits (LSB or MSB first) → [parity bit] → STOP (1)`.
- All registers use an **asynchronous active-low reset**.
- Testbench validates the design at a UART clock of **200 MHz**.

### Frame Formats Supported

1. Start bit + 8 data bits + even parity + stop bit
2. Start bit + 8 data bits + odd parity + stop bit
3. Start bit + 8 data bits + stop bit (parity disabled)

### FSM States (`FSM_TX`)

Straight from `FSM_TX`'s `localparam`s and next-state/output logic (`cs`/`ns`, outputs `SER_EN`, `SAMPLE`, `SEL`, which drive the serializer and the output mux):

| State     | Encoding | `SEL` | Next State                                                   | Outputs / Behavior                                                                 |
|-----------|:--------:|:-----:|----------------------------------------------------------------|--------------------------------------------------------------------------------------|
| `IDLE`    | `000`    | `000` | `START` when `DATA_VALID`, else stays `IDLE`                   | `SER_EN=0`. `SAMPLE=1` for the cycle `DATA_VALID` is high (latches `P_DATA` in).      |
| `START`   | `001`    | `001` | unconditionally → `TRANS` (one clock = one bit period)          | `SER_EN=1`, `SAMPLE=0`. Mux outputs the start bit.                                    |
| `TRANS`   | `010`    | `010` | stays `TRANS` until `SER_DONE`; then `PARITY` if `REG_PAR_EN`, else `STOP` | `SER_EN=1` (deasserted the cycle `SER_DONE` fires). Serializer shifts the 8 data bits out. |
| `PARITY`  | `011`    | `011` | unconditionally → `STOP`                                       | `SER_EN=0`. Mux outputs the computed parity bit. Only entered if `REG_PAR_EN`.        |
| `STOP`    | `100`    | `100` | unconditionally → `IDLE`                                       | `SER_EN=0`. Mux outputs the stop bit (`1`).                                            |

`SEL` feeds the output mux (`start_bit` / serialized data / `par_bit` / `stop_bit`); `Busy` is high in every state except `IDLE`.

---

## UART Receiver (RX)

### Block Interface

| Port Name      | Width | Direction | Description                                    |
|-----------------|:-----:|:---------:|-------------------------------------------------|
| `CLK`           | 1     | in        | UART RX clock signal (oversampled)               |
| `RST`           | 1     | in        | Synchronized reset signal                        |
| `PAR_EN`        | 1     | in        | Parity enable (0: disabled, 1: enabled)          |
| `PAR_TYP`       | 1     | in        | Parity type (0: even, 1: odd)                    |
| `Prescale`      | 6     | in        | Oversampling prescale value                      |
| `RX_IN`         | 1     | in        | Serial data input                                |
| `P_DATA`        | 8     | out       | Received data byte                               |
| `data_valid`    | 1     | out       | High for one cycle when `P_DATA` is valid        |
| `Parity_Error`  | 1     | out       | High when received parity does not match         |
| `Stop_Error`    | 1     | out       | High when the stop bit is not `1`                |

### Specification Highlights

- `RX_IN` idles high; a frame begins on the falling edge (start bit).
- Supports **oversampling by 8, 16, or 32**, configured via `Prescale`. Each bit is sampled near its midpoint (majority/3-sample vote at 8x oversampling) to reject glitches near bit edges.
- `data_valid` and `P_DATA` are only updated when the frame is clean (`Parity_Error == 0 && Stop_Error == 0`).
- Back-to-back frames are supported with **no gap** required between them.
- All registers use an **asynchronous active-low reset**.
- Testbench validates the design against a UART TX clock of **115.2 KHz**, with derived RX clocks:

  | Prescale | RX_CLK               |
  |:--------:|-----------------------|
  | 8        | 115.2 KHz × 8 = 921.6 KHz |
  | 16       | 115.2 KHz × 16 = 1.843 MHz |
  | 32       | 115.2 KHz × 32 = 3.686 MHz |

### FSM States (`FSM_RX`)

Straight from `FSM_RX`'s `localparam`s and next-state/output logic. `EDGE_CNT` counts oversample edges within the current bit (reset each bit via `CNT_RST`), `BIT_CNT` counts bits within the frame, and `PRESCALE` sets the oversample ratio (8/16/32). Each `sample_check(chk_sig)` invocation asserts `DAT_SAMP_EN` for a 3-cycle sampling window centered on the bit (`half_prescale-1 .. half_prescale+1`) and pulses the state's check-enable signal (`chk_sig`) one cycle later, at `EDGE_CNT == half_prescale+2`.

| State         | Encoding | Next State                                                                                                    | Outputs / Behavior                                                                                          |
|---------------|:--------:|-------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------|
| `IDLE`        | `000`    | `START_CHK` when `RX_IN` goes low, else stays `IDLE`                                                          | `CNT_RST=1` by default; if `~RX_IN`, `CNT_EN=1` and `CNT_RST=0` to start counting the start bit.               |
| `START_CHK`   | `001`    | At `BIT_CNT==0 && EDGE_CNT==PRESCALE-1`: `IDLE` if `STRT_GLITCH`, else `DATA_SAMP`. Otherwise stays.           | `CNT_EN=1`. `sample_check(STRT_CHK_EN)` — samples mid-bit, pulses `STRT_CHK_EN` to validate the start bit.     |
| `DATA_SAMP`   | `010`    | At `BIT_CNT==8 && EDGE_CNT==PRESCALE-1`: `PARITY_CHK` if `PAR_EN`, else `STP_CHK`. Otherwise stays.            | `CNT_EN=1`. `sample_check(DES_EN)` — samples each of the 8 data bits and pulses `DES_EN` to shift into the deserializer. |
| `PARITY_CHK`  | `011`    | At `BIT_CNT==9 && EDGE_CNT==PRESCALE-1`: `STP_CHK`. Otherwise stays. (Only entered if `PAR_EN`.)               | `CNT_EN=1`. `sample_check(PAR_CHK_EN)` — samples the parity bit and pulses `PAR_CHK_EN` to compare parity.     |
| `STP_CHK`     | `100`    | At `(BIT_CNT==9 && ~PAR_EN)\|\|(BIT_CNT==10 && PAR_EN)) && EDGE_CNT==PRESCALE-1`: `IDLE`. Otherwise stays.        | `CNT_EN=1`. `sample_check(STP_CHK_EN)` — samples/checks the stop bit. Also sets `frame_done=1` at `EDGE_CNT==PRESCALE-2`, and `CNT_RST=1` at `EDGE_CNT==PRESCALE-1`. |

`DATA_VALID` is a registered output: on the cycle after `frame_done`, it's set to `~STP_ERR && ~PAR_ERR` (i.e. only pulses high if the frame was clean); otherwise it's held low.

### Internal Architecture

The RX datapath is split into cooperating submodules, coordinated by a central FSM:

- **FSM** — sequences the frame through `IDLE → START_CHK → DATA_SAMP → [PARITY_CHK] → STP_CHK`, and drives enable signals to the other blocks.
- **edge_bit_counter** — tracks oversample edge count (`edge_cnt`) and bit position (`bit_cnt`) within the current frame.
- **data_sampling** — samples `RX_IN` at the configured oversample points and produces `sampled_bit`.
- **strt_check** — detects start-bit glitches (`strt_glitch`).
- **parity_check** — computes/compares the parity bit (`par_err`).
- **stop_check** — checks the stop bit (`stp_err`).
- **deserializer** — shifts sampled bits into the output byte (`P_DATA`).

---

## Requirements Implemented

- [x] UART TX implemented in Verilog per spec, verified with a SystemVerilog testbench @ 200 MHz.
- [x] UART RX implemented in Verilog per spec, verified with a SystemVerilog testbench referenced to a 115.2 KHz UART clock (8x/16x/32x oversampling).
- [x] Configurable parity (enable + even/odd) and configurable oversampling on RX.
- [x] Self-checking testbenches with scoreboarding for `data_valid`, `P_DATA`, `Parity_Error`, and `Stop_Error`.

## Status / Notes

This is an active, iterative design project — RTL and testbenches are being refined module by module (FSM, data sampling, parity/stop checking) as edge cases are found during simulation. See individual module headers/comments for in-progress notes.
