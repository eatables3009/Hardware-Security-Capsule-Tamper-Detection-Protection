# Hardware-Security-Capsule-Tamper-Detection-Protection
Verilog-based hardware security module with tamper detection and protection logic, verified using a simulation testbench.
# 🔐 Hardware Security Capsule (Verilog)

This project implements a **hardware-level security module** in Verilog that detects tampering attempts and triggers protective actions. It demonstrates fundamental concepts in **hardware security, fault detection, and secure system design**.

---

## 📌 Features

- 🔍 Tamper detection logic
- 🚨 Security trigger / alert mechanism
- 🔒 Protection response (lock/reset/disable behavior)
- 🧪 Fully verified using a testbench
- ⚡ Lightweight and synthesizable design

---

---

## ⚙️ Module Overview

### 🔐 Security Capsule (`security_capsule.v`)

Core responsibilities:
- Monitor system inputs for abnormal behavior
- Detect tampering conditions
- Trigger protection signals

Typical signals:
- Inputs: clock, reset, trigger/tamper signals
- Outputs: alert flag, secure state signal

---

### 🧪 Testbench (`tb_security_capsule.v`)

- Simulates normal and attack scenarios
- Verifies detection and response behavior
- Helps visualize system response over time

---

## ▶️ How to Run

### Using Icarus Verilog

```bash
iverilog -o sim security_capsule.v tb_security_capsule.v
vvp sim
