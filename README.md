# Operating-System-Transplant
## Introduction
 Transplant μC/OS II Operating System on 89-instructions MIPS dynamic pipeline CPU
## Our work
- Realized 89 MIPS CPU, GPIO, UART serial port on Digilent Nexys4 FPGA board, and realized 
  DDR2 reading and writing by MIG, SPI FLASH reading, and seven-segment digital tube, and 
  used Wishbone B2 to connect all modules
- Modified the μC/OS II system, compiled it using the Ubuntu cross-compilation environment, 
  coded it to the flash, and achieved serial port output after running

- For more information, refer to [CPU report](./resources/Report1.pdf) and 
  [OS report](./resources/Report2.pdf).

## Dependencies
- Vivado 2016.2
- Digilent Nexys 4 DDR FPGA board
- [Mars 4.5](http://www.cs.missouristate.edu/MARS/): Mips Assembly and Runtime Simulator

## How to use
### MIPS CPU
1) Include all the files in [code](./code) directory.
2) Use Vivado to synthesis, implementation, generate bitstream and program to board.
3) Configure the spi flash data and write it to the binary program file of the μC/OS II 
   operating system. You need to specify the [Configuration file](./cpu/OS.bin).
- <img src=".\resources\1_1.png" width="500"/>

4) Serial Port Result
- Enable serial port debugging, set the baud rate to 19200 BPS, data bit to 8, no parity bit, 
  and stop bit to 1. Run the bit down the board to observe the serial communication
- I use SSCOM to listen for signals over the serial port, but any serial debugger will work
- <img src=".\resources\1_2.png" width="600"/>

5) Digital tube GPIO output, sw\[3:0\]=6, check gpio output.
- <img src=".\resources\1_3.jpg" width="300"/>

### Operate system
1) We provide pre-compiled operating system files [here](./resources/OS.bin). If you need to 
   modify, you can also follow the steps below
   1) Compile the bootloader
   - <img src=".\resources\2_1.png" width="600"/>
   2) Compile μC/OSII system
   - Since makefiles are built `.depend` files, you need to run `distclean` first to clear 
     dependencies.
   - <img src=".\resources\2_2.png" width="600"/>
   - <img src=".\resources\2_3.png" width="1000"/>
2) Configure the spi flash data and write it to the binary program file of the μC/OS II 
   operating system. You need to specify the [Configuration file](./resources/OS.bin).
- <img src=".\resources\3_1.png" width="500"/>

3) Serial Port Result
- Opens the serial port debugging, sets the baud rate to 19200 BPS, 8 data bits, 
  no parity bits, and 1 stop bit. Run the bit down the board to observe the serial 
  communication
- <img src=".\resources\3_2.png" width="600"/>

4) By uart, enter the first operator '5', the operator '-', and the second operator '2' 
   in order. The run ends when the final result is obtained.
- <img src=".\resources\3_3.png" width="600"/>

5) You can also try other operators.
- <img src=".\resources\3_4.png" width="600"/>

6) Digital tube GPIO output, sw\[3:0\]=6, check gpio output.
- <img src=".\resources\3_5.jpg" width="300"/>