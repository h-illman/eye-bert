# program_fpga.ps1 — program the DE25-Standard over USB-Blaster II
# Usage: .\program_fpga.ps1 [-Sof path\to\bert_top.sof]
param([string]$Sof = "..\platform\output_files\bert_top.sof")
$ErrorActionPreference = "Stop"
if (-not (Test-Path $Sof)) { throw "SOF not found: $Sof — run a Quartus compile first." }
quartus_pgm -c "USB-BlasterII" -m JTAG -o "p;$Sof@1"
Write-Host "FPGA programmed: $Sof"
