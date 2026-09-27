# MFA Smart Lock

**FPGA-Based Multi-Factor Authentication System**

Target: Digilent Basys 3 / Xilinx Artix-7 XC7A35T-1CPG236C
HDL: Verilog-2001 | Tool: Xilinx Vivado

---

## 1. Project Overview

This project implements an FPGA-based smart lock using true 2-of-4 multi-factor authentication. A configured user must successfully provide two of four possible authentication factors: NFC/RFID, keypad PIN, OTP, or biometric authentication. The FPGA performs the core authentication and physical lock-control functions.

The design contains six user slots: one administrator and five guests. Each user can have a configurable two-factor requirement. Security functions include PIN hashing, HOTP support, failed-attempt counting, timed lockout, and intrusion-pattern detection.

## 2. Authentication Architecture

```
NFC/RFID ───────┐
Keypad ─────────┤
OTP / UART ─────┤
Biometric ──────┤
                ▼
       ┌─────────────────────┐
       │     FPGA / RTL      │
       │ MFA + User DB +     │
       │ Security + FSM      │
       └───────┬─────────────┘
               ├── Solenoid
               ├── Buzzer
               ├── LEDs
               └── OLED support
               │
              UART
               │
             ESP32
               │
           Bluetooth
               │
          Android App
```

The Android/ESP32 path is intended for monitoring, management and future mobile integration. The FPGA remains the authority for the physical authentication and lock-control path.

## 3. Factor Encoding

| Bit | Factor      | RTL / Interface                                 |
|-----|-------------|--------------------------------------------------|
| 0   | NFC / RFID  | `nfc_interface.v` + dedicated UART RX            |
| 1   | Keypad PIN  | `keypad_scanner.v` + `pin_hash.v`                |
| 2   | OTP         | `otp_check.v` + `hotp_rfc4226.v` + dedicated UART RX |
| 3   | Biometric   | `biometric_interface.v` + dedicated UART RX      |

Valid two-factor masks are `0011` (NFC+PIN), `0101` (NFC+OTP), `0110` (PIN+OTP), `1001` (NFC+Biometric), `1010` (PIN+Biometric), and `1100` (OTP+Biometric).

## 4. Complete RTL Module Reference

| Module | Role | Description |
|---|---|---|
| `mfa_lock_top.v` | Top-level integration | Connects the clock/reset, keypad, three UART inputs, authentication FSM, user database, factor logic, security logic and physical outputs. This is the main synthesis/implementation top. |
| `access_control_fsm.v` | Main authentication controller | Controls initialization, ready state, user/credential capture, first-factor verification, second-factor waiting/verification, grant, deny, attempt checking, lockout and administrator routing. |
| `admin_menu_fsm.v` | Administrator management FSM | Provides the control path for add/remove/edit user operations and factor-pair configuration through the user database. The physical keypad-driven data-entry UI is still a final integration item if required by project scope. |
| `factor_match.v` | Two-factor tracking | Tracks which required factors have passed and determines when both configured factors have been successfully completed. |
| `user_db.v` | User database | Stores valid/admin status, required factor mask, PIN hash, NFC UID, OTP seed and biometric template ID. Current design uses six slots: one admin and five guests. Supports search/add/remove/edit commands. |
| `keypad_scanner.v` | 4×4 keypad scanner | Scans keypad rows/columns, detects key presses and produces key codes for PIN entry and local interaction. |
| `debounce.v` | Input debouncer | Filters unstable digital/mechanical inputs and produces stable input events. |
| `uart_rx.v` | UART receiver | Generic serial receiver. Three dedicated instances serve NFC, biometric and OTP input paths. |
| `uart_tx.v` | UART transmitter | Generic serial transmit module providing the FPGA UART output path. |
| `nfc_interface.v` | NFC/RFID interface | Receives UID bytes over UART, assembles the UID and produces the completed/checked result used by authentication logic. |
| `biometric_interface.v` | Biometric interface | Receives biometric pass/fail information and template ID over UART. Actual biometric matching is performed by the external sensor. |
| `pin_hash.v` | PIN hashing | Processes the entered PIN using SHA-256 and produces the project's 32-bit comparison value. |
| `hotp_rfc4226.v` | HOTP cryptographic engine | Implements HMAC-SHA1/RFC 4226 HOTP and generates the six-digit HOTP value. RFC 4226 Appendix D vectors were verified. |
| `otp_check.v` | OTP validation | Validates the received OTP using the user's OTP seed and configured validity/window behavior. |
| `attempt_counter.v` | Failure counter | Counts failed authentication attempts and triggers lockout at the configured maximum. Documented hardware value: 5 attempts. |
| `lockout_timer.v` | Lockout timer | Keeps the system locked for the configured timeout and returns the system to READY after expiry. Documented hardware value: 30 seconds. |
| `intrusion_detect.v` | Intrusion detection | Tracks rapid-failure patterns and repeated lockouts as additional security events. |
| `solenoid_driver.v` | Physical lock driver | Generates the lock-release control signal after successful MFA. Requires an external MOSFET/transistor driver and external solenoid supply. |
| `buzzer_driver.v` | Buzzer controller | Generates audible status/security feedback for events such as denial, lockout and intrusion. |
| `led_status.v` | LED status controller | Maps authentication and security conditions to green/red status outputs. |
| `oled_display.v` | OLED support | Provides display command/sequencing support for authentication state, lockout information and administrator menu information. |

