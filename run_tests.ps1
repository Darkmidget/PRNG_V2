$bin = "C:\AMDDesignTools\2025.2\Vivado\bin"

Write-Host "Compiling all sources..."
$srcs = @(Get-ChildItem src\*.v | Select-Object -ExpandProperty FullName)
$tbs = @(Get-ChildItem testbench\*.v | Select-Object -ExpandProperty FullName)

$args_xvlog = @()
$args_xvlog += $srcs
$args_xvlog += $tbs
$args_xvlog += "C:\AMDDesignTools\2025.2\Vivado\data\verilog\src\glbl.v"

& "$bin\xvlog.bat" $args_xvlog
if ($LASTEXITCODE -ne 0) {
    Write-Host "`nError: xvlog failed to compile sources." -ForegroundColor Red
    exit 1
}

function Run-Test {
    param([string]$tb_name)
    Write-Host "`n--- Running $tb_name ---"
    
    # Run xelab with unisims_ver and glbl for Xilinx primitives (e.g. XADC)
    & "$bin\xelab.bat" -debug typical -L unisims_ver -L unimacro_ver -L secureip -L xpm $tb_name glbl -s "${tb_name}_sim"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`nError: xelab failed for $tb_name. Aborting simulation." -ForegroundColor Red
        exit 1
    }
    
    # Run xsim
    & "$bin\xsim.bat" "${tb_name}_sim" -R
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`nError: xsim failed for $tb_name. Aborting tests." -ForegroundColor Red
        exit 1
    }
}

Run-Test "tb_game_of_life"
Run-Test "tb_hx8357d_controller"
Run-Test "tb_lfsr_nl_seed_uart"
Run-Test "reaction_game_tb"
