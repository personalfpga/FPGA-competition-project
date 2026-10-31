@echo off
setlocal
set "task_vivado="
if defined VIVADO_BIN set "task_vivado=%VIVADO_BIN%"
if not defined task_vivado for /f "delims=" %%V in ('where vivado 2^>nul') do if not defined task_vivado set "task_vivado=%%V"
if not defined task_vivado for %%V in ("%SystemDrive%\AMDDesignTools\2025.2\Vivado\bin\vivado.bat" "%SystemDrive%\Xilinx\Vivado\2025.2\bin\vivado.bat") do if exist "%%~V" set "task_vivado=%%~V"
if not defined task_vivado (
  echo Vivado not found. Add Vivado 2025.2 bin to PATH or set VIVADO_BIN to vivado.bat.
  exit /b 1
)
call "%task_vivado%" %*
exit /b %errorlevel%