## 5. Authentication Flow

```
READY
  │
  ▼
ID_CAPTURE
  │
  ▼
FACTOR1_VERIFY
  │
  ▼
FACTOR2_WAIT
  │
  ▼
FACTOR2_VERIFY
  │
  ├── FAIL → ATTEMPT_CHECK → DENY / LOCKOUT
  │
  └── PASS → GRANT → Solenoid Unlock
```

Administrator path: after successful MFA, an administrator is routed to `S_ADMIN_MENU` instead of the normal guest unlock path.

## 6. Security Architecture

The security chain combines two-factor validation, per-user configuration, cryptographic PIN processing, OTP functionality, failure counting, timed lockout and intrusion-pattern detection.

```
Authentication
      ↓
User Database
      ↓
Factor Match
      ↓
PIN / OTP Security
      ↓
Attempt Counter
      ↓
Lockout Timer
      ↓
Intrusion Detection
      ↓
Physical Lock Control
```

## 7. Verification

| Test | Scenario | Result |
|---|---|---|
| 1 | Correct NFC + correct PIN | PASS — unlock / `S_GRANT` |
| 2 | Correct NFC + wrong PIN | PASS — locked / attempt increments |
| 3 | Five wrong attempts | PASS — `S_LOCKOUT` |
| 4 | Lockout timeout | PASS — `S_READY` |
| 5 | Correct login after recovery | PASS — unlock |

```
Total errors = 0
**************** ALL TESTS PASSED ****************
```

The final full-system testbench verifies correct authentication, rejection of an incorrect second factor, repeated-failure lockout, timeout recovery and successful authentication after recovery.

## 8. Verification Testbenches

- **`mfa_lock_top_tb.v`** — Full-system behavioral verification.
- **`hotp_rfc4226_tb.v`** — Unit verification of the HOTP engine against RFC 4226 Appendix D vectors.
- **`user_db_tb.v`** — User-database-level verification.

## 9. Vivado / FPGA Configuration

| Parameter | Value |
|---|---|
| Board | Digilent Basys 3 |
| FPGA | XC7A35T-1CPG236C |
| HDL | Verilog-2001 |
| Tool | Xilinx Vivado |
| Clock | 100 MHz |
| UART | 115200 baud |
| Authentication | 2 of 4 factors |
| User slots | 6 (1 admin + 5 guests) |
| PIN security | SHA-256 |
| OTP | HMAC-SHA1 / RFC 4226 HOTP |
| Maximum attempts | 5 |
| Hardware lockout | 30 s |
| Simulation lockout | 1 s |

## 10. Repository Structure

```
MFA-Smart-Lock-FPGA/
├── README.md
├── .gitignore
├── rtl/
│   ├── [all RTL modules]
├── simulation/
│   ├── mfa_lock_top_tb.v
│   ├── hotp_rfc4226_tb.v
│   └── user_db_tb.v
├── constraints/
│   └── basys3_mfa_lock.xdc
├── docs/
│   ├── architecture/
│   ├── waveforms/
│   ├── vivado/
│   └── images/
└── reports/
    └── MFA_Smart_Lock_Phase_1_to_6_Report.pdf
```

Generated Vivado folders such as `.cache`, `.hw`, `.ip_user_files`, `.runs`, `.sim` and `.gen` should normally remain outside the source repository.

## 11. Implementation Status

| Stage | Status |
|---|---|
| RTL design and integration | COMPLETE |
| Full-system simulation | COMPLETE |
| Waveform verification | COMPLETE |
| Vivado synthesis | COMPLETE |
| XDC / pin constraints | COMPLETE |
| Place and route | COMPLETE |
| Timing analysis | COMPLETE |
| DRC | CLEAN |
| Gate-level / synthesized schematic | COMPLETE |
| Bitstream | GENERATED |
| Physical hardware bring-up | NEXT STAGE |

## 12. Recorded Implementation Results

| Metric | Recorded value |
|---|---|
| LUT | 294 |
| Flip-Flops | 299 |
| BRAM | 0 |
| WNS | +4.636 ns |
| TNS | 0 ns |
| WHS | +0.134 ns |
| THS | 0 ns |
| Reported total power | ≈ 0.085 W |
| Failed routes | 0 |

## 13. Hardware Integration

The next stage is physical bring-up of the keypad, NFC/RFID reader, biometric sensor, ESP32/Bluetooth bridge, OTP/mobile path, solenoid, buzzer, LEDs and OLED. The solenoid must be driven through appropriate external power and transistor/MOSFET circuitry rather than directly from FPGA I/O.

## 14. Limitations and Future Work

Physical hardware validation, end-to-end ESP32/Bluetooth communication, real OTP-source integration and biometric hardware validation remain. Complete physical administrator data-entry interaction may also require finalization. Persistent user storage across FPGA reset is not implemented in the current design.

## 15. Notes

This README uses the project's detailed technical documentation as its reference. The repository should contain the final active RTL source files, final testbench, final Basys 3 XDC, selected verification evidence and the Phase 1–6 project report. Older duplicate source copies and generated Vivado artifacts should not be presented as the active implementation.

## 16. Author

**Bhaskar Vignesh Karumuri**
FPGA • Verilog • Digital Design • Hardware Security • IoT Integration
